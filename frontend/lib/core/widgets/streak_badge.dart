import 'package:flutter/material.dart';
import '../../generated/app_localizations.dart';
import '../theme/app_theme.dart';

/// "Grease Monkey" streak — daily count of completed work orders, shown as a
/// glowing flame pill in the AppBar. Fed by `streakDaysProvider`
/// (frontend/lib/features/reports/application/reports_provider.dart), which
/// derives it from real paid work-order dates — not mock data.
class StreakBadge extends StatelessWidget {
  const StreakBadge({required this.days, super.key});
  final int days;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final lit = days > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: lit ? [const Color(0xFF241A0C), const Color(0xFF1A1409)] : [AppColors.surfaceRaised, AppColors.surfaceRaised],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: lit ? AppColors.vividOrange.withValues(alpha: 0.35) : AppColors.border),
        boxShadow: lit
            ? [BoxShadow(color: AppColors.vividOrange.withValues(alpha: 0.25), blurRadius: 10, spreadRadius: 1)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔥', style: TextStyle(fontSize: 15, color: lit ? null : AppColors.textFaint)),
          const SizedBox(width: 6),
          Text(
            '$days',
            style: AppFonts.mono(TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: lit ? AppColors.vividOrange : AppColors.textFaint,
            )),
          ),
          const SizedBox(width: 6),
          Text(
            l.dayStreak,
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: lit ? const Color(0xFFC98A55) : AppColors.textFaint),
          ),
        ],
      ),
    );
  }
}
