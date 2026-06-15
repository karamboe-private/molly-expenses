import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class LoggerService {
  static void log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('ERROR: $message');
      if (error != null) debugPrint('Exception: $error');
      if (stackTrace != null) debugPrint('Stack: $stackTrace');
    }

    if (!kDebugMode) {
      FirebaseCrashlytics.instance.log(message);
      if (error != null) {
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          reason: message,
        );
      }
    }
  }
}
