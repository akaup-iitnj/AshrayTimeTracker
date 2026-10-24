import 'package:flutter/material.dart';

import 'bold.dart';
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
        _NavTile(
          tooltip: 'Previous day',
          icon: Icons.chevron_left_rounded,
          onTap: () => onDateChanged(date.subtract(const Duration(days: 1))),
        ),
        Expanded(
          child: Column(
            children: [
              Text(relative ?? dateText, style: archivo(800, size: 18)),
              if (relative != null)
                Text(dateText, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        _NavTile(
          tooltip: 'Next day',
          icon: Icons.chevron_right_rounded,
          onTap: () => onDateChanged(date.add(const Duration(days: 1))),
        ),
        const SizedBox(width: 6),
        _NavTile(
          tooltip: 'Open calendar',
          icon: Icons.calendar_month_rounded,
          color: Bold.sky,
          onTap: () => _openCalendar(context),
        ),
        if (!isSameDay(date, today)) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: 'Go to today',
            child: BoldCard(
              color: Bold.yellow,
              radius: Bold.radiusSm,
              shadow: Bold.shadowSm,
              onTap: () => onDateChanged(today),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Text('Today', style: dmSans(800, size: 13)),
            ),
          ),
        ],
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.color = Bold.panel,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: BoldCard(
        color: color,
        radius: Bold.radiusSm,
        shadow: Bold.shadowSm,
        onTap: onTap,
        semanticLabel: tooltip,
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 22, color: Bold.ink),
      ),
    );
  }
}
