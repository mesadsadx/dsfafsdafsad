import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../services/haptic_service.dart';

class SetRow extends StatelessWidget {
  final int index;
  final double weight;
  final int reps;
  final bool completed;
  final VoidCallback onTap;

  const SetRow({
    super.key,
    required this.index,
    required this.weight,
    required this.reps,
    required this.completed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isBodyweight = weight == 0;
    final isTimed = isBodyweight && reps >= 30;
    final weightStr = isBodyweight
        ? 'Вес тела'
        : '${weight % 1 == 0 ? weight.toInt() : weight} кг';
    final repsStr = isTimed ? '$reps сек.' : '$reps повт.';

    return GestureDetector(
      onTap: () {
        if (completed) {
          HapticService.setUndo();
        } else {
          HapticService.setComplete();
        }
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: completed
              ? AppColors.surfaceVariant.withValues(alpha: 0.5)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: completed
                      ? AppColors.textMuted
                      : AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: completed
                      ? AppColors.textMuted
                      : AppColors.textPrimary,
                  decoration:
                      completed ? TextDecoration.lineThrough : null,
                  decorationColor: AppColors.textMuted,
                  fontSize: 14,
                ),
                child: Text(
                  isBodyweight
                      ? '$weightStr  ×  $repsStr'
                      : '$weightStr  ×  $repsStr',
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: completed ? AppColors.accent : Colors.transparent,
                border: Border.all(
                  color: completed
                      ? AppColors.accent
                      : AppColors.textMuted,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: completed
                  ? const Icon(Icons.check, size: 13, color: Colors.black)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
