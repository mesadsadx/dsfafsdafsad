class Exercise {
  final String code;
  final String name;
  final double weight;
  final int sets;
  final int reps;
  final List<bool> completedSets;

  Exercise({
    required this.code,
    required this.name,
    required this.weight,
    required this.sets,
    required this.reps,
    List<bool>? completedSets,
  }) : completedSets = completedSets ?? List.filled(sets, false);

  int get completedCount => completedSets.where((s) => s).length;
  double get completionRatio => sets == 0 ? 0 : completedCount / sets;

  Exercise copyWith({List<bool>? completedSets}) => Exercise(
    code: code,
    name: name,
    weight: weight,
    sets: sets,
    reps: reps,
    completedSets: completedSets ?? List<bool>.from(this.completedSets),
  );

  Map<String, dynamic> toMap() => {
    'code': code,
    'name': name,
    'weight': weight,
    'sets': sets,
    'reps': reps,
    'completedSets': completedSets,
  };

  factory Exercise.fromMap(Map<String, dynamic> map) => Exercise(
    code: map['code'] as String,
    name: map['name'] as String,
    weight: (map['weight'] as num).toDouble(),
    sets: map['sets'] as int,
    reps: map['reps'] as int,
    completedSets: List<bool>.from(map['completedSets'] as List),
  );
}
