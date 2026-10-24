import 'dart:convert';
import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import 'app_store.dart';
import 'models.dart';

enum CsvExportOutcome { saved, shared, cancelled }

class CsvExportData {
  const CsvExportData({
    required this.fileName,
    required this.contents,
    required this.entryCount,
  });

  final String fileName;
  final String contents;
  final int entryCount;

  Uint8List get bytes =>
      Uint8List.fromList(<int>[0xEF, 0xBB, 0xBF, ...utf8.encode(contents)]);
}

abstract class CsvExporter {
  Future<CsvExportOutcome> export(CsvExportData data);
}

class PlatformCsvExporter implements CsvExporter {
  const PlatformCsvExporter();

  @override
  Future<CsvExportOutcome> export(CsvExportData data) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      final location = await file_selector.getSaveLocation(
        suggestedName: data.fileName,
        acceptedTypeGroups: const <file_selector.XTypeGroup>[
          file_selector.XTypeGroup(label: 'CSV files', extensions: ['csv']),
        ],
      );
      if (location == null) return CsvExportOutcome.cancelled;
      final file = file_selector.XFile.fromData(
        data.bytes,
        mimeType: 'text/csv',
        name: data.fileName,
      );
      await file.saveTo(location.path);
      return CsvExportOutcome.saved;
    }

    final result = await SharePlus.instance.share(
      ShareParams(
        title: 'Export Chronicle data',
        subject: 'Chronicle CSV export',
        text: 'A backup of ${data.entryCount} logged hours.',
        files: <XFile>[XFile.fromData(data.bytes, mimeType: 'text/csv')],
        fileNameOverrides: <String>[data.fileName],
      ),
    );
    return result.status == ShareResultStatus.dismissed
        ? CsvExportOutcome.cancelled
        : CsvExportOutcome.shared;
  }
}

CsvExportData buildCsvExport(AppStore store, {DateTime? generatedAt}) {
  final entries = store.allEntries.where((entry) => !entry.isDeleted).toList()
    ..sort((first, second) {
      final byDate = first.date.compareTo(second.date);
      return byDate != 0 ? byDate : first.hourStart.compareTo(second.hourStart);
    });
  final lines = <String>[
    _csvRow(const <Object?>[
      'date',
      'hour_start',
      'hour_end',
      'time_range',
      'task',
      'category',
      'category_id',
      'updated_at_utc',
    ]),
    for (final entry in entries)
      _csvRow(<Object?>[
        entry.date,
        entry.hourStart,
        (entry.hourStart + 1) % 24,
        hourLabel(entry.hourStart),
        entry.task,
        store.categoryFor(entry.categoryId)?.name ?? 'Uncategorized',
        entry.categoryId,
        entry.updatedAt.toUtc().toIso8601String(),
      ]),
  ];
  final exportDate = generatedAt ?? DateTime.now();
  return CsvExportData(
    fileName: 'time-tracker-export-${dateKey(exportDate)}.csv',
    contents: '${lines.join('\r\n')}\r\n',
    entryCount: entries.length,
  );
}

String _csvRow(Iterable<Object?> cells) => cells.map(_csvCell).join(',');

String _csvCell(Object? value) {
  var text = value?.toString() ?? '';
  // Spreadsheet applications may execute strings beginning with these
  // characters as formulas. Preserve the visible value while forcing imported
  // user-authored text to be treated as text.
  if (value is String && RegExp(r'^[\t\r\n ]*[=+\-@]').hasMatch(text)) {
    text = "'$text";
  }
  return '"${text.replaceAll('"', '""')}"';
}
