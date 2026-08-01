import 'package:flutter/material.dart';
import '../../generated/app_localizations.dart';
import '../theme/app_theme.dart';

const kWorkOrderStatusOrder = ['draft', 'completed', 'paid'];
const _kStopIcon = {'draft': Icons.edit_note, 'completed': Icons.check_circle, 'paid': Icons.payments};

String _statusLabel(AppLocalizations l, String status) => switch (status) {
      'draft' => l.draft,
      'completed' => l.completed,
      'paid' => l.paid,
      _ => status,
    };

/// "The Pit Stop" — replaces the old flat status Chip with a game-style
/// progression stepper (Draft -> Completed -> Paid). [onAdvance] is called
/// when the CTA is tapped; the caller still owns confirmation dialogs
/// (e.g. payment method) exactly as WorkOrderDetailPanel did before.
class PitStopStepper extends StatelessWidget {
  const PitStopStepper({
    required this.status,
    required this.nextLabel,
    this.onAdvance,
    super.key,
  });

  final String status;
  final String? nextLabel; // e.g. "Mark as completed"; null when fully paid
  final VoidCallback? onAdvance;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final currentIndex = kWorkOrderStatusOrder.indexOf(status);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Text('🏁', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Text(l.thePitStop, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.textMuted)),
          ]),
          const SizedBox(height: 18),
          Row(
            children: [
              for (var i = 0; i < kWorkOrderStatusOrder.length; i++) ...[
                _Stop(
                  label: _statusLabel(l, kWorkOrderStatusOrder[i]),
                  icon: _kStopIcon[kWorkOrderStatusOrder[i]]!,
                  state: i < currentIndex
                      ? _StopState.done
                      : i == currentIndex
                          ? _StopState.current
                          : _StopState.upcoming,
                ),
                if (i < kWorkOrderStatusOrder.length - 1)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: i < currentIndex ? AppColors.neonGreen : AppColors.border,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
          if (nextLabel != null) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onAdvance,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text(nextLabel!),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.neonGreen,
                  foregroundColor: const Color(0xFF04170C),
                  shadowColor: AppColors.neonGreen.withValues(alpha: 0.5),
                  elevation: 6,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _StopState { done, current, upcoming }

class _Stop extends StatelessWidget {
  const _Stop({required this.label, required this.icon, required this.state});
  final String label;
  final IconData icon;
  final _StopState state;

  @override
  Widget build(BuildContext context) {
    final active = state != _StopState.upcoming;
    final color = active ? AppColors.neonGreen : AppColors.border;
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? const Color(0xFF12251A) : AppColors.surfaceRaised,
            border: Border.all(color: color, width: 2),
            boxShadow: state == _StopState.current
                ? [BoxShadow(color: AppColors.neonGreen.withValues(alpha: 0.55), blurRadius: 14, spreadRadius: 2)]
                : null,
          ),
          child: Icon(icon, size: 20, color: active ? AppColors.neonGreen : AppColors.textFaint),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: active ? AppColors.textHigh : AppColors.textFaint),
        ),
      ],
    );
  }
}
