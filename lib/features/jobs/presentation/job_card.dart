import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
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

  String _statusLabel(AppLocalizations l10n) {
    switch (job.status) {
      case JobStatus.inProgress:
        return l10n.jobStatusInProgress;
      case JobStatus.enRoute:
        return l10n.jobStatusEnRoute;
      case JobStatus.completed:
        return l10n.jobStatusCompleted;
      case JobStatus.cancelled:
        return l10n.jobStatusCancelled;
      case JobStatus.assigned:
        return l10n.jobStatusAssigned;
      case JobStatus.confirmed:
        return l10n.jobStatusConfirmed;
      case JobStatus.noShow:
        return l10n.jobStatusNoShow;
      default:
        return job.status.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final timeFmt = DateFormat('h:mm a', l10n.localeName);
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
                      job.service?.name ?? l10n.defaultServiceName,
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
                      _statusLabel(l10n),
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
                      l10n.estimatedMinutes(job.service!.estimatedMinutes),
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
