import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';

/// Month calendar: days with FoG episodes show a dot; tap a day to select it.
/// The questionnaire's most-requested way to review past episodes.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.visibleMonth,
    required this.selectedDay,
    required this.today,
    required this.episodeCountByDay,
    required this.onSelectDay,
    required this.onMonthChanged,
  });

  /// Any date inside the month to display.
  final DateTime visibleMonth;
  final DateTime selectedDay;
  final DateTime today;

  /// Number of episodes per day (keys are date-only values).
  final Map<DateTime, int> episodeCountByDay;
  final ValueChanged<DateTime> onSelectDay;
  final ValueChanged<DateTime> onMonthChanged;

  static const List<String> _weekdayLetters = [
    'S',
    'M',
    'T',
    'W',
    'T',
    'F',
    'S'
  ];

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final daysInMonth =
        DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
    // Sunday-first grid: Sunday (weekday 7) -> 0, Monday -> 1 ...
    final leadingBlanks = firstOfMonth.weekday % 7;
    final totalCells = ((leadingBlanks + daysInMonth + 6) ~/ 7) * 7;

    final canGoForward = DateTime(visibleMonth.year, visibleMonth.month + 1, 1)
        .isBefore(DateTime(today.year, today.month + 1, 1));

    final rows = <Widget>[];
    for (var row = 0; row < totalCells ~/ 7; row++) {
      final cells = <Widget>[];
      for (var col = 0; col < 7; col++) {
        final index = row * 7 + col;
        final dayNumber = index - leadingBlanks + 1;
        if (dayNumber < 1 || dayNumber > daysInMonth) {
          cells.add(const Expanded(child: SizedBox(height: 52)));
        } else {
          final day =
              DateTime(visibleMonth.year, visibleMonth.month, dayNumber);
          cells.add(Expanded(child: _buildDay(day)));
        }
      }
      rows.add(Row(children: cells));
    }

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              iconSize: 30,
              color: AppColors.navy,
              constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => onMonthChanged(
                  DateTime(visibleMonth.year, visibleMonth.month - 1, 1)),
            ),
            Expanded(
              child: Text(
                Fmt.monthYear(visibleMonth),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              iconSize: 30,
              color: AppColors.navy,
              constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: canGoForward
                  ? () => onMonthChanged(
                      DateTime(visibleMonth.year, visibleMonth.month + 1, 1))
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final letter in _weekdayLetters)
              Expanded(
                child: Center(
                  child: Text(
                    letter,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        ...rows,
      ],
    );
  }

  Widget _buildDay(DateTime day) {
    final isFuture = day.isAfter(Fmt.dayOnly(today));
    final isSelected = Fmt.sameDay(day, selectedDay);
    final isToday = Fmt.sameDay(day, today);
    final count = episodeCountByDay[day] ?? 0;

    final Color textColor;
    if (isSelected) {
      textColor = Colors.white;
    } else if (isFuture) {
      textColor = AppColors.border;
    } else {
      textColor = AppColors.ink;
    }

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${Fmt.dateLong(day)}, '
          '${count == 0 ? 'no episodes' : '$count episode${count == 1 ? '' : 's'}'}',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isFuture ? null : () => onSelectDay(day),
        child: Container(
          height: 52,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.navy : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: isToday && !isSelected
                ? Border.all(color: AppColors.sky, width: 2)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                height: 6,
                width: 6,
                decoration: BoxDecoration(
                  color: count == 0
                      ? Colors.transparent
                      : (isSelected ? AppColors.sky : AppColors.navy),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
