import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/earnings/data/earnings_repository.dart';

export '../features/earnings/data/earnings_repository.dart'
    show EarningsSummary, CleanerEarningEntry, CleanerPayoutEntry, StripeConnectStatus;

/// Real earnings from the business's payout ledger (see
/// cleansera_sass/src/modules/payroll) — what's pending, what's been paid,
/// and the recent job-by-job and payout history behind those totals. This
/// replaced an older version of this provider that computed a client-side
/// "value of completed jobs" estimate, because that number was never a real
/// payroll figure — a cleaner's actual pay depends on a rate their business
/// sets, which now lives on the backend as CleanerCompensation.
final earningsProvider = FutureProvider.autoDispose<EarningsSummary>((ref) async {
  final repo = ref.watch(earningsRepositoryProvider);
  return repo.fetchSummary();
});

/// Whether this cleaner can actually be paid automatically yet. Drives the
/// "Connect your payout account" banner on the earnings screen — until this
/// resolves payoutsEnabled: true, a business can still record a payout for
/// this cleaner, but the automated Stripe transfer path will reject it.
final stripeConnectStatusProvider = FutureProvider.autoDispose<StripeConnectStatus>((ref) async {
  final repo = ref.watch(earningsRepositoryProvider);
  return repo.fetchStripeStatus();
});
