import 'package:flutter/material.dart';

class NoteActivityHeatmap extends StatefulWidget {
  const NoteActivityHeatmap({
    super.key,
    required this.activityByDay,
    required this.selectedDate,
    required this.onDateSelected,
    this.weeks = 12,
    this.today,
  });

  final Map<DateTime, int> activityByDay;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final int weeks;
  final DateTime? today;

  @override
  State<NoteActivityHeatmap> createState() => _NoteActivityHeatmapState();

  static DateTime dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static String shortDate(DateTime value) {
    return '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')}';
  }
}

class _NoteActivityHeatmapState extends State<NoteActivityHeatmap> {
  static const double _cellSize = 14;
  static const double _cellGap = 4;
  static const double _weekWidth = _cellSize + _cellGap;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToLatest();
  }

  @override
  void didUpdateWidget(covariant NoteActivityHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weeks != widget.weeks) {
      _scrollToLatest();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final weeks = widget.weeks.clamp(4, 52);
    final normalizedToday = NoteActivityHeatmap.dateOnly(
      widget.today ?? DateTime.now(),
    );
    final currentMonday = normalizedToday.subtract(
      Duration(days: normalizedToday.weekday - DateTime.monday),
    );
    final firstDay = currentMonday.subtract(Duration(days: (weeks - 1) * 7));
    final gridWidth = weeks * _weekWidth - _cellGap;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 22),
          child: _WeekdayLabels(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: weeks > 12,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: gridWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MonthLabels(
                      firstDay: firstDay,
                      weeks: weeks,
                      weekWidth: _weekWidth,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var week = 0; week < weeks; week++) ...[
                          _HeatmapWeek(
                            firstDay: firstDay.add(Duration(days: week * 7)),
                            today: normalizedToday,
                            selectedDate: NoteActivityHeatmap.dateOnly(
                              widget.selectedDate,
                            ),
                            activityByDay: widget.activityByDay,
                            onDateSelected: widget.onDateSelected,
                          ),
                          if (week != weeks - 1)
                            const SizedBox(width: _cellGap),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthLabels extends StatelessWidget {
  const _MonthLabels({
    required this.firstDay,
    required this.weeks,
    required this.weekWidth,
  });

  final DateTime firstDay;
  final int weeks;
  final double weekWidth;

  @override
  Widget build(BuildContext context) {
    final labels = <({int week, int month})>[];
    for (var week = 0; week < weeks; week++) {
      final weekStart = firstDay.add(Duration(days: week * 7));
      for (var day = 0; day < 7; day++) {
        final date = weekStart.add(Duration(days: day));
        if (date.day == 1 &&
            (labels.isEmpty || labels.last.month != date.month)) {
          labels.add((week: week, month: date.month));
          break;
        }
      }
    }
    if (labels.isEmpty || labels.first.week >= 3) {
      labels.insert(0, (week: 0, month: firstDay.month));
    }

    return SizedBox(
      key: const ValueKey('heatmapMonthLabels'),
      height: 18,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final label in labels)
            Positioned(
              left: label.week * weekWidth,
              child: Text(
                '${label.month}月',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      ),
    );
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
            1 => colorScheme.primary.withValues(alpha: 0.3),
            2 => colorScheme.primary.withValues(alpha: 0.5),
            3 => colorScheme.primary.withValues(alpha: 0.72),
            _ => colorScheme.primary,
          };
    final label = '${NoteActivityHeatmap.shortDate(date)}，$count 条笔记';

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
