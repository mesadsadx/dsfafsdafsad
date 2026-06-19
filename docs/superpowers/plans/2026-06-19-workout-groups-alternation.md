# Workout Groups & Alternation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tag exercises as A/B/C/D (or None), auto-determine today's session from workout history, and load all session exercises at once via a secondary FAB in WorkoutScreen.

**Architecture:** `ProgressionConfig.group` stores the tag. `nextSessionProvider` derives 'AB' or 'CD' from the last workout. A `suggestExercise()` utility (extracted from `add_exercise_dialog.dart`) is shared with the template-loading logic. The secondary FAB calls `WorkoutNotifier.addExercises()` which does a single batch Firestore transaction.

**Tech Stack:** Flutter/Dart, Riverpod 2.x, Cloud Firestore, existing `AppColors` / `GradientScaffold`.

## Global Constraints

- Dart 3 record syntax: `(int, int)` positional with `.$1` / `.$2`
- No new packages
- `flutter analyze` must report "No issues found" after every task
- All Firestore writes use transactions
- Groups are exactly: `null` (None), `'A'`, `'B'`, `'C'`, `'D'`
- Session 'AB' includes groups `{null, 'A', 'B'}`; session 'CD' includes `{null, 'C', 'D'}`

---

## File Map

| Action | Path | Responsibility |
|--------|------|---------------|
| Create | `lib/utils/progression.dart` | Public `suggestExercise()` + default ladder constants |
| Modify | `lib/models/progression_config.dart` | Add `group: String?` field |
| Modify | `lib/services/firestore_service.dart` | Add `getLastWorkout`, `addExercisesBatch` |
| Modify | `lib/providers/progression_provider.dart` | Add `lastWorkoutProvider`, `nextSessionProvider` |
| Modify | `lib/widgets/add_exercise_dialog.dart` | Use `suggestExercise` from utility, remove duplicate logic |
| Modify | `lib/screens/progression_screen.dart` | Add group selector chips in each card |
| Modify | `lib/providers/workout_provider.dart` | Add `addExercises(List<Exercise>)` to `WorkoutNotifier` |
| Modify | `lib/screens/workout_screen.dart` | Add secondary FAB + `_loadTemplate()` async method |

---

## Task 1: Extract `suggestExercise` to Shared Utility + Add `group` to Model

**Files:**
- Create: `lib/utils/progression.dart`
- Modify: `lib/models/progression_config.dart`
- Modify: `lib/widgets/add_exercise_dialog.dart`

**Interfaces:**
- Produces:
  - `suggestExercise(Exercise last, ProgressionConfig? config)` → `({double weight, int sets, int reps, bool isProgressed})`
  - `ProgressionConfig.group: String?`

- [ ] **Step 1: Create `lib/utils/progression.dart`**

