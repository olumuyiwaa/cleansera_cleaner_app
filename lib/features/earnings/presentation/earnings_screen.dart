import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/earnings_provider.dart';

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earningsAsync = ref.watch(earningsProvider);
    final currency = NumberFormat.simpleCurrency();
    final dateLabel = DateFormat('MMM d');

    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(earningsProvider),
        child: earningsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 80),
              Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(earningsProvider),
                  child: const Text('Could not load earnings — retry'),
                ),
              ),
            ],
          ),
          data: (summary) {
            final hasAnyData = summary.pendingCents > 0 ||
                summary.lifetimePaidCents > 0 ||
                summary.recentEarnings.isNotEmpty;

            if (!hasAnyData) {
              return ListView(
                children: const [
                  SizedBox(height: 100),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          Icon(Icons.payments_outlined,
                              size: 48, color: AppColors.textSecondary),
                          SizedBox(height: 12),
                          Text(
                            'No earnings yet',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Earnings show up here once your business sets a '
                            'pay rate for you and you complete a job.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: AppColors.primary,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Pending',
                                  style: TextStyle(color: Colors.white70)),
                              const SizedBox(height: 6),
                              Text(
                                currency.format(summary.pendingCents / 100),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Paid to date',
                                  style:
                                      TextStyle(color: AppColors.textSecondary)),
                              const SizedBox(height: 6),
                              Text(
                                currency.format(summary.lifetimePaidCents / 100),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (summary.recentPayouts.isNotEmpty) ...[
                  Text(
                    'Recent payouts',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...summary.recentPayouts.map(
                    (p) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(currency.format(p.totalCents / 100)),
                        subtitle: Text(
                          p.paidAt != null
                              ? 'Paid ${dateLabel.format(p.paidAt!)}'
                              : 'Created ${dateLabel.format(p.createdAt)}',
                        ),
                        trailing: Chip(
                          label: Text(p.status),
                          backgroundColor: p.status == 'PAID'
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.orange.withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            color:
                                p.status == 'PAID' ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Text(
                  'Recent jobs',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                ...summary.recentEarnings.map(
                  (entry) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text('Job ${dateLabel.format(entry.earnedAt)}'),
                      subtitle: Text(entry.status),
                      trailing: Text(
                        currency.format(entry.amountCents / 100),
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
