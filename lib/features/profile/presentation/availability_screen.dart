import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/availability_slot.dart';
import '../../../providers/profile_provider.dart';

class AvailabilityScreen extends ConsumerWidget {
  const AvailabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availabilityAsync = ref.watch(availabilityProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.availabilityTitle)),
      body: availabilityAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l10n.failedToLoadAvailability),
              TextButton(
                onPressed: () => ref.invalidate(availabilityProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (slots) => _AvailabilityEditor(initialSlots: slots),
      ),
    );
  }
}

class _AvailabilityEditor extends ConsumerStatefulWidget {
  const _AvailabilityEditor({required this.initialSlots});

  final List<AvailabilitySlot> initialSlots;

  @override
  ConsumerState<_AvailabilityEditor> createState() =>
      _AvailabilityEditorState();
}

class _AvailabilityEditorState extends ConsumerState<_AvailabilityEditor> {
  late List<AvailabilitySlot> _slots;

  @override
  void initState() {
    super.initState();
    _slots = List.of(widget.initialSlots);
  }

  List<AvailabilitySlot> _slotsFor(int day) =>
      _slots.where((s) => s.dayOfWeek == day).toList();

  Future<TimeOfDay?> _pickTime(TimeOfDay initial) {
    return showTimePicker(context: context, initialTime: initial);
  }

  TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _addSlot(int day) {
    setState(() {
      _slots.add(AvailabilitySlot(
        dayOfWeek: day,
        startTime: '09:00',
        endTime: '17:00',
      ));
    });
  }

  void _removeSlot(AvailabilitySlot slot) {
    setState(() => _slots.remove(slot));
  }

  Future<void> _editStart(AvailabilitySlot slot) async {
    final picked = await _pickTime(_parseTime(slot.startTime));
    if (picked == null) return;
    setState(() {
      final idx = _slots.indexOf(slot);
      _slots[idx] = slot.copyWith(startTime: _formatTime(picked));
    });
  }

  Future<void> _editEnd(AvailabilitySlot slot) async {
    final picked = await _pickTime(_parseTime(slot.endTime));
    if (picked == null) return;
    setState(() {
      final idx = _slots.indexOf(slot);
      _slots[idx] = slot.copyWith(endTime: _formatTime(picked));
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final ok = await ref
        .read(profileActionsProvider.notifier)
        .updateAvailability(_slots);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? l10n.availabilitySaved : l10n.availabilitySaveFailed),
      ),
    );
  }

  /// weekdayLabels (models/availability_slot.dart) is a hardcoded English
  /// const list — fine as a fallback/reference, but not locale-aware, so
  /// this screen (its only usage site) reads day names from l10n instead.
  String _weekdayLabel(AppLocalizations l10n, int day) {
    switch (day) {
      case 1:
        return l10n.monday;
      case 2:
        return l10n.tuesday;
      case 3:
        return l10n.wednesday;
      case 4:
        return l10n.thursday;
      case 5:
        return l10n.friday;
      case 6:
        return l10n.saturday;
      case 7:
        return l10n.sunday;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionsState = ref.watch(profileActionsProvider);
    final busy = actionsState.isLoading;
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (int day = 1; day <= 7; day++) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _weekdayLabel(l10n, day),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                      onPressed: () => _addSlot(day),
                    ),
                  ],
                ),
                if (_slotsFor(day).isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      l10n.notAvailable,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                else
                  ..._slotsFor(day).map(
                    (slot) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Row(
                          children: [
                            TextButton(
                              onPressed: () => _editStart(slot),
                              child: Text(slot.startTime),
                            ),
                            const Text('–'),
                            TextButton(
                              onPressed: () => _editEnd(slot),
                              child: Text(slot.endTime),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.error),
                              onPressed: () => _removeSlot(slot),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ElevatedButton(
              onPressed: busy ? null : _save,
              child: Text(busy ? l10n.saving : l10n.saveAvailability),
            ),
          ),
        ),
      ],
    );
  }
}