```dart
// lib/utils/progression.dart
import '../models/exercise.dart';
import '../models/progression_config.dart';

const _defaultLadder = [
  (3, 10), (3, 12), (3, 15),
  (4, 10), (4, 12), (4, 15),
  (5, 10), (5, 12), (5, 15),
  (6, 10), (6, 12), (6, 15),
];

const _defaultWeightStep = 2.5;
const _noProgressionCodes = {'BP'};

({double weight, int sets, int reps, bool isProgressed}) suggestExercise(
  Exercise last,
  ProgressionConfig? config,
) {
  if (config != null && config.isRepeating) {
    return (weight: last.weight, sets: last.sets, reps: last.reps, isProgressed: false);
  }

  if (config != null && config.ladder.isNotEmpty) {
    final allDone = last.completedSets.every((c) => c);
    if (!allDone) {
      return (weight: last.weight, sets: last.sets, reps: last.reps, isProgressed: false);
    }
    final stepIdx =
        config.ladder.indexWhere((s) => s.$1 == last.sets && s.$2 == last.reps);
    if (stepIdx == -1) {
      return (weight: last.weight, sets: last.sets, reps: last.reps, isProgressed: false);
    }
    final weightIdx =
        config.weights.indexWhere((w) => (w - last.weight).abs() < 0.01);
    int nextStep = stepIdx + 1;
    int nextWeightIdx = weightIdx < 0 ? 0 : weightIdx;
    if (nextStep >= config.ladder.length) {
      nextStep = 0;
      nextWeightIdx = (weightIdx < 0 ? 0 : weightIdx) + 1;
      if (nextWeightIdx >= config.weights.length) {
        return (
          weight: last.weight,
          sets: config.ladder.last.$1,
          reps: config.ladder.last.$2,
          isProgressed: false,
        );
      }
    }
    final nextWeight =
        config.weights.isNotEmpty ? config.weights[nextWeightIdx] : last.weight;
    final step = config.ladder[nextStep];
    return (weight: nextWeight, sets: step.$1, reps: step.$2, isProgressed: true);
  }

  if (_noProgressionCodes.contains(last.code)) {
    return (weight: last.weight, sets: last.sets, reps: last.reps, isProgressed: false);
  }

  final idx =
      _defaultLadder.indexWhere((s) => s.$1 == last.sets && s.$2 == last.reps);
  if (idx == -1) {
    return (weight: last.weight, sets: last.sets, reps: last.reps, isProgressed: false);
  }
  final allDone = last.completedSets.every((c) => c);
  if (!allDone) {
    return (weight: last.weight, sets: last.sets, reps: last.reps, isProgressed: false);
  }
  if (idx == _defaultLadder.length - 1) {
    final nextWeight = last.weight > 0 ? last.weight + _defaultWeightStep : 0.0;
    return (weight: nextWeight, sets: 3, reps: 10, isProgressed: true);
  }
  final next = _defaultLadder[idx + 1];
  return (weight: last.weight, sets: next.$1, reps: next.$2, isProgressed: true);
}
```

- [ ] **Step 2: Add `group` field to `lib/models/progression_config.dart`**

Replace the entire file content:

```dart
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
```

- [ ] **Step 3: Refactor `lib/widgets/add_exercise_dialog.dart` to use the utility**

At the top, replace the existing imports/constants/`_suggest` block.

Remove these lines from `add_exercise_dialog.dart`:
```dart
// Progression ladder: (sets, reps). Applies to all exercises except _noProgressionCodes.
const _ladder = [ ... ];
// Weight-only progression exercises (sets/reps stay fixed per plan).
const _noProgressionCodes = {'BP'};
// Default weight increment when progression resets.
const _weightStep = 2.5;
({double weight, int sets, int reps, bool isProgressed}) _suggest(
  Exercise last,
  ProgressionConfig? config,
) { ... }
```

Add this import after the existing ones:
```dart
import '../utils/progression.dart';
```

In `_applyLast`, change the call from `_suggest(last, config)` to `suggestExercise(last, config)`:

```dart
void _applyLast(Exercise last) {
  final config = ref.read(progressionConfigProvider(last.code));
  final s = suggestExercise(last, config);

  _weightCtrl.text = s.weight == s.weight.truncateToDouble()
      ? s.weight.toInt().toString()
      : s.weight.toString();
  _setsCtrl.text = s.sets.toString();
  _repsCtrl.text = s.reps.toString();

  final allDone = last.completedSets.every((c) => c);
  if (config?.isRepeating == true) {
    final status = allDone ? '✓' : '✗';
    _hintText =
        'Повторяется: ${_formatWeight(last.weight)} × ${last.sets} × ${last.reps} $status';
    _hintIsProgress = false;
  } else if (s.isProgressed) {
    if (last.weight > 0 && (s.weight - last.weight).abs() > 0.01) {
      _hintText =
          '↑ Новый вес: ${_formatWeight(s.weight)} × ${s.sets} × ${s.reps}';
    } else {
      _hintText =
          '↑ Прогрессия: ${last.sets}×${last.reps} → ${s.sets}×${s.reps}';
    }
    _hintIsProgress = true;
  } else {
    final status = allDone ? '✓' : '✗';
    _hintText =
        'Прошлый раз: ${_formatWeight(last.weight)} × ${last.sets} × ${last.reps} $status';
    _hintIsProgress = false;
  }
  setState(() {});
}
```

- [ ] **Step 4: Verify analyze**

```
flutter analyze
```
Expected: No issues found.

