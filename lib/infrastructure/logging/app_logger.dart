import 'package:gitopen/infrastructure/logging/file_log_output.dart';
import 'package:logger/logger.dart';

/// App-wide logger configured to mirror everything to both the console and
/// an append-only file at `<appSupport>/gitopen.log`.  Use this from any
/// file that needs to trace repo-load lifecycle, native errors, or anything
/// else worth keeping after the process dies.
///
/// `appLogFileOutput.init` must be awaited from `main()` before the first
/// log line is emitted — otherwise the file sink may not be open in time.
final appLogFileOutput = FileLogOutput();

final appLog = Logger(
  output: MultiOutput([ConsoleOutput(), appLogFileOutput]),
  printer: PrettyPrinter(
    methodCount: 0,
    colors: false,
    printEmojis: false,
  ),
);
