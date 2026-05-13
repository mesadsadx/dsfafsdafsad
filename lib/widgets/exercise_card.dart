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

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${exercise.completedCount}/${exercise.sets}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
            const Gap(10),
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
    );
  }
}
