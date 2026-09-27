import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../providers/earnings_provider.dart';
import '../data/earnings_repository.dart';

/// Soft nudge to connect Stripe for automatic payouts.
/// Never blocks viewing earnings — bank transfer / cash is fully supported.
class _StripeConnectBanner extends ConsumerWidget {
  const _StripeConnectBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(stripeConnectStatusProvider);
    final l10n = AppLocalizations.of(context);

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
                                ? l10n.finishConnectingStripe
                                : l10n.getPaidFasterWithStripe,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            status.message ?? l10n.stripeOptionalExplanation,
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
                    child: Text(isResume ? l10n.resumeStripeSetup : l10n.connectStripe),
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
    final l10n = AppLocalizations.of(context);
    try {
      final repo = ref.read(earningsRepositoryProvider);
      final url = await repo.fetchStripeOnboardingLink();
      final uri = Uri.parse(url);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.couldNotOpenStripeOnboarding)),
        );
      }
      ref.invalidate(stripeConnectStatusProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.couldNotStartOnboarding(e.toString()))),
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
    final l10n = AppLocalizations.of(context);
    final currency = NumberFormat.simpleCurrency(locale: l10n.localeName);
    final dateLabel = DateFormat('MMM d', l10n.localeName);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.earningsTitle)),
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
                        child: Text(l10n.couldNotLoadEarningsRetry),
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
                      children: [
                        const SizedBox(height: 100),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              children: [
                                const Icon(Icons.payments_outlined,
                                    size: 48, color: AppColors.textSecondary),
                                const SizedBox(height: 12),
                                Text(
                                  l10n.noEarningsYet,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l10n.noEarningsExplanation,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.textSecondary),
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
                                    Text(l10n.pending,
                                        style:
                                        const TextStyle(color: Colors.white70)),
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
                                    Text(l10n.paidToDate,
                                        style: const TextStyle(
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
                        l10n.businessPaysYouExplanation,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (summary.recentPayouts.isNotEmpty) ...[
                        Text(
                          l10n.recentPayouts,
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
                                    l10n.paidOn(dateLabel.format(p.paidAt!))
                                  else
                                    l10n.createdOn(dateLabel.format(p.createdAt)),
                                  if (p.method != null && p.method!.isNotEmpty)
                                    p.methodLabel(l10n),
                                  if (p.reference != null &&
                                      p.reference!.isNotEmpty)
                                    l10n.refNumber(p.reference!),
                                ].join(' · '),
                              ),
                              trailing: Chip(
                                label: Text(p.statusLabel(l10n)),
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
                        l10n.recentJobs,
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
                            Text(l10n.jobOn(dateLabel.format(entry.earnedAt))),
                            subtitle: Text(entry.statusLabel(l10n)),
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