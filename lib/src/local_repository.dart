import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class LocalRepository {
  LocalRepository(this._preferences);

  static const _entriesKey = 'hour_entries_v1';
  static const _categoriesKey = 'categories_v1';
  static const _settingsKey = 'settings_v1';
  static const _cloudUserKey = 'linked_cloud_user_v1';

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
    } on FormatException {
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
    } on FormatException {
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
    } on FormatException {
      return const AppSettings();
    }
  }

  String? loadLinkedCloudUserId() => _preferences.getString(_cloudUserKey);

  Future<void> saveLinkedCloudUserId(String userId) async {
    await _preferences.setString(_cloudUserKey, userId);
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
}
