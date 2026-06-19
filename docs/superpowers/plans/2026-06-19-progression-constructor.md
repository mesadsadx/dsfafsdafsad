# Progression Constructor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a third "Прогрессия" tab where the user can configure per-exercise progression rules (repeating, strength, custom weight/ladder), stored in Firestore, with `AddExerciseDialog._suggest()` updated to respect those rules.

**Architecture:** `ProgressionConfig` model stored in Firestore at `users/{uid}/progressions/{code}`. A StreamProvider exposes a `Map<String, ProgressionConfig>` to the UI. The `ProgressionScreen` renders expandable glass cards (one at a time). `AddExerciseDialog` reads the config synchronously via a derived `Provider.family` and passes it to `_suggest()`.

**Tech Stack:** Flutter/Dart, Riverpod 2.x (StreamProvider, Provider.family, autoDispose), Cloud Firestore, GoRouter, existing `GradientScaffold` / `NativeLiquidGlass` / `AppColors`.

## Global Constraints

- Dart 3 record syntax: `(int, int)` positional records with `.$1` / `.$2`
- Firestore writes use `set()` (not `merge`) for `progressions/{code}`
- No new packages — use existing `cloud_firestore`, `flutter_riverpod`, `go_router`, `gap`
- All new screens use `GradientScaffold` and `AppColors` from `lib/app/theme.dart`
- `flutter analyze` must report "No issues found" after every task

---

## File Map

| Action | Path | Responsibility |
|--------|------|---------------|
| Create | `lib/models/progression_config.dart` | Model + Firestore serialization |
| Modify | `lib/services/firestore_service.dart` | Add `watchProgressions`, `saveProgression`, `deleteProgression` |
| Create | `lib/providers/progression_provider.dart` | `progressionsProvider` + `progressionConfigProvider` |
| Create | `lib/screens/progression_screen.dart` | 3rd tab screen with expandable cards |
| Modify | `lib/widgets/liquid_glass_nav_bar.dart` | Add 3rd nav item "Прогрессия" |
| Modify | `lib/screens/home_screen.dart` | Map index 2 → `/progression`, add `go('/progression')` |
| Modify | `lib/app/router.dart` | Add `/progression` route to ShellRoute |
| Modify | `lib/widgets/add_exercise_dialog.dart` | `_suggest()` accepts `ProgressionConfig?`, reads from provider |

---

## Task 1: ProgressionConfig Model

**Files:**
- Create: `lib/models/progression_config.dart`

**Interfaces:**
- Produces: `ProgressionConfig` class with `fromFirestore`, `toFirestore`, `copyWith`

- [ ] **Step 1: Create the model file**

```dart
// lib/models/progression_config.dart
class ProgressionConfig {
  final String exerciseCode;
  final bool isRepeating;
  final bool isStrength;
  final List<double> weights;
  final List<(int, int)> ladder; // (sets, reps)

  const ProgressionConfig({
    required this.exerciseCode,
    this.isRepeating = false,
    this.isStrength = false,
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
        'weights': weights,
        'ladder': ladder.map((s) => '${s.$1}x${s.$2}').toList(),
      };
}
```

- [ ] **Step 2: Verify analyze passes**

```
flutter analyze lib/models/progression_config.dart
```
Expected: No issues.

- [ ] **Step 3: Commit**

```
git add lib/models/progression_config.dart
git commit -m "feat: add ProgressionConfig model"
```

---

## Task 2: FirestoreService — Progression Methods

**Files:**
- Modify: `lib/services/firestore_service.dart`

**Interfaces:**
- Consumes: `ProgressionConfig` from Task 1
- Produces:
  - `watchProgressions(uid)` → `Stream<Map<String, ProgressionConfig>>`
  - `saveProgression(uid, config)` → `Future<void>`
  - `deleteProgression(uid, code)` → `Future<void>`

- [ ] **Step 1: Add import and helper at top of `firestore_service.dart`**

Add import after existing imports:
```dart
import '../models/progression_config.dart';
```

Add a helper ref inside the class body (after `_workoutsRef`):
```dart
  CollectionReference _progressionsRef(String uid) =>
      _db.collection('users').doc(uid).collection('progressions');
```

