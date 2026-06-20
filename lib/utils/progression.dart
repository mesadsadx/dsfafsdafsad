import '../models/exercise.dart';
import '../models/progression_config.dart';

const _defaultLadder = [
  (3, 10), (3, 12), (3, 15),
  (4, 10), (4, 12), (4, 15),
  (5, 10), (5, 12), (5, 15),
  (6, 10), (6, 12), (6, 15),
];

const _defaultWeightStep = 2.5;
const _noProgressionCodes = {'BP'};

({double weight, int sets, int reps, bool isProgressed}) suggestExercise(
  Exercise last,
  ProgressionConfig? config,
) {
  final isStrength = config?.isStrength ?? true;

  if (config != null && config.isRepeating) {
    return (weight: isStrength ? last.weight : 0.0, sets: last.sets, reps: last.reps, isProgressed: false);
  }

  if (config != null && config.ladder.isNotEmpty) {
    final allDone = last.completedSets.every((c) => c);
    if (!allDone) {
      return (weight: isStrength ? last.weight : 0.0, sets: last.sets, reps: last.reps, isProgressed: false);
    }
    final stepIdx =
        config.ladder.indexWhere((s) => s.$1 == last.sets && s.$2 == last.reps);
    if (stepIdx == -1) {
      return (weight: isStrength ? last.weight : 0.0, sets: last.sets, reps: last.reps, isProgressed: false);
    }
    final weightIdx =
        config.weights.indexWhere((w) => (w - last.weight).abs() < 0.01);
    int nextStep = stepIdx + 1;
    int nextWeightIdx = weightIdx < 0 ? 0 : weightIdx;
    if (nextStep >= config.ladder.length) {
      nextStep = 0;
      if (!isStrength) {
        // No weights — just cycle the ladder from the top.
        final step = config.ladder[nextStep];
        return (weight: 0.0, sets: step.$1, reps: step.$2, isProgressed: true);
      }
      nextWeightIdx = (weightIdx < 0 ? 0 : weightIdx) + 1;
      if (nextWeightIdx >= config.weights.length) {
        return (
          weight: last.weight,
          sets: config.ladder.last.$1,
          reps: config.ladder.last.$2,
          isProgressed: false,
        );
      }
    }
    final nextWeight = isStrength
        ? (config.weights.isNotEmpty ? config.weights[nextWeightIdx] : last.weight)
        : 0.0;
    final step = config.ladder[nextStep];
    return (weight: nextWeight, sets: step.$1, reps: step.$2, isProgressed: true);
  }

  if (_noProgressionCodes.contains(last.code)) {
    return (weight: isStrength ? last.weight : 0.0, sets: last.sets, reps: last.reps, isProgressed: false);
  }

  final idx =
      _defaultLadder.indexWhere((s) => s.$1 == last.sets && s.$2 == last.reps);
  if (idx == -1) {
    return (weight: isStrength ? last.weight : 0.0, sets: last.sets, reps: last.reps, isProgressed: false);
  }
  final allDone = last.completedSets.every((c) => c);
  if (!allDone) {
    return (weight: isStrength ? last.weight : 0.0, sets: last.sets, reps: last.reps, isProgressed: false);
  }
  if (idx == _defaultLadder.length - 1) {
    final nextWeight = (isStrength && last.weight > 0) ? last.weight + _defaultWeightStep : 0.0;
    return (weight: nextWeight, sets: 3, reps: 10, isProgressed: true);
  }
  final next = _defaultLadder[idx + 1];
  return (weight: isStrength ? last.weight : 0.0, sets: next.$1, reps: next.$2, isProgressed: true);
}
