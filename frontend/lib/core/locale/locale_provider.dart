import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Reuses the same conditional storage abstraction used by TokenStorage:
//   web  → dart:html window.localStorage
//   native → flutter_secure_storage
import '../storage/_storage_stub.dart' if (dart.library.html) '../storage/_storage_web.dart';

const _localeKey = 'locale_code';

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en')) {
    _load();
  }

  Future<void> _load() async {
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
