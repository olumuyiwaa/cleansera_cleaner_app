import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/job.dart';

class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job});

  final Job job;

  Color get _statusColor {
    switch (job.status) {
      case JobStatus.inProgress:
      case JobStatus.enRoute:
        return AppColors.primary;
      case JobStatus.completed:
        return AppColors.success;
      case JobStatus.cancelled:
      case JobStatus.noShow:
        return AppColors.error;
      case JobStatus.assigned:
      case JobStatus.confirmed:
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }

  String get _statusLabel {
    switch (job.status) {
      case JobStatus.inProgress:
        return 'In progress';
      case JobStatus.enRoute:
        return 'En route';
      case JobStatus.completed:
        return 'Completed';
      case JobStatus.cancelled:
        return 'Cancelled';
      case JobStatus.assigned:
        return 'Assigned';
      case JobStatus.confirmed:
        return 'Confirmed';
      case JobStatus.noShow:
        return 'No show';
      default:
        return job.status.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('h:mm a');
    final timeRange = job.scheduledEnd != null
        ? '${timeFmt.format(job.scheduledStart)} – ${timeFmt.format(job.scheduledEnd!)}'
        : timeFmt.format(job.scheduledStart);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/home/jobs/${job.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job.service?.name ?? 'Cleaning',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel,
                      style: TextStyle(
                        color: _statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    timeRange,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  if (job.service?.estimatedMinutes != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      '· ${job.service!.estimatedMinutes} min',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
              if (job.customer != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      job.customer!.fullName,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
              if (job.address != null) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        job.address!.fullAddress,
                        style: const TextStyle(color: AppColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