- [ ] **Step 5: Commit**

```
git add lib/utils/progression.dart lib/models/progression_config.dart lib/widgets/add_exercise_dialog.dart
git commit -m "feat: extract suggestExercise utility, add group field to ProgressionConfig"
```

---

## Task 2: FirestoreService — `getLastWorkout` + `addExercisesBatch`

**Files:**
- Modify: `lib/services/firestore_service.dart`

**Interfaces:**
- Produces:
  - `getLastWorkout(String uid)` → `Future<Workout?>`
  - `addExercisesBatch(String uid, String date, List<Exercise> exercises)` → `Future<void>`

- [ ] **Step 1: Add `getLastWorkout` to `FirestoreService`**

Add after the `getLastExercise` method (before the closing `}`):

```dart
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
```

- [ ] **Step 2: Add `addExercisesBatch` to `FirestoreService`**

Add after `getLastWorkout`:

```dart
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
```

- [ ] **Step 3: Verify analyze**

```
flutter analyze lib/services/firestore_service.dart
```
Expected: No issues found.

- [ ] **Step 4: Commit**

```
git add lib/services/firestore_service.dart
git commit -m "feat: add getLastWorkout and addExercisesBatch to FirestoreService"
```

---

## Task 3: New Providers — `lastWorkoutProvider` + `nextSessionProvider`

**Files:**
- Modify: `lib/providers/progression_provider.dart`

**Interfaces:**
- Consumes: `getLastWorkout` from Task 2; `progressionsProvider` (existing); `authStateProvider`, `firestoreServiceProvider` (existing)
- Produces:
  - `lastWorkoutProvider` → `AsyncValue<Workout?>`
  - `nextSessionProvider` → `String` (synchronous, 'AB' or 'CD')

- [ ] **Step 1: Add import for `Workout` model**

At the top of `lib/providers/progression_provider.dart`, add:
```dart
import '../models/workout.dart';
```

- [ ] **Step 2: Add `lastWorkoutProvider`**

Append after the existing `progressionConfigProvider`:

```dart
final lastWorkoutProvider = FutureProvider.autoDispose<Workout?>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null || uid.isEmpty) return Future.value(null);
  return ref.read(firestoreServiceProvider).getLastWorkout(uid);
});
```

- [ ] **Step 3: Add `nextSessionProvider`**

Append after `lastWorkoutProvider`:

```dart
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
```

- [ ] **Step 4: Verify analyze**

```
flutter analyze lib/providers/progression_provider.dart
```
Expected: No issues found.

- [ ] **Step 5: Commit**

```
git add lib/providers/progression_provider.dart
git commit -m "feat: add lastWorkoutProvider and nextSessionProvider"
```

---

## Task 4: Group Selector in ProgressionScreen

**Files:**
- Modify: `lib/screens/progression_screen.dart`

Changes are entirely within `_ExerciseProgressionCardState`:
1. Add `late String? _group` state field
2. Initialize `_group = config?.group` in `_initControllers`
3. Include `group: _group` in `_save()`
4. Add `_groupSelector()` widget helper
5. Insert `_groupSelector()` in the expanded body after the checkboxes
6. Show group chip in collapsed header if group is set

- [ ] **Step 1: Add `_group` to state and update `_initControllers`**

In `_ExerciseProgressionCardState`, after `late TextEditingController _ladderCtrl;`, add:
```dart
  late String? _group;
```

Inside `_initControllers`, after the `_ladderCtrl` initialization line and before `_weightsCtrl.addListener`, add:
```dart
    _group = config?.group;
```

- [ ] **Step 2: Update `_save()` to include `group`**

Replace the `_save()` method:

```dart
  void _save() {
    widget.onSave(ProgressionConfig(
      exerciseCode: widget.code,
      isRepeating: _isRepeating,
      isStrength: _isStrength,
      group: _group,
      weights: _isRepeating ? [] : (_parseWeights() ?? []),
      ladder: _isRepeating ? [] : (_parseLadder() ?? []),
    ));
  }
```

- [ ] **Step 3: Add `_groupSelector()` widget helper**

Add this method to `_ExerciseProgressionCardState` (after `_field`):

