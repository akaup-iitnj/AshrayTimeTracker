import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hourly_time_tracker/src/app.dart';
import 'package:hourly_time_tracker/src/app_store.dart';
import 'package:hourly_time_tracker/src/local_repository.dart';
import 'package:hourly_time_tracker/src/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}
