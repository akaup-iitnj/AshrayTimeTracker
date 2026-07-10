import 'package:flutter_test/flutter_test.dart';
import 'package:hourly_time_tracker/src/app_store.dart';
import 'package:hourly_time_tracker/src/local_repository.dart';
import 'package:hourly_time_tracker/src/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppStore> createLocalStore() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return AppStore.load(
    LocalRepository(await SharedPreferences.getInstance()),
    NoopReminderScheduler(),
  );
}

void main() {
  test('deleting a category preserves tasks as uncategorized', () async {
    final store = await createLocalStore();
    final date = DateTime(2026, 7, 11);
    await store.saveEntry(
      date: date,
      hourStart: 9,
      task: 'Keep this description',
      categoryId: 'work',
    );

    await store.deleteCategory('work');

    final entry = store.entryFor(date, 9);
    expect(store.categoryFor('work'), isNull);
    expect(entry?.task, 'Keep this description');
    expect(entry?.categoryId, isNull);
    expect(entry?.isComplete, isFalse);
    expect(store.reportFor(date).keys.single, isNull);
  });

  test('blank and duplicate category names are handled safely', () async {
    final store = await createLocalStore();

    expect(await store.addCategory('   ', 0xFF000000), isNull);
    final first = await store.addCategory('Deep Work', 0xFF000000);
    final second = await store.addCategory('Deep Work', 0xFFFFFFFF);

    expect(first?.id, 'deep-work');
    expect(second?.id, 'deep-work-2');
  });

  test('invalid reminder windows are ignored', () async {
    final store = await createLocalStore();
    final original = store.settings;

    await store.updateReminderWindow(22, 8);
    await store.updateReminderWindow(-1, 8);
    await store.updateReminderWindow(8, 25);

    expect(store.settings.reminderStartHour, original.reminderStartHour);
    expect(store.settings.reminderEndHour, original.reminderEndHour);
  });
}
