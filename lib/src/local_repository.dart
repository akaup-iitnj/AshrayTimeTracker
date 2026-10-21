import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class LocalRepository {
  LocalRepository(this._preferences);

  static const _entriesKey = 'hour_entries_v1';
  static const _categoriesKey = 'categories_v1';
  static const _settingsKey = 'settings_v1';
  static const _reflectionsKey = 'daily_reflections_v1';
  static const _cloudUserKey = 'linked_cloud_user_v1';
  static const _pendingRatingsKey = 'pending_quick_ratings_v1';

  final SharedPreferences _preferences;

  static Future<LocalRepository> create() async {
    return LocalRepository(await SharedPreferences.getInstance());
  }

  List<HourEntry> loadEntries() {
    final raw = _preferences.getString(_entriesKey);
    if (raw == null) return <HourEntry>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(
            (item) => HourEntry.fromJson(
              Map<String, Object?>.from(item as Map<dynamic, dynamic>),
            ),
          )
          .toList();
    } on Object {
      return <HourEntry>[];
    }
  }

  List<TimeCategory> loadCategories() {
    final raw = _preferences.getString(_categoriesKey);
    if (raw == null) return List<TimeCategory>.from(defaultCategories);
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final categories = list
          .map(
            (item) => TimeCategory.fromJson(
              Map<String, Object?>.from(item as Map<dynamic, dynamic>),
            ),
          )
          .toList();
      return categories.isEmpty
          ? List<TimeCategory>.from(defaultCategories)
          : categories;
    } on Object {
      return List<TimeCategory>.from(defaultCategories);
    }
  }

  AppSettings loadSettings() {
    final raw = _preferences.getString(_settingsKey);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(
        Map<String, Object?>.from(jsonDecode(raw) as Map<dynamic, dynamic>),
      );
    } on Object {
      return const AppSettings();
    }
  }

  List<DailyReflection> loadReflections() {
    final raw = _preferences.getString(_reflectionsKey);
    if (raw == null) return <DailyReflection>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(
            (item) => DailyReflection.fromJson(
              Map<String, Object?>.from(item as Map<dynamic, dynamic>),
            ),
          )
          .toList();
    } on Object {
      return <DailyReflection>[];
    }
  }

  String? loadLinkedCloudUserId() => _preferences.getString(_cloudUserKey);

  Future<void> saveLinkedCloudUserId(String userId) async {
    await _preferences.setString(_cloudUserKey, userId);
  }

  /// Queues a rating from a notification action. This runs in a background
  /// isolate, so it writes its own key instead of touching the entry list the
  /// main isolate keeps cached in memory.
  static Future<void> queueQuickRating(QuickRating rating) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final pending = _decodeRatings(preferences.getString(_pendingRatingsKey))
      ..add(rating);
    await preferences.setString(
      _pendingRatingsKey,
      jsonEncode(pending.map((item) => item.toJson()).toList()),
    );
  }

  /// Returns and clears ratings queued by notification actions.
  Future<List<QuickRating>> takePendingRatings() async {
    await _preferences.reload();
    final pending = _decodeRatings(_preferences.getString(_pendingRatingsKey));
    if (pending.isNotEmpty) await _preferences.remove(_pendingRatingsKey);
    return pending;
  }

  static List<QuickRating> _decodeRatings(String? raw) {
    if (raw == null) return <QuickRating>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(
            (item) => QuickRating.fromJson(
              Map<String, Object?>.from(item as Map<dynamic, dynamic>),
            ),
          )
          .toList();
    } on Object {
      return <QuickRating>[];
    }
  }

  Future<void> saveEntries(Iterable<HourEntry> entries) async {
    final ordered = entries.toList()
      ..sort((a, b) {
        final dateComparison = a.date.compareTo(b.date);
        return dateComparison != 0
            ? dateComparison
            : a.hourStart.compareTo(b.hourStart);
      });
    await _preferences.setString(
      _entriesKey,
      jsonEncode(ordered.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<void> saveCategories(Iterable<TimeCategory> categories) async {
    await _preferences.setString(
      _categoriesKey,
      jsonEncode(categories.map((category) => category.toJson()).toList()),
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _preferences.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  Future<void> saveReflections(Iterable<DailyReflection> reflections) async {
    final ordered = reflections.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    await _preferences.setString(
      _reflectionsKey,
      jsonEncode(ordered.map((reflection) => reflection.toJson()).toList()),
    );
  }
}
