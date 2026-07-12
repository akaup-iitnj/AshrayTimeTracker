import 'dart:async';

import 'package:flutter/foundation.dart';

import 'cloud_repository.dart';
import 'local_repository.dart';
import 'models.dart';
import 'reminder_service.dart';

class AppStore extends ChangeNotifier {
  AppStore._(
    this._repository,
    this._reminders,
    this._cloud,
    this._entries,
    this._categories,
    this._reflections,
    this._settings,
    this._linkedCloudUserId,
  ) {
    _authSubscription = _cloud?.authChanges.listen((_) => notifyListeners());
  }

  final LocalRepository _repository;
  final ReminderScheduler _reminders;
  final CloudRepository? _cloud;
  final Map<String, HourEntry> _entries;
  final List<TimeCategory> _categories;
  final Map<String, DailyReflection> _reflections;
  AppSettings _settings;
  String? _linkedCloudUserId;
  StreamSubscription<void>? _authSubscription;
  bool _isSyncing = false;
  bool _syncRequested = false;
  DateTime? _lastSyncAt;
  String? _syncError;

  static Future<AppStore> load(
    LocalRepository repository,
    ReminderScheduler reminders, [
    CloudRepository? cloud,
  ]) async {
    final legacyTimestamp = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final loadedEntries = repository.loadEntries();
    final loadedCategories = repository.loadCategories();
    final loadedReflections = repository.loadReflections();
    final loadedSettings = repository.loadSettings();

    final entries = [
      for (final entry in loadedEntries)
        entry.createdAt == null
            ? HourEntry(
                date: entry.date,
                hourStart: entry.hourStart,
                task: entry.task,
                categoryId: entry.categoryId,
                createdAt: entry.updatedAt,
                updatedAt: entry.updatedAt,
                deletedAt: entry.deletedAt,
              )
            : entry,
    ];
    final categories = [
      for (final category in loadedCategories)
        category.createdAt == null || category.updatedAt == null
            ? TimeCategory(
                id: category.id,
                name: category.name,
                colorValue: category.colorValue,
                createdAt: category.createdAt ?? legacyTimestamp,
                updatedAt: category.updatedAt ?? legacyTimestamp,
                deletedAt: category.deletedAt,
              )
            : category,
    ];
    final settings =
        loadedSettings.createdAt == null || loadedSettings.updatedAt == null
        ? AppSettings(
            remindersEnabled: loadedSettings.remindersEnabled,
            reminderStartHour: loadedSettings.reminderStartHour,
            reminderEndHour: loadedSettings.reminderEndHour,
            morningVideosEnabled: loadedSettings.morningVideosEnabled,
            morningVideosHour: loadedSettings.morningVideosHour,
            timezone: loadedSettings.timezone,
            createdAt: loadedSettings.createdAt ?? legacyTimestamp,
            updatedAt: loadedSettings.updatedAt ?? legacyTimestamp,
          )
        : loadedSettings;

    if (entries.any((entry) => entry.createdAt == entry.updatedAt) &&
        loadedEntries.any((entry) => entry.createdAt == null)) {
      await repository.saveEntries(entries);
    }
    if (loadedCategories.any(
      (category) => category.createdAt == null || category.updatedAt == null,
    )) {
      await repository.saveCategories(categories);
    }
    if (loadedSettings.createdAt == null || loadedSettings.updatedAt == null) {
      await repository.saveSettings(settings);
    }

    return AppStore._(
      repository,
      reminders,
      cloud,
      <String, HourEntry>{for (final entry in entries) entry.id: entry},
      categories,
      <String, DailyReflection>{
        for (final reflection in loadedReflections) reflection.date: reflection,
      },
      settings,
      repository.loadLinkedCloudUserId(),
    );
  }

  List<TimeCategory> get categories =>
      List.unmodifiable(_categories.where((category) => !category.isDeleted));
  Iterable<TimeCategory> get allCategories => _categories;
  AppSettings get settings => _settings;
  ReminderScheduler get reminders => _reminders;
  Iterable<HourEntry> get allEntries => _entries.values;
  Iterable<DailyReflection> get allReflections => _reflections.values;

  bool get cloudAvailable => _cloud != null;
  bool get isCloudSignedIn => _cloud?.isSignedIn ?? false;
  String? get cloudUserEmail => _cloud?.currentUserEmail;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncAt => _lastSyncAt;
  String? get syncError => _syncError;

