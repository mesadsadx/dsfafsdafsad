import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app/theme.dart';

class WeekStrip extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelect;

  const WeekStrip({super.key, required this.selectedDate, required this.onSelect});

  DateTime get _weekStart {
    final d = selectedDate;
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    final start = _weekStart;
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final selOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
      child: Row(
        children: List.generate(7, (i) {
          final day = start.add(Duration(days: i));
          final dayOnly = DateTime(day.year, day.month, day.day);
          final isSelected = dayOnly == selOnly;
          final isToday = dayOnly == todayOnly;
          final isFuture = dayOnly.isAfter(todayOnly);
          final dayLabel = DateFormat('E', 'ru').format(day);
          final abbr = dayLabel.length >= 2
              ? dayLabel.substring(0, 2).toUpperCase()
              : dayLabel.toUpperCase();

          return Expanded(
            child: GestureDetector(
              onTap: isFuture ? null : () => onSelect(day),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    abbr,
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.4,
                      color: isSelected
                          ? AppColors.accent
                          : isFuture
                              ? AppColors.textMuted.withOpacity(0.4)
                              : AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppColors.accent
                          : isToday
                              ? AppColors.accent.withOpacity(0.12)
                              : Colors.transparent,
                      border: isToday && !isSelected
                          ? Border.all(
                              color: AppColors.accent.withOpacity(0.4), width: 1)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isSelected
                              ? Colors.black
                              : isFuture
                                  ? AppColors.textMuted.withOpacity(0.35)
                                  : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
