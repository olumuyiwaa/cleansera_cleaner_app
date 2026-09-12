import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/jobs/data/jobs_repository.dart';
import '../models/job.dart';

class EarningsSummary {
  const EarningsSummary({
    required this.jobs,
    required this.totalCents,
    required this.jobCount,
    required this.byWeek,
  });

  final List<Job> jobs;
  final int totalCents;
  final int jobCount;

  /// Monday-of-week (as a date-only DateTime) -> total cents earned that
  /// week, most recent week first.
  final List<MapEntry<DateTime, int>> byWeek;

  static const empty = EarningsSummary(
    jobs: [],
    totalCents: 0,
    jobCount: 0,
    byWeek: [],
  );
}

DateTime _startOfWeek(DateTime d) {
  final date = DateTime(d.year, d.month, d.day);
  return date.subtract(Duration(days: date.weekday - 1)); // Monday
}

/// Earnings are informational only: CleanSera doesn't process payroll
/// between a cleaner and their business (see /areas/cleansera.md gap
/// notes), so there's no backend ledger of actual payouts to read. This is
/// the value of jobs the cleaner has completed, computed client-side from
/// the same /cleaner/bookings/my data the Jobs tab already uses — a stated
/// estimate of what they've earned the business, not a payment record.
final earningsProvider =
    FutureProvider.autoDispose.family<EarningsSummary, int>((ref, daysBack) async {
  final repo = ref.watch(jobsRepositoryProvider);
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: daysBack));

  final jobs = await repo.fetchMyJobs(from: from, to: now, status: 'COMPLETED');
  if (jobs.isEmpty) return EarningsSummary.empty;

  final totalCents = jobs.fold<int>(0, (sum, j) => sum + (j.totalCents ?? 0));

  final Map<DateTime, int> weekTotals = {};
  for (final j in jobs) {
    final weekStart = _startOfWeek(j.scheduledStart);
    weekTotals[weekStart] = (weekTotals[weekStart] ?? 0) + (j.totalCents ?? 0);
  }
  final byWeek = weekTotals.entries.toList()
    ..sort((a, b) => b.key.compareTo(a.key));

  return EarningsSummary(
    jobs: jobs,
    totalCents: totalCents,
    jobCount: jobs.length,
    byWeek: byWeek,
  );
});
