import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hourly_time_tracker/src/app.dart';
import 'package:hourly_time_tracker/src/app_store.dart';
import 'package:hourly_time_tracker/src/local_repository.dart';
import 'package:hourly_time_tracker/src/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_cloud_repository.dart';
import 'support/fake_csv_exporter.dart';

Future<AppStore> createTestStore() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final preferences = await SharedPreferences.getInstance();
  return AppStore.load(LocalRepository(preferences), NoopReminderScheduler());
}

void main() {
  testWidgets('shows all core day-view controls', (tester) async {
    final store = await createTestStore();
    await tester.pumpWidget(TimeTrackerApp(store: store));

    expect(find.text('Your day'), findsOneWidget);
    expect(find.text('0 / 24 logged'), findsOneWidget);
    expect(find.text('12am–1am'), findsOneWidget);
    expect(find.byIcon(Icons.donut_large_outlined), findsOneWidget);
  });

  testWidgets('logs a task and category for an hour', (tester) async {
    final store = await createTestStore();
    await tester.pumpWidget(TimeTrackerApp(store: store));

    await tester.tap(find.text('Tap to add what you did').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Project planning');
    await tester.ensureVisible(find.text('Work'));
    await tester.tap(find.text('Work'));
    await tester.pump();
    await tester.ensureVisible(find.text('Save hour'));
    await tester.tap(find.text('Save hour'));
    await tester.pumpAndSettle();

    expect(find.text('Project planning'), findsOneWidget);
    expect(find.text('1 / 24 logged'), findsOneWidget);
  });

  testWidgets('opens a month calendar from the day header', (tester) async {
    final store = await createTestStore();
    await tester.pumpWidget(TimeTrackerApp(store: store));

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Jump to a day'), findsOneWidget);
    expect(find.text('Open day'), findsOneWidget);
  });

  testWidgets('creates a custom category while logging an hour', (
    tester,
  ) async {
    final store = await createTestStore();
    await tester.pumpWidget(TimeTrackerApp(store: store));

    await tester.tap(find.text('Tap to add what you did').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('New category'));
    await tester.tap(find.text('New category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Deep Work');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Deep Work'), findsOneWidget);
    expect(
      store.categories.any((category) => category.name == 'Deep Work'),
      isTrue,
    );
  });

  testWidgets('edits and clears an existing hour', (tester) async {
    final store = await createTestStore();
    final today = DateTime.now();
    await store.saveEntry(
      date: today,
      hourStart: 0,
      task: 'Initial task',
      categoryId: 'work',
    );
    await tester.pumpWidget(TimeTrackerApp(store: store));

    await tester.tap(find.text('Initial task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Edited task');
    await tester.tap(find.text('Save hour'));
    await tester.pumpAndSettle();

    expect(find.text('Edited task'), findsOneWidget);

    await tester.tap(find.text('Edited task'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear this hour'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(store.entryFor(today, 0), isNull);
    expect(find.text('Tap to add what you did'), findsWidgets);
  });

  testWidgets('daily report shows category totals', (tester) async {
    final store = await createTestStore();
    final today = DateTime.now();
    await store.saveEntry(
      date: today,
      hourStart: 8,
      task: 'Planning',
      categoryId: 'work',
    );
    await store.saveEntry(
      date: today,
      hourStart: 9,
      task: 'Implementation',
      categoryId: 'work',
    );
    await tester.pumpWidget(TimeTrackerApp(store: store));

    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();

    expect(find.text('Daily report'), findsOneWidget);
    expect(find.text('2h · 100%'), findsOneWidget);
  });

  testWidgets('saves a daily wellbeing check-in', (tester) async {
    final store = await createTestStore();
    await tester.pumpWidget(TimeTrackerApp(store: store));

    await tester.tap(find.text('Check-in'));
    await tester.pumpAndSettle();
    expect(find.text('Daily check-in'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Felt focused and calm.');
    await tester.ensureVisible(find.text('Save check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save check-in'));
    await tester.pumpAndSettle();

    final reflection = store.reflectionFor(DateTime.now());
    expect(reflection?.mood, 3);
    expect(reflection?.energy, 3);
    expect(reflection?.calm, 3);
    expect(reflection?.note, 'Felt focused and calm.');
  });

  testWidgets('signs in and signs out through the account screen', (
    tester,
  ) async {
    final cloud = FakeCloudRepository(signedIn: false);
    final store = await createStore(cloud);
    await tester.pumpWidget(TimeTrackerApp(store: store));

    await tester.tap(find.byIcon(Icons.tune_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Cloud sync'), 400);
    await tester.tap(find.text('Cloud sync'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'person@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('person@example.com'), findsOneWidget);
    expect(find.text('Sync now'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sync across devices'), findsOneWidget);
  });

  testWidgets('exports logged hours from Settings', (tester) async {
    final store = await createTestStore();
    final exporter = FakeCsvExporter();
    await store.saveEntry(
      date: DateTime.now(),
      hourStart: 10,
      task: 'Export me',
      categoryId: 'work',
    );
    await tester.pumpWidget(
      TimeTrackerApp(store: store, csvExporter: exporter),
    );

    await tester.tap(find.byIcon(Icons.tune_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Export CSV'), 400);
    await tester.tap(find.text('Export CSV'));
    await tester.pumpAndSettle();

    expect(exporter.exported?.entryCount, 1);
    expect(exporter.exported?.contents, contains('Export me'));
    expect(find.text('Saved 1 logged hour as CSV.'), findsOneWidget);
  });
}
