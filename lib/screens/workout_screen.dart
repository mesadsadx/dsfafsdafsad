import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../app/theme.dart';
import '../models/exercise.dart';
import '../providers/workout_provider.dart';
import '../widgets/add_exercise_dialog.dart';
import '../widgets/exercise_card.dart';
import '../widgets/week_strip.dart';

class WorkoutScreen extends ConsumerStatefulWidget {
  final String? date;

  const WorkoutScreen({super.key, this.date});

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.date != null
        ? DateTime.parse(widget.date!)
        : DateTime.now();
  }

  bool get _showWeekStrip => widget.date == null;

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

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

    return Scaffold(
      appBar: AppBar(
        title: Text(_formatDate(_selectedDate)),
        leading: widget.date != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
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
        padding: EdgeInsets.only(bottom: _showWeekStrip ? bottomPad + 72 : 0),
        child: FloatingActionButton(
          onPressed: () async {
            final exercise = await showDialog<Exercise>(
              context: context,
              builder: (_) => const AddExerciseDialog(),
            );
            if (exercise != null) notifier.addExercise(exercise);
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