```dart
  Widget _groupSelector() {
    const options = [null, 'A', 'B', 'C', 'D'];
    return Wrap(
      spacing: 6,
      children: options.map((g) {
        final label = g ?? 'None';
        final selected = _group == g;
        return GestureDetector(
          onTap: () => setState(() => _group = g),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? AppColors.accent
                    : AppColors.textMuted.withValues(alpha: 0.35),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                color:
                    selected ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
```

- [ ] **Step 4: Insert group selector into expanded body**

In `build()`, inside the expanded `Column`, after the `_checkRow('Силовое', ...)` block and before the `if (!_isRepeating)` block, add:

```dart
                        const SizedBox(height: 12),
                        const Text(
                          'Группа',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _groupSelector(),
```

- [ ] **Step 5: Show group chip in collapsed header**

In `build()`, inside the collapsed header `Row`, after the `isStrength` chip block and before the `custom` chip block, add:

```dart
                  if (widget.config?.group != null) ...[
                    const SizedBox(width: 4),
                    _chip(widget.config!.group!, AppColors.heatmap50),
                  ],
```

- [ ] **Step 6: Verify analyze**

```
flutter analyze lib/screens/progression_screen.dart
```
Expected: No issues found.

- [ ] **Step 7: Commit**

```
git add lib/screens/progression_screen.dart
git commit -m "feat: add group selector (None/A/B/C/D) to ProgressionScreen cards"
```

---

## Task 5: `WorkoutNotifier.addExercises` + Secondary FAB in WorkoutScreen

**Files:**
- Modify: `lib/providers/workout_provider.dart`
- Modify: `lib/screens/workout_screen.dart`

**Interfaces:**
- Consumes: `addExercisesBatch` from Task 2; `nextSessionProvider`, `progressionsProvider` from Task 3; `suggestExercise` from Task 1; `dictionaryProvider` (existing); `firestoreServiceProvider` (existing)
- Produces: `WorkoutNotifier.addExercises(List<Exercise>)` → `Future<void>`

- [ ] **Step 1: Add `addExercises` to `WorkoutNotifier`**

In `lib/providers/workout_provider.dart`, add inside `WorkoutNotifier` after `addExercise`:

```dart
  Future<void> addExercises(List<Exercise> exercises) async {
    if (_uid.isEmpty || exercises.isEmpty) return;
    final workout = state.valueOrNull;
    final previousState = state;
    final newExercises = <Exercise>[
      ...(workout?.exercises ?? []),
      ...exercises,
    ];
    state = AsyncValue.data(Workout(date: _date, exercises: newExercises));
    try {
      await _service.addExercisesBatch(_uid, _date, exercises);
    } catch (_) {
      state = previousState;
    }
  }
```

- [ ] **Step 2: Add required imports to `workout_screen.dart`**

At the top of `lib/screens/workout_screen.dart`, add after existing imports:

```dart
import '../models/exercise.dart';
import '../models/progression_config.dart';
import '../providers/progression_provider.dart';
import '../providers/settings_provider.dart';
import '../services/firestore_service.dart';
import '../utils/progression.dart';
```

Note: `exercise.dart` and `settings_provider.dart` may already be imported — only add if not present.

- [ ] **Step 3: Add `_loadingTemplate` state and `_loadTemplate()` method**

In `_WorkoutScreenState`, after `late DateTime _selectedDate;`, add:

```dart
  bool _loadingTemplate = false;
```

Add `_loadTemplate()` method in `_WorkoutScreenState` (after `_formatDate`):

