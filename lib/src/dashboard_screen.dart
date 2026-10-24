import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_store.dart';
import 'bold.dart';
import 'models.dart';

/// Where Chronicler opens: this week's tracked hours as a chart, then a tile
/// per view with a snippet of it. Every tile opens its full view; the logo
/// brings you back here. It isn't a tab of its own.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.store, required this.onOpen});

  final AppStore store;

  /// Opens a tab: 0 Day, 1 Report, 2 Check-in, 3 Settings.
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final now = DateTime.now();
        final today = dayOnly(now);
        return LayoutBuilder(
          builder: (context, constraints) {
            final side = math.max(16.0, (constraints.maxWidth - 960) / 2);
            final twoColumns = constraints.maxWidth - side * 2 >= 620;
            final tiles = <Widget>[
              _TodayTile(store: store, now: now, onTap: () => onOpen(0)),
              _ReportTile(store: store, today: today, onTap: () => onOpen(1)),
              _CheckInTile(store: store, today: today, onTap: () => onOpen(2)),
              _StreakTile(store: store, today: today, onTap: () => onOpen(0)),
              _RemindersTile(store: store, now: now, onTap: () => onOpen(3)),
            ];
            return ListView(
              key: const PageStorageKey<String>('dashboard'),
              padding: EdgeInsets.fromLTRB(side, 22, side, 32),
              children: [
                Text(
                  _greeting(now),
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  MaterialLocalizations.of(context).formatFullDate(today),
                  style: dmSans(600, size: 15, color: Bold.muted),
                ),
                const SizedBox(height: 20),
                _WeekCard(store: store, today: today),
                const SizedBox(height: 12),
                for (var i = 0; i < tiles.length; i += twoColumns ? 2 : 1) ...[
                  if (i > 0) const SizedBox(height: 12),
                  // Paired tiles share a row height, like Eisenhower's grid.
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: tiles[i]),
                        if (twoColumns) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: i + 1 < tiles.length
                                ? tiles[i + 1]
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  static String _greeting(DateTime now) {
    if (now.hour < 5) return 'Still up?';
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

// ------------------------------------------------------------------ the week

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.store, required this.today});

  final AppStore store;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final days = [
      for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i)),
    ];
    final week = [for (final day in days) store.trackedFor(day)];
    int total(
      Iterable<({int productive, int unproductive, int unrated})> all,
    ) => all.fold(0, (n, d) => n + d.productive + d.unproductive + d.unrated);
    final thisWeek = total(week);
    final lastWeek = total([
      for (var i = 13; i >= 7; i--)
        store.trackedFor(today.subtract(Duration(days: i))),
    ]);
    final delta = thisWeek - lastWeek;
    final productive = week.fold(0, (n, d) => n + d.productive);
    final rated = week.fold(0, (n, d) => n + d.productive + d.unproductive);

    return BoldCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TileLabel('Tracked this week', icon: Icons.bar_chart_rounded),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 14,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('$thisWeek', style: archivo(900, size: 52, height: 1)),
                  const SizedBox(width: 6),
                  Text(
                    thisWeek == 1 ? 'hour' : 'hours',
                    style: dmSans(700, size: 16),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: BoldTag(
                  label: delta == 0
                      ? 'same as last week'
                      : '${delta > 0 ? '+' : ''}$delta vs last week',
                  color: delta > 0
                      ? Bold.sky
                      : delta < 0
                      ? Bold.coral
                      : Bold.stone,
                  icon: delta > 0
                      ? Icons.trending_up_rounded
                      : delta < 0
                      ? Icons.trending_down_rounded
                      : Icons.trending_flat_rounded,
                ),
              ),
              if (rated > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: BoldTag(
                    label: '$productive of $rated rated productive',
                    color: Bold.panel,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _WeekChart(days: days, week: week, today: today),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _Legend(color: Bold.blue, label: 'Productive'),
              _Legend(color: Bold.coral, label: 'Not productive'),
              _Legend(color: Bold.stone, label: 'Not rated'),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({
    required this.days,
    required this.week,
    required this.today,
  });

  final List<DateTime> days;
  final List<({int productive, int unproductive, int unrated})> week;
  final DateTime today;

  static const _plot = 132.0;

  @override
  Widget build(BuildContext context) {
    final totals = [
      for (final d in week) d.productive + d.unproductive + d.unrated,
    ];
    // Scale to the busiest day, but never so tall that one hour fills it.
    final top = math.max(8, totals.fold(0, math.max)).toDouble();
    final localizations = MaterialLocalizations.of(context);
    return Semantics(
      label:
          'Hours tracked each day this week: '
          '${[for (var i = 0; i < days.length; i++) '${localizations.formatShortMonthDay(days[i])} ${totals[i]}'].join(', ')}',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < days.length; i++)
              Expanded(
                child: _DayBar(
                  day: days[i],
                  tracked: week[i],
                  total: totals[i],
                  scale: _plot / top,
                  isToday: isSameDay(days[i], today),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.day,
    required this.tracked,
    required this.total,
    required this.scale,
    required this.isToday,
  });

  final DateTime day;
  final ({int productive, int unproductive, int unrated}) tracked;
  final int total;
  final double scale;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final segments = [
      (tracked.unrated, Bold.stone),
      (tracked.unproductive, Bold.coral),
      (tracked.productive, Bold.blue),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            total == 0 ? '' : '$total',
            style: dmSans(800, size: 12, color: Bold.ink),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            height: total == 0 ? 6 : total * scale,
            constraints: const BoxConstraints(maxWidth: 46),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: total == 0 ? Bold.soft : Bold.panel,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Bold.ink, width: Bold.border),
              boxShadow: Bold.hardShadow(total == 0 ? 0 : Bold.shadowSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (hours, color) in segments)
                  if (hours > 0)
                    Expanded(
                      flex: hours,
                      child: ColoredBox(color: color),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 26,
            height: 22,
            alignment: Alignment.center,
            decoration: isToday
                ? BoxDecoration(
                    color: Bold.yellow,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Bold.ink, width: 1.5),
                  )
                : null,
            child: Text(
              letters[day.weekday - 1],
              style: dmSans(isToday ? 800 : 600, size: 12, color: Bold.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Bold.ink, width: 1.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: dmSans(600, size: 12, color: Bold.ink)),
      ],
    );
  }
}

// ------------------------------------------------------------------ tiles

/// The frame every view tile shares: a coloured Bold card with a caps label,
/// an arrow that says it opens, and its snippet.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.child,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BoldCard(
      color: color,
      onTap: onTap,
      semanticLabel: 'Open $label',
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _TileLabel(label, icon: icon)),
              const Icon(
                Icons.arrow_outward_rounded,
                size: 20,
                color: Bold.ink,
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TileLabel extends StatelessWidget {
  const _TileLabel(this.text, {required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Bold.ink),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: dmSans(
              800,
              size: 12,
              color: Bold.ink,
            ).copyWith(letterSpacing: 0.8),
          ),
        ),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline(this.value, this.unit);

  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(value, style: archivo(900, size: 36, height: 1)),
        const SizedBox(width: 6),
        Flexible(child: Text(unit, style: dmSans(700, size: 14))),
      ],
    );
  }
}

