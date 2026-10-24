import 'dart:async';

import 'package:flutter/material.dart';

import 'app_store.dart';
import 'bold.dart';
import 'csv_export.dart';
import 'dashboard_screen.dart';
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
    this.homeAfter = const Duration(minutes: 2),
  });

  final AppStore store;
  final CsvExporter csvExporter;

  /// Coming back after at least this long away opens the dashboard again.
  final Duration homeAfter;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chronicler',
      theme: boldTheme(),
      home: AppShell(
        store: store,
        csvExporter: csvExporter,
        homeAfter: homeAfter,
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.store,
    required this.csvExporter,
    this.homeAfter = const Duration(minutes: 2),
  });

  final AppStore store;
  final CsvExporter csvExporter;
  final Duration homeAfter;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  /// The dashboard isn't a tab: it is where the app opens and where the
  /// logo (and Back, from any tab) returns to.
  static const _dashboard = -1;

  int _view = _dashboard;
  DateTime? _awaySince;
  DateTime _selectedDate = dayOnly(DateTime.now());

  void _open(int view) {
    setState(() {
      // A tile summarises today, so it opens its view on today.
      if (_view == _dashboard && view != _dashboard) {
        _selectedDate = dayOnly(DateTime.now());
      }
      _view = view;
    });
  }

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
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _awaySince ??= DateTime.now();
    }
    if (state == AppLifecycleState.resumed) {
      _returnHomeIfAway();
      unawaited(
        widget.store.applyPendingRatings().whenComplete(
          widget.store.synchronize,
        ),
      );
    }
  }

  /// Android resumes an app where it was left, and a browser tab keeps its
  /// page, so opening Chronicler again would show the last tab. After a real
  /// absence it shows the dashboard instead, unless an hour is mid-edit.
  void _returnHomeIfAway() {
    final since = _awaySince;
    _awaySince = null;
    if (since == null || !mounted || _view == _dashboard) return;
    if (DateTime.now().difference(since) < widget.homeAfter) return;
    if (Navigator.of(context).canPop()) return;
    setState(() => _view = _dashboard);
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
      _view = 0;
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
      DashboardScreen(store: widget.store, onOpen: _open),
    ];
    final onDashboard = _view == _dashboard;
    final stack = IndexedStack(
      index: onDashboard ? pages.length - 1 : _view,
      children: pages,
    );

    return PopScope(
      canPop: onDashboard,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _open(_dashboard);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 760) {
            return Scaffold(
              body: SafeArea(
                child: Row(
                  children: [
                    NavigationRail(
                      selectedIndex: onDashboard ? null : _view,
                      onDestinationSelected: _open,
                      labelType: NavigationRailLabelType.all,
                      leading: Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 20),
                        child: _HomeButton(
                          onTap: () => _open(_dashboard),
                          child: const ChronicleMark(size: 48),
                        ),
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
                    Expanded(child: stack),
                  ],
                ),
              ),
            );
          }

          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  _PhoneTopBar(onHome: () => _open(_dashboard)),
                  Expanded(child: stack),
                ],
              ),
            ),
            bottomNavigationBar: DecoratedBox(
              // In front: the bar paints its own background over a border behind.
              position: DecorationPosition.foreground,
              decoration: const BoxDecoration(
                border: Border(top: Bold.outline),
              ),
              // NavigationBar always marks a tab; on the dashboard none is
              // current, so it drops the indicator and the filled icons.
              child: NavigationBarTheme(
                data: NavigationBarTheme.of(context).copyWith(
                  indicatorColor: onDashboard ? Colors.transparent : null,
                  indicatorShape: onDashboard
                      ? const RoundedRectangleBorder()
                      : null,
                ),
                child: NavigationBar(
                  selectedIndex: onDashboard ? 0 : _view,
                  onDestinationSelected: _open,
                  destinations: [
                    for (final item in destinations)
                      onDashboard
                          ? NavigationDestination(
                              icon: item.icon,
                              selectedIcon: item.icon,
                              label: item.label,
                            )
                          : item,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The logo as the way home: tapping it opens the dashboard.
class _HomeButton extends StatelessWidget {
  const _HomeButton({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Dashboard',
      child: Semantics(
        button: true,
        label: 'Open dashboard',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(onTap: onTap, child: child),
        ),
      ),
    );
  }
}

/// Phones have no rail, so the logo and wordmark sit in a slim bar on top.
class _PhoneTopBar extends StatelessWidget {
  const _PhoneTopBar({required this.onHome});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: const BoxDecoration(border: Border(bottom: Bold.outline)),
      child: Row(
        children: [
          _HomeButton(
            onTap: onHome,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ChronicleMark(size: 34),
                const SizedBox(width: 10),
                Text('Chronicler', style: archivo(900, size: 20)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
