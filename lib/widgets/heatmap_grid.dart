import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../app/theme.dart';

class HeatmapGrid extends StatelessWidget {
  final Map<String, double?> dayCompletions;
  final DateTime month;
  final void Function(String date) onDayTap;
  final String? todayDate;

  const HeatmapGrid({
    super.key,
    required this.dayCompletions,
    required this.month,
    required this.onDayTap,
    this.todayDate,
  });

  Color _colorFor(double? ratio) {
    if (ratio == null) return AppColors.heatmapEmpty;
    if (ratio == 0) return AppColors.heatmap0;
    if (ratio < 0.5) return AppColors.heatmap50.withValues(alpha: 0.7);
    if (ratio < 1.0) return AppColors.heatmap75;
    return AppColors.heatmap100;
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
        DateUtils.getDaysInMonth(month.year, month.month);
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final startOffset = (firstWeekday - 1) % 7;
    final fmt = DateFormat('yyyy-MM-dd');
    final weekLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final totalCells = startOffset + daysInMonth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: weekLabels
              .map((l) => Expanded(
                    child: Center(
                      child: Text(l,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 10)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: totalCells,
          itemBuilder: (context, index) {
            if (index < startOffset) return const SizedBox.shrink();
            final day = index - startOffset + 1;
            final dateStr =
                fmt.format(DateTime(month.year, month.month, day));
            final ratio = dayCompletions[dateStr];
            final isToday = dateStr == todayDate;

            return GestureDetector(
              onTap: () => onDayTap(dateStr),
              child: Container(
                decoration: BoxDecoration(
                  color: _colorFor(ratio),
                  borderRadius: BorderRadius.circular(3),
                  border: isToday
                      ? Border.all(color: AppColors.accent, width: 1.5)
                      : null,
                ),
              )
                  .animate()
                  .fadeIn(
                    duration: 250.ms,
                    delay: Duration(milliseconds: index * 8),
                  ),
            );
          },
        ),
      ],
    );
  }
}
