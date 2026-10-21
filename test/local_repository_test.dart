import 'package:flutter_test/flutter_test.dart';
import 'package:hourly_time_tracker/src/local_repository.dart';
import 'package:hourly_time_tracker/src/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<LocalRepository> createRepository(
  Map<String, Object> initialValues,
) async {
  SharedPreferences.setMockInitialValues(initialValues);
  return LocalRepository(await SharedPreferences.getInstance());
}

void main() {
  test(
    'entries, categories, reflections, settings, and account linkage round-trip',
    () async {
      final repository = await createRepository(<String, Object>{});
      final now = DateTime.utc(2026, 7, 11, 14);
      final deletedAt = now.add(const Duration(minutes: 5));
      final entry = HourEntry(
        date: '2026-07-11',
        hourStart: 14,
        task: 'Write, review, and ship',
        categoryId: 'deep-work',
        createdAt: now,
        updatedAt: deletedAt,
        deletedAt: deletedAt,
      );
      final category = TimeCategory(
        id: 'deep-work',
        name: 'Deep Work',
        colorValue: 0xFF123456,
        createdAt: now,
        updatedAt: now,
      );
      final settings = AppSettings(
        remindersEnabled: true,
        reminderStartHour: 7,
        reminderEndHour: 21,
        morningVideosEnabled: true,
        morningVideosHour: 6,
        timezone: 'America/New_York',
        createdAt: now,
        updatedAt: now,
      );
      final reflection = DailyReflection(
        date: '2026-07-11',
        mood: 4,
        energy: 3,
        calm: 5,
        note: 'A good day.',
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveEntries([entry]);
      await repository.saveCategories([category]);
      await repository.saveSettings(settings);
      await repository.saveReflections([reflection]);
      await repository.saveLinkedCloudUserId('user-1');

      expect(repository.loadEntries().single.toJson(), entry.toJson());
      expect(repository.loadCategories().single.toJson(), category.toJson());
      expect(repository.loadSettings().toJson(), settings.toJson());
      expect(repository.loadReflections().single.toJson(), reflection.toJson());
      expect(repository.loadLinkedCloudUserId(), 'user-1');
    },
  );

  test('malformed JSON falls back to safe defaults', () async {
    final repository = await createRepository(<String, Object>{
      'hour_entries_v1': '{not json',
      'categories_v1': '{not json',
      'settings_v1': '{not json',
      'daily_reflections_v1': '{not json',
    });

    expect(repository.loadEntries(), isEmpty);
    expect(repository.loadCategories().length, defaultCategories.length);
    expect(repository.loadSettings().remindersEnabled, isFalse);
    expect(repository.loadReflections(), isEmpty);
  });

  test('valid JSON with an unexpected shape cannot crash startup', () async {
    final repository = await createRepository(<String, Object>{
      'hour_entries_v1': '{"unexpected":true}',
      'categories_v1': '[{"id":12}]',
      'settings_v1': '[]',
    });

    expect(repository.loadEntries(), isEmpty);
    expect(repository.loadCategories().length, defaultCategories.length);
    expect(repository.loadSettings().reminderStartHour, 8);
  });

  test('entries are persisted in chronological order', () async {
    final repository = await createRepository(<String, Object>{});
    final now = DateTime.utc(2026, 7, 11);
    await repository.saveEntries([
      HourEntry(
        date: '2026-07-12',
        hourStart: 8,
        task: 'Later day',
        categoryId: 'work',
        updatedAt: now,
      ),
      HourEntry(
        date: '2026-07-11',
        hourStart: 15,
        task: 'Later hour',
        categoryId: 'work',
        updatedAt: now,
      ),
      HourEntry(
        date: '2026-07-11',
        hourStart: 9,
        task: 'Earlier hour',
        categoryId: 'work',
        updatedAt: now,
      ),
    ]);

    expect(repository.loadEntries().map((entry) => entry.id), [
      '2026-07-11|9',
      '2026-07-11|15',
      '2026-07-12|8',
    ]);
  });
}
