import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/app_store.dart';
import 'src/cloud_config.dart';
import 'src/cloud_repository.dart';
import 'src/local_repository.dart';
import 'src/reminder_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final repository = await LocalRepository.create();
  await Supabase.initialize(
    url: CloudConfig.url,
    publishableKey: CloudConfig.publishableKey,
  );
  final cloud = SupabaseCloudRepository(Supabase.instance.client);
  final reminders = LocalReminderService();
  try {
    await reminders.initialize();
  } on Object catch (error, stackTrace) {
    debugPrint('Reminder initialization failed: $error\n$stackTrace');
  }
  final store = await AppStore.load(repository, reminders, cloud);

  runApp(TimeTrackerApp(store: store));
  unawaited(_startBackgroundWork(store));
}

Future<void> _startBackgroundWork(AppStore store) async {
  await store.synchronize();
  try {
    await store.refreshReminders();
  } on Object catch (error, stackTrace) {
    debugPrint('Reminder scheduling failed: $error\n$stackTrace');
  }
}
