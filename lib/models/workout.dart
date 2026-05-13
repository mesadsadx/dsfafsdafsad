import 'exercise.dart';

class Workout {
  final String date;
  final List<Exercise> exercises;

  const Workout({required this.date, required this.exercises});

  double get completionRatio {
    if (exercises.isEmpty) return 0;
    final total = exercises.fold(0, (sum, e) => sum + e.sets);
    final done = exercises.fold(0, (sum, e) => sum + e.completedCount);
    return total == 0 ? 0 : done / total;
  }

  Workout copyWith({List<Exercise>? exercises}) =>
      Workout(date: date, exercises: exercises ?? this.exercises);

  Map<String, dynamic> toMap() => {
    'date': date,
    'exercises': exercises.map((e) => e.toMap()).toList(),
  };

  factory Workout.fromMap(Map<String, dynamic> map) => Workout(
    date: map['date'] as String,
    exercises: (map['exercises'] as List)
        .map((e) => Exercise.fromMap(e as Map<String, dynamic>))
        .toList(),
  );
}