class _TodayTile extends StatelessWidget {
  const _TodayTile({
    required this.store,
    required this.now,
    required this.onTap,
  });

  final AppStore store;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final today = dayOnly(now);
    final logged = store.completedCount(today);
    final current = store.entryFor(today, now.hour);
    final task = current?.task.trim() ?? '';
    return _Tile(
      label: 'Today',
      icon: Icons.view_day_rounded,
      color: Bold.yellow,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Headline('$logged', 'of 24 hours logged'),
          const SizedBox(height: 12),
          BoldProgress(value: logged / 24, height: 14),
          const SizedBox(height: 12),
          Text(
            task.isEmpty
                ? 'Now, ${hourLabel(now.hour)}: not logged yet'
                : 'Now, ${hourLabel(now.hour)}: $task',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: dmSans(600, size: 14, color: Bold.ink),
          ),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.store,
    required this.today,
    required this.onTap,
  });

  final AppStore store;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final report = store.reportFor(today).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = report.fold(0, (n, e) => n + e.value);
    final productivity = store.productivityFor(today);
    final rated = productivity.productive + productivity.unproductive;
    return _Tile(
      label: 'Daily report',
      icon: Icons.donut_large_rounded,
      color: Bold.sky,
      onTap: onTap,
      child: total == 0
          ? Text(
              rated == 0
                  ? 'Nothing logged today yet. Your category totals show up '
                        'here as you go.'
                  : '${productivity.productive} of $rated rated hours '
                        'productive so far.',
              style: dmSans(600, size: 14, color: Bold.ink),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in report.take(3)) ...[
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: item.key == null
                              ? Bold.stone
                              : Color(item.key!.colorValue),
                          shape: BoxShape.circle,
                          border: Border.all(color: Bold.ink, width: 1.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.key?.name ?? 'Uncategorized',
                          overflow: TextOverflow.ellipsis,
                          style: dmSans(700, size: 14, color: Bold.ink),
                        ),
                      ),
                      Text(
                        '${item.value}h',
                        style: dmSans(800, size: 14, color: Bold.ink),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  BoldProgress(
                    value: item.value / total,
                    height: 10,
                    color: item.key == null
                        ? Bold.stone
                        : Color(item.key!.colorValue),
                  ),
                  const SizedBox(height: 10),
                ],
                if (rated > 0)
                  Text(
                    '${productivity.productive} of $rated rated hours productive',
                    style: dmSans(600, size: 13, color: Bold.ink),
                  ),
              ],
            ),
    );
  }
}

