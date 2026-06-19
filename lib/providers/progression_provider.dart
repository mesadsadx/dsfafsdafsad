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

final progressionOrderProvider = StreamProvider<List<String>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchProgressionOrder(uid);
});

/// User-defined groups (ordered list, e.g. ["Спина", "Грудь", "Ноги"]).
final groupsProvider = StreamProvider<List<String>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchGroups(uid);
});

/// Returns the next group to train (circular rotation), or null if no groups.
/// Exercises with no group are always included regardless.
final nextSessionProvider = Provider.autoDispose<String?>((ref) {
  final groups = ref.watch(groupsProvider).valueOrNull ?? [];
  if (groups.isEmpty) return null;

  final configs = ref.watch(progressionsProvider).valueOrNull ?? {};
  final lastWorkout = ref.watch(lastWorkoutProvider).valueOrNull;

  if (lastWorkout == null) return groups.first;

  String? lastGroup;
  for (final ex in lastWorkout.exercises) {
    final g = configs[ex.code]?.group;
    if (g != null && groups.contains(g)) {
      lastGroup = g;
      break;
    }
  }

  if (lastGroup == null) return groups.first;
  final idx = groups.indexOf(lastGroup);
  return groups[(idx + 1) % groups.length];
});
