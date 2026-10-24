import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hourly_time_tracker/src/app.dart';
import 'package:hourly_time_tracker/src/bold.dart';
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

/// The app opens on the dashboard; most tests start from the Day tab.
Future<void> openDay(WidgetTester tester) async {
  await tester.tap(find.text('Day'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on the dashboard and its tiles open each view', (
    tester,
  ) async {
    final store = await createTestStore();
    await store.saveEntry(
      date: DateTime.now(),
      hourStart: 0,
      task: 'Dashboard entry',
      categoryId: 'work',
      productive: true,
    );
    await tester.pumpWidget(TimeTrackerApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('TRACKED THIS WEEK'), findsOneWidget);
    expect(find.text('of 24 hours logged'), findsOneWidget);
    expect(find.text('Your day'), findsNothing);

    await tester.tap(find.text('DAILY REPORT'));
    await tester.pumpAndSettle();
    expect(find.text('Daily report'), findsOneWidget);

    await tester.tap(find.byTooltip('Dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('TRACKED THIS WEEK'), findsOneWidget);

    await tester.tap(find.text('TODAY'));
    await tester.pumpAndSettle();
    expect(find.text('Your day'), findsOneWidget);
    expect(find.text('Dashboard entry'), findsOneWidget);
  });

  testWidgets('returns to the dashboard after time away', (tester) async {
    final store = await createTestStore();
    await tester.pumpWidget(
      TimeTrackerApp(store: store, homeAfter: Duration.zero),
    );
    await openDay(tester);
    expect(find.text('Your day'), findsOneWidget);

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();

    expect(find.text('TRACKED THIS WEEK'), findsOneWidget);
    expect(find.text('Your day'), findsNothing);
  });

  testWidgets('shows all core day-view controls', (tester) async {
    final store = await createTestStore();
    await tester.pumpWidget(TimeTrackerApp(store: store));
    await openDay(tester);

    expect(find.text('Your day'), findsOneWidget);
    expect(find.text('0 / 24 logged'), findsOneWidget);
    expect(find.text('12am–1am'), findsOneWidget);
    expect(find.byIcon(Icons.donut_large_outlined), findsOneWidget);
  });

  testWidgets('logs a task and category for an hour', (tester) async {
    final store = await createTestStore();
    await tester.pumpWidget(TimeTrackerApp(store: store));
    await openDay(tester);

    await tester.tap(find.text('Tap to add what you did').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Project planning');
    await tester.ensureVisible(find.text('Work'));
    await tester.tap(find.text('Work'));
    await tester.pump();
    await tester.ensureVisible(find.text('Save hour'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save hour'));
    await tester.pumpAndSettle();

    expect(find.text('Project planning'), findsOneWidget);
    expect(find.text('1 / 24 logged'), findsOneWidget);
  });

  testWidgets('saves an hour with only a productive rating', (tester) async {
    final store = await createTestStore();
    await tester.pumpWidget(TimeTrackerApp(store: store));
    await openDay(tester);

    await tester.tap(find.text('Tap to add what you did').first);
    await tester.pumpAndSettle();
    final saveButton = find.widgetWithText(BoldButton, 'Save hour');
    await tester.dragUntilVisible(
      saveButton,
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<BoldButton>(saveButton).onPressed, isNull);

    await tester.tap(find.text('Not productive'));
    await tester.pump();
    expect(tester.widget<BoldButton>(saveButton).onPressed, isNotNull);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final entry = store.entryFor(DateTime.now(), 0);
    expect(entry?.productive, isFalse);
    expect(entry?.task, isEmpty);
    expect(entry?.categoryId, isNull);
    expect(find.text('Not productive'), findsOneWidget);
    // A rating alone counts as a logged hour.
    expect(find.text('1 / 24 logged'), findsOneWidget);
  });

  testWidgets('opens a month calendar from the day header', (tester) async {
    final store = await createTestStore();
    await tester.pumpWidget(TimeTrackerApp(store: store));
    await openDay(tester);

    await tester.tap(find.byTooltip('Open calendar'));
    await tester.pumpAndSettle();

    expect(find.text('Jump to a day'), findsOneWidget);
    expect(find.text('Open day'), findsOneWidget);
  });

  testWidgets('creates a custom category while logging an hour', (
    tester,
  ) async {
    final store = await createTestStore();
    await tester.pumpWidget(TimeTrackerApp(store: store));
    await openDay(tester);

    await tester.tap(find.text('Tap to add what you did').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('New category'));
    await tester.pumpAndSettle();
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
    await openDay(tester);

    await tester.tap(find.text('Initial task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Edited task');
    await tester.dragUntilVisible(
      find.text('Save hour'),
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
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
