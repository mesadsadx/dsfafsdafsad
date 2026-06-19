import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exercise.dart';
import '../models/key_dictionary.dart';
import '../models/progression_config.dart';
import '../models/workout.dart';

class FirestoreService {
  final FirebaseFirestore _db;

  FirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  DocumentReference _settingsRef(String uid) =>
      _db.collection('users').doc(uid).collection('settings').doc('config');

  DocumentReference _workoutRef(String uid, String date) =>
      _db.collection('users').doc(uid).collection('workouts').doc(date);

  CollectionReference _workoutsRef(String uid) =>
      _db.collection('users').doc(uid).collection('workouts');

  CollectionReference _progressionsRef(String uid) =>
      _db.collection('users').doc(uid).collection('progressions');

  Future<void> saveKey1(
    String uid,
    String raw,
    KeyDictionary dictionary,
  ) async {
    await _settingsRef(uid).set({
      'key1_raw': raw,
      'dictionary': dictionary.toMap(),
    }, SetOptions(merge: true));
  }

  Future<KeyDictionary?> loadDictionary(String uid) async {
    final snap = await _settingsRef(uid).get();
    if (!snap.exists) return null;
    final data = snap.data() as Map<String, dynamic>?;
    if (data == null || !data.containsKey('dictionary')) return null;
    return KeyDictionary.fromMap(data['dictionary'] as Map<String, dynamic>);
  }

  Future<void> saveWorkout(String uid, Workout workout) async {
    await _workoutRef(uid, workout.date).set(workout.toMap());
  }

  Future<Workout?> loadWorkout(String uid, String date) async {
    final snap = await _workoutRef(uid, date).get();
    if (!snap.exists) return null;
    return Workout.fromMap(snap.data() as Map<String, dynamic>);
  }

  Stream<List<Workout>> watchMonthWorkouts(String uid, int year, int month) {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final lastDay = DateTime(year, month + 1, 0).day;
    final d = lastDay.toString().padLeft(2, '0');
    return _workoutsRef(uid)
        .where('date', isGreaterThanOrEqualTo: '$y-$m-01')
        .where('date', isLessThanOrEqualTo: '$y-$m-$d')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Workout.fromMap(d.data() as Map<String, dynamic>))
            .toList());
  }

  Future<void> toggleSet(
    String uid,
    String date,
    int exerciseIndex,
    int setIndex,
    bool newValue,
  ) async {
    final ref = _workoutRef(uid, date);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final exercises = List<Map<String, dynamic>>.from(
        (data['exercises'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      final sets = List<bool>.from(exercises[exerciseIndex]['completedSets'] as List);
      sets[setIndex] = newValue;
      exercises[exerciseIndex] = {...exercises[exerciseIndex], 'completedSets': sets};
      tx.update(ref, {'exercises': exercises});
    });
  }

  Future<void> addExercise(String uid, String date, Exercise exercise) async {
    final ref = _workoutRef(uid, date);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        final exercises = List<Map<String, dynamic>>.from(
          (data['exercises'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        exercises.add(exercise.toMap());
        tx.update(ref, {'exercises': exercises});
      } else {
        tx.set(ref, Workout(date: date, exercises: [exercise]).toMap());
      }
    });
  }

  Future<void> updateExercise(
    String uid,
    String date,
    int exerciseIndex,
    Exercise exercise,
  ) async {
    final ref = _workoutRef(uid, date);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final exercises = List<Map<String, dynamic>>.from(
        (data['exercises'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map)),
      );
      exercises[exerciseIndex] = exercise.toMap();
      tx.update(ref, {'exercises': exercises});
    });
  }

  Stream<Map<String, ProgressionConfig>> watchProgressions(String uid) {
    return _progressionsRef(uid).snapshots().map(
          (snap) => {
            for (final doc in snap.docs)
              doc.id: ProgressionConfig.fromFirestore(
                doc.id,
                doc.data() as Map<String, dynamic>,
              ),
          },
        );
  }

  Future<void> saveProgression(String uid, ProgressionConfig config) async {
    await _progressionsRef(uid)
        .doc(config.exerciseCode)
        .set(config.toFirestore());
  }

  Future<void> deleteProgression(String uid, String exerciseCode) async {
    await _progressionsRef(uid).doc(exerciseCode).delete();
  }

  /// Returns the most recent non-empty workout across all dates.
  Future<Workout?> getLastWorkout(String uid) async {
    final snaps = await _workoutsRef(uid)
        .orderBy('date', descending: true)
        .limit(10)
        .get();
    for (final doc in snaps.docs) {
      final workout = Workout.fromMap(doc.data() as Map<String, dynamic>);
      if (workout.exercises.isNotEmpty) return workout;
    }
    return null;
  }

  Future<void> addExercisesBatch(
    String uid,
    String date,
    List<Exercise> exercises,
  ) async {
    if (exercises.isEmpty) return;
    final ref = _workoutRef(uid, date);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        final existing = List<Map<String, dynamic>>.from(
          (data['exercises'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map)),
        );
        existing.addAll(exercises.map((e) => e.toMap()));
        tx.update(ref, {'exercises': existing});
      } else {
        tx.set(ref, Workout(date: date, exercises: exercises).toMap());
      }
    });
  }

  Future<void> deleteWorkout(String uid, String date) async {
    await _workoutRef(uid, date).delete();
  }

  Stream<List<String>> watchGroups(String uid) {
    return _settingsRef(uid).snapshots().map((snap) {
      if (!snap.exists) return <String>[];
      final data = snap.data() as Map<String, dynamic>?;
      final raw = data?['groups'];
      if (raw == null) return <String>[];
      return List<String>.from(raw as List);
    });
  }

  Future<void> saveGroups(String uid, List<String> groups) async {
    await _settingsRef(uid).set({'groups': groups}, SetOptions(merge: true));
  }

  Stream<List<String>> watchProgressionOrder(String uid) {
    return _settingsRef(uid).snapshots().map((snap) {
      if (!snap.exists) return <String>[];
      final data = snap.data() as Map<String, dynamic>?;
      final raw = data?['progressionOrder'];
      if (raw == null) return <String>[];
      return List<String>.from(raw as List);
    });
  }

  Future<void> saveProgressionOrder(String uid, List<String> order) async {
    await _settingsRef(uid).set({'progressionOrder': order}, SetOptions(merge: true));
  }

  /// Returns the most recent [Exercise] with [code] from the last [limit] workouts.
  Future<Exercise?> getLastExercise(String uid, String code, {int limit = 30}) async {
    final snaps = await _workoutsRef(uid)
        .orderBy('date', descending: true)
        .limit(limit)
        .get();
    for (final doc in snaps.docs) {
      final workout = Workout.fromMap(doc.data() as Map<String, dynamic>);
      for (final ex in workout.exercises) {
        if (ex.code == code) return ex;
      }
    }
    return null;
  }
}
