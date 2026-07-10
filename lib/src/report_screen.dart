import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_store.dart';
import 'date_navigator.dart';
import 'models.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({
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
            final report = store.reportFor(date);
            final slices =
                report.entries
                    .map(
                      (item) => _ReportSlice(
                        name: item.key?.name ?? 'Uncategorized',
                        color: item.key == null
                            ? Theme.of(context).colorScheme.outline
                            : Color(item.key!.colorValue),
                        hours: item.value,
                      ),
                    )
                    .toList()
                  ..sort((a, b) => b.hours.compareTo(a.hours));
            final total = slices.fold<int>(0, (sum, item) => sum + item.hours);

            return ListView(
              key: PageStorageKey<String>('report-${dateKey(date)}'),
              padding: EdgeInsets.fromLTRB(side, 22, side, 32),
              children: [
                Text(
                  'Daily report',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                DateNavigator(date: date, onDateChanged: onDateChanged),
                const SizedBox(height: 24),
                if (total == 0)
                  const _EmptyReport()
                else ...[
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: constraints.maxWidth >= 600
                          ? Row(
                              children: [
                                _Chart(slices: slices, total: total),
                                const SizedBox(width: 44),
                                Expanded(
                                  child: _ReportSummary(
                                    slices: slices,
                                    total: total,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _Chart(slices: slices, total: total),
                                const SizedBox(height: 28),
                                _ReportSummary(slices: slices, total: total),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Category breakdown',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 18),
                          for (
                            var index = 0;
                            index < slices.length;
                            index++
                          ) ...[
                            _CategoryBar(slice: slices[index], total: total),
                            if (index != slices.length - 1)
                              const SizedBox(height: 18),
                          ],
                        ],
                      ),
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
}

class _EmptyReport extends StatelessWidget {
  const _EmptyReport();

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 52),
        child: Column(
          children: [
            Icon(
              Icons.donut_large_outlined,
              size: 46,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 14),
            Text(
              'Nothing logged yet',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Add tasks to the day and your category totals will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({required this.slices, required this.total});

  final List<_ReportSlice> slices;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$total hours logged across ${slices.length} categories',
      child: SizedBox.square(
        dimension: 190,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size.square(190),
              painter: _DonutPainter(slices),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$total',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  total == 1 ? 'hour logged' : 'hours logged',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportSummary extends StatelessWidget {
  const _ReportSummary({required this.slices, required this.total});

  final List<_ReportSlice> slices;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Where the day went',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          '${24 - total} ${24 - total == 1 ? 'hour is' : 'hours are'} still unlogged.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        for (final slice in slices.take(4))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: slice.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(child: Text(slice.name)),
                Text(
                  '${slice.hours}h',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.slice, required this.total});

  final _ReportSlice slice;
  final int total;

  @override
  Widget build(BuildContext context) {
    final percent = slice.hours / total;
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: slice.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                slice.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text('${slice.hours}h · ${(percent * 100).round()}%'),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 7,
            color: slice.color,
            backgroundColor: slice.color.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}

class _ReportSlice {
  const _ReportSlice({
    required this.name,
    required this.color,
    required this.hours,
  });

  final String name;
  final Color color;
  final int hours;
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.slices);

  final List<_ReportSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<int>(0, (sum, item) => sum + item.hours);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 13;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const gap = 0.025;
    var startAngle = -math.pi / 2;

    for (final slice in slices) {
      final sweep = (slice.hours / total) * math.pi * 2;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        rect,
        startAngle + gap / 2,
        math.max(0, sweep - gap),
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.slices != slices;
}
