import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../providers/jobs_provider.dart';
import 'job_card.dart';

/// Full list screen (also reachable from nested routes if needed).
class JobsListScreen extends ConsumerWidget {
  const JobsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(upcomingJobsProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.jobsListTitle)),
      body: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(upcomingJobsProvider),
            child: Text(l10n.retry),
          ),
        ),
        data: (jobs) {
          if (jobs.isEmpty) {
            return Center(child: Text(l10n.noJobs));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(upcomingJobsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: jobs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => JobCard(job: jobs[i]),
            ),
          );
        },
      ),
    );
  }
}
