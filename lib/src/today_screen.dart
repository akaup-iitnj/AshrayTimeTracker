import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_store.dart';
import 'date_navigator.dart';
import 'edit_hour_screen.dart';
import 'models.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    required this.store,
    required this.date,
    required this.onDateChanged,
  });

  final AppStore store;
  final DateTime date;
  final ValueChanged<DateTime> onDateChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final side = math.max(16.0, (constraints.maxWidth - 760) / 2);
            final complete = store.completedCount(date);
            return ListView(
              key: PageStorageKey<String>('day-${dateKey(date)}'),
              padding: EdgeInsets.fromLTRB(side, 22, side, 28),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your day',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      '$complete / 24 logged',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DateNavigator(date: date, onDateChanged: onDateChanged),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: complete / 24,
                    minHeight: 7,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 20),
                for (var hour = 0; hour < 24; hour++) ...[
                  _HourRow(store: store, date: date, hourStart: hour),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _HourRow extends StatelessWidget {
  const _HourRow({
    required this.store,
    required this.date,
    required this.hourStart,
  });

  final AppStore store;
  final DateTime date;
  final int hourStart;

  @override
  Widget build(BuildContext context) {
    final entry = store.entryFor(date, hourStart);
    final category = store.categoryFor(entry?.categoryId);
    final hasTask = entry?.task.isNotEmpty == true;
    final now = DateTime.now();
    final isCurrent = isSameDay(now, date) && now.hour == hourStart;
    final colors = Theme.of(context).colorScheme;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isCurrent ? colors.primary : colors.outlineVariant,
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => EditHourScreen(
                store: store,
                date: date,
                hourStart: hourStart,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              SizedBox(
                width: 88,
                child: Text(
                  hourLabel(hourStart),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isCurrent ? colors.primary : null,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasTask ? entry!.task : 'Tap to add what you did',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: hasTask ? null : colors.onSurfaceVariant,
                        fontStyle: hasTask ? null : FontStyle.italic,
                      ),
                    ),
                    if (category != null || entry?.productive != null) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (category != null)
                            _CategoryLabel(category: category),
                          if (entry?.productive case final productive?)
                            _ProductiveLabel(productive: productive),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                entry?.isComplete == true
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: entry?.isComplete == true
                    ? colors.primary
                    : colors.outlineVariant,
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryLabel extends StatelessWidget {
  const _CategoryLabel({required this.category});

  final TimeCategory category;

  @override
  Widget build(BuildContext context) {
    final color = Color(category.colorValue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        category.name,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProductiveLabel extends StatelessWidget {
  const _ProductiveLabel({required this.productive});

  final bool productive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = productive ? colors.primary : colors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            productive
                ? Icons.thumb_up_alt_outlined
                : Icons.thumb_down_alt_outlined,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            productive ? 'Productive' : 'Not productive',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
