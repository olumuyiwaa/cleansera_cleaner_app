import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/jobs/data/jobs_repository.dart';
import '../models/checklist.dart';
import '../models/job.dart';
import 'auth_provider.dart';

/// Today's jobs for the authenticated cleaner.
final todayJobsProvider = FutureProvider.autoDispose<List<Job>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return [];

  final repo = ref.watch(jobsRepositoryProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final end = start.add(const Duration(days: 1));

  final jobs = await repo.fetchMyJobs(from: start, to: end);
  jobs.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
  return jobs;
});

/// Upcoming (next 7 days excluding today optional filter handled in UI).
final upcomingJobsProvider =
    FutureProvider.autoDispose<List<Job>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return [];

  final repo = ref.watch(jobsRepositoryProvider);
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day);
  final to = from.add(const Duration(days: 14));

  final jobs = await repo.fetchMyJobs(from: from, to: to);
  jobs.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
  return jobs;
});

final jobDetailProvider =
    FutureProvider.autoDispose.family<Job, String>((ref, id) async {
  final repo = ref.watch(jobsRepositoryProvider);
  return repo.fetchJob(id);
});

final jobChecklistProvider =
    FutureProvider.autoDispose.family<JobChecklist, String>((ref, bookingId) {
  final repo = ref.watch(jobsRepositoryProvider);
  return repo.fetchChecklist(bookingId);
});

class JobActionsNotifier extends StateNotifier<AsyncValue<void>> {
  JobActionsNotifier(this._repo, this._ref) : super(const AsyncData(null));

  final JobsRepository _repo;
  final Ref _ref;

  Future<Job?> checkIn(String jobId, {double? lat, double? lng}) async {
    state = const AsyncLoading();
    try {
      final job = await _repo.checkIn(jobId, lat: lat, lng: lng);
      _invalidate(jobId);
      state = const AsyncData(null);
      return job;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  Future<Job?> start(String jobId) async {
    state = const AsyncLoading();
    try {
      final job = await _repo.startJob(jobId);
      _invalidate(jobId);
      state = const AsyncData(null);
      return job;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  Future<Job?> complete(String jobId, {String? notes}) async {
    state = const AsyncLoading();
    try {
      final job = await _repo.completeJob(jobId, notes: notes);
      _invalidate(jobId);
      state = const AsyncData(null);
      return job;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  Future<void> completeChecklistItem(String itemId, String bookingId) async {
    state = const AsyncLoading();
    try {
      await _repo.completeChecklistItem(bookingId, itemId);
      _ref.invalidate(jobChecklistProvider(bookingId));
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<bool> sendOnMyWay(String jobId) async {
    state = const AsyncLoading();
    try {
      await _repo.sendOnMyWay(jobId);
      _invalidate(jobId);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  /// Full photo-proof flow in one call: presigned URL -> upload bytes ->
  /// register against the booking -> refresh the job so canComplete/
  /// hasAfterPhoto reflect the new photo immediately.
  Future<bool> uploadJobPhoto(
    String jobId, {
    required String stage,
    required List<int> bytes,
    String contentType = 'image/jpeg',
    String? filename,
  }) async {
    state = const AsyncLoading();
    try {
      final target = await _repo.getPhotoUploadUrl(
        jobId,
        stage: stage,
        contentType: contentType,
        filename: filename,
      );
      await _repo.uploadPhotoBytes(target.uploadUrl, bytes, contentType: contentType);
      await _repo.createJobPhoto(jobId, stage: stage, storageKey: target.storageKey);
      _invalidate(jobId);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  void _invalidate(String jobId) {
    _ref.invalidate(todayJobsProvider);
    _ref.invalidate(upcomingJobsProvider);
    _ref.invalidate(jobDetailProvider(jobId));
  }
}

final jobActionsProvider =
    StateNotifierProvider<JobActionsNotifier, AsyncValue<void>>((ref) {
  return JobActionsNotifier(ref.watch(jobsRepositoryProvider), ref);
});
