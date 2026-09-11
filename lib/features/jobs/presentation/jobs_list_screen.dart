import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/jobs_provider.dart';
import 'job_card.dart';

/// Full list screen (also reachable from nested routes if needed).
class JobsListScreen extends ConsumerWidget {
  const JobsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(upcomingJobsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('All jobs')),
      body: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(upcomingJobsProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (jobs) {
          if (jobs.isEmpty) {
            return const Center(child: Text('No jobs'));
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
