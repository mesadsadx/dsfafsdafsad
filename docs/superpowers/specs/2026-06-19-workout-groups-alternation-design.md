# Workout Groups & Alternation — Design Spec
**Date:** 2026-06-19

## Overview

Each exercise can be assigned to a group (A, B, C, D, or None). Exercises in group None appear in every workout. A+B form one session, C+D form the alternating session. A "Load workout" button in WorkoutScreen auto-populates all exercises for today's session with progression applied.

## Groups

| Group | Meaning |
|-------|---------|
| None  | Always included in every workout |
| A     | Session 1 — primary back |
| B     | Session 1 — primary shoulders |
| C     | Session 2 — alternates with A (back) |
| D     | Session 2 — alternates with B (shoulders) |

Session 1 = {None} + {A} + {B}  
Session 2 = {None} + {C} + {D}

## Session Determination

When loading today's workout:

1. Fetch last non-empty workout from Firestore (already ordered by date desc)
2. Cross-reference each exercise code with `progressions` configs
3. If any exercise in that workout belongs to A or B → next session is **CD**
4. If any exercise in that workout belongs to C or D → next session is **AB**
5. If no group matches (all None or no history) → default to **AB**

This is computed in a `Provider.autoDispose` (`nextSessionProvider`) that watches `progressionsProvider` and `lastWorkoutProvider`.

## Data Model Changes

Add `group` field to `ProgressionConfig`:

```dart
final String? group; // null | 'A' | 'B' | 'C' | 'D'
```

Firestore field: `'group'` (string or null/absent).

## Architecture

### New providers
- `lastWorkoutProvider` — `FutureProvider.autoDispose<Workout?>`: fetches most recent non-empty workout (reuses `getLastWorkout` from FirestoreService)
- `nextSessionProvider` — `Provider.autoDispose<String>`: derives 'AB' or 'CD' from last workout + progression configs

### Modified files
- `lib/models/progression_config.dart` — add `group` field
- `lib/services/firestore_service.dart` — add `getLastWorkout(uid)` method
- `lib/providers/progression_provider.dart` — add `lastWorkoutProvider`, `nextSessionProvider`
- `lib/screens/progression_screen.dart` — add group selector chips in each card
- `lib/screens/workout_screen.dart` — add secondary FAB, `_loadTemplate()` method
- `lib/providers/workout_provider.dart` — add `loadTemplate(List<Exercise>)` batch method

## UI: Progression Screen — Group Selector

Inside each expanded card, below the isRepeating/isStrength checkboxes, add a row of chips: `None  A  B  C  D`. Selected chip is highlighted with `AppColors.accent`. Saved alongside the rest of the config.

## UI: WorkoutScreen — Load Template Button

A secondary small FAB appears above the main "+" FAB, with icon `Icons.playlist_add_outlined`. Only active (non-grey) when the day's exercises list is empty.

On tap:
1. Read `nextSessionProvider` → determine groups to load (e.g., {null, 'A', 'B'})
2. For each exercise in `KeyDictionary` (sorted), where `config.group` is in the target groups:
   a. Fetch `lastExercise(uid, code)` — may already be in cache from `lastExerciseProvider`
   b. Apply `_suggest(last, config)` to get weight/sets/reps
   c. Build `Exercise` object
3. Call `notifier.addExercises(List<Exercise>)` → single batch write to Firestore

`addExercises` in `WorkoutNotifier` is a new method that appends all exercises optimistically (similar to existing `addExercise` but handles a list in a single Firestore transaction).

## Error Handling

- If `lastExercise` is null for a given code → use `config.weights.isNotEmpty ? config.weights.first : 0.0` as default weight, and `config.ladder.isNotEmpty ? config.ladder.first : (3, 10)` as default sets/reps
- If Firestore write fails → optimistic rollback (same pattern as existing `addExercise`)
- If `KeyDictionary` is empty → the secondary FAB is hidden entirely

## Out of Scope

- Manual session override (always auto-determined from history)
- More than 4 groups (A/B/C/D is fixed)
- Multiple split types (A+C one day, B+D another — not supported)
