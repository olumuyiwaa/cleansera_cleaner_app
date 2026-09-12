import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/availability_slot.dart';
import '../../../providers/profile_provider.dart';

class AvailabilityScreen extends ConsumerWidget {
  const AvailabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availabilityAsync = ref.watch(availabilityProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Availability')),
      body: availabilityAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Failed to load availability'),
              TextButton(
                onPressed: () => ref.invalidate(availabilityProvider),
                child: const Text('Retry'),
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
    final ok = await ref
        .read(profileActionsProvider.notifier)
        .updateAvailability(_slots);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Availability saved' : 'Could not save. Try again.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actionsState = ref.watch(profileActionsProvider);
    final busy = actionsState.isLoading;

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
                        weekdayLabels[day],
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
                      'Not available',
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
              child: Text(busy ? 'Saving…' : 'Save availability'),
            ),
          ),
        ),
      ],
    );
  }
}