  HourEntry? entryFor(DateTime date, int hourStart) {
    final entry = _entries[entryId(dateKey(date), hourStart)];
    return entry?.isDeleted == true ? null : entry;
  }

  List<HourEntry> entriesFor(DateTime date) {
    final key = dateKey(date);
    final result =
        _entries.values
            .where((entry) => entry.date == key && !entry.isDeleted)
            .toList()
          ..sort((a, b) => a.hourStart.compareTo(b.hourStart));
    return result;
  }

  TimeCategory? categoryFor(String? id) {
    if (id == null) return null;
    for (final category in _categories) {
      if (category.id == id && !category.isDeleted) return category;
    }
    return null;
  }

  Map<TimeCategory?, int> reportFor(DateTime date) {
    final report = <TimeCategory?, int>{};
    for (final entry in entriesFor(date)) {
      if (entry.task.trim().isEmpty) continue;
      final category = categoryFor(entry.categoryId);
      report[category] = (report[category] ?? 0) + 1;
    }
    return report;
  }

  int completedCount(DateTime date) =>
      entriesFor(date).where((entry) => entry.isComplete).length;

  int categoryUsageCount(String categoryId) => _entries.values
      .where((entry) => !entry.isDeleted && entry.categoryId == categoryId)
      .length;

  DailyReflection? reflectionFor(DateTime date) => _reflections[dateKey(date)];

