import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../models/exercise.dart';
import '../models/key_dictionary.dart';
import '../models/workout.dart';

class KeyCodecException implements Exception {
  final String message;
  const KeyCodecException(this.message);
  @override
  String toString() => 'KeyCodecException: $message';
}

class KeyCodec {
  // Handles: whitespace, URL-safe chars, missing padding
  static Uint8List _decodeRobust(String input) {
    var s = input.replaceAll(RegExp(r'\s'), ''); // strip all whitespace
    s = s.replaceAll('-', '+').replaceAll('_', '/'); // url-safe → standard
    switch (s.length % 4) {
      case 2: s += '=='; break;
      case 3: s += '='; break;
      default: break;
    }
    return base64Decode(s);
  }

  static KeyDictionary decodeKey1(String base64String) {
    final Uint8List bytes;
    try {
      bytes = _decodeRobust(base64String);
    } on FormatException {
      throw const KeyCodecException('Key 1 is not valid Base64');
    }
    final text = utf8.decode(bytes).trim();
    if (text.isEmpty) throw const KeyCodecException('Key 1 is empty');

    final entries = <String, String>{};
    for (final pair in text.split('|')) {
      final eqIdx = pair.indexOf('=');
      if (eqIdx == -1) continue;
      final code = pair.substring(0, eqIdx).trim();
      final name = pair.substring(eqIdx + 1).trim();
      if (code.isNotEmpty && name.isNotEmpty) entries[code] = name;
    }
    if (entries.isEmpty) throw const KeyCodecException('Key 1 produced no valid entries');
    return KeyDictionary(entries: entries);
  }

  static List<Workout> decodeKey2(
    String base64String,
    KeyDictionary dictionary,
    DateTime weekStart,
  ) {
    final Uint8List bytes;
    try {
      bytes = _decodeRobust(base64String);
    } on FormatException {
      throw const KeyCodecException('Key 2 is not valid Base64');
    }
    final text = utf8.decode(bytes).trim();
    final fmt = DateFormat('yyyy-MM-dd');
    final workouts = <Workout>[];

    for (final dayStr in text.split(';')) {
      final colonIdx = dayStr.indexOf(':');
      if (colonIdx == -1) continue;
      final dayNum = int.tryParse(dayStr.substring(0, colonIdx).trim());
      if (dayNum == null || dayNum < 1 || dayNum > 7) continue;

      final date = weekStart.add(Duration(days: dayNum - 1));
      final exercises = <Exercise>[];

      final exerciseStr = dayStr.substring(colonIdx + 1).trim();
      for (final exStr in exerciseStr.split(',')) {
        final dashIdx = exStr.indexOf('-');
        if (dashIdx == -1) continue;
        final code = exStr.substring(0, dashIdx).trim();
        final parts = exStr.substring(dashIdx + 1).trim().split('x');
        if (parts.length != 3) continue;
        final weight = double.tryParse(parts[0]);
        final sets = int.tryParse(parts[1]);
        final reps = int.tryParse(parts[2]);
        if (weight == null || sets == null || reps == null || sets <= 0) continue;
        exercises.add(Exercise(
          code: code,
          name: dictionary.nameFor(code),
          weight: weight,
          sets: sets,
          reps: reps,
        ));
      }
      if (exercises.isNotEmpty) {
        workouts.add(Workout(date: fmt.format(date), exercises: exercises));
      }
    }
    return workouts;
  }
}
