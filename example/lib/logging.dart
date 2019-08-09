import 'package:logging/logging.dart';

void setupLoggingPrintRecord() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.loggerName} - ${rec.level.name}: ${rec.time}: ${rec.message}');

    if (rec.error != null) {
      print(rec.error);
    }
    // ignore: avoid_as
    final stackTrace = rec.stackTrace ?? (rec.error is Error ? (rec.error as Error).stackTrace : null);
    if (stackTrace != null) {
      print(stackTrace);
    }
  });
}
