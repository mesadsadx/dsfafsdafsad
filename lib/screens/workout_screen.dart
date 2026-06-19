import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../app/theme.dart';
import '../models/exercise.dart';
import '../providers/auth_provider.dart';
import '../providers/progression_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';
import '../utils/progression.dart';
import '../widgets/add_exercise_dialog.dart';
import '../widgets/edit_exercise_dialog.dart';
import '../widgets/exercise_card.dart';
import '../widgets/glass_icon_button.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/week_strip.dart';

class WorkoutScreen extends ConsumerStatefulWidget {
  final String? date;

  const WorkoutScreen({super.key, this.date});

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  late DateTime _selectedDate;
  bool _loadingTemplate = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.date != null
        ? (DateTime.tryParse(widget.date!) ?? DateTime.now())
        : DateTime.now();
  }

  bool get _showWeekStrip => widget.date == null;

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

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

      final entries = dict.sortedEntries
          .where((e) => groups.contains(configs[e.key]?.group))
          .toList();

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
          final isStrength = config?.isStrength ?? true;
          weight = (isStrength && config?.weights.isNotEmpty == true)
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

      await ref
          .read(workoutNotifierProvider(_dateStr).notifier)
          .addExercises(exercises);
    } finally {
      if (mounted) setState(() => _loadingTemplate = false);
    }
  }

  Future<void> _confirmClear(BuildContext context, WorkoutNotifier notifier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Очистить день?'),
        content: const Text(
          'Все упражнения за этот день будут удалены.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true) notifier.clearWorkout();
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final isToday =
        d.year == now.year && d.month == now.month && d.day == now.day;
    if (isToday) return 'Сегодня';
    return DateFormat('d MMMM', 'ru').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final workoutAsync = ref.watch(workoutNotifierProvider(_dateStr));
    final notifier = ref.read(workoutNotifierProvider(_dateStr).notifier);
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final dict = ref.watch(dictionaryProvider).valueOrNull;
    ref.watch(nextSessionProvider);
    ref.watch(lastWorkoutProvider);

    return GradientScaffold(
      appBar: AppBar(
        title: Text(_formatDate(_selectedDate)),
        leading: widget.date != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
        actions: [
          if (workoutAsync.valueOrNull?.exercises.isNotEmpty == true)
            GlassIconButton(
              icon: Icons.delete_outline,
              onPressed: () => _confirmClear(context, notifier),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8, left: 4),
            child: GlassIconButton(
              icon: Icons.settings_outlined,
              onPressed: () => context.push('/settings'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showWeekStrip)
            WeekStrip(
              selectedDate: _selectedDate,
              onSelect: (d) => setState(() => _selectedDate = d),
            ),
          Expanded(
            child: workoutAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Ошибка: $e',
                    style:
                        const TextStyle(color: AppColors.textSecondary)),
              ),
              data: (workout) {
                if (workout == null || workout.exercises.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Тренировки нет.\nДобавьте упражнение или загрузите Key 2 в настройках.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textSecondary, height: 1.6),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      child: LinearProgressIndicator(
                        value: workout.completionRatio,
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.accent),
                        minHeight: 3,
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                            16, 16, 16, bottomPad + 80),
                        itemCount: workout.exercises.length,
                        separatorBuilder: (_, __) => const Gap(10),
                        itemBuilder: (_, i) => ExerciseCard(
                          exercise: workout.exercises[i],
                          exerciseIndex: i,
                          onSetToggle: notifier.toggleSet,
                          onEdit: (idx) async {
                            final updated =
                                await showDialog<Exercise>(
                              context: context,
                              builder: (_) => EditExerciseDialog(
                                exercise: workout.exercises[idx],
                              ),
                            );
                            if (updated != null) {
                              notifier.updateExercise(idx, updated);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding:
            EdgeInsets.only(bottom: _showWeekStrip ? bottomPad + 72 : 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (dict != null && !dict.isEmpty) ...[
              FloatingActionButton.small(
                heroTag: 'template',
                tooltip: 'Загрузить тренировку',
                onPressed: () {
                  final hasExercises =
                      workoutAsync.valueOrNull?.exercises.isNotEmpty == true;
                  if (!hasExercises && !_loadingTemplate) _loadTemplate();
                },
                backgroundColor: () {
                  final hasExercises =
                      workoutAsync.valueOrNull?.exercises.isNotEmpty == true;
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
                          final hasExercises = workoutAsync
                                  .valueOrNull?.exercises.isNotEmpty ==
                              true;
                          return (hasExercises || _loadingTemplate)
                              ? AppColors.textMuted
                              : Colors.black;
                        }(),
                      ),
              ),
              const SizedBox(height: 8),
            ],
            FloatingActionButton(
              heroTag: 'add',
              onPressed: () async {
                final exercise = await showDialog<Exercise>(
                  context: context,
                  builder: (_) => const AddExerciseDialog(),
                );
                if (exercise != null) notifier.addExercise(exercise);
              },
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
