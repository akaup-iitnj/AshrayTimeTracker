import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hourly_time_tracker/src/models.dart';
import 'package:hourly_time_tracker/src/cloud_repository.dart';

import 'support/fake_cloud_repository.dart';

void main() {
  test('a newer cloud entry is merged into the local store', () async {
    final now = DateTime.now().toUtc();
    final cloud = FakeCloudRepository(
      remote: CloudSnapshot(
        categories: const [],
        entries: [
          HourEntry(
            date: '2026-07-10',
            hourStart: 9,
            task: 'Edited on another device',
            categoryId: 'work',
            createdAt: now,
            updatedAt: now.add(const Duration(minutes: 1)),
          ),
        ],
        settings: null,
      ),
    );
    final store = await createStore(cloud);

    await store.synchronize();

    expect(
      store.entryFor(DateTime(2026, 7, 10), 9)?.task,
      'Edited on another device',
    );
    expect(cloud.pushed?.categories.length, defaultCategories.length);
    expect(store.lastSyncAt, isNotNull);
    expect(store.syncError, isNull);
  });

  test(
    'fresh default categories do not overwrite cloud customizations',
    () async {
      final now = DateTime.now().toUtc();
      final cloud = FakeCloudRepository(
        remote: CloudSnapshot(
          categories: [
            TimeCategory(
              id: 'work',
              name: 'Focused Work',
              colorValue: 0xFF123456,
              createdAt: now.subtract(const Duration(days: 2)),
              updatedAt: now.subtract(const Duration(days: 1)),
            ),
          ],
          entries: const [],
          settings: null,
        ),
      );
      final store = await createStore(cloud);

      await store.synchronize();

      expect(store.categoryFor('work')?.name, 'Focused Work');
      expect(store.categoryFor('work')?.colorValue, 0xFF123456);
    },
  );

  test('a newer local deletion is not revived by an older cloud row', () async {
    final cloud = FakeCloudRepository(signedIn: false);
    final store = await createStore(cloud);
    final date = DateTime(2026, 7, 10);
    await store.saveEntry(
      date: date,
      hourStart: 14,
      task: 'Temporary entry',
      categoryId: 'work',
    );
    await store.deleteEntry(date, 14);
    final tombstone = store.allEntries.single;

    cloud
      ..remote = CloudSnapshot(
        categories: const [],
        entries: [
          HourEntry(
            date: tombstone.date,
            hourStart: tombstone.hourStart,
            task: tombstone.task,
            categoryId: tombstone.categoryId,
            createdAt: tombstone.createdAt,
            updatedAt: tombstone.updatedAt.subtract(const Duration(days: 1)),
          ),
        ],
        settings: null,
      )
      ..signedIn = true;

    await store.synchronize();

    expect(store.entryFor(date, 14), isNull);
    expect(cloud.pushed?.entries.single.deletedAt, isNotNull);
  });

  test('a newer local entry wins and is uploaded', () async {
    final cloud = FakeCloudRepository(signedIn: false);
    final store = await createStore(cloud);
    final date = DateTime(2026, 7, 11);
    await store.saveEntry(
      date: date,
      hourStart: 10,
      task: 'Edited locally',
      categoryId: 'work',
    );
    final local = store.entryFor(date, 10)!;
    cloud
      ..remote = CloudSnapshot(
        categories: const [],
        entries: [
          HourEntry(
            date: local.date,
            hourStart: local.hourStart,
            task: 'Older cloud edit',
            categoryId: 'learning',
            createdAt: local.createdAt,
            updatedAt: local.updatedAt.subtract(const Duration(minutes: 5)),
          ),
        ],
        settings: null,
      )
      ..signedIn = true;

    await store.synchronize();

    expect(store.entryFor(date, 10)?.task, 'Edited locally');
    expect(cloud.pushed?.entries.single.task, 'Edited locally');
  });

  test('a newer cloud tombstone removes an older local entry', () async {
    final cloud = FakeCloudRepository(signedIn: false);
    final store = await createStore(cloud);
    final date = DateTime(2026, 7, 11);
    await store.saveEntry(
      date: date,
      hourStart: 11,
      task: 'Delete this elsewhere',
      categoryId: 'work',
    );
    final local = store.entryFor(date, 11)!;
    final deletedAt = local.updatedAt.add(const Duration(minutes: 5));
    cloud
      ..remote = CloudSnapshot(
        categories: const [],
        entries: [
          HourEntry(
            date: local.date,
            hourStart: local.hourStart,
            task: local.task,
            categoryId: local.categoryId,
            createdAt: local.createdAt,
            updatedAt: deletedAt,
            deletedAt: deletedAt,
          ),
        ],
        settings: null,
      )
      ..signedIn = true;

    await store.synchronize();

    expect(store.entryFor(date, 11), isNull);
    expect(cloud.pushed?.entries.single.deletedAt, deletedAt);
  });

  test('newer cloud settings replace older local settings', () async {
    final cloud = FakeCloudRepository(signedIn: false);
    final store = await createStore(cloud);
    await store.updateReminderWindow(9, 20);
    final local = store.settings;
    cloud
      ..remote = CloudSnapshot(
        categories: const [],
        entries: const [],
        settings: AppSettings(
          remindersEnabled: true,
          reminderStartHour: 7,
          reminderEndHour: 22,
          createdAt: local.createdAt,
          updatedAt: local.updatedAt!.add(const Duration(minutes: 5)),
        ),
      )
      ..signedIn = true;

    await store.synchronize();

    expect(store.settings.remindersEnabled, isTrue);
    expect(store.settings.reminderStartHour, 7);
    expect(store.settings.reminderEndHour, 22);
  });

  test('a newer cloud reflection is merged and retained', () async {
    final now = DateTime.now().toUtc();
    final cloud = FakeCloudRepository(
      remote: CloudSnapshot(
        categories: const [],
        entries: const [],
        settings: null,
        reflections: [
          DailyReflection(
            date: '2026-07-11',
            mood: 2,
            energy: 1,
            calm: 2,
            note: 'A difficult day.',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
    );
    final store = await createStore(cloud);

    await store.synchronize();

    expect(store.reflectionFor(DateTime(2026, 7, 11))?.mood, 2);
    expect(cloud.pushed?.reflections.single.note, 'A difficult day.');
  });

  test('a failed sync preserves local data and a retry recovers', () async {
    final cloud = FakeCloudRepository(signedIn: false);
    final store = await createStore(cloud);
    final date = DateTime(2026, 7, 11);
    await store.saveEntry(
      date: date,
      hourStart: 12,
      task: 'Available offline',
      categoryId: 'work',
    );
    cloud
      ..signedIn = true
      ..fetchError = Exception('Network unavailable');

    await store.synchronize();

    expect(store.entryFor(date, 12)?.task, 'Available offline');
    expect(store.syncError, contains('Network unavailable'));

    cloud.fetchError = null;
    await store.synchronize();

    expect(store.syncError, isNull);
    expect(cloud.pushed?.entries.single.task, 'Available offline');
  });

  test(
    'an edit made during a push is included in the follow-up sync',
    () async {
      final pushStarted = Completer<void>();
      final pushGate = Completer<void>();
      final cloud = FakeCloudRepository(
        pushStarted: pushStarted,
        pushGate: pushGate,
      );
      final store = await createStore(cloud);
      final date = DateTime(2026, 7, 11);

      final syncing = store.synchronize();
      await pushStarted.future;
      await store.saveEntry(
        date: date,
        hourStart: 13,
        task: 'Saved during sync',
        categoryId: 'work',
      );
      pushGate.complete();
      await syncing;

      expect(cloud.pushCount, greaterThanOrEqualTo(2));
      expect(
        cloud.remote.entries.any((entry) => entry.task == 'Saved during sync'),
        isTrue,
      );
    },
  );

  test(
    'sign-in rejects a different account on a linked installation',
    () async {
      final cloud = FakeCloudRepository(signedIn: false, userId: 'user-2');
      final store = await createStore(
        cloud,
        initialPreferences: const <String, Object>{
          'linked_cloud_user_v1': 'user-1',
        },
      );

      await expectLater(
        store.signIn('other@example.com', 'password'),
        throwsA(isA<StateError>()),
      );

      expect(cloud.signedIn, isFalse);
      expect(store.isCloudSignedIn, isFalse);
    },
  );

  test('Google sign-in links the account and runs the first sync', () async {
    final cloud = FakeCloudRepository(signedIn: false);
    final store = await createStore(cloud);

    await store.signInWithGoogle();

    expect(cloud.googleSignIns, 1);
    expect(store.isCloudSignedIn, isTrue);
    expect(cloud.fetchCount, 1);
    expect(store.syncError, isNull);
  });

  test(
    'Google sign-in to a different account is refused on a linked device',
    () async {
      final cloud = FakeCloudRepository(signedIn: false, userId: 'user-2');
      final store = await createStore(
        cloud,
        initialPreferences: const <String, Object>{
          'linked_cloud_user_v1': 'user-1',
        },
      );

      await store.signInWithGoogle();

      expect(cloud.signedIn, isFalse);
      expect(store.isCloudSignedIn, isFalse);
      expect(store.syncError, contains('different account'));
      expect(cloud.fetchCount, 0);
    },
  );

  test('a missing Supabase schema becomes an actionable sync error', () async {
    final cloud = FakeCloudRepository()
      ..fetchError = Exception(
        'PGRST205 Could not find the table public.time_categories',
      );
    final store = await createStore(cloud);

    await store.synchronize();

    expect(store.syncError, contains('Cloud tables are not set up yet'));
    expect(store.isSyncing, isFalse);
  });
}
