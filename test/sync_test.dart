import 'package:flutter_test/flutter_test.dart';
import 'package:hourly_time_tracker/src/app_store.dart';
import 'package:hourly_time_tracker/src/cloud_repository.dart';
import 'package:hourly_time_tracker/src/local_repository.dart';
import 'package:hourly_time_tracker/src/models.dart';
import 'package:hourly_time_tracker/src/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeCloudRepository implements CloudRepository {
  FakeCloudRepository({
    this.signedIn = true,
    this.remote = const CloudSnapshot(
      categories: [],
      entries: [],
      settings: null,
    ),
  });

  bool signedIn;
  CloudSnapshot remote;
  CloudSnapshot? pushed;
  Object? fetchError;

  @override
  Stream<void> get authChanges => const Stream<void>.empty();

  @override
  String? get currentUserEmail => signedIn ? 'test@example.com' : null;

  @override
  String? get currentUserId => signedIn ? 'user-1' : null;

  @override
  bool get isSignedIn => signedIn;

  @override
  Future<CloudSnapshot> fetchSnapshot() async {
    if (fetchError case final error?) throw error;
    return remote;
  }

  @override
  Future<void> pushSnapshot(CloudSnapshot snapshot) async {
    pushed = snapshot;
    remote = snapshot;
  }

  @override
  Future<void> signIn(String email, String password) async {
    signedIn = true;
  }

  @override
  Future<void> signOut() async {
    signedIn = false;
  }

  @override
  Future<CloudAuthResult> signUp(String email, String password) async {
    signedIn = true;
    return const CloudAuthResult(needsEmailConfirmation: false);
  }
}

Future<AppStore> createStore(FakeCloudRepository cloud) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final preferences = await SharedPreferences.getInstance();
  return AppStore.load(
    LocalRepository(preferences),
    NoopReminderScheduler(),
    cloud,
  );
}

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
