import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_config.dart';

import 'models.dart';

class CloudSnapshot {
  const CloudSnapshot({
    required this.categories,
    required this.entries,
    required this.settings,
    this.reflections = const [],
  });

  final List<TimeCategory> categories;
  final List<HourEntry> entries;
  final AppSettings? settings;
  final List<DailyReflection> reflections;
}

class CloudAuthResult {
  const CloudAuthResult({required this.needsEmailConfirmation});

  final bool needsEmailConfirmation;
}

abstract class CloudRepository {
  String? get currentUserId;
  String? get currentUserEmail;
  bool get isSignedIn;
  Stream<void> get authChanges;

  Future<CloudAuthResult> signUp(String email, String password);
  Future<void> signIn(String email, String password);

  /// Starts Google sign-in in the browser. It completes later, when the
  /// browser returns to the app and [authChanges] reports the session.
  Future<void> signInWithGoogle();
  Future<void> signOut();
  Future<CloudSnapshot> fetchSnapshot();
  Future<void> pushSnapshot(CloudSnapshot snapshot);
}

class SupabaseCloudRepository implements CloudRepository {
  SupabaseCloudRepository(this._client);

  final SupabaseClient _client;

  // Cleared when hour_entries has no productive column yet (migration 005 not
  // applied), so ratings stay local instead of breaking the whole sync.
  bool _remoteHasProductive = true;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  String? get currentUserEmail => _client.auth.currentUser?.email;

  @override
  bool get isSignedIn => _client.auth.currentSession != null;

  @override
  Stream<void> get authChanges =>
      _client.auth.onAuthStateChange.map<void>((_) {});

