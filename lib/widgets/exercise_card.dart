import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../app/theme.dart';
import '../models/exercise.dart';
import 'set_row.dart';

class ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final int exerciseIndex;
  final void Function(int exerciseIndex, int setIndex) onSetToggle;

  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.exerciseIndex,
    required this.onSetToggle,
  });

  Color _accentColor(double ratio) {
    if (ratio == 0) return AppColors.textMuted;
    if (ratio < 0.5) return AppColors.heatmap50;
    if (ratio < 1.0) return AppColors.heatmap75;
    return AppColors.accent;
  }

  @override
  Widget build(BuildContext context) {
    final ratio = exercise.completionRatio;
    final accent = _accentColor(ratio);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceVariant,
            AppColors.surface,
          ],
        ),
        border: Border.all(
          color: accent.withOpacity(ratio > 0 ? 0.25 : 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          if (ratio == 1.0)
            BoxShadow(
              color: AppColors.accent.withOpacity(0.08),
              blurRadius: 16,
              spreadRadius: 2,
            ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // left accent bar
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 3,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                color: accent,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            exercise.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _CompletionRing(
                          completed: exercise.completedCount,
                          total: exercise.sets,
                          color: accent,
                        ),
                      ],
                    ),
                    const Gap(12),
                    ...List.generate(
                      exercise.sets,
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: SetRow(
                          index: i,
                          weight: exercise.weight,
                          reps: exercise.reps,
                          completed: exercise.completedSets[i],
                          onTap: () => onSetToggle(exerciseIndex, i),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionRing extends StatelessWidget {
  final int completed;
  final int total;
  final Color color;

  const _CompletionRing({
    required this.completed,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: total > 0 ? completed / total : 0,
            backgroundColor: AppColors.divider,
            valueColor: AlwaysStoppedAnimation(color),
            strokeWidth: 3,
            strokeCap: StrokeCap.round,
          ),
          Text(
            completed == total && total > 0 ? '✓' : '$completed',
            style: TextStyle(
              fontSize: completed == total && total > 0 ? 14 : 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
