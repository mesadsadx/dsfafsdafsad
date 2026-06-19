import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/progression_config.dart';
import '../models/workout.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';

final progressionsProvider =
    StreamProvider<Map<String, ProgressionConfig>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchProgressions(uid);
});

final progressionConfigProvider =
    Provider.autoDispose.family<ProgressionConfig?, String>((ref, code) {
  return ref.watch(progressionsProvider).valueOrNull?[code];
});

final lastWorkoutProvider = FutureProvider.autoDispose<Workout?>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null || uid.isEmpty) return Future.value(null);
  return ref.read(firestoreServiceProvider).getLastWorkout(uid);
});

/// Returns 'AB' or 'CD' based on which groups the last workout contained.
final nextSessionProvider = Provider.autoDispose<String>((ref) {
  final configs = ref.watch(progressionsProvider).valueOrNull ?? {};
  final lastWorkout = ref.watch(lastWorkoutProvider).valueOrNull;

  if (lastWorkout == null) return 'AB';

  for (final ex in lastWorkout.exercises) {
    final group = configs[ex.code]?.group;
    if (group == 'A' || group == 'B') return 'CD';
    if (group == 'C' || group == 'D') return 'AB';
  }
  return 'AB';
});
