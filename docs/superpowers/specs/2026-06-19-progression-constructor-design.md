# Progression Constructor — Design Spec
**Date:** 2026-06-19

## Overview

A dedicated third tab ("Прогрессия") that lets the user configure per-exercise progression rules. Replaces the hardcoded `_ladder` and `_noProgressionCodes` in `add_exercise_dialog.dart` with user-defined configs stored in Firestore.

## Data Model

### `ProgressionConfig`
```dart
class ProgressionConfig {
  final String exerciseCode;
  final bool isRepeating;   // repeats same values, no progression
  final bool isStrength;    // cosmetic flag (displayed as chip)
  final List<double> weights;         // e.g. [40, 42.5, 45, 47.5]
  final List<(int sets, int reps)> ladder;  // e.g. [(3,10),(3,12),(3,15),...]
}
```

If `isRepeating == true`, `weights` and `ladder` are empty — exercise always repeats last values.

### Firestore path
```
users/{uid}/progressions/{exerciseCode}
  isRepeating: bool
  isStrength: bool
  weights: [40.0, 42.5, 45.0, ...]
  ladder: ["3x10", "3x12", "3x15", "4x10", ...]
```

## Architecture

### New files
- `lib/models/progression_config.dart` — model + serialization
- `lib/providers/progression_provider.dart` — `progressionsProvider` (StreamProvider), `progressionConfigProvider.family` per code
- `lib/screens/progression_screen.dart` — the tab screen
- `lib/services/firestore_service.dart` — add `watchProgressions()`, `saveProgression()`, `deleteProgression()`

### Modified files
- `lib/screens/home_screen.dart` — add 3rd tab
- `lib/app/router.dart` — add `/progression` route
- `lib/widgets/add_exercise_dialog.dart` — `_suggest()` updated to use custom config

## UI: Progression Screen

Scrollable list of all exercises from `KeyDictionary`. Each is an expandable glass card (accordion, custom animation — NOT Material `ExpansionTile`).

**Collapsed state:** shows exercise name + status chips on the right:
- No config → grey "default" chip
- `isRepeating` → 🔁 chip
- `isStrength` → ⚡ chip
- Has custom ladder → green "custom" chip

**Expanded state (inline, animated with `AnimatedCrossFade` or `AnimatedSize`):**
```
┌─ Жим лёжа (BP) ────────── [⚡] [custom] ▼ ┐
│                                             │
│  [✓] Повторяющееся   [✓] Силовое           │
│                                             │
│  Веса (через запятую, кг):                 │
│  [40, 42.5, 45, 47.5, 50              ]    │
│                                             │
│  Прогрессия (формат 3x10, 4x12, ...):     │
│  [3x10, 3x12, 3x15, 4x10, 4x12, 4x15]    │
│                                             │
│  [Сбросить]                [Сохранить]     │
└─────────────────────────────────────────────┘
```

When `isRepeating` is checked, weight/ladder fields are hidden. Fields show inline validation (parse error highlighted in red). "Сбросить" deletes the custom config (reverts to default ladder).

Only one card can be expanded at a time (tapping another collapses the previous).

## Progression Logic (`_suggest()` update)

```
1. Load ProgressionConfig for this code (from progressionConfigProvider)
2. Load last Exercise from Firestore
3. If no last exercise → return defaults (empty fields, no hint)
4. If config exists AND isRepeating → return (last.weight, last.sets, last.reps), hint: "Повторяется"
5. If config exists AND NOT isRepeating:
   a. Find current weight index: config.weights.indexOf(last.weight)
   b. Find current step index: config.ladder.indexWhere(sets==last.sets && reps==last.reps)
   c. If all sets done:
      - Advance step; if at end → advance weight, reset step to 0
      - If weight also at end → stay at last weight (max reached)
   d. Return (weights[nextWeightIdx], ladder[nextStepIdx])
6. If NO config → use existing default 3×10→6×15 ladder logic
```

## Navigation

- HomeScreen gets a 3rd tab: `CupertinoTabBar` item with icon `Icons.trending_up_outlined`, label "Прогрессия"
- Route: `/progression` as a `NoTransitionPage` in the `ShellRoute`

## Error Handling

- Parse errors in weights/ladder fields: show red hint text, disable Save button
- Firestore write error: show snackbar "Не удалось сохранить"
- Empty KeyDictionary: show placeholder "Сначала настройте Key 1 в настройках"

## Out of Scope

- Reordering ladder steps via drag-and-drop (type manually)
- Importing/exporting configs
- Per-exercise weight step (always advances to next weight in the list)
