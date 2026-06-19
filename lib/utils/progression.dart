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
  if (config != null && config.isRepeating) {
    return (weight: last.weight, sets: last.sets, reps: last.reps, isProgressed: false);
  }

  if (config != null && config.ladder.isNotEmpty) {
    final allDone = last.completedSets.every((c) => c);
    if (!allDone) {
      return (weight: last.weight, sets: last.sets, reps: last.reps, isProgressed: false);
    }
    final stepIdx =
        config.ladder.indexWhere((s) => s.$1 == last.sets && s.$2 == last.reps);
    if (stepIdx == -1) {
      return (weight: last.weight, sets: last.sets, reps: last.reps, isProgressed: false);
    }
    final weightIdx =
        config.weights.indexWhere((w) => (w - last.weight).abs() < 0.01);
    int nextStep = stepIdx + 1;
    int nextWeightIdx = weightIdx < 0 ? 0 : weightIdx;
    if (nextStep >= config.ladder.length) {
      nextStep = 0;
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
    final nextWeight =
        config.weights.isNotEmpty ? config.weights[nextWeightIdx] : last.weight;
    final step = config.ladder[nextStep];
    return (weight: nextWeight, sets: step.$1, reps: step.$2, isProgressed: true);
  }

  if (_noProgressionCodes.contains(last.code)) {
    return (weight: last.weight, sets: last.sets, reps: last.reps, isProgressed: false);
  }

  final idx =
      _defaultLadder.indexWhere((s) => s.$1 == last.sets && s.$2 == last.reps);
  if (idx == -1) {
    return (weight: last.weight, sets: last.sets, reps: last.reps, isProgressed: false);
  }
  final allDone = last.completedSets.every((c) => c);
  if (!allDone) {
    return (weight: last.weight, sets: last.sets, reps: last.reps, isProgressed: false);
  }
  if (idx == _defaultLadder.length - 1) {
    final nextWeight = last.weight > 0 ? last.weight + _defaultWeightStep : 0.0;
    return (weight: nextWeight, sets: 3, reps: 10, isProgressed: true);
  }
  final next = _defaultLadder[idx + 1];
  return (weight: last.weight, sets: next.$1, reps: next.$2, isProgressed: true);
}
