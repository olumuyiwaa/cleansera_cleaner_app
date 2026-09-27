import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'generated/app_localizations.dart' show AppLocalizations;

const _prefsKey = 'app_locale_v1';

/// Supported locales, in the order shown by the language switcher.
const supportedLocales = AppLocalizations.supportedLocales;

class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(null) {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && supportedLocales.any((l) => l.languageCode == saved)) {
      state = Locale(saved);
      return;
    }
    // No explicit choice saved yet — leave state null so MaterialApp falls
    // back to its own localeResolutionCallback (device locale if supported,
    // else the first supported locale). Once the person picks a language
    // via the switcher, that choice is saved and always wins from then on.
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, locale.languageCode);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier();
});
