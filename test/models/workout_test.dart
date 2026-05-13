import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/models/exercise.dart';
import 'package:workout_tracker/models/workout.dart';

void main() {
  group('Exercise', () {
    test('completedSets defaults to all false', () {
      final ex = Exercise(code: 'A1', name: 'жим', weight: 60, sets: 3, reps: 10);
      expect(ex.completedSets, [false, false, false]);
    });

    test('completedCount counts true values', () {
      final ex = Exercise(
        code: 'A1', name: 'жим', weight: 60, sets: 4, reps: 8,
        completedSets: [true, false, true, false],
      );
      expect(ex.completedCount, 2);
    });

    test('completionRatio is 0.5 when half done', () {
      final ex = Exercise(
        code: 'A1', name: 'жим', weight: 60, sets: 4, reps: 8,
        completedSets: [true, false, true, false],
      );
      expect(ex.completionRatio, 0.5);
    });

    test('copyWith replaces completedSets', () {
      final ex = Exercise(code: 'A1', name: 'жим', weight: 60, sets: 2, reps: 10);
      final updated = ex.copyWith(completedSets: [true, false]);
      expect(updated.completedSets, [true, false]);
      expect(updated.code, 'A1');
    });

    test('round-trips through toMap/fromMap', () {
      final ex = Exercise(
        code: 'A1', name: 'жим лёжа', weight: 60.5, sets: 4, reps: 8,
        completedSets: [true, false, true, false],
      );
      final ex2 = Exercise.fromMap(ex.toMap());
      expect(ex2.code, ex.code);
      expect(ex2.weight, ex.weight);
      expect(ex2.completedSets, ex.completedSets);
    });
  });

  group('Workout', () {
    test('completionRatio aggregates all exercises', () {
      final w = Workout(date: '2026-05-13', exercises: [
        Exercise(
          code: 'A1', name: 'жим', weight: 60, sets: 4, reps: 8,
          completedSets: [true, true, false, false],
        ),
        Exercise(
          code: 'A2', name: 'тяга', weight: 40, sets: 2, reps: 12,
          completedSets: [true, false],
        ),
      ]);
      expect(w.completionRatio, 0.5);
    });

    test('completionRatio is 0 for empty exercises list', () {
      final w = Workout(date: '2026-05-13', exercises: []);
      expect(w.completionRatio, 0);
    });

    test('round-trips through toMap/fromMap', () {
      final w = Workout(date: '2026-05-11', exercises: [
        Exercise(code: 'A1', name: 'жим', weight: 60, sets: 3, reps: 10),
      ]);
      final w2 = Workout.fromMap(w.toMap());
      expect(w2.date, w.date);
      expect(w2.exercises.length, 1);
      expect(w2.exercises[0].name, 'жим');
    });
  });
}