  @override
  Future<CloudAuthResult> signUp(String email, String password) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
    );
    return CloudAuthResult(needsEmailConfirmation: response.session == null);
  }

  @override
  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      // The web app returns to the page it is served from; Android returns
      // through the app's own link.
      redirectTo: kIsWeb
          ? '${Uri.base.origin}${Uri.base.path}'
          : CloudConfig.mobileAuthRedirect,
    );
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<CloudSnapshot> fetchSnapshot() async {
    _requireUserId();
    final categoryRows = await _client
        .from('time_categories')
        .select()
        .order('sort_order');
    final entryRows = await _client
        .from('hour_entries')
        .select()
        .order('entry_date')
        .order('hour_start');
    final settingsRows = await _client.from('user_settings').select().limit(1);
    final reflectionRows = await _client
        .from('daily_reflections')
        .select()
        .order('reflection_date');

    return CloudSnapshot(
      categories: categoryRows.map(_categoryFromRemote).toList(),
      entries: entryRows.map(_entryFromRemote).toList(),
      settings: settingsRows.isEmpty
          ? null
          : _settingsFromRemote(settingsRows.first),
      reflections: reflectionRows.map(_reflectionFromRemote).toList(),
    );
  }

  @override
  Future<void> pushSnapshot(CloudSnapshot snapshot) async {
    final userId = _requireUserId();
    if (snapshot.categories.isNotEmpty) {
      await _client.from('time_categories').upsert([
        for (var index = 0; index < snapshot.categories.length; index++)
          _categoryToRemote(snapshot.categories[index], userId, index),
      ], onConflict: 'user_id,id');
    }
    if (snapshot.entries.isNotEmpty) {
      try {
        await _upsertEntries(snapshot.entries, userId);
      } on PostgrestException catch (error) {
        if (!_remoteHasProductive || !error.message.contains('productive')) {
          rethrow;
        }
        _remoteHasProductive = false;
        await _upsertEntries(snapshot.entries, userId);
      }
    }
    if (snapshot.settings case final settings?) {
      await _client
          .from('user_settings')
          .upsert(_settingsToRemote(settings, userId), onConflict: 'user_id');
    }
    if (snapshot.reflections.isNotEmpty) {
      await _client
          .from('daily_reflections')
          .upsert(
            snapshot.reflections
                .map((reflection) => _reflectionToRemote(reflection, userId))
                .toList(),
            onConflict: 'user_id,reflection_date',
          );
    }
  }

  Future<void> _upsertEntries(List<HourEntry> entries, String userId) {
    return _client
        .from('hour_entries')
        .upsert(
          entries.map((entry) => _entryToRemote(entry, userId)).toList(),
          onConflict: 'user_id,entry_date,hour_start',
        );
  }

  String _requireUserId() {
    final userId = currentUserId;
    if (userId == null) throw StateError('Cloud sync requires sign-in.');
    return userId;
  }

  TimeCategory _categoryFromRemote(Map<String, dynamic> row) {
    return TimeCategory(
      id: row['id'] as String,
      name: row['name'] as String,
      colorValue: (row['color_value'] as num).toInt(),
      createdAt: _requiredDate(row['created_at']),
      updatedAt: _requiredDate(row['updated_at']),
      deletedAt: _optionalDate(row['deleted_at']),
    );
  }

  HourEntry _entryFromRemote(Map<String, dynamic> row) {
    return HourEntry(
      date: row['entry_date'] as String,
      hourStart: (row['hour_start'] as num).toInt(),
      task: row['task'] as String? ?? '',
      categoryId: row['category_id'] as String?,
      productive: row['productive'] as bool?,
      createdAt: _requiredDate(row['created_at']),
      updatedAt: _requiredDate(row['updated_at']),
      deletedAt: _optionalDate(row['deleted_at']),
    );
  }

  AppSettings _settingsFromRemote(Map<String, dynamic> row) {
    return AppSettings(
      remindersEnabled: row['reminders_enabled'] as bool? ?? false,
      reminderStartHour: (row['reminder_start_hour'] as num?)?.toInt() ?? 8,
      reminderEndHour: (row['reminder_end_hour'] as num?)?.toInt() ?? 23,
      morningVideosEnabled: row['morning_videos_enabled'] as bool? ?? false,
      morningVideosHour: (row['morning_videos_hour'] as num?)?.toInt() ?? 8,
      timezone: row['timezone'] as String? ?? 'UTC',
      createdAt: _requiredDate(row['created_at']),
      updatedAt: _requiredDate(row['updated_at']),
    );
  }

  DailyReflection _reflectionFromRemote(Map<String, dynamic> row) {
    return DailyReflection(
      date: row['reflection_date'] as String,
      mood: (row['mood'] as num).toInt(),
      energy: (row['energy'] as num).toInt(),
      calm: (row['calm'] as num).toInt(),
      note: row['note'] as String? ?? '',
      createdAt: _requiredDate(row['created_at']),
      updatedAt: _requiredDate(row['updated_at']),
    );
  }

  Map<String, Object?> _categoryToRemote(
    TimeCategory category,
    String userId,
    int sortOrder,
  ) {
    return <String, Object?>{
      'user_id': userId,
      'id': category.id,
      'name': category.name,
      'color_value': category.colorValue,
      'sort_order': sortOrder,
      'created_at': category.createdAt!.toIso8601String(),
      'updated_at': category.updatedAt!.toIso8601String(),
      'deleted_at': category.deletedAt?.toIso8601String(),
    };
  }

  Map<String, Object?> _entryToRemote(HourEntry entry, String userId) {
    return <String, Object?>{
      'user_id': userId,
      'entry_date': entry.date,
      'hour_start': entry.hourStart,
      'task': entry.task,
      'category_id': entry.categoryId,
      if (_remoteHasProductive) 'productive': entry.productive,
      'created_at': (entry.createdAt ?? entry.updatedAt).toIso8601String(),
      'updated_at': entry.updatedAt.toIso8601String(),
      'deleted_at': entry.deletedAt?.toIso8601String(),
    };
  }

  Map<String, Object?> _settingsToRemote(AppSettings settings, String userId) {
    return <String, Object?>{
      'user_id': userId,
      'reminders_enabled': settings.remindersEnabled,
      'reminder_start_hour': settings.reminderStartHour,
      'reminder_end_hour': settings.reminderEndHour,
      'morning_videos_enabled': settings.morningVideosEnabled,
      'morning_videos_hour': settings.morningVideosHour,
      'timezone': settings.timezone,
      'created_at': settings.createdAt!.toIso8601String(),
      'updated_at': settings.updatedAt!.toIso8601String(),
    };
  }

  Map<String, Object?> _reflectionToRemote(
    DailyReflection reflection,
    String userId,
  ) {
    return <String, Object?>{
      'user_id': userId,
      'reflection_date': reflection.date,
      'mood': reflection.mood,
      'energy': reflection.energy,
      'calm': reflection.calm,
      'note': reflection.note,
      'created_at': (reflection.createdAt ?? reflection.updatedAt)
          .toIso8601String(),
      'updated_at': reflection.updatedAt.toIso8601String(),
    };
  }

  DateTime _requiredDate(Object? value) =>
      DateTime.parse(value! as String).toUtc();

  DateTime? _optionalDate(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toUtc();
}
