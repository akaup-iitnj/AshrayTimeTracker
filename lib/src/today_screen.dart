import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_store.dart';
import 'bold.dart';
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'Your day',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                    ),
                    BoldTag(label: '$complete / 24 logged'),
                  ],
                ),
                const SizedBox(height: 14),
                DateNavigator(date: date, onDateChanged: onDateChanged),
                const SizedBox(height: 14),
                BoldProgress(value: complete / 24),
                const SizedBox(height: 20),
                for (var hour = 0; hour < 24; hour++) ...[
                  _HourRow(store: store, date: date, hourStart: hour),
                  const SizedBox(height: 6),
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
    final complete = entry?.isComplete == true;
    final now = DateTime.now();
    final isCurrent = isSameDay(now, date) && now.hour == hourStart;
    final text = Theme.of(context).textTheme;

    return BoldCard(
      color: isCurrent ? Bold.yellow : Bold.panel,
      shadow: isCurrent ? Bold.shadow : Bold.shadowSm + 1,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                EditHourScreen(store: store, date: date, hourStart: hourStart),
          ),
        );
      },
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(hourLabel(hourStart), style: archivo(800, size: 14)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasTask ? entry!.task : 'Tap to add what you did',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: hasTask
                      ? text.bodyMedium.weight(600)
                      : text.bodyMedium?.copyWith(
                          color: isCurrent ? Bold.ink : Bold.faint,
                        ),
                ),
                if (category != null || entry?.productive != null) ...[
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (category != null)
                        CategoryChip(
                          name: category.name,
                          color: Color(category.colorValue),
                        ),
                      if (entry?.productive case final productive?)
                        ProductiveTag(productive: productive),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _CompletionMark(complete: complete),
        ],
      ),
    );
  }
}

class _CompletionMark extends StatelessWidget {
  const _CompletionMark({required this.complete});

  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: complete ? 'Logged' : 'Not logged',
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: complete ? Bold.blue : Bold.panel,
          shape: BoxShape.circle,
          border: Border.all(color: Bold.ink, width: Bold.border),
        ),
        child: complete
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}
