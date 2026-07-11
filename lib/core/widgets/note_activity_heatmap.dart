import 'package:flutter/material.dart';

class NoteActivityHeatmap extends StatelessWidget {
  const NoteActivityHeatmap({
    super.key,
    required this.activityByDay,
    required this.selectedDate,
    required this.onDateSelected,
    this.today,
  });

  final Map<DateTime, int> activityByDay;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final weeks = constraints.maxWidth >= 900
            ? 52
            : constraints.maxWidth >= 620
            ? 28
            : 16;
        final normalizedToday = _dateOnly(today ?? DateTime.now());
        final currentMonday = normalizedToday.subtract(
          Duration(days: normalizedToday.weekday - DateTime.monday),
        );
        final firstDay = currentMonday.subtract(
          Duration(days: (weeks - 1) * 7),
        );
        final lastDay = firstDay.add(Duration(days: weeks * 7 - 1));

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_shortDate(firstDay)} - ${_shortDate(lastDay)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '最近 $weeks 周',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _WeekdayLabels(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var week = 0; week < weeks; week++) ...[
                            _HeatmapWeek(
                              firstDay: firstDay.add(Duration(days: week * 7)),
                              today: normalizedToday,
                              selectedDate: _dateOnly(selectedDate),
                              activityByDay: activityByDay,
                              onDateSelected: onDateSelected,
                            ),
                            if (week != weeks - 1) const SizedBox(width: 4),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _IntensityLegend(),
            ],
          ),
        );
      },
    );
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static String _shortDate(DateTime value) {
    return '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')}';
  }
}

class _WeekdayLabels extends StatelessWidget {
  const _WeekdayLabels();

  @override
  Widget build(BuildContext context) {
    const labels = ['一', '', '三', '', '五', '', '日'];
    return Column(
      children: [
        for (final label in labels)
          SizedBox(
            width: 16,
            height: 18,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class _HeatmapWeek extends StatelessWidget {
  const _HeatmapWeek({
    required this.firstDay,
    required this.today,
    required this.selectedDate,
    required this.activityByDay,
    required this.onDateSelected,
  });

  final DateTime firstDay;
  final DateTime today;
  final DateTime selectedDate;
  final Map<DateTime, int> activityByDay;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var dayIndex = 0; dayIndex < 7; dayIndex++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _HeatmapCell(
              date: firstDay.add(Duration(days: dayIndex)),
              today: today,
              selectedDate: selectedDate,
              count: activityByDay[firstDay.add(Duration(days: dayIndex))] ?? 0,
              onDateSelected: onDateSelected,
            ),
          ),
      ],
    );
  }
}

class _HeatmapCell extends StatelessWidget {
  const _HeatmapCell({
    required this.date,
    required this.today,
    required this.selectedDate,
    required this.count,
    required this.onDateSelected,
  });

  final DateTime date;
  final DateTime today;
  final DateTime selectedDate;
  final int count;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final isFuture = date.isAfter(today);
    final isSelected = date == selectedDate;
    final colorScheme = Theme.of(context).colorScheme;
    final background = isFuture
        ? Colors.transparent
        : switch (count) {
            0 => colorScheme.surfaceContainerHighest,
            1 => colorScheme.primary.withValues(alpha: 0.35),
            2 => colorScheme.primary.withValues(alpha: 0.55),
            3 => colorScheme.primary.withValues(alpha: 0.75),
            _ => colorScheme.primary,
          };
    final label = '${NoteActivityHeatmap._shortDate(date)}，$count 条笔记';

    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: !isFuture,
        selected: isSelected,
        child: InkWell(
          key: ValueKey('activity-cell-${_keyDate(date)}'),
          onTap: isFuture ? null : () => onDateSelected(date),
          borderRadius: BorderRadius.circular(3),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(3),
              border: isSelected
                  ? Border.all(color: colorScheme.onSurface, width: 1.5)
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  static String _keyDate(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}

class _IntensityLegend extends StatelessWidget {
  const _IntensityLegend();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = [
      colorScheme.surfaceContainerHighest,
      colorScheme.primary.withValues(alpha: 0.35),
      colorScheme.primary.withValues(alpha: 0.55),
      colorScheme.primary.withValues(alpha: 0.75),
      colorScheme.primary,
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('少', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(width: 6),
        for (final color in colors) ...[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 4),
        ],
        Text('多', style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