- [ ] **Step 2: Add the three methods at the end of `FirestoreService` (before the closing `}`)**

```dart
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
```

- [ ] **Step 3: Verify analyze passes**

```
flutter analyze lib/services/firestore_service.dart
```
Expected: No issues.

- [ ] **Step 4: Commit**

```
git add lib/services/firestore_service.dart
git commit -m "feat: add watchProgressions/saveProgression/deleteProgression to FirestoreService"
```

---

## Task 3: Progression Providers

**Files:**
- Create: `lib/providers/progression_provider.dart`

**Interfaces:**
- Consumes: `firestoreServiceProvider`, `authStateProvider` (both from existing providers)
- Produces:
  - `progressionsProvider` → `AsyncValue<Map<String, ProgressionConfig>>`
  - `progressionConfigProvider(code)` → `ProgressionConfig?` (synchronous, derived)

- [ ] **Step 1: Create the provider file**

```dart
// lib/providers/progression_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/progression_config.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

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
```

- [ ] **Step 2: Verify analyze passes**

```
flutter analyze lib/providers/progression_provider.dart
```
Expected: No issues.

- [ ] **Step 3: Commit**

```
git add lib/providers/progression_provider.dart
git commit -m "feat: add progressionsProvider and progressionConfigProvider"
```

---

## Task 4: Progression Screen

**Files:**
- Create: `lib/screens/progression_screen.dart`

**Interfaces:**
- Consumes: `progressionsProvider`, `progressionConfigProvider`, `dictionaryProvider`, `authStateProvider`, `firestoreServiceProvider` (all existing or from Tasks 2–3)
- Produces: `ProgressionScreen` widget (exported, used by router in Task 5)

