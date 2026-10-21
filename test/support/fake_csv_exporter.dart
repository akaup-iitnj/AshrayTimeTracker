import 'package:hourly_time_tracker/src/csv_export.dart';

class FakeCsvExporter implements CsvExporter {
  FakeCsvExporter({this.outcome = CsvExportOutcome.saved, this.error});

  CsvExportOutcome outcome;
  Object? error;
  CsvExportData? exported;

  @override
  Future<CsvExportOutcome> export(CsvExportData data) async {
    final failure = error;
    if (failure != null) throw failure;
    exported = data;
    return outcome;
  }
}
