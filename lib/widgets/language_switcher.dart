import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_provider.dart';

/// Two-way EN/NL toggle — mirrors the web dashboard's LanguageSwitcher.tsx.
/// A plain pill of buttons rather than a dropdown, since there are only two
/// locales today: both options are visible at a glance instead of hiding
/// the current one behind a tap. Uses the current locale from
/// AppLocalizations.of(context) as the source of truth for which option is
/// highlighted, since that's already resolved (saved choice, else device
/// locale, else English) rather than re-deriving it from localeProvider's
/// raw (possibly still-null-before-restore) state.
class LanguageSwitcher extends ConsumerWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = AppLocalizations.of(context).localeName;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final locale in supportedLocales)
              _LocaleButton(
                label: locale.languageCode.toUpperCase(),
                selected: current == locale.languageCode,
                onTap: () =>
                    ref.read(localeProvider.notifier).setLocale(locale),
              ),
          ],
        ),
      ),
    );
  }
}

class _LocaleButton extends StatelessWidget {
  const _LocaleButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: selected ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
