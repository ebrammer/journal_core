// lib/src/utils/logging.dart

import 'package:flutter/foundation.dart';

class Log {
  static void info(String message) {
    if (kDebugMode) {
      debugPrint('ℹ️ [journal_core] $message');
    }
  }

  static void warn(String message) {
    if (kDebugMode) {
      debugPrint('⚠️ [journal_core] $message');
    }
  }

  static void error(String message) {
    if (kDebugMode) {
      debugPrint('❌ [journal_core] $message');
    }
  }
}