class _CheckInTile extends StatelessWidget {
  const _CheckInTile({
    required this.store,
    required this.today,
    required this.onTap,
  });

  final AppStore store;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reflection = store.reflectionFor(today);
    return _Tile(
      label: 'Check-in',
      icon: Icons.favorite_rounded,
      color: Bold.coral,
      onTap: onTap,
      child: reflection == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Not checked in today', style: archivo(800, size: 20)),
                const SizedBox(height: 6),
                Text(
                  'Take a minute: how did today feel?',
                  style: dmSans(600, size: 14, color: Bold.ink),
                ),
              ],
            )
          : Column(
              children: [
                for (final (name, score) in [
                  ('Mood', reflection.mood),
                  ('Energy', reflection.energy),
                  ('Calm', reflection.calm),
                ]) ...[
                  Row(
                    children: [
                      SizedBox(
                        width: 64,
                        child: Text(
                          name,
                          style: dmSans(700, size: 13, color: Bold.ink),
                        ),
                      ),
                      Expanded(
                        child: BoldProgress(
                          value: score / 5,
                          height: 12,
                          color: Bold.panel,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$score/5',
                        style: dmSans(800, size: 13, color: Bold.ink),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }
}

class _StreakTile extends StatelessWidget {
  const _StreakTile({
    required this.store,
    required this.today,
    required this.onTap,
  });

  final AppStore store;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final streak = store.trackingStreak(today);
    final todayTracked = store.trackedCount(today);
    return _Tile(
      label: 'Streak',
      icon: Icons.local_fire_department_rounded,
      color: Bold.panel,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Headline('$streak', streak == 1 ? 'day in a row' : 'days in a row'),
          const SizedBox(height: 8),
          Text(
            streak == 0
                ? 'Log one hour to start a streak.'
                : todayTracked == 0
                ? 'Log an hour today to keep it going.'
                : 'Every day with at least one hour logged.',
            style: dmSans(600, size: 14, color: Bold.ink),
          ),
        ],
      ),
    );
  }
}

class _RemindersTile extends StatelessWidget {
  const _RemindersTile({
    required this.store,
    required this.now,
    required this.onTap,
  });

  final AppStore store;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final settings = store.settings;
    final String headline;
    final String detail;
    if (!store.reminders.isSupported) {
      headline = 'On your phone';
      detail = 'Hourly prompts run in the Android app.';
    } else if (!settings.remindersEnabled) {
      headline = 'Off';
      detail = 'Turn on hourly prompts in Settings.';
    } else {
      final next = nextReminder(settings, now);
      headline = isSameDay(next, now)
          ? 'Next at ${formatHour(next.hour)}'
          : 'Tomorrow, ${formatHour(next.hour)}';
      detail =
          'Every hour, ${formatHour(settings.reminderStartHour + 1)}'
          '–${formatHour(settings.reminderEndHour)}.';
    }
    return _Tile(
      label: 'Reminders',
      icon: Icons.notifications_active_rounded,
      color: Bold.stone,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(headline, style: archivo(800, size: 20)),
          const SizedBox(height: 6),
          Text(detail, style: dmSans(600, size: 14, color: Bold.ink)),
        ],
      ),
    );
  }
}

/// When the next hourly prompt fires. A prompt for the hour starting at h
/// arrives at h + 1, for every h in the reminder window.
DateTime nextReminder(AppSettings settings, DateTime now) {
  final today = dayOnly(now);
  for (var h = settings.reminderStartHour; h < settings.reminderEndHour; h++) {
    final at = today.add(Duration(hours: h + 1));
    if (at.isAfter(now)) return at;
  }
  return today.add(Duration(days: 1, hours: settings.reminderStartHour + 1));
}
