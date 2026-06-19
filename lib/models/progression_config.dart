class ProgressionConfig {
  final String exerciseCode;
  final bool isRepeating;
  final bool isStrength;
  final String? group; // null | 'A' | 'B' | 'C' | 'D'
  final List<double> weights;
  final List<(int, int)> ladder; // (sets, reps)

  const ProgressionConfig({
    required this.exerciseCode,
    this.isRepeating = false,
    this.isStrength = false,
    this.group,
    this.weights = const [],
    this.ladder = const [],
  });

  factory ProgressionConfig.fromFirestore(
    String code,
    Map<String, dynamic> data,
  ) {
    return ProgressionConfig(
      exerciseCode: code,
      isRepeating: (data['isRepeating'] as bool?) ?? false,
      isStrength: (data['isStrength'] as bool?) ?? false,
      group: data['group'] as String?,
      weights: ((data['weights'] as List?) ?? [])
          .map((w) => (w as num).toDouble())
          .toList(),
      ladder: ((data['ladder'] as List?) ?? []).map((s) {
        final parts = (s as String).split('x');
        return (int.parse(parts[0]), int.parse(parts[1]));
      }).toList(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'isRepeating': isRepeating,
        'isStrength': isStrength,
        if (group != null) 'group': group,
        'weights': weights,
        'ladder': ladder.map((s) => '${s.$1}x${s.$2}').toList(),
      };
}
