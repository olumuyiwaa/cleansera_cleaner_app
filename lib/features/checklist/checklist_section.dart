import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/jobs_provider.dart';

class ChecklistSection extends ConsumerWidget {
  const ChecklistSection({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checklistAsync = ref.watch(jobChecklistProvider(bookingId));

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
                    Text(
                      '${checklist.completedCount}/${checklist.totalCount}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: checklist.progress,
                  backgroundColor: AppColors.border,
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 6,
                ),
                const SizedBox(height: 12),
                ...checklist.items.map((item) {
                  return CheckboxListTile(
                    value: item.isCompleted,
                    onChanged: item.isCompleted
                        ? null
                        : (_) {
                            ref
                                .read(jobActionsProvider.notifier)
                                .completeChecklistItem(item.id, bookingId);
                          },
                    title: Text(
                      item.title,
                      style: TextStyle(
                        decoration: item.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: item.isCompleted
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                    ),
                    subtitle: item.description != null
                        ? Text(item.description!)
                        : null,
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
