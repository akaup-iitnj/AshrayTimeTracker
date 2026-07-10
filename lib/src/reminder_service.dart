import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

abstract class ReminderScheduler {
  bool get isSupported;
  ValueListenable<ReminderTarget?> get reminderTaps;

  Future<void> initialize();
  ReminderTarget? consumeReminderTap();
  Future<bool> requestPermission();
  Future<void> sync(AppSettings settings, Iterable<HourEntry> entries);
  Future<void> cancelForEntry(DateTime date, int hourStart);
}

class LocalReminderService implements ReminderScheduler {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final ValueNotifier<ReminderTarget?> _reminderTaps = ValueNotifier(null);
  bool _initialized = false;

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  ValueListenable<ReminderTarget?> get reminderTaps => _reminderTaps;

  @override
  Future<void> initialize() async {
    if (!isSupported || _initialized) return;

    tz_data.initializeTimeZones();
    try {
      final deviceTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(deviceTimezone.identifier));
    } on Object {
      // timezone defaults to UTC if the device identifier is unavailable.
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
      onDidReceiveNotificationResponse: (response) {
        _reminderTaps.value = ReminderTarget.fromPayload(response.payload);
      },
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _reminderTaps.value = ReminderTarget.fromPayload(
        launchDetails?.notificationResponse?.payload,
      );
    }
    _initialized = true;
  }

  @override
  ReminderTarget? consumeReminderTap() {
    final target = _reminderTaps.value;
    _reminderTaps.value = null;
    return target;
  }

  @override
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await initialize();
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        false;
  }

  @override
  Future<void> sync(AppSettings settings, Iterable<HourEntry> entries) async {
    if (!isSupported) return;
    await initialize();
    await _plugin.cancelAllPendingNotifications();
    if (!settings.remindersEnabled) return;

    final completeIds = entries
        .where((entry) => entry.isComplete)
        .map((entry) => entry.id)
        .toSet();
    final now = tz.TZDateTime.now(tz.local);
    final today = DateTime(now.year, now.month, now.day);

    // Keep below Android's common 500-alarm limit while covering two weeks.
    for (var dayOffset = 0; dayOffset < 14; dayOffset++) {
      final date = today.add(Duration(days: dayOffset));
      for (
        var hour = settings.reminderStartHour;
        hour < settings.reminderEndHour;
        hour++
      ) {
        if (completeIds.contains(entryId(dateKey(date), hour))) continue;
        final triggerBase = date.add(Duration(hours: hour + 1));
        final trigger = tz.TZDateTime(
          tz.local,
          triggerBase.year,
          triggerBase.month,
          triggerBase.day,
          triggerBase.hour,
        );
        if (!trigger.isAfter(now)) continue;

        final target = ReminderTarget(date: date, hourStart: hour);
        await _plugin.zonedSchedule(
          id: _notificationId(date, hour),
          scheduledDate: trigger,
          title: 'Log your last hour',
          body: 'What did you do from ${hourLabel(hour)}?',
          payload: target.payload,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'hourly_reminders',
              'Hourly reminders',
              channelDescription:
                  'Prompts you to log the hour that just ended.',
              icon: 'ic_notification',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
  }

  @override
  Future<void> cancelForEntry(DateTime date, int hourStart) async {
    if (!isSupported || !_initialized) return;
    await _plugin.cancel(id: _notificationId(date, hourStart));
  }

  int _notificationId(DateTime date, int hourStart) {
    final daysSinceEpoch =
        DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    return daysSinceEpoch * 24 + hourStart;
  }
}

class NoopReminderScheduler implements ReminderScheduler {
  final ValueNotifier<ReminderTarget?> _taps = ValueNotifier(null);

  @override
  bool get isSupported => false;

  @override
  ValueListenable<ReminderTarget?> get reminderTaps => _taps;

  @override
  Future<void> cancelForEntry(DateTime date, int hourStart) async {}

  @override
  ReminderTarget? consumeReminderTap() => null;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> sync(AppSettings settings, Iterable<HourEntry> entries) async {}
}
