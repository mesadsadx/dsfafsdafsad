import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';

final lastExerciseProvider =
    FutureProvider.autoDispose.family<Exercise?, String>((ref, code) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null || uid.isEmpty) return null;
  return ref.read(firestoreServiceProvider).getLastExercise(uid, code);
});

final monthWorkoutsProvider =
    StreamProvider.family<List<Workout>, ({int year, int month})>(
  (ref, params) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    if (uid == null) return const Stream.empty();
    return ref
        .watch(firestoreServiceProvider)
        .watchMonthWorkouts(uid, params.year, params.month);
  },
);

class WorkoutNotifier extends StateNotifier<AsyncValue<Workout?>> {
  final FirestoreService _service;
  final String _uid;
  final String _date;

  WorkoutNotifier(this._service, this._uid, this._date)
      : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    if (_uid.isEmpty) {
      state = const AsyncValue.data(null);
      return;
    }
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _service.loadWorkout(_uid, _date));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleSet(int exerciseIndex, int setIndex) async {
    if (_uid.isEmpty) return;
    final workout = state.valueOrNull;
    if (workout == null) return;

    final previousState = state;
    final newCompleted =
        List<bool>.from(workout.exercises[exerciseIndex].completedSets);
    newCompleted[setIndex] = !newCompleted[setIndex];

    final newExercises = List<Exercise>.from(workout.exercises);
    newExercises[exerciseIndex] =
        workout.exercises[exerciseIndex].copyWith(completedSets: newCompleted);

    state = AsyncValue.data(workout.copyWith(exercises: newExercises));
    try {
      await _service.toggleSet(
          _uid, _date, exerciseIndex, setIndex, newCompleted[setIndex]);
    } catch (_) {
      state = previousState;
    }
  }

  Future<void> updateExercise(int exerciseIndex, Exercise updated) async {
    if (_uid.isEmpty) return;
    final workout = state.valueOrNull;
    if (workout == null) return;
    final previousState = state;
    final newExercises = List<Exercise>.from(workout.exercises);
    newExercises[exerciseIndex] = updated;
    state = AsyncValue.data(workout.copyWith(exercises: newExercises));
    try {
      await _service.updateExercise(_uid, _date, exerciseIndex, updated);
    } catch (_) {
      state = previousState;
    }
  }

  Future<void> addExercise(Exercise exercise) async {
    if (_uid.isEmpty) return;
    final workout = state.valueOrNull;
    final previousState = state;
    final newExercises = <Exercise>[...(workout?.exercises ?? []), exercise];
    state = AsyncValue.data(Workout(date: _date, exercises: newExercises));
    try {
      await _service.addExercise(_uid, _date, exercise);
    } catch (_) {
      state = previousState;
    }
  }
}

final workoutNotifierProvider = StateNotifierProvider.family<WorkoutNotifier,
    AsyncValue<Workout?>, String>(
  (ref, date) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final service = ref.watch(firestoreServiceProvider);
    return WorkoutNotifier(service, uid, date);
  },
);
