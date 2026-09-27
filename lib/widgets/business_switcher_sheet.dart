import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/business_affiliation.dart';
import '../providers/auth_provider.dart';
import '../providers/earnings_provider.dart';
import '../providers/messaging_provider.dart';
import '../providers/profile_provider.dart';

/// Opens the "switch business" picker as a modal bottom sheet. Call this
/// from anywhere a cleaner might want to change which business they're
/// currently acting as (the Profile tab, the app bar, etc.) rather than
/// building the sheet inline each time.
Future<void> showBusinessSwitcherSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const BusinessSwitcherSheet(),
  );
}

/// Lets a cleaner who works for more than one business switch which one is
/// currently active, without signing out and back in. Reuses the same
/// backend endpoints the login-time picker uses to resolve an ambiguous
/// login — POST /auth/select-business — just without a password, since the
/// cleaner is already authenticated (see AuthNotifier.switchBusiness).
class BusinessSwitcherSheet extends ConsumerWidget {
  const BusinessSwitcherSheet({super.key});

  Future<void> _switchTo(
    BuildContext context,
    WidgetRef ref,
    BusinessAffiliation affiliation,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await ref.read(authProvider.notifier).switchBusiness(
          affiliation.businessId,
        );
    if (!context.mounted) return;

    if (!ok) {
      final error = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? l10n.couldNotSwitchBusiness)),
      );
      return;
    }

    // These don't watch authProvider, so a successful switch doesn't refresh
    // them on its own — clear the previous business's cached data now so the
    // cleaner never sees a stale conversation, document list, or earnings
    // total attributed to the wrong workspace.
    ref.invalidate(myConversationProvider);
    ref.invalidate(conversationsProvider);
    ref.invalidate(cleanerProfileProvider);
    ref.invalidate(availabilityProvider);
    ref.invalidate(documentsProvider);
    ref.invalidate(earningsProvider);
    ref.invalidate(stripeConnectStatusProvider);

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.switchedToBusiness(affiliation.businessName))),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final affiliationsAsync = ref.watch(affiliationsProvider);
    final currentBusinessId = ref.watch(authProvider).profile?.businessId;
    final switching = ref.watch(authProvider).isLoading;
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              l10n.switchBusiness,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.switchBusinessDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            affiliationsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Text(l10n.couldNotLoadBusinesses),
                    TextButton(
                      onPressed: () => ref.invalidate(affiliationsProvider),
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
              data: (affiliations) {
                if (affiliations.length <= 1) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      l10n.onlyOneBusiness,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final a in affiliations)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: a.businessId == currentBusinessId
                            ? AppColors.primaryLight.withValues(alpha: 0.1)
                            : null,
                        child: ListTile(
                          leading: const Icon(Icons.business_outlined,
                              color: AppColors.primary),
                          title: Text(a.businessName),
                          subtitle: Text(a.role),
                          trailing: a.businessId == currentBusinessId
                              ? const Icon(Icons.check_circle,
                                  color: AppColors.success)
                              : (switching
                                  ? null
                                  : const Icon(Icons.chevron_right)),
                          enabled: !switching && a.businessId != currentBusinessId,
                          onTap: () => _switchTo(context, ref, a),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
