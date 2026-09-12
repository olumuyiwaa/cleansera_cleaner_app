import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/earnings_provider.dart';

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  static const _daysBack = 84; // last 12 weeks

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earningsAsync = ref.watch(earningsProvider(_daysBack));
    final currency = NumberFormat.simpleCurrency();
    final weekLabel = DateFormat('MMM d');

    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(earningsProvider(_daysBack)),
        child: earningsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 80),
              Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(earningsProvider(_daysBack)),
                  child: const Text('Could not load earnings — retry'),
                ),
              ),
            ],
          ),
          data: (summary) {
            if (summary.jobCount == 0) {
              return ListView(
                children: const [
                  SizedBox(height: 100),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.payments_outlined,
                            size: 48, color: AppColors.textSecondary),
                        SizedBox(height: 12),
                        Text('No completed jobs in the last 12 weeks'),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'This reflects the value of jobs you\'ve completed — '
                    'it\'s not a payment record. Your business handles your '
                    'actual pay.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                Card(
                  color: AppColors.primary,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Last 12 weeks',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          currency.format(summary.totalCents / 100),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${summary.jobCount} completed job${summary.jobCount == 1 ? '' : 's'}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'By week',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                ...summary.byWeek.map(
                  (entry) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text('Week of ${weekLabel.format(entry.key)}'),
                      trailing: Text(
                        currency.format(entry.value / 100),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
