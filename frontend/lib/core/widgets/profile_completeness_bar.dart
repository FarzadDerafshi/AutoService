import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Gamified "Garage Completeness" progress bar for Client/Vehicle forms.
/// Pass the set of fields that count toward completeness as (label, filled)
/// pairs; the widget computes the percentage and renders a glowing bar plus
/// a nudge naming the next missing field.
class ProfileCompletenessBar extends StatelessWidget {
  const ProfileCompletenessBar({required this.fields, this.title = 'Garage Completeness', super.key});
  final List<(String label, bool filled)> fields;
  final String title;

  @override
  Widget build(BuildContext context) {
    final total = fields.length;
    final done = fields.where((f) => f.$2).length;
    final pct = total == 0 ? 0.0 : done / total;
    final missing = fields.where((f) => !f.$2).map((f) => f.$1).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppFonts.header(const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
              Text('${(pct * 100).round()}%', style: AppFonts.mono(const TextStyle(fontWeight: FontWeight.w700, color: AppColors.neonGreen))),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: const Color(0xFF1A232B),
              valueColor: const AlwaysStoppedAnimation(AppColors.neonGreen),
            ),
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              pct >= 1
                  ? 'Fully tuned! 🔧'
                  : 'Add ${missing.take(2).join(' + ')} to level up.',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Fully tuned! 🔧', style: TextStyle(fontSize: 11, color: AppColors.neonGreen)),
            ),
        ],
      ),
    );
  }
}
