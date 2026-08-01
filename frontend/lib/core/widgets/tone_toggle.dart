import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../locale/tone_provider.dart';

/// Corporate/Street voice toggle — independent of the EN/TR language
/// selector (see core/locale/tone_provider.dart). Labels are intentionally
/// left untranslated, same treatment as the "EN"/"TR" language chips: they
/// name a mode, not a sentence to localize.
class ToneToggle extends ConsumerWidget {
  const ToneToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ref.watch(toneProvider);
    return SegmentedButton<AppTone>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: AppTone.corporate,
          tooltip: 'Corporate wording',
          icon: Icon(Icons.business_center, size: 16),
        ),
        ButtonSegment(
          value: AppTone.street,
          tooltip: 'Street/garage wording',
          icon: Icon(Icons.build, size: 16),
        ),
      ],
      selected: {tone},
      onSelectionChanged: (s) => ref.read(toneProvider.notifier).setTone(s.first),
    );
  }
}