```dart
  Future<void> _loadTemplate() async {
    if (_loadingTemplate) return;
    setState(() => _loadingTemplate = true);

    try {
      final session = ref.read(nextSessionProvider);
      final configs = ref.read(progressionsProvider).valueOrNull ?? {};
      final dict = ref.read(dictionaryProvider).valueOrNull;
      final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
      final service = ref.read(firestoreServiceProvider);

      if (dict == null || dict.isEmpty || uid.isEmpty) return;

      final Set<String?> groups =
          session == 'AB' ? {null, 'A', 'B'} : {null, 'C', 'D'};

      // Collect exercise codes belonging to this session
      final entries = dict.sortedEntries.where((e) {
        final config = configs[e.key];
        return groups.contains(config?.group);
      }).toList();

      // Parallel fetch last exercise for each code
      final lastList = await Future.wait(
        entries.map((e) => service.getLastExercise(uid, e.key)),
      );

      final exercises = <Exercise>[];
      for (var i = 0; i < entries.length; i++) {
        final code = entries[i].key;
        final name = entries[i].value;
        final config = configs[code];
        final last = lastList[i];

        final double weight;
        final int sets;
        final int reps;

        if (last == null) {
          weight = (config?.weights.isNotEmpty == true)
              ? config!.weights.first
              : 0.0;
          final step = (config?.ladder.isNotEmpty == true)
              ? config!.ladder.first
              : (3, 10);
          sets = step.$1;
          reps = step.$2;
        } else {
          final s = suggestExercise(last, config);
          weight = s.weight;
          sets = s.sets;
          reps = s.reps;
        }

        exercises.add(Exercise(
          code: code,
          name: name,
          weight: weight,
          sets: sets,
          reps: reps,
        ));
      }

      final notifier =
          ref.read(workoutNotifierProvider(_dateStr).notifier);
      await notifier.addExercises(exercises);
    } finally {
      if (mounted) setState(() => _loadingTemplate = false);
    }
  }
```

- [ ] **Step 4: Add `ref.watch(nextSessionProvider)` and `ref.watch(lastWorkoutProvider)` in `build()`**

In `_WorkoutScreenState.build()`, after `final workoutAsync = ref.watch(workoutNotifierProvider(_dateStr));`, add:

```dart
    ref.watch(nextSessionProvider); // keep alive for _loadTemplate
    ref.watch(lastWorkoutProvider); // keep alive for session detection
    final dict = ref.watch(dictionaryProvider).valueOrNull;
```

(Note: If `dict` is already watched somewhere in this build, skip the duplicate. Check for existing `dictionaryProvider` usage — if not present, add.)

- [ ] **Step 5: Replace the `floatingActionButton` with stacked FABs**

In `_WorkoutScreenState.build()`, replace the existing `floatingActionButton: Padding(...)` with:

```dart
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
            bottom: _showWeekStrip ? bottomPad + 72 : 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (dict != null && dict.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FloatingActionButton.small(
                  heroTag: 'template',
                  tooltip: 'Загрузить тренировку',
                  onPressed: () {
                    final workout = workoutAsync.valueOrNull;
                    final hasExercises =
                        workout != null && workout.exercises.isNotEmpty;
                    if (!hasExercises && !_loadingTemplate) _loadTemplate();
                  },
                  backgroundColor: () {
                    final workout = workoutAsync.valueOrNull;
                    final hasExercises =
                        workout != null && workout.exercises.isNotEmpty;
                    return (hasExercises || _loadingTemplate)
                        ? AppColors.surfaceVariant
                        : AppColors.accent;
                  }(),
                  child: _loadingTemplate
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          Icons.playlist_add_outlined,
                          color: () {
                            final workout = workoutAsync.valueOrNull;
                            final hasExercises = workout != null &&
                                workout.exercises.isNotEmpty;
                            return (hasExercises || _loadingTemplate)
                                ? AppColors.textMuted
                                : Colors.black;
                          }(),
                        ),
                ),
              ),
            FloatingActionButton(
              heroTag: 'add',
              onPressed: () async {
                final exercise = await showDialog<Exercise>(
                  context: context,
                  builder: (_) => const AddExerciseDialog(),
                );
                if (exercise != null) {
                  ref
                      .read(workoutNotifierProvider(_dateStr).notifier)
                      .addExercise(exercise);
                }
              },
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
```

Note: the `context` is captured before the async gap — this is safe because `showDialog` is called directly in the `onPressed` callback (not after an await).

- [ ] **Step 6: Verify full project analyze**

```
flutter analyze
```
Expected: No issues found.

- [ ] **Step 7: Commit**

```
git add lib/providers/workout_provider.dart lib/screens/workout_screen.dart
git commit -m "feat: add template loading (secondary FAB) with AB/CD session alternation"
```
