import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hourly_time_tracker/src/app.dart';
import 'package:hourly_time_tracker/src/bold.dart';
import 'package:hourly_time_tracker/src/app_store.dart';
import 'package:hourly_time_tracker/src/local_repository.dart';
import 'package:hourly_time_tracker/src/reminder_service.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('log, report, restart, and clear an hour', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final firstStore = await AppStore.load(
      LocalRepository(preferences),
      NoopReminderScheduler(),
    );
    await tester.pumpWidget(TimeTrackerApp(store: firstStore));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tap to add what you did').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'End-to-end smoke entry');
    final workChip = find.widgetWithText(ChoiceChip, 'Work');
    await tester.ensureVisible(workChip);
    await tester.tap(workChip);
    await tester.pump();
    final saveButton = find.widgetWithText(BoldButton, 'Save hour');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(find.text('End-to-end smoke entry'), findsOneWidget);

    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    expect(find.text('Daily report'), findsOneWidget);
    expect(find.text('1h · 100%'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    firstStore.dispose();
    final restartedStore = await AppStore.load(
      LocalRepository(preferences),
      NoopReminderScheduler(),
    );
    await tester.pumpWidget(TimeTrackerApp(store: restartedStore));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(find.text('End-to-end smoke entry'), findsOneWidget);

    await tester.tap(find.text('End-to-end smoke entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear this hour'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('0 / 24 logged'), findsOneWidget);
  });
}
