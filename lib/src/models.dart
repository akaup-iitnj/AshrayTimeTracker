class TimeCategory {
  const TimeCategory({
    required this.id,
    required this.name,
    required this.colorValue,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String name;
  final int colorValue;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  TimeCategory copyWith({
    String? name,
    int? colorValue,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return TimeCategory(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory TimeCategory.fromJson(Map<String, Object?> json) {
    return TimeCategory(
      id: json['id']! as String,
      name: json['name']! as String,
      colorValue: json['colorValue']! as int,
      createdAt: _dateTimeFromJson(json['createdAt']),
      updatedAt: _dateTimeFromJson(json['updatedAt']),
      deletedAt: _dateTimeFromJson(json['deletedAt']),
    );
  }
}

class HourEntry {
  const HourEntry({
    required this.date,
    required this.hourStart,
    required this.task,
    required this.categoryId,
    required this.updatedAt,
    this.createdAt,
    this.deletedAt,
  });

  final String date;
  final int hourStart;
  final String task;
  final String? categoryId;
  final DateTime updatedAt;
  final DateTime? createdAt;
  final DateTime? deletedAt;

  String get id => entryId(date, hourStart);
  bool get isDeleted => deletedAt != null;
  bool get isComplete =>
      !isDeleted && task.trim().isNotEmpty && categoryId != null;

  HourEntry copyWith({
    String? task,
    String? categoryId,
    DateTime? updatedAt,
    DateTime? createdAt,
    DateTime? deletedAt,
  }) {
    return HourEntry(
      date: date,
      hourStart: hourStart,
      task: task ?? this.task,
      categoryId: categoryId ?? this.categoryId,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'date': date,
    'hourStart': hourStart,
    'task': task,
    'categoryId': categoryId,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory HourEntry.fromJson(Map<String, Object?> json) {
    return HourEntry(
      date: json['date']! as String,
      hourStart: json['hourStart']! as int,
      task: json['task']! as String,
      categoryId: json['categoryId'] as String?,
      createdAt: _dateTimeFromJson(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']! as String).toUtc(),
      deletedAt: _dateTimeFromJson(json['deletedAt']),
    );
  }
}

class AppSettings {
  const AppSettings({
    this.remindersEnabled = false,
    this.reminderStartHour = 8,
    this.reminderEndHour = 23,
    this.timezone = 'UTC',
    this.createdAt,
    this.updatedAt,
  });

  final bool remindersEnabled;
  final int reminderStartHour;
  final int reminderEndHour;
  final String timezone;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AppSettings copyWith({
    bool? remindersEnabled,
    int? reminderStartHour,
    int? reminderEndHour,
    String? timezone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      reminderStartHour: reminderStartHour ?? this.reminderStartHour,
      reminderEndHour: reminderEndHour ?? this.reminderEndHour,
      timezone: timezone ?? this.timezone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'remindersEnabled': remindersEnabled,
    'reminderStartHour': reminderStartHour,
    'reminderEndHour': reminderEndHour,
    'timezone': timezone,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory AppSettings.fromJson(Map<String, Object?> json) {
    return AppSettings(
      remindersEnabled: json['remindersEnabled'] as bool? ?? false,
      reminderStartHour: json['reminderStartHour'] as int? ?? 8,
      reminderEndHour: json['reminderEndHour'] as int? ?? 23,
      timezone: json['timezone'] as String? ?? 'UTC',
      createdAt: _dateTimeFromJson(json['createdAt']),
      updatedAt: _dateTimeFromJson(json['updatedAt']),
    );
  }
}

class ReminderTarget {
  const ReminderTarget({required this.date, required this.hourStart});

  final DateTime date;
  final int hourStart;

  String get payload => '${dateKey(date)}|$hourStart';

  static ReminderTarget? fromPayload(String? payload) {
    if (payload == null) return null;
    final parts = payload.split('|');
    if (parts.length != 2) return null;
    final date = dateFromKey(parts.first);
    final hour = int.tryParse(parts.last);
    if (date == null || hour == null || hour < 0 || hour > 23) return null;
    return ReminderTarget(date: date, hourStart: hour);
  }
}

const defaultCategories = <TimeCategory>[
  TimeCategory(id: 'work', name: 'Work', colorValue: 0xFF345995),
  TimeCategory(id: 'learning', name: 'Learning', colorValue: 0xFF7A5CFA),
  TimeCategory(id: 'health', name: 'Health', colorValue: 0xFF2A9D8F),
  TimeCategory(id: 'sleep', name: 'Sleep', colorValue: 0xFF596780),
  TimeCategory(id: 'admin', name: 'Admin', colorValue: 0xFFE09F3E),
  TimeCategory(id: 'leisure', name: 'Leisure', colorValue: 0xFFE76F51),
  TimeCategory(id: 'social', name: 'Social', colorValue: 0xFFBF5AF2),
  TimeCategory(id: 'other', name: 'Other', colorValue: 0xFF7B817A),
];

String dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

DateTime? dateFromKey(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

String entryId(String date, int hourStart) => '$date|$hourStart';

DateTime dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool isSameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String hourLabel(int hourStart) =>
    '${formatHour(hourStart)}–${formatHour((hourStart + 1) % 24)}';

String formatHour(int hour) {
  final normalized = hour % 24;
  if (normalized == 0) return '12am';
  if (normalized == 12) return '12pm';
  if (normalized < 12) return '${normalized}am';
  return '${normalized - 12}pm';
}

DateTime? _dateTimeFromJson(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toUtc();
}
