import 'dart:io';

void main(List<String> arguments) {
  final threshold = arguments.isEmpty ? 60.0 : double.tryParse(arguments.first);
  if (threshold == null || threshold < 0 || threshold > 100) {
    stderr.writeln('Usage: dart run tool/check_coverage.dart [0-100]');
    exitCode = 64;
    return;
  }

  final report = File('coverage/lcov.info');
  if (!report.existsSync()) {
    stderr.writeln(
      'coverage/lcov.info was not found. Run flutter test --coverage first.',
    );
    exitCode = 66;
    return;
  }

  var linesFound = 0;
  var linesHit = 0;
  for (final line in report.readAsLinesSync()) {
    if (line.startsWith('LF:')) {
      linesFound += int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      linesHit += int.parse(line.substring(3));
    }
  }
  final percent = linesFound == 0 ? 0.0 : linesHit * 100 / linesFound;
  stdout.writeln(
    'Line coverage: ${percent.toStringAsFixed(1)}% '
    '($linesHit/$linesFound), required: ${threshold.toStringAsFixed(1)}%',
  );
  if (percent < threshold) exitCode = 1;
}
