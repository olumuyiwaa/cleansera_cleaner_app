import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/earnings_provider.dart';
import '../data/earnings_repository.dart';

/// Soft nudge to connect Stripe for automatic payouts.
/// Never blocks viewing earnings — bank transfer / cash is fully supported.
class _StripeConnectBanner extends ConsumerWidget {
  const _StripeConnectBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(stripeConnectStatusProvider);

    return statusAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (status) {
        if (status.payoutsEnabled) return const SizedBox.shrink();

        final isResume = status.connected;
        return Card(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          color: AppColors.primary.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.account_balance_outlined,
                        color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isResume
                                ? 'Finish connecting Stripe (optional)'
                                : 'Get paid faster with Stripe (optional)',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            status.message ??
                                'Your business can already pay you by bank transfer or cash. '
                                    'Connect Stripe only if you want automatic deposits.',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _startOnboarding(context, ref),
                    child: Text(isResume ? 'Resume Stripe setup' : 'Connect Stripe'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _startOnboarding(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(earningsRepositoryProvider);
      final url = await repo.fetchStripeOnboardingLink();
      final uri = Uri.parse(url);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not open the Stripe onboarding page')),
        );
      }
      ref.invalidate(stripeConnectStatusProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start onboarding: $e')),
        );
      }
    }
  }
}

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earningsAsync = ref.watch(earningsProvider);
    final currency = NumberFormat.simpleCurrency();
    final dateLabel = DateFormat('MMM d');

    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: Column(
        children: [
          const _StripeConnectBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(earningsProvider);
                ref.invalidate(stripeConnectStatusProvider);
              },
              child: earningsAsync.when(
                loading: () =>
                const Center(child: CircularProgressIndicator()),
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
                      summary.recentEarnings.isNotEmpty ||
                      summary.recentPayouts.isNotEmpty;

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
                                      'pay rate for you and you complete a job. '
                                      'You do not need Stripe to get paid — '
                                      'your employer can use bank transfer or cash.',
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
                                        style:
                                        TextStyle(color: Colors.white70)),
                                    const SizedBox(height: 6),
                                    Text(
                                      currency
                                          .format(summary.pendingCents / 100),
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
                                        style: TextStyle(
                                            color: AppColors.textSecondary)),
                                    const SizedBox(height: 6),
                                    Text(
                                      currency.format(
                                          summary.lifetimePaidCents / 100),
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
                      const SizedBox(height: 12),
                      Text(
                        'Your business pays you — often by bank transfer or cash. '
                            'Stripe is optional for automatic deposits.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (summary.recentPayouts.isNotEmpty) ...[
                        Text(
                          'Recent payouts',
                          style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
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
                                [
                                  if (p.paidAt != null)
                                    'Paid ${dateLabel.format(p.paidAt!)}'
                                  else
                                    'Created ${dateLabel.format(p.createdAt)}',
                                  if (p.method != null && p.method!.isNotEmpty)
                                    p.methodLabel,
                                  if (p.reference != null &&
                                      p.reference!.isNotEmpty)
                                    'Ref ${p.reference}',
                                ].join(' · '),
                              ),
                              trailing: Chip(
                                label: Text(p.status),
                                backgroundColor: p.status == 'PAID'
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : Colors.orange.withValues(alpha: 0.15),
                                labelStyle: TextStyle(
                                  color: p.status == 'PAID'
                                      ? Colors.green
                                      : Colors.orange,
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
                        style:
                        Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...summary.recentEarnings.map(
                            (entry) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title:
                            Text('Job ${dateLabel.format(entry.earnedAt)}'),
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
          ),
        ],
      ),
    );
  }
}