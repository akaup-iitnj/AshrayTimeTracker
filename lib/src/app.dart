import 'dart:async';

import 'package:flutter/material.dart';

import 'app_store.dart';
import 'bold.dart';
import 'csv_export.dart';
import 'edit_hour_screen.dart';
import 'models.dart';
import 'morning_videos_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';
import 'today_screen.dart';
import 'wellbeing_screen.dart';

class TimeTrackerApp extends StatelessWidget {
  const TimeTrackerApp({
    super.key,
    required this.store,
    this.csvExporter = const PlatformCsvExporter(),
  });

  final AppStore store;
  final CsvExporter csvExporter;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chronicle',
      theme: boldTheme(),
      home: AppShell(store: store, csvExporter: csvExporter),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.store, required this.csvExporter});

  final AppStore store;
  final CsvExporter csvExporter;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  DateTime _selectedDate = dayOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.store.reminders.reminderTaps.addListener(_handleReminderTap);
    widget.store.reminders.morningVideoTaps.addListener(_handleMorningVideoTap);
    widget.store.reminders.quickRatingsQueued.addListener(_applyQuickRatings);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleReminderTap();
      _handleMorningVideoTap();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.store.reminders.reminderTaps.removeListener(_handleReminderTap);
    widget.store.reminders.morningVideoTaps.removeListener(
      _handleMorningVideoTap,
    );
    widget.store.reminders.quickRatingsQueued.removeListener(
      _applyQuickRatings,
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        widget.store.applyPendingRatings().whenComplete(
          widget.store.synchronize,
        ),
      );
    }
  }

  void _applyQuickRatings() {
    unawaited(widget.store.applyPendingRatings());
  }

  void _handleReminderTap() {
    if (!mounted) return;
    final target = widget.store.reminders.consumeReminderTap();
    if (target == null) return;
    setState(() {
      _selectedDate = dayOnly(target.date);
      _selectedIndex = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EditHourScreen(
            store: widget.store,
            date: target.date,
            hourStart: target.hourStart,
          ),
        ),
      );
    });
  }

  void _handleMorningVideoTap() {
    if (!mounted || !widget.store.reminders.consumeMorningVideoTap()) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const MorningVideosScreen()),
      );
    });
  }

  void _setDate(DateTime date) {
    setState(() => _selectedDate = dayOnly(date));
  }

  @override
  Widget build(BuildContext context) {
    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.view_day_outlined),
        selectedIcon: Icon(Icons.view_day),
        label: 'Day',
      ),
      const NavigationDestination(
        icon: Icon(Icons.donut_large_outlined),
        selectedIcon: Icon(Icons.donut_large),
        label: 'Report',
      ),
      const NavigationDestination(
        icon: Icon(Icons.favorite_outline),
        selectedIcon: Icon(Icons.favorite),
        label: 'Check-in',
      ),
      const NavigationDestination(
        icon: Icon(Icons.tune_outlined),
        selectedIcon: Icon(Icons.tune),
        label: 'Settings',
      ),
    ];
    final pages = <Widget>[
      TodayScreen(
        store: widget.store,
        date: _selectedDate,
        onDateChanged: _setDate,
      ),
      ReportScreen(
        store: widget.store,
        date: _selectedDate,
        onDateChanged: _setDate,
      ),
      WellbeingScreen(
        store: widget.store,
        date: _selectedDate,
        onDateChanged: _setDate,
      ),
      SettingsScreen(store: widget.store, csvExporter: widget.csvExporter),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (index) {
                      setState(() => _selectedIndex = index);
                    },
                    labelType: NavigationRailLabelType.all,
                    leading: const Padding(
                      padding: EdgeInsets.only(top: 16, bottom: 20),
                      child: ChronicleMark(size: 48),
                    ),
                    destinations: destinations
                        .map(
                          (item) => NavigationRailDestination(
                            icon: item.icon,
                            selectedIcon: item.selectedIcon,
                            label: Text(item.label),
                          ),
                        )
                        .toList(),
                  ),
                  const VerticalDivider(
                    width: Bold.border,
                    thickness: Bold.border,
                    color: Bold.ink,
                  ),
                  Expanded(
                    child: IndexedStack(index: _selectedIndex, children: pages),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: SafeArea(
            child: IndexedStack(index: _selectedIndex, children: pages),
          ),
          bottomNavigationBar: DecoratedBox(
            // In front: the bar paints its own background over a border behind.
            position: DecorationPosition.foreground,
            decoration: const BoxDecoration(border: Border(top: Bold.outline)),
            child: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
              },
              destinations: destinations,
            ),
          ),
        );
      },
    );
  }
}
