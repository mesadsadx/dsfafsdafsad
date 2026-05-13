import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../app/theme.dart';
import '../providers/workout_provider.dart';
import '../widgets/heatmap_grid.dart';

class HeatmapScreen extends ConsumerStatefulWidget {
  const HeatmapScreen({super.key});

  @override
  ConsumerState<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends ConsumerState<HeatmapScreen> {
  bool _yearView = false;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final monthLabel = DateFormat('MMMM yyyy', 'ru').format(now);
    final label = monthLabel[0].toUpperCase() + monthLabel.substring(1);

    return Scaffold(
      appBar: AppBar(
        title: Text(_yearView ? '${now.year}' : label),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _ViewToggle(
              yearView: _yearView,
              onChanged: (v) => setState(() => _yearView = v),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: _yearView
            ? _YearView(key: const ValueKey('year'), todayStr: todayStr)
            : _MonthView(
                key: const ValueKey('month'),
                now: now,
                todayStr: todayStr,
              ),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  final bool yearView;
  final ValueChanged<bool> onChanged;

  const _ViewToggle({required this.yearView, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Seg(label: 'Мес', selected: !yearView, onTap: () => onChanged(false)),
          _Seg(label: 'Год', selected: yearView, onTap: () => onChanged(true)),
        ],
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Seg({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.black : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Month view ────────────────────────────────────────────────

class _MonthView extends ConsumerWidget {
  final DateTime now;
  final String todayStr;

  const _MonthView({super.key, required this.now, required this.todayStr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(
      monthWorkoutsProvider((year: now.year, month: now.month)),
    );

    return workoutsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Ошибка: $e',
            style: const TextStyle(color: AppColors.textSecondary)),
      ),
      data: (workouts) {
        final completions = <String, double?>{
          for (final w in workouts) w.date: w.completionRatio,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _LegendRow(),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  child: HeatmapGrid(
                    dayCompletions: completions,
                    month: DateTime(now.year, now.month),
                    todayDate: todayStr,
                    onDayTap: (date) => context.push('/workout/$date'),
                    fillHeight: constraints.maxHeight - 80,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Year view ─────────────────────────────────────────────────

class _YearView extends ConsumerWidget {
  final String todayStr;

  const _YearView({super.key, required this.todayStr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final months = List.generate(12, (i) => DateTime(now.year, i + 1));
    final fmt = DateFormat('MMMM', 'ru');

    // Pair months into rows of 2
    final rows = List.generate(6, (i) => [months[i * 2], months[i * 2 + 1]]);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LegendRow(),
          const SizedBox(height: 16),
          ...rows.map((pair) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int m = 0; m < pair.length; m++) ...[
                      if (m > 0) const SizedBox(width: 16),
                      Expanded(child: _MiniMonth(
                        month: pair[m],
                        todayStr: todayStr,
                        monthLabel: () {
                          final raw = fmt.format(pair[m]);
                          return raw[0].toUpperCase() + raw.substring(1);
                        }(),
                      )),
                    ],
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ── Mini month (year view cell) ───────────────────────────────

class _MiniMonth extends ConsumerWidget {
  final DateTime month;
  final String todayStr;
  final String monthLabel;

  const _MiniMonth({
    required this.month,
    required this.todayStr,
    required this.monthLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(
      monthWorkoutsProvider((year: month.year, month: month.month)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          monthLabel,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 5),
        workoutsAsync.when(
          loading: () => const SizedBox(
            height: 50,
            child: Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ),
          ),
          error: (_, __) => const SizedBox(height: 50),
          data: (workouts) {
            final completions = <String, double?>{
              for (final w in workouts) w.date: w.completionRatio,
            };
            return HeatmapGrid(
              dayCompletions: completions,
              month: month,
              todayDate: todayStr,
              onDayTap: (date) => context.push('/workout/$date'),
              compact: true,
            );
          },
        ),
      ],
    );
  }
}

// ── Legend ────────────────────────────────────────────────────

class _LegendRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final steps = [null, 0.0, 0.35, 0.65, 1.0];
    final labels = ['—', '0%', '35%', '65%', '100%'];

    return Row(
      children: [
        const Text('Прогресс:',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(width: 8),
        ...List.generate(steps.length, (i) {
          return Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: HeatmapGrid.colorFor(steps[i]),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 3),
              Text(labels[i],
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 10)),
              const SizedBox(width: 8),
            ],
          );
        }),
      ],
    );
  }
}
