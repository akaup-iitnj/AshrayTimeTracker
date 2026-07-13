import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hourly_time_tracker/src/app_store.dart';
import 'package:hourly_time_tracker/src/csv_export.dart';
import 'package:hourly_time_tracker/src/local_repository.dart';
import 'package:hourly_time_tracker/src/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppStore> createStore() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return AppStore.load(
    LocalRepository(await SharedPreferences.getInstance()),
    NoopReminderScheduler(),
  );
}

void main() {
  test('CSV export is chronological, escaped, and spreadsheet ready', () async {
    final store = await createStore();
    await store.saveEntry(
      date: DateTime(2026, 7, 12),
      hourStart: 9,
      task: 'Later entry',
      categoryId: 'learning',
    );
    await store.saveEntry(
      date: DateTime(2026, 7, 11),
      hourStart: 8,
      task: 'Plan "alpha", then\nreview',
      categoryId: 'work',
    );

    final data = buildCsvExport(store, generatedAt: DateTime(2026, 7, 13));

    expect(data.fileName, 'time-tracker-export-2026-07-13.csv');
    expect(data.entryCount, 2);
    expect(
      data.contents.indexOf('2026-07-11'),
      lessThan(data.contents.indexOf('2026-07-12')),
    );
    expect(data.contents, contains('"Plan ""alpha"", then\nreview"'));
    expect(data.contents, contains('"Work"'));
    expect(data.contents, endsWith('\r\n'));
    expect(data.bytes.take(3), [0xEF, 0xBB, 0xBF]);
    expect(utf8.decode(data.bytes.skip(3).toList()), data.contents);
  });

  test(
    'deleted entries are omitted and uncategorized tasks are retained',
    () async {
      final store = await createStore();
      final date = DateTime(2026, 7, 11);
      await store.saveEntry(
        date: date,
        hourStart: 8,
        task: 'Keep after category deletion',
        categoryId: 'work',
      );
      await store.saveEntry(
        date: date,
        hourStart: 9,
        task: 'Remove this hour',
        categoryId: 'learning',
      );
      await store.deleteCategory('work');
      await store.deleteEntry(date, 9);

      final data = buildCsvExport(store, generatedAt: date);

      expect(data.entryCount, 1);
      expect(data.contents, contains('Keep after category deletion'));
      expect(data.contents, contains('Uncategorized'));
      expect(data.contents, isNot(contains('Remove this hour')));
    },
  );

  test('CSV export neutralizes spreadsheet formulas in user text', () async {
    final dangerousValues = <String>[
      '=HYPERLINK("https://example.test")',
      '+cmd|calc',
      '-1+2',
      '@SUM(1,2)',
      '  =1+1',
    ];

    for (var index = 0; index < dangerousValues.length; index++) {
      final store = await createStore();
      await store.saveEntry(
        date: DateTime(2026, 7, 11),
        hourStart: index,
        task: dangerousValues[index],
        categoryId: 'work',
      );

      final data = buildCsvExport(store, generatedAt: DateTime(2026, 7, 11));
      final escaped = dangerousValues[index].trim().replaceAll('"', '""');
      expect(data.contents, contains('"\'$escaped"'));
    }
  });
}
