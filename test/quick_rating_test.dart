import 'package:flutter_test/flutter_test.dart';
import 'package:hourly_time_tracker/src/app_store.dart';
import 'package:hourly_time_tracker/src/local_repository.dart';
import 'package:hourly_time_tracker/src/models.dart';
import 'package:hourly_time_tracker/src/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppStore> _loadStore() async {
  return AppStore.load(
    LocalRepository(await SharedPreferences.getInstance()),
    NoopReminderScheduler(),
  );
}

void main() {
  final date = DateTime(2026, 10, 19);

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('rating an empty hour creates a rating-only entry', () async {
    final store = await _loadStore();

    await store.rateHour(date, 14, true);

    final entry = store.entryFor(date, 14);
    expect(entry?.productive, isTrue);
    expect(entry?.task, isEmpty);
    expect(entry?.isComplete, isFalse);
    expect(entry?.isLogged, isTrue);
    expect(store.loggedCount(date), 1);
    expect(store.trackedFor(date), (
      productive: 1,
      unproductive: 0,
      unrated: 0,
    ));
    expect(store.reportFor(date), isEmpty);
    expect(store.productivityFor(date), (productive: 1, unproductive: 0));
  });

  test('rating keeps an existing task and category', () async {
    final store = await _loadStore();
    await store.saveEntry(
      date: date,
      hourStart: 9,
      task: 'Planning',
      categoryId: 'work',
    );

    await store.rateHour(date, 9, false);

    final entry = store.entryFor(date, 9);
    expect(entry?.task, 'Planning');
    expect(entry?.categoryId, 'work');
    expect(entry?.productive, isFalse);
  });

  test('queued notification ratings are applied once and persist', () async {
    final store = await _loadStore();
    await LocalRepository.queueQuickRating(
      QuickRating(
        date: dateKey(date),
        hourStart: 10,
        productive: false,
        ratedAt: DateTime.now().toUtc(),
      ),
    );

    await store.applyPendingRatings();
    await store.applyPendingRatings();

    expect(store.entryFor(date, 10)?.productive, isFalse);
    final reloaded = await _loadStore();
    expect(reloaded.entryFor(date, 10)?.productive, isFalse);
    expect(
      await LocalRepository(
        await SharedPreferences.getInstance(),
      ).takePendingRatings(),
      isEmpty,
    );
  });

  test('a queued rating older than a later edit is ignored', () async {
    final store = await _loadStore();
    final tappedAt = DateTime.now().toUtc().subtract(
      const Duration(minutes: 5),
    );
    await store.saveEntry(
      date: date,
      hourStart: 11,
      task: 'Edited after the tap',
      categoryId: 'work',
      productive: true,
    );
    await LocalRepository.queueQuickRating(
      QuickRating(
        date: dateKey(date),
        hourStart: 11,
        productive: false,
        ratedAt: tappedAt,
      ),
    );

    await store.applyPendingRatings();

    expect(store.entryFor(date, 11)?.productive, isTrue);
  });

  test('productive survives JSON round trips', () {
    final entry = HourEntry(
      date: '2026-10-19',
      hourStart: 8,
      task: '',
      categoryId: null,
      productive: true,
      updatedAt: DateTime.utc(2026, 10, 19, 9),
    );

    expect(HourEntry.fromJson(entry.toJson()).productive, isTrue);
    expect(
      HourEntry.fromJson(<String, Object?>{
        'date': '2026-10-19',
        'hourStart': 8,
        'task': 'Legacy',
        'updatedAt': '2026-10-19T09:00:00Z',
      }).productive,
      isNull,
    );
  });
}
