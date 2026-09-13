import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/jobs_provider.dart';
import '../../providers/offline_queue_provider.dart';

class ChecklistSection extends ConsumerWidget {
  const ChecklistSection({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checklistAsync = ref.watch(jobChecklistProvider(bookingId));
    final pendingItemIds = ref.watch(offlineChecklistQueueProvider)[bookingId] ?? const {};

    return checklistAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (checklist) {
        if (checklist.items.isEmpty) {
          return const SizedBox.shrink();
        }

        // Items completed while offline haven't round-tripped to the server
        // yet, so the fetched checklist doesn't know about them — merge the
        // queue's pending set in so the checkbox reflects what the cleaner
        // actually did, not just the last successful sync.
        final completedCount = checklist.items
            .where((i) => i.isCompleted || pendingItemIds.contains(i.id))
            .length;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      checklist.title ?? 'Checklist',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    if (pendingItemIds.isNotEmpty) ...[
                      const Icon(Icons.cloud_off, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      '$completedCount/${checklist.totalCount}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: checklist.totalCount == 0 ? 0 : completedCount / checklist.totalCount,
                  backgroundColor: AppColors.border,
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 6,
                ),
                if (pendingItemIds.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    "Offline — ${pendingItemIds.length} item${pendingItemIds.length == 1 ? '' : 's'} will sync once you're back online.",
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 12),
                ...checklist.items.map((item) {
                  final isPending = pendingItemIds.contains(item.id);
                  final isCompleted = item.isCompleted || isPending;
                  return CheckboxListTile(
                    value: isCompleted,
                    onChanged: isCompleted
                        ? null
                        : (_) {
                            ref
                                .read(offlineChecklistQueueProvider.notifier)
                                .completeItem(bookingId, item.id);
                          },
                    title: Text(
                      item.title,
                      style: TextStyle(
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                        color: isCompleted
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                    ),
                    subtitle: item.description != null
                        ? Text(item.description!)
                        : (isPending ? const Text('Syncing…') : null),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primary,
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
