import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../app/theme.dart';
import '../providers/workout_provider.dart';
import '../widgets/heatmap_grid.dart';

class HeatmapScreen extends ConsumerWidget {
  const HeatmapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final monthLabel = DateFormat('MMMM yyyy', 'ru').format(now);

    final workoutsAsync = ref.watch(
      monthWorkoutsProvider((year: now.year, month: now.month)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          monthLabel[0].toUpperCase() + monthLabel.substring(1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: workoutsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('Ошибка загрузки: $e',
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
          data: (workouts) {
            final completions = <String, double?>{
              for (final w in workouts) w.date: w.completionRatio,
            };
            return SingleChildScrollView(
              child: HeatmapGrid(
                dayCompletions: completions,
                month: DateTime(now.year, now.month),
                todayDate: todayStr,
                onDayTap: (date) => context.push('/workout/$date'),
              ),
            );
          },
        ),
      ),
    );
  }
}
