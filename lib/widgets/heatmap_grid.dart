import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../app/theme.dart';

class HeatmapGrid extends StatelessWidget {
  final Map<String, double?> dayCompletions;
  final DateTime month;
  final void Function(String date) onDayTap;
  final String? todayDate;
  final bool compact;
  // When set, tile size is constrained so all rows fit within this height.
  final double? fillHeight;

  const HeatmapGrid({
    super.key,
    required this.dayCompletions,
    required this.month,
    required this.onDayTap,
    this.todayDate,
    this.compact = false,
    this.fillHeight,
  });

  static Color colorFor(double? ratio) {
    if (ratio == null) return AppColors.heatmapEmpty;
    if (ratio == 0) return const Color(0xFF1B4332);
    if (ratio < 0.20) return const Color(0xFF1E5038);
    if (ratio < 0.35) return const Color(0xFF2D6A4F);
    if (ratio < 0.50) return const Color(0xFF388660);
    if (ratio < 0.65) return const Color(0xFF40916C);
    if (ratio < 0.85) return const Color(0xFF52B788);
    return const Color(0xFF74C69D);
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final startOffset = (firstWeekday - 1) % 7;
    final fmt = DateFormat('yyyy-MM-dd');
    final weekLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final totalCells = startOffset + daysInMonth;
    final spacing = compact ? 2.0 : 5.0;
    const maxRows = 6;
    final labelsH = compact ? 16.0 : 22.0;
    final labelsGap = compact ? 3.0 : 5.0;

    return LayoutBuilder(builder: (context, constraints) {
      // Tile size by width: fill available width across 7 columns
      final tileByWidth = (constraints.maxWidth - 6 * spacing) / 7;

      // Tile size by height: fit maxRows into fillHeight
      double tileSize = tileByWidth;
      if (fillHeight != null) {
        final gridH = fillHeight! - labelsH - labelsGap;
        final tileByHeight = (gridH - (maxRows - 1) * spacing) / maxRows;
        tileSize = min(tileByWidth, tileByHeight.clamp(4.0, double.infinity));
      }

      final gridWidth = 7 * tileSize + 6 * spacing;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Week day labels aligned to grid width
          SizedBox(
            width: gridWidth,
            child: Row(
              children: weekLabels
                  .map((l) => Expanded(
                        child: Center(
                          child: Text(
                            l,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: compact ? 7 : 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          SizedBox(height: labelsGap),
          SizedBox(
            width: gridWidth,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                childAspectRatio: 1.0, // always square
              ),
              itemCount: totalCells,
              itemBuilder: (context, index) {
                if (index < startOffset) return const SizedBox.shrink();
                final day = index - startOffset + 1;
                final dateStr =
                    fmt.format(DateTime(month.year, month.month, day));
                final ratio = dayCompletions[dateStr];
                final isToday = dateStr == todayDate;
                final color = colorFor(ratio);

                return GestureDetector(
                  onTap: () => onDayTap(dateStr),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius:
                          BorderRadius.circular(compact ? 2 : 6),
                      border: isToday
                          ? Border.all(
                              color: AppColors.accent, width: 1.5)
                          : ratio != null
                              ? Border.all(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  width: 0.5)
                              : null,
                      boxShadow: !compact && ratio != null && ratio > 0
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: compact
                        ? null
                        : Center(
                            child: Text(
                              '$day',
                              style: TextStyle(
                                fontSize: 9,
                                color: ratio != null
                                    ? Colors.white.withValues(alpha: 0.5)
                                    : AppColors.textMuted.withValues(alpha: 0.3),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                  )
                      .animate()
                      .fadeIn(
                        duration: 220.ms,
                        delay: Duration(milliseconds: index * 6),
                      ),
                );
              },
            ),
          ),
        ],
      );
    });
  }
}
