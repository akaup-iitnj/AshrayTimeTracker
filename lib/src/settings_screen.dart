import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'account_screen.dart';
import 'app_store.dart';
import 'bold.dart';
import 'category_editor_dialog.dart';
import 'csv_export.dart';
import 'models.dart';
import 'morning_videos_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.store,
    required this.csvExporter,
  });

  final AppStore store;
  final CsvExporter csvExporter;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final side = math.max(16.0, (constraints.maxWidth - 760) / 2);
            return ListView(
              padding: EdgeInsets.fromLTRB(side, 22, side, 36),
              children: [
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 22),
                const _SectionTitle(title: 'Reminders'),
                const SizedBox(height: 10),
                _ReminderCard(store: store),
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Expanded(child: _SectionTitle(title: 'Categories')),
                    TextButton.icon(
                      onPressed: () => _showCategoryDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                BoldCard(
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < store.categories.length;
                        index++
                      ) ...[
                        _CategoryTile(
                          store: store,
                          category: store.categories[index],
                          onEdit: () => _showCategoryDialog(
                            context,
                            category: store.categories[index],
                          ),
                          onDelete: () =>
                              _confirmDelete(context, store.categories[index]),
                        ),
                        if (index != store.categories.length - 1)
                          const Divider(height: 1, indent: 54),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const _SectionTitle(title: 'Data'),
                const SizedBox(height: 10),
                _CloudCard(store: store),
                const SizedBox(height: 10),
                _ExportCard(store: store, csvExporter: csvExporter),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showCategoryDialog(
    BuildContext context, {
    TimeCategory? category,
  }) async {
    final result = await showCategoryEditorDialog(context, category: category);
    if (result == null) return;
    if (category == null) {
      await store.addCategory(result.name, result.colorValue);
    } else {
      await store.updateCategory(category.id, result.name, result.colorValue);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TimeCategory category,
  ) async {
    final usage = store.categoryUsageCount(category.id);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${category.name}?'),
        content: Text(
          usage == 0
              ? 'This category will be removed.'
              : '$usage ${usage == 1 ? 'entry uses' : 'entries use'} this category. Those entries will become uncategorized.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await store.deleteCategory(category.id);
  }
}

class _ExportCard extends StatefulWidget {
  const _ExportCard({required this.store, required this.csvExporter});

  final AppStore store;
  final CsvExporter csvExporter;

  @override
  State<_ExportCard> createState() => _ExportCardState();
}

class _ExportCardState extends State<_ExportCard> {
  bool _exporting = false;

  Future<void> _export() async {
    final data = buildCsvExport(widget.store);
    if (data.entryCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('There are no logged hours to export yet.'),
        ),
      );
      return;
    }
    setState(() => _exporting = true);
    try {
      final outcome = await widget.csvExporter.export(data);
      if (!mounted || outcome == CsvExportOutcome.cancelled) return;
      final action = outcome == CsvExportOutcome.saved ? 'Saved' : 'Shared';
      final noun = data.entryCount == 1 ? 'hour' : 'hours';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$action ${data.entryCount} logged $noun as CSV.'),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV export failed: $error')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BoldCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        enabled: !_exporting,
        onTap: _exporting ? null : _export,
        leading: const Icon(Icons.file_download_outlined),
        title: const Text('Export CSV'),
        subtitle: const Text(
          'Save every logged hour as a spreadsheet-ready backup.',
        ),
        trailing: _exporting
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _CloudCard extends StatelessWidget {
  const _CloudCard({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final signedIn = store.isCloudSignedIn;
    final error = store.syncError;
    final String subtitle;
    if (!store.cloudAvailable) {
      subtitle = 'Cloud sync is unavailable in this build.';
    } else if (store.isSyncing) {
      subtitle = 'Synchronizing local and cloud data…';
    } else if (error != null) {
      subtitle = error;
    } else if (signedIn) {
      subtitle = store.lastSyncAt == null
          ? 'Signed in · waiting for the first sync'
          : 'Up to date · tap for account details';
    } else {
      subtitle = 'Sign in to sync this device with your other devices.';
    }
    return BoldCard(
      color: Bold.sky,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        enabled: store.cloudAvailable,
        onTap: store.cloudAvailable
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AccountScreen(store: store),
                  ),
                );
              }
            : null,
        leading: Icon(
          error != null
              ? Icons.cloud_off_outlined
              : signedIn
              ? Icons.cloud_done_outlined
              : Icons.cloud_outlined,
          color: error != null ? Theme.of(context).colorScheme.error : null,
        ),
        title: Text(store.cloudUserEmail ?? 'Cloud sync'),
        subtitle: Text(
          subtitle,
          style: error != null
              ? TextStyle(color: Theme.of(context).colorScheme.error)
              : null,
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final settings = store.settings;
    final supported = store.reminders.isSupported;
    return BoldCard(
      color: Bold.yellow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.notifications_none),
              title: const Text('Hourly prompts'),
              subtitle: Text(
                supported
                    ? 'Ask what you did after each hour.'
                    : 'Reminder scheduling is available in the Android app.',
              ),
              value: supported && settings.remindersEnabled,
              onChanged: supported
                  ? (enabled) async {
                      final success = await store.setRemindersEnabled(enabled);
                      if (!success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Notifications are disabled. Allow them in Android settings to enable prompts.',
                            ),
                          ),
                        );
                      }
                    }
                  : null,
            ),
            if (supported) ...[
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.wb_sunny_outlined),
                title: const Text('Morning videos'),
                subtitle: const Text(
                  'Show your two saved videos every morning.',
                ),
                value: settings.morningVideosEnabled,
                onChanged: (enabled) async {
                  final success = await store.setMorningVideosEnabled(enabled);
                  if (!success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Allow notifications in Android settings to enable the morning reminder.',
                        ),
                      ),
                    );
                  }
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('morning-${settings.morningVideosHour}'),
                      initialValue: settings.morningVideosHour,
                      decoration: const InputDecoration(
                        labelText: 'Every morning at',
                      ),
                      items: [
                        for (var hour = 4; hour <= 12; hour++)
                          DropdownMenuItem(
                            value: hour,
                            child: Text(formatHour(hour)),
                          ),
                      ],
                      onChanged: settings.morningVideosEnabled
                          ? (hour) {
                              if (hour != null) {
                                store.updateMorningVideosHour(hour);
                              }
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MorningVideosScreen(),
                        ),
                      );
                    },
                    child: const Text('View videos'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            if (supported) ...[
              const Divider(),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Reminder window',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontVariations: const [FontVariation('wght', 700)],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'A prompt arrives after every hour in this window.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('start-${settings.reminderStartHour}'),
                      initialValue: settings.reminderStartHour,
                      decoration: const InputDecoration(labelText: 'Starts'),
                      items: [
                        for (
                          var hour = 0;
                          hour < settings.reminderEndHour;
                          hour++
                        )
                          DropdownMenuItem(
                            value: hour,
                            child: Text(formatHour(hour)),
                          ),
                      ],
                      onChanged: settings.remindersEnabled
                          ? (hour) {
                              if (hour != null) {
                                store.updateReminderWindow(
                                  hour,
                                  settings.reminderEndHour,
                                );
                              }
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('end-${settings.reminderEndHour}'),
                      initialValue: settings.reminderEndHour,
                      decoration: const InputDecoration(labelText: 'Ends'),
                      items: [
                        for (
                          var hour = settings.reminderStartHour + 1;
                          hour <= 24;
                          hour++
                        )
                          DropdownMenuItem(
                            value: hour,
                            child: Text(
                              hour == 24 ? '12am next day' : formatHour(hour),
                            ),
                          ),
                      ],
                      onChanged: settings.remindersEnabled
                          ? (hour) {
                              if (hour != null) {
                                store.updateReminderWindow(
                                  settings.reminderStartHour,
                                  hour,
                                );
                              }
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.store,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  final AppStore store;
  final TimeCategory category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final usage = store.categoryUsageCount(category.id);
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 18, right: 8),
      leading: CircleAvatar(
        radius: 10,
        backgroundColor: Color(category.colorValue),
      ),
      title: Text(category.name),
      subtitle: Text('$usage ${usage == 1 ? 'hour' : 'hours'} logged'),
      trailing: PopupMenuButton<String>(
        tooltip: 'Category actions',
        onSelected: (action) => action == 'edit' ? onEdit() : onDelete(),
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: dmSans(
        800,
        size: 13,
        color: Bold.ink,
      ).copyWith(letterSpacing: 0.8),
    );
  }
}