- [ ] **Step 1: Create `lib/screens/progression_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../app/theme.dart';
import '../models/progression_config.dart';
import '../providers/auth_provider.dart';
import '../providers/progression_provider.dart';
import '../providers/settings_provider.dart';
import '../services/firestore_service.dart';
import '../widgets/gradient_scaffold.dart';

class ProgressionScreen extends ConsumerStatefulWidget {
  const ProgressionScreen({super.key});

  @override
  ConsumerState<ProgressionScreen> createState() => _ProgressionScreenState();
}

class _ProgressionScreenState extends ConsumerState<ProgressionScreen> {
  String? _expandedCode;

  @override
  Widget build(BuildContext context) {
    final dict = ref.watch(dictionaryProvider).valueOrNull;
    final configs = ref.watch(progressionsProvider).valueOrNull ?? {};
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    final service = ref.read(firestoreServiceProvider);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return GradientScaffold(
      appBar: AppBar(title: const Text('Прогрессия')),
      body: (dict == null || dict.isEmpty)
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Сначала настройте Key 1 в настройках',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, height: 1.6),
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad + 80),
              itemCount: dict.sortedEntries.length,
              separatorBuilder: (_, __) => const Gap(10),
              itemBuilder: (_, i) {
                final entry = dict.sortedEntries[i];
                final code = entry.key;
                return _ExerciseProgressionCard(
                  key: ValueKey(code),
                  code: code,
                  name: entry.value,
                  config: configs[code],
                  isExpanded: _expandedCode == code,
                  onTap: () => setState(() {
                    _expandedCode = _expandedCode == code ? null : code;
                  }),
                  onSave: (config) async {
                    try {
                      await service.saveProgression(uid, config);
                      if (mounted) setState(() => _expandedCode = null);
                    } catch (_) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Не удалось сохранить')),
                      );
                    }
                  },
                  onReset: () async {
                    try {
                      await service.deleteProgression(uid, code);
                      if (mounted) setState(() => _expandedCode = null);
                    } catch (_) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Не удалось сбросить')),
                      );
                    }
                  },
                );
              },
            ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ExerciseProgressionCard extends StatefulWidget {
  final String code;
  final String name;
  final ProgressionConfig? config;
  final bool isExpanded;
  final VoidCallback onTap;
  final void Function(ProgressionConfig) onSave;
  final VoidCallback onReset;

  const _ExerciseProgressionCard({
    super.key,
    required this.code,
    required this.name,
    required this.config,
    required this.isExpanded,
    required this.onTap,
    required this.onSave,
    required this.onReset,
  });

  @override
  State<_ExerciseProgressionCard> createState() =>
      _ExerciseProgressionCardState();
}

class _ExerciseProgressionCardState extends State<_ExerciseProgressionCard> {
  late bool _isRepeating;
  late bool _isStrength;
  late TextEditingController _weightsCtrl;
  late TextEditingController _ladderCtrl;

  @override
  void initState() {
    super.initState();
    _initControllers(widget.config);
  }

  @override
  void didUpdateWidget(_ExerciseProgressionCard old) {
    super.didUpdateWidget(old);
    // Re-init form when config changes from Firestore while card is closed.
    if (!widget.isExpanded && old.config != widget.config) {
      _disposeControllers();
      _initControllers(widget.config);
    }
  }

  void _initControllers(ProgressionConfig? config) {
    _isRepeating = config?.isRepeating ?? false;
    _isStrength = config?.isStrength ?? false;
    _weightsCtrl = TextEditingController(
      text: config?.weights
              .map((w) =>
                  w == w.truncateToDouble() ? w.toInt().toString() : '$w')
              .join(', ') ??
          '',
    );
    _ladderCtrl = TextEditingController(
      text: config?.ladder.map((s) => '${s.$1}x${s.$2}').join(', ') ?? '',
    );
    _weightsCtrl.addListener(() => setState(() {}));
    _ladderCtrl.addListener(() => setState(() {}));
  }

  void _disposeControllers() {
    _weightsCtrl.dispose();
    _ladderCtrl.dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  // Returns null if the text is non-empty but malformed.
  List<double>? _parseWeights() {
    final text = _weightsCtrl.text.trim();
    if (text.isEmpty) return [];
    final result = <double>[];
    for (final part in text.split(',')) {
      final v = double.tryParse(part.trim());
      if (v == null) return null;
      result.add(v);
    }
    return result;
  }

  // Returns null if the text is non-empty but malformed.
  List<(int, int)>? _parseLadder() {
    final text = _ladderCtrl.text.trim();
    if (text.isEmpty) return [];
    final result = <(int, int)>[];
    final re = RegExp(r'^(\d+)[xX](\d+)$');
    for (final part in text.split(',')) {
      final m = re.firstMatch(part.trim());
      if (m == null) return null;
      final s = int.tryParse(m.group(1)!);
      final r = int.tryParse(m.group(2)!);
      if (s == null || r == null) return null;
      result.add((s, r));
    }
    return result;
  }

  bool get _canSave {
    if (_isRepeating) return true;
    final w = _parseWeights();
    final l = _parseLadder();
    return w != null && l != null;
  }

  void _save() {
    widget.onSave(ProgressionConfig(
      exerciseCode: widget.code,
      isRepeating: _isRepeating,
      isStrength: _isStrength,
      weights: _isRepeating ? [] : (_parseWeights() ?? []),
      ladder: _isRepeating ? [] : (_parseLadder() ?? []),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasCustom = widget.config != null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceVariant, AppColors.surface],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  if (widget.config?.isRepeating == true)
                    _chip('🔁', AppColors.textSecondary),
                  if (widget.config?.isStrength == true) ...[
                    const SizedBox(width: 4),
                    _chip('⚡', AppColors.heatmap75),
                  ],
                  if (hasCustom &&
                      !(widget.config!.isRepeating) &&
                      widget.config!.ladder.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    _chip('custom', AppColors.accent),
                  ],
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: widget.isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Expanded body ────────────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: widget.isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(color: AppColors.divider, height: 1),
                        const SizedBox(height: 12),
                        _checkRow(
                          'Повторяющееся',
                          _isRepeating,
                          (v) => setState(() => _isRepeating = v ?? false),
                        ),
                        const SizedBox(height: 4),
                        _checkRow(
                          'Силовое',
                          _isStrength,
                          (v) => setState(() => _isStrength = v ?? false),
                        ),
                        if (!_isRepeating) ...[
                          const SizedBox(height: 12),
                          _field(
                            controller: _weightsCtrl,
                            label: 'Веса (кг через запятую)',
                            hint: '40, 42.5, 45, 47.5',
                            error: _weightsCtrl.text.trim().isNotEmpty &&
                                    _parseWeights() == null
                                ? 'Неверный формат'
                                : null,
                          ),
                          const SizedBox(height: 8),
                          _field(
                            controller: _ladderCtrl,
                            label: 'Прогрессия (3x10, 4x12, ...)',
                            hint: '3x10, 3x12, 3x15, 4x10, 4x12, 4x15',
                            error: _ladderCtrl.text.trim().isNotEmpty &&
                                    _parseLadder() == null
                                ? 'Неверный формат (нужно NxM)'
                                : null,
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (hasCustom)
                              TextButton(
                                onPressed: widget.onReset,
                                child: const Text(
                                  'Сбросить',
                                  style: TextStyle(
                                      color: AppColors.textSecondary),
                                ),
                              ),
                            if (hasCustom) const SizedBox(width: 4),
                            ElevatedButton(
                              onPressed: _canSave ? _save : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.black,
                              ),
                              child: const Text('Сохранить'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _checkRow(String label, bool value, ValueChanged<bool?> onChange) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChange,
            activeColor: AppColors.accent,
            side: const BorderSide(color: AppColors.textMuted, width: 1.5),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 14)),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? error,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analyze passes**

```
flutter analyze lib/screens/progression_screen.dart
```
Expected: No issues.

- [ ] **Step 3: Commit**

```
git add lib/screens/progression_screen.dart
git commit -m "feat: add ProgressionScreen with expandable exercise cards"
```

---

## Task 5: Add Third Tab to Navigation

**Files:**
- Modify: `lib/widgets/liquid_glass_nav_bar.dart` — add 3rd `_NavItem`
- Modify: `lib/screens/home_screen.dart` — map index 2, add `go('/progression')`
- Modify: `lib/app/router.dart` — add `/progression` route to `ShellRoute`

- [ ] **Step 1: Add 3rd `_NavItem` to `LiquidGlassNavBar`**

In `lib/widgets/liquid_glass_nav_bar.dart`, inside the `Row` that currently has 2 `_NavItem`s, add a third after the `Активность` item:

```dart
_NavItem(
  icon: Icons.trending_up_outlined,
  activeIcon: Icons.trending_up,
  label: 'Прогрессия',
  selected: currentIndex == 2,
  onTap: () => onTap(2),
),
```

Also adjust the horizontal padding so 3 items fit — change each `_NavItem`'s `Padding` from `horizontal: 24` to `horizontal: 16`.

- [ ] **Step 2: Update `HomeScreen._tabIndex` and `onTap`**

In `lib/screens/home_screen.dart`, update `_tabIndex`:

```dart
int _tabIndex(String location) {
  if (location.startsWith('/activity')) return 1;
  if (location.startsWith('/progression')) return 2;
  return 0;
}
```

And update the `LiquidGlassNavBar.onTap` callback:

```dart
onTap: (i) {
  if (i == 0) context.go('/today');
  if (i == 1) context.go('/activity');
  if (i == 2) context.go('/progression');
},
```

- [ ] **Step 3: Add `/progression` route to `router.dart`**

In `lib/app/router.dart`, add the import:
```dart
import '../screens/progression_screen.dart';
```

Inside the `ShellRoute.routes` list (after the `/activity` route), add:
```dart
GoRoute(
  path: '/progression',
  pageBuilder: (_, __) =>
      const NoTransitionPage(child: ProgressionScreen()),
),
```

- [ ] **Step 4: Verify analyze passes**

```
flutter analyze lib/widgets/liquid_glass_nav_bar.dart lib/screens/home_screen.dart lib/app/router.dart
```
Expected: No issues.

- [ ] **Step 5: Commit**

```
git add lib/widgets/liquid_glass_nav_bar.dart lib/screens/home_screen.dart lib/app/router.dart
git commit -m "feat: add Прогрессия as third tab in nav bar and router"
```

---

## Task 6: Update AddExerciseDialog to Use Custom Configs

**Files:**
- Modify: `lib/widgets/add_exercise_dialog.dart`

**Interfaces:**
- Consumes: `progressionConfigProvider(code)` from Task 3
- The top-level `_suggest()` function gains a second parameter `ProgressionConfig? config`

- [ ] **Step 1: Add import**

At the top of `lib/widgets/add_exercise_dialog.dart`, add:
```dart
import '../models/progression_config.dart';
import '../providers/progression_provider.dart';
```

- [ ] **Step 2: Replace the `_suggest()` function**

Replace the entire existing `_suggest()` function with:

```dart
({double weight, int sets, int reps, bool isProgressed}) _suggest(
  Exercise last,
  ProgressionConfig? config,
) {
  // ── Custom config: repeating ────────────────────────────────────────────
  if (config != null && config.isRepeating) {
    return (
      weight: last.weight,
      sets: last.sets,
      reps: last.reps,
      isProgressed: false,
    );
  }

  // ── Custom config: custom ladder ────────────────────────────────────────
  if (config != null && config.ladder.isNotEmpty) {
    final allDone = last.completedSets.every((c) => c);
    if (!allDone) {
      return (
        weight: last.weight,
        sets: last.sets,
        reps: last.reps,
        isProgressed: false,
      );
    }

    final stepIdx = config.ladder
        .indexWhere((s) => s.$1 == last.sets && s.$2 == last.reps);
    if (stepIdx == -1) {
      return (
        weight: last.weight,
        sets: last.sets,
        reps: last.reps,
        isProgressed: false,
      );
    }

    final weightIdx = config.weights
        .indexWhere((w) => (w - last.weight).abs() < 0.01);

    int nextStep = stepIdx + 1;
    int nextWeightIdx = weightIdx < 0 ? 0 : weightIdx;

    if (nextStep >= config.ladder.length) {
      // End of ladder → advance weight, reset to step 0
      nextStep = 0;
      nextWeightIdx = (weightIdx < 0 ? 0 : weightIdx) + 1;
      if (nextWeightIdx >= config.weights.length) {
        // Already at max weight — stay
        return (
          weight: last.weight,
          sets: config.ladder.last.$1,
          reps: config.ladder.last.$2,
          isProgressed: false,
        );
      }
    }

    final nextWeight = config.weights.isNotEmpty
        ? config.weights[nextWeightIdx]
        : last.weight;
    final step = config.ladder[nextStep];
    return (
      weight: nextWeight,
      sets: step.$1,
      reps: step.$2,
      isProgressed: true,
    );
  }

  // ── Fallback: hardcoded default ladder ──────────────────────────────────
  if (_noProgressionCodes.contains(last.code)) {
    return (
      weight: last.weight,
      sets: last.sets,
      reps: last.reps,
      isProgressed: false,
    );
  }

  final idx = _ladder.indexWhere(
      (s) => s.$1 == last.sets && s.$2 == last.reps);
  if (idx == -1) {
    return (
      weight: last.weight,
      sets: last.sets,
      reps: last.reps,
      isProgressed: false,
    );
  }

  final allDone = last.completedSets.every((c) => c);
  if (!allDone) {
    return (
      weight: last.weight,
      sets: last.sets,
      reps: last.reps,
      isProgressed: false,
    );
  }

  if (idx == _ladder.length - 1) {
    final nextWeight = last.weight > 0 ? last.weight + _weightStep : 0.0;
    return (weight: nextWeight, sets: 3, reps: 10, isProgressed: true);
  }

  final next = _ladder[idx + 1];
  return (
    weight: last.weight,
    sets: next.$1,
    reps: next.$2,
    isProgressed: true,
  );
}
```

- [ ] **Step 3: Update `_applyLast()` to read the config**

In `_AddExerciseDialogState`, replace `_applyLast`:

```dart
void _applyLast(Exercise last) {
  final config = ref.read(progressionConfigProvider(last.code));
  final s = _suggest(last, config);

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

- [ ] **Step 4: Verify analyze passes**

```
flutter analyze lib/widgets/add_exercise_dialog.dart
```
Expected: No issues.

- [ ] **Step 5: Verify whole project**

```
flutter analyze
```
Expected: No issues found.

- [ ] **Step 6: Commit**

```
git add lib/widgets/add_exercise_dialog.dart
git commit -m "feat: use custom ProgressionConfig in AddExerciseDialog suggestion logic"
```
