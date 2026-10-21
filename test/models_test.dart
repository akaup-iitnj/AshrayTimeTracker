import 'package:flutter_test/flutter_test.dart';
import 'package:hourly_time_tracker/src/models.dart';

void main() {
  test('formats hour ranges around noon and midnight', () {
    expect(hourLabel(0), '12am–1am');
    expect(hourLabel(11), '11am–12pm');
    expect(hourLabel(12), '12pm–1pm');
    expect(hourLabel(23), '11pm–12am');
  });

  test('reminder payload round-trips its target', () {
    final target = ReminderTarget(date: DateTime(2026, 7, 10), hourStart: 14);
    final restored = ReminderTarget.fromPayload(target.payload);

    expect(dateKey(restored!.date), '2026-07-10');
    expect(restored.hourStart, 14);
  });

  test('an entry is complete only with a task and category', () {
    final entry = HourEntry(
      date: '2026-07-10',
      hourStart: 9,
      task: 'Write proposal',
      categoryId: 'work',
      updatedAt: DateTime.utc(2026, 7, 10),
    );

    expect(entry.isComplete, isTrue);
    expect(entry.copyWith(task: ' ').isComplete, isFalse);
  });
}
