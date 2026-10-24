import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_store.dart';
import 'bold.dart';
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
            final productivity = store.productivityFor(date);
            final slices =
                report.entries
                    .map(
                      (item) => _ReportSlice(
                        name: item.key?.name ?? 'Uncategorized',
                        color: item.key == null
                            ? Bold.stone
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
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 14),
                DateNavigator(date: date, onDateChanged: onDateChanged),
                const SizedBox(height: 24),
                if (productivity.productive + productivity.unproductive >
                    0) ...[
                  _ProductivityCard(
                    productive: productivity.productive,
                    unproductive: productivity.unproductive,
                  ),
                  const SizedBox(height: 16),
                ],
                if (total == 0)
                  const _EmptyReport()
                else ...[
                  BoldCard(
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
                  BoldCard(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Category breakdown',
                            style: Theme.of(context).textTheme.titleLarge,
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

class _ProductivityCard extends StatelessWidget {
  const _ProductivityCard({
    required this.productive,
    required this.unproductive,
  });

  final int productive;
  final int unproductive;

  @override
  Widget build(BuildContext context) {
    final rated = productive + unproductive;
    return BoldCard(
      color: Bold.sky,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Productivity', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '$productive of $rated rated '
              '${rated == 1 ? 'hour' : 'hours'} productive',
              style: dmSans(600, size: 14, color: Bold.ink),
            ),
            const SizedBox(height: 14),
            Container(
              height: 18,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Bold.panel,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: Bold.ink, width: Bold.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (productive > 0)
                    Expanded(
                      flex: productive,
                      child: const ColoredBox(color: Bold.blue),
                    ),
                  if (productive > 0 && unproductive > 0)
                    const SizedBox(
                      width: Bold.border,
                      child: ColoredBox(color: Bold.ink),
                    ),
                  if (unproductive > 0)
                    Expanded(
                      flex: unproductive,
                      child: const ColoredBox(color: Bold.coral),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyReport extends StatelessWidget {
  const _EmptyReport();

  @override
  Widget build(BuildContext context) {
    return BoldCard(
      color: Bold.yellow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
        child: Column(
          children: [
            const Icon(Icons.donut_large_rounded, size: 46, color: Bold.ink),
            const SizedBox(height: 14),
            Text(
              'Nothing logged yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Add tasks to the day and your category totals will appear here.',
              textAlign: TextAlign.center,
              style: dmSans(500, size: 14, color: Bold.ink),
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
                Text('$total', style: Theme.of(context).textTheme.displaySmall),
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
          style: Theme.of(context).textTheme.titleLarge,
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
                    border: Border.all(color: Bold.ink, width: 1.5),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(child: Text(slice.name)),
                Text(
                  '${slice.hours}h',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontVariations: [FontVariation('wght', 700)],
                  ),
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
                border: Border.all(color: Bold.ink, width: 1.5),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                slice.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontVariations: [FontVariation('wght', 600)],
                ),
              ),
            ),
            Text('${slice.hours}h · ${(percent * 100).round()}%'),
          ],
        ),
        const SizedBox(height: 8),
        BoldProgress(value: percent, color: slice.color, height: 14),
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
    final outer = math.min(size.width, size.height) / 2 - 2;
    final inner = outer - 30;
    final outline = Paint()
      ..color = Bold.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = Bold.border
      ..strokeJoin = StrokeJoin.round;
    var startAngle = -math.pi / 2;

    for (final slice in slices) {
      final sweep = (slice.hours / total) * math.pi * 2;
      final Path path;
      if (sweep >= math.pi * 2) {
        path = Path()
          ..fillType = PathFillType.evenOdd
          ..addOval(Rect.fromCircle(center: center, radius: outer))
          ..addOval(Rect.fromCircle(center: center, radius: inner));
      } else {
        path = Path()
          ..arcTo(
            Rect.fromCircle(center: center, radius: outer),
            startAngle,
            sweep,
            true,
          )
          ..arcTo(
            Rect.fromCircle(center: center, radius: inner),
            startAngle + sweep,
            -sweep,
            false,
          )
          ..close();
      }
      canvas
        ..drawPath(path, Paint()..color = slice.color)
        ..drawPath(path, outline);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.slices != slices;
}
