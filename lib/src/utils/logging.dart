// lib/src/utils/logging.dart

import 'package:flutter/foundation.dart';

class Log {
  // Static flag to manually enable or disable logging
  static bool isLoggingEnabled = true;

  // Enable logging
  static void enableLogging() {
    isLoggingEnabled = true;
    debugPrint('ℹ️ [journal_core] Logging enabled');
  }

  // Disable logging
  static void disableLogging() {
    isLoggingEnabled = false;
    debugPrint('ℹ️ [journal_core] Logging disabled');
  }

  static void info(String message) {
    if (kDebugMode && isLoggingEnabled) {
      debugPrint('ℹ️ [journal_core] $message');
    }
  }

  static void warn(String message) {
    if (kDebugMode && isLoggingEnabled) {
      debugPrint('⚠️ [journal_core] $message');
    }
  }

  static void error(String message) {
    if (kDebugMode && isLoggingEnabled) {
      debugPrint('❌ [journal_core] $message');
    }
  }
}
