import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MechanicScore {
  const MechanicScore({required this.name, required this.jobsClosed});
  final String name;
  final int jobsClosed;
}

const _kAvatarColors = [AppColors.neonGreen, AppColors.electricBlue, AppColors.vividOrange, AppColors.textMuted];

/// "Top Wrench" — weekly leaderboard of mechanics by jobs closed, for the
/// dashboard/reports view. Not wired into any screen yet: `work_orders` has
/// no assigned-mechanic column (see DECISIONS.md), so there is no real data
/// to feed it. Feed it real data from a reports provider (e.g. group
/// workOrdersRepository results by assigned mechanic) once that column
/// exists; this widget only renders the ranked list + crown on #1.
class TopWrenchLeaderboard extends StatelessWidget {
  const TopWrenchLeaderboard({required this.scores, this.title = 'Top Wrench — This Week', super.key});
  final List<MechanicScore> scores;
  final String title;

  @override
  Widget build(BuildContext context) {
    final sorted = [...scores]..sort((a, b) => b.jobsClosed.compareTo(a.jobsClosed));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Text('🏆', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13.5)),
          ]),
          const SizedBox(height: 12),
          for (var i = 0; i < sorted.length; i++) _Row(rank: i + 1, score: sorted[i], color: _kAvatarColors[i % _kAvatarColors.length]),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.rank, required this.score, required this.color});
  final int rank;
  final MechanicScore score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final initial = score.name.isNotEmpty ? score.name[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text('$rank', style: AppFonts.mono(TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: rank == 1 ? AppColors.neonGreen : AppColors.textMuted))),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 17,
            backgroundColor: AppColors.surfaceRaised,
            child: Text(initial, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(score.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text('${score.jobsClosed} jobs closed', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          if (rank == 1) const Text('👑', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
