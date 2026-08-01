import 'package:flutter_riverpod/flutter_riverpod.dart';
// Reuses the same conditional storage abstraction used by LocaleNotifier/TokenStorage:
//   web  → dart:html window.localStorage
//   native → flutter_secure_storage
import '../storage/_storage_stub.dart' if (dart.library.html) '../storage/_storage_web.dart';

/// Independent of language (see [LocaleNotifier]) — this picks the *voice*
/// the app's copy is written in. `street` is the playful "garage" wording
/// (the app's default); `corporate` is the original neutral/professional
/// wording. Implemented as a locale country-code variant ('CP') under the
/// hood — see `l10n/app_en_CP.arb` / `app_tr_CP.arb` and DECISIONS.md.
enum AppTone { street, corporate }

const _toneKey = 'tone_mode';

class ToneNotifier extends StateNotifier<AppTone> {
  ToneNotifier() : super(AppTone.street) {
    _load();
  }

  Future<void> _load() async {
    final saved = await storageRead(_toneKey);
    if (saved == AppTone.corporate.name) {
      state = AppTone.corporate;
    }
  }

  Future<void> setTone(AppTone tone) async {
    await storageWrite(_toneKey, tone.name);
    state = tone;
  }
}

final toneProvider = StateNotifierProvider<ToneNotifier, AppTone>((ref) => ToneNotifier());
