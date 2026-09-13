import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/jobs/data/jobs_repository.dart';
import 'jobs_provider.dart';

const _prefsKey = 'offline_checklist_queue_v1';

class _QueuedItem {
  _QueuedItem({required this.bookingId, required this.itemId, required this.done});

  final String bookingId;
  final String itemId;
  final bool done;

  Map<String, dynamic> toJson() => {'bookingId': bookingId, 'itemId': itemId, 'done': done};

  factory _QueuedItem.fromJson(Map<String, dynamic> json) => _QueuedItem(
        bookingId: json['bookingId'] as String,
        itemId: json['itemId'] as String,
        done: json['done'] as bool? ?? true,
      );
}

/// Lets a cleaner keep checking off checklist items while offline (a real
/// scenario — a lot of residential jobs happen in basements or buildings
/// with poor signal). Ticking an item tries the network first; if that
/// fails, the action is persisted locally and the item shows as done in the
/// UI immediately (optimistic), then replayed automatically the next time
/// connectivity comes back.
///
/// Safe to replay blindly because the backend endpoint
/// (POST /checklists/:bookingId/items/:itemId/complete) sets `done` to an
/// explicit value rather than toggling — sending the same completion twice
/// is a no-op, not a double-toggle bug.
class OfflineChecklistQueue extends StateNotifier<Map<String, Set<String>>> {
  OfflineChecklistQueue(this._ref) : super({}) {
    _restore();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) flush();
    });
  }

  final Ref _ref;
  final List<_QueuedItem> _queue = [];
  bool _flushing = false;
  late final dynamic _sub;

  JobsRepository get _repo => _ref.read(jobsRepositoryProvider);

  bool isPending(String bookingId, String itemId) =>
      state[bookingId]?.contains(itemId) ?? false;

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List)
          .map((e) => _QueuedItem.fromJson(e as Map<String, dynamic>))
          .toList();
      _queue.addAll(list);
      _rebuildState();
      // Try to flush immediately in case we launched already online with a
      // backlog from a previous offline session.
      unawaited(flush());
    } catch (e) {
      debugPrint('OfflineChecklistQueue: restore failed ($e)');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_queue.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('OfflineChecklistQueue: persist failed ($e)');
    }
  }

  void _rebuildState() {
    final map = <String, Set<String>>{};
    for (final q in _queue) {
      map.putIfAbsent(q.bookingId, () => {}).add(q.itemId);
    }
    state = map;
  }

  /// Attempts the completion immediately; on any failure that looks like a
  /// connectivity problem, queues it instead of surfacing an error to the
  /// cleaner mid-job. Returns true either way (queued counts as "handled"
  /// from the UI's perspective) so the checkbox can tick immediately.
  Future<bool> completeItem(String bookingId, String itemId, {bool done = true}) async {
    try {
      await _repo.completeChecklistItem(bookingId, itemId, done: done);
      _ref.invalidate(jobChecklistProvider(bookingId));
      return true;
    } catch (e) {
      _queue.add(_QueuedItem(bookingId: bookingId, itemId: itemId, done: done));
      _rebuildState();
      unawaited(_persist());
      return true;
    }
  }

  Future<void> flush() async {
    if (_flushing || _queue.isEmpty) return;
    _flushing = true;
    try {
      final remaining = <_QueuedItem>[];
      final touchedBookings = <String>{};
      for (final q in List<_QueuedItem>.from(_queue)) {
        try {
          await _repo.completeChecklistItem(q.bookingId, q.itemId, done: q.done);
          touchedBookings.add(q.bookingId);
        } catch (e) {
          // Still offline (or a real server error) — keep it queued and
          // stop here; we'll retry the whole remaining batch next time
          // connectivity comes back rather than spamming a failing request.
          remaining.add(q);
          remaining.addAll(_queue.skipWhile((x) => x != q).skip(1));
          break;
        }
      }
      _queue
        ..clear()
        ..addAll(remaining);
      _rebuildState();
      await _persist();
      for (final bookingId in touchedBookings) {
        _ref.invalidate(jobChecklistProvider(bookingId));
      }
    } finally {
      _flushing = false;
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final offlineChecklistQueueProvider =
    StateNotifierProvider<OfflineChecklistQueue, Map<String, Set<String>>>((ref) {
  return OfflineChecklistQueue(ref);
});
