import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Reuses the same conditional storage abstraction used by TokenStorage:
//   web  → dart:html window.localStorage
//   native → flutter_secure_storage
import '../storage/_storage_stub.dart' if (dart.library.html) '../storage/_storage_web.dart';

const _localeKey = 'locale_code';

/// Whether the EN/TR language-switcher UI (login, register, join, app-shell
/// menu) is shown. Turned off per Farzad's request after first user testing
/// — all users are Turkish for now — until he asks to bring it back. Both
/// ARB files must keep being maintained regardless of this flag; only the
/// switcher UI is hidden, not the underlying localization.
const kLanguageToggleVisible = false;

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('tr')) {
    _load();
  }

  Future<void> _load() async {
    // While the switcher is hidden, ignore any locale a browser already had
    // saved from before this change (or from a prior test session) — every
    // user gets Turkish, full stop, not just new sessions with no saved
    // value yet. Re-enabling kLanguageToggleVisible restores respect for
    // whatever's actually stored.
    if (!kLanguageToggleVisible) return;
    final code = await storageRead(_localeKey);
    if (code != null && _supported.contains(code)) {
      state = Locale(code);
    }
  }

  Future<void> setLocale(Locale locale) async {
    await storageWrite(_localeKey, locale.languageCode);
    state = locale;
  }

  static const List<String> _supported = ['en', 'tr'];
}

final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale>((ref) => LocaleNotifier());
