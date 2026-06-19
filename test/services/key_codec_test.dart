import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/models/key_dictionary.dart';
import 'package:workout_tracker/services/key_codec.dart';

void main() {
  group('KeyCodec.decodeKey1', () {
    test('decodes valid base64 key1', () {
      const raw = 'A1=жим лёжа|A2=гиперэкстензия|A3=сгиб/разгиб ног';
      final encoded = base64Encode(utf8.encode(raw));
      final dict = KeyCodec.decodeKey1(encoded);
      expect(dict.nameFor('A1'), 'жим лёжа');
      expect(dict.nameFor('A2'), 'гиперэкстензия');
      expect(dict.nameFor('A3'), 'сгиб/разгиб ног');
    });

    test('returns code unchanged when not in dictionary', () {
      const raw = 'A1=жим лёжа';
      final encoded = base64Encode(utf8.encode(raw));
      final dict = KeyCodec.decodeKey1(encoded);
      expect(dict.nameFor('Z9'), 'Z9');
    });

    test('throws KeyCodecException on invalid base64', () {
      expect(
        () => KeyCodec.decodeKey1('not-valid-base64!!!'),
        throwsA(isA<KeyCodecException>()),
      );
    });

    test('throws KeyCodecException when result is empty', () {
      final encoded = base64Encode(utf8.encode(''));
      expect(
        () => KeyCodec.decodeKey1(encoded),
        throwsA(isA<KeyCodecException>()),
      );
    });

    test('trims whitespace from code and name', () {
      const raw = ' A1 = жим лёжа | A2 = тяга ';
      final encoded = base64Encode(utf8.encode(raw));
      final dict = KeyCodec.decodeKey1(encoded);
      expect(dict.nameFor('A1'), 'жим лёжа');
      expect(dict.nameFor('A2'), 'тяга');
    });
  });

  group('KeyCodec.decodeKey2', () {
    late KeyDictionary dict;
    final monday = DateTime(2026, 5, 11);

    setUp(() {
      dict = const KeyDictionary(entries: {
        'A1': 'жим лёжа',
        'A2': 'гиперэкстензия',
        'A3': 'сгиб/разгиб ног',
      });
    });

    test('decodes single workout day correctly', () {
      const raw = '1:A1-60x4x8,A2-0x4x15';
      final encoded = base64Encode(utf8.encode(raw));
      final workouts = KeyCodec.decodeKey2(encoded, dict, monday);
      expect(workouts.length, 1);
      expect(workouts[0].date, '2026-05-11');
      expect(workouts[0].exercises.length, 2);
      expect(workouts[0].exercises[0].name, 'жим лёжа');
      expect(workouts[0].exercises[0].weight, 60);
      expect(workouts[0].exercises[0].sets, 4);
      expect(workouts[0].exercises[0].reps, 8);
      expect(workouts[0].exercises[1].weight, 0);
    });

    test('maps day numbers to correct calendar dates', () {
      const raw = '1:A1-60x4x8;3:A3-35x6x15;5:A2-0x3x12';
      final encoded = base64Encode(utf8.encode(raw));
      final workouts = KeyCodec.decodeKey2(encoded, dict, monday);
      expect(workouts.length, 3);
      expect(workouts[0].date, '2026-05-11');
      expect(workouts[1].date, '2026-05-13');
      expect(workouts[2].date, '2026-05-15');
    });

    test('uses code as name when not in dictionary', () {
      const raw = '1:Z9-50x3x10';
      final encoded = base64Encode(utf8.encode(raw));
      final workouts = KeyCodec.decodeKey2(encoded, dict, monday);
      expect(workouts[0].exercises[0].name, 'Z9');
    });

    test('skips malformed exercise entries gracefully', () {
      const raw = '1:A1-60x4x8,BADENTRY,A2-0x4x15';
      final encoded = base64Encode(utf8.encode(raw));
      final workouts = KeyCodec.decodeKey2(encoded, dict, monday);
      expect(workouts[0].exercises.length, 2);
    });

    test('completedSets initialised to all false', () {
      const raw = '1:A1-60x4x8';
      final encoded = base64Encode(utf8.encode(raw));
      final workouts = KeyCodec.decodeKey2(encoded, dict, monday);
      expect(workouts[0].exercises[0].completedSets, [false, false, false, false]);
    });

    test('throws KeyCodecException on invalid base64', () {
      expect(
        () => KeyCodec.decodeKey2('not-valid!!!', dict, monday),
        throwsA(isA<KeyCodecException>()),
      );
    });
  });
}