  Future<void> saveReflection({
    required DateTime date,
    required int mood,
    required int energy,
    required int calm,
    required String note,
  }) async {
    if ([mood, energy, calm].any((score) => score < 1 || score > 5)) return;
    final key = dateKey(date);
    final existing = _reflections[key];
    final now = DateTime.now().toUtc();
    _reflections[key] = DailyReflection(
      date: key,
      mood: mood,
      energy: energy,
      calm: calm,
      note: note.trim(),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    notifyListeners();
    await _repository.saveReflections(_reflections.values);
    _queueSync();
  }

  Future<void> saveEntry({
    required DateTime date,
    required int hourStart,
    required String task,
    required String categoryId,
  }) async {
    final now = DateTime.now().toUtc();
    final existing = _entries[entryId(dateKey(date), hourStart)];
    final entry = HourEntry(
      date: dateKey(date),
      hourStart: hourStart,
      task: task.trim(),
      categoryId: categoryId,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    _entries[entry.id] = entry;
    notifyListeners();
    await _repository.saveEntries(_entries.values);
    await _reminders.cancelForEntry(date, hourStart);
    _queueSync();
  }

  Future<void> deleteEntry(DateTime date, int hourStart) async {
    final id = entryId(dateKey(date), hourStart);
    final existing = _entries[id];
    if (existing == null || existing.isDeleted) return;
    final now = DateTime.now().toUtc();
    _entries[id] = HourEntry(
      date: existing.date,
      hourStart: existing.hourStart,
      task: existing.task,
      categoryId: existing.categoryId,
      createdAt: existing.createdAt ?? existing.updatedAt,
      updatedAt: now,
      deletedAt: now,
    );
    notifyListeners();
    await _repository.saveEntries(_entries.values);
    await _reminders.sync(_settings, _entries.values);
    _queueSync();
  }

  Future<TimeCategory?> addCategory(String name, int colorValue) async {
    final normalized = name.trim();
    if (normalized.isEmpty) return null;
    final slug = normalized
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final base = slug.isEmpty ? 'category' : slug;
    var id = base;
    var suffix = 2;
    while (_categories.any((category) => category.id == id)) {
      id = '$base-$suffix';
      suffix++;
    }
    final now = DateTime.now().toUtc();
    final category = TimeCategory(
      id: id,
      name: normalized,
      colorValue: colorValue,
      createdAt: now,
      updatedAt: now,
    );
    _categories.add(category);
    notifyListeners();
    await _repository.saveCategories(_categories);
    _queueSync();
    return category;
  }

  Future<void> updateCategory(String id, String name, int colorValue) async {
    final index = _categories.indexWhere(
      (category) => category.id == id && !category.isDeleted,
    );
    if (index == -1 || name.trim().isEmpty) return;
    _categories[index] = _categories[index].copyWith(
      name: name.trim(),
      colorValue: colorValue,
      updatedAt: DateTime.now().toUtc(),
    );
    notifyListeners();
    await _repository.saveCategories(_categories);
    _queueSync();
  }

  Future<void> deleteCategory(String id) async {
    final index = _categories.indexWhere(
      (category) => category.id == id && !category.isDeleted,
    );
    if (index == -1) return;
    final now = DateTime.now().toUtc();
    _categories[index] = _categories[index].copyWith(
      updatedAt: now,
      deletedAt: now,
    );
    for (final entry in _entries.values.toList()) {
      if (!entry.isDeleted && entry.categoryId == id) {
        _entries[entry.id] = HourEntry(
          date: entry.date,
          hourStart: entry.hourStart,
          task: entry.task,
          categoryId: null,
          createdAt: entry.createdAt ?? entry.updatedAt,
          updatedAt: now,
        );
      }
    }
    notifyListeners();
    await Future.wait([
      _repository.saveCategories(_categories),
      _repository.saveEntries(_entries.values),
    ]);
    await _reminders.sync(_settings, _entries.values);
    _queueSync();
  }

  Future<bool> setRemindersEnabled(bool enabled) async {
    if (enabled) {
      final granted = await _reminders.requestPermission();
      if (!granted) return false;
    }
    _settings = _settings.copyWith(remindersEnabled: enabled);
    notifyListeners();
    await _repository.saveSettings(_settings);
    await _reminders.sync(_settings, _entries.values);
    _queueSync();
    return true;
  }

  Future<void> updateReminderWindow(int startHour, int endHour) async {
    if (startHour < 0 || endHour > 24 || startHour >= endHour) return;
    _settings = _settings.copyWith(
      reminderStartHour: startHour,
      reminderEndHour: endHour,
    );
    notifyListeners();
    await _repository.saveSettings(_settings);
    await _reminders.sync(_settings, _entries.values);
    _queueSync();
  }

  Future<bool> setMorningVideosEnabled(bool enabled) async {
    if (enabled) {
      final granted = await _reminders.requestPermission();
      if (!granted) return false;
    }
    _settings = _settings.copyWith(morningVideosEnabled: enabled);
    notifyListeners();
    await _repository.saveSettings(_settings);
    await _reminders.sync(_settings, _entries.values);
    _queueSync();
    return true;
  }

  Future<void> updateMorningVideosHour(int hour) async {
    if (hour < 0 || hour > 23) return;
    _settings = _settings.copyWith(morningVideosHour: hour);
    notifyListeners();
    await _repository.saveSettings(_settings);
    await _reminders.sync(_settings, _entries.values);
    _queueSync();
  }

  Future<CloudAuthResult> signUp(String email, String password) async {
    final cloud = _requireCloud();
    final result = await cloud.signUp(email, password);
    notifyListeners();
    if (cloud.isSignedIn) {
      await _ensureLinkedCloudUser();
      await synchronize();
    }
    return result;
  }

  Future<void> signIn(String email, String password) async {
    final cloud = _requireCloud();
    await cloud.signIn(email, password);
    try {
      await _ensureLinkedCloudUser();
    } on Object {
      await cloud.signOut();
      rethrow;
    }
    notifyListeners();
    await synchronize();
  }

  Future<void> signOut() async {
    await _requireCloud().signOut();
    _syncError = null;
    notifyListeners();
  }

  Future<void> synchronize() async {
    final cloud = _cloud;
    if (cloud == null || !cloud.isSignedIn) return;
    if (_isSyncing) {
      _syncRequested = true;
      return;
    }

    _isSyncing = true;
    _syncError = null;
    notifyListeners();
    try {
      await _ensureLinkedCloudUser();
      do {
        _syncRequested = false;
        final remote = await cloud.fetchSnapshot();
        final mergedCategories = _mergeCategories(
          _categories,
          remote.categories,
        );
        final mergedEntries = _mergeEntries(_entries.values, remote.entries);
        final mergedReflections = _mergeReflections(
          _reflections.values,
          remote.reflections,
        );
        final mergedSettings = _newerSettings(_settings, remote.settings);
        final mergedSnapshot = CloudSnapshot(
          categories: mergedCategories,
          entries: mergedEntries,
          settings: mergedSettings,
          reflections: mergedReflections,
        );
        await cloud.pushSnapshot(mergedSnapshot);

        // Preserve edits made while the network request was in progress.
        final finalCategories = _mergeCategories(mergedCategories, _categories);
        final finalEntries = _mergeEntries(mergedEntries, _entries.values);
        final finalReflections = _mergeReflections(
          mergedReflections,
          _reflections.values,
        );
        final finalSettings = _newerSettings(mergedSettings, _settings);
        _categories
          ..clear()
          ..addAll(finalCategories);
        _entries
          ..clear()
          ..addEntries(finalEntries.map((entry) => MapEntry(entry.id, entry)));
        _reflections
          ..clear()
          ..addEntries(
            finalReflections.map(
              (reflection) => MapEntry(reflection.date, reflection),
            ),
          );
        _settings = finalSettings;
        await Future.wait([
          _repository.saveCategories(_categories),
          _repository.saveEntries(_entries.values),
          _repository.saveSettings(_settings),
          _repository.saveReflections(_reflections.values),
        ]);
        await _reminders.sync(_settings, _entries.values);
        _lastSyncAt = DateTime.now();
        _syncError = null;
        notifyListeners();
      } while (_syncRequested && cloud.isSignedIn);
    } on Object catch (error) {
      _syncError = _friendlySyncError(error);
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> refreshReminders() =>
      _reminders.sync(_settings, _entries.values);

  void _queueSync() {
    if (!isCloudSignedIn) return;
    if (_isSyncing) {
      _syncRequested = true;
      return;
    }
    unawaited(synchronize());
  }

  CloudRepository _requireCloud() {
    final cloud = _cloud;
    if (cloud == null) throw StateError('Cloud sync is not configured.');
    return cloud;
  }

  Future<void> _ensureLinkedCloudUser() async {
    final cloud = _requireCloud();
    final userId = cloud.currentUserId;
    if (userId == null) throw StateError('Cloud sync requires sign-in.');
    if (_linkedCloudUserId != null && _linkedCloudUserId != userId) {
      throw StateError(
        'This installation is linked to a different account. Reinstall the app or continue with the original account.',
      );
    }
    if (_linkedCloudUserId == null) {
      _linkedCloudUserId = userId;
      await _repository.saveLinkedCloudUserId(userId);
    }
  }

  String _friendlySyncError(Object error) {
    final message = error.toString();
    if (message.contains('PGRST205') ||
        message.contains('Could not find the table')) {
      return 'Cloud tables are not set up yet. Run the supplied Supabase SQL migration.';
    }
    return message.replaceFirst(RegExp(r'^\w+Exception:\s*'), '');
  }

  @override
  void dispose() {
    final subscription = _authSubscription;
    if (subscription != null) unawaited(subscription.cancel());
    super.dispose();
  }
}

List<TimeCategory> _mergeCategories(
  Iterable<TimeCategory> first,
  Iterable<TimeCategory> second,
) {
  final merged = <String, TimeCategory>{};
  for (final category in [...first, ...second]) {
    final existing = merged[category.id];
    if (existing == null || category.updatedAt!.isAfter(existing.updatedAt!)) {
      merged[category.id] = category;
    }
  }
  return merged.values.toList();
}

List<HourEntry> _mergeEntries(
  Iterable<HourEntry> first,
  Iterable<HourEntry> second,
) {
  final merged = <String, HourEntry>{};
  for (final entry in [...first, ...second]) {
    final existing = merged[entry.id];
    if (existing == null || entry.updatedAt.isAfter(existing.updatedAt)) {
      merged[entry.id] = entry;
    }
  }
  return merged.values.toList();
}

List<DailyReflection> _mergeReflections(
  Iterable<DailyReflection> first,
  Iterable<DailyReflection> second,
) {
  final merged = <String, DailyReflection>{};
  for (final reflection in [...first, ...second]) {
    final existing = merged[reflection.date];
    if (existing == null || reflection.updatedAt.isAfter(existing.updatedAt)) {
      merged[reflection.date] = reflection;
    }
  }
  return merged.values.toList();
}

AppSettings _newerSettings(AppSettings first, AppSettings? second) {
  if (second == null) return first;
  return second.updatedAt!.isAfter(first.updatedAt!) ? second : first;
}
