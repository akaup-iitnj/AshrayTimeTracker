import 'package:flutter/material.dart';

import 'models.dart';

class DateNavigator extends StatelessWidget {
  const DateNavigator({
    super.key,
    required this.date,
    required this.onDateChanged,
  });

  final DateTime date;
  final ValueChanged<DateTime> onDateChanged;

  Future<void> _openCalendar(BuildContext context) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Jump to a day',
      cancelText: 'Cancel',
      confirmText: 'Open day',
    );
    if (selected != null) onDateChanged(dayOnly(selected));
  }

  @override
  Widget build(BuildContext context) {
    final today = dayOnly(DateTime.now());
    final localizations = MaterialLocalizations.of(context);
    final dateText = localizations.formatMediumDate(date);
    final relative = isSameDay(date, today)
        ? 'Today'
        : isSameDay(date, today.subtract(const Duration(days: 1)))
        ? 'Yesterday'
        : null;

    return Row(
      children: [
        IconButton(
          tooltip: 'Previous day',
          onPressed: () =>
              onDateChanged(date.subtract(const Duration(days: 1))),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                relative ?? dateText,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (relative != null)
                Text(dateText, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Next day',
          onPressed: () => onDateChanged(date.add(const Duration(days: 1))),
          icon: const Icon(Icons.chevron_right),
        ),
        IconButton(
          tooltip: 'Open calendar',
          onPressed: () => _openCalendar(context),
          icon: const Icon(Icons.calendar_month_outlined),
        ),
        if (!isSameDay(date, today))
          TextButton(
            onPressed: () => onDateChanged(today),
            child: const Text('Today'),
          ),
      ],
    );
  }
}
