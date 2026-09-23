import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Service terpusat untuk pelaporan error, exception, dan crash ke Firebase Crashlytics.
/// Memiliki perlindungan otomatis terhadap inisialisasi Firebase dan mode offline.
class CrashlyticsService {
  CrashlyticsService._internal();

  static final CrashlyticsService _instance = CrashlyticsService._internal();
  static CrashlyticsService get instance => _instance;

  FirebaseCrashlytics? get _crashlytics {
    if (Firebase.apps.isEmpty) {
      return null;
    }
    return FirebaseCrashlytics.instance;
  }

  /// Mengonfigurasi penangkap crash global pada Flutter framework dan asynchronous engine.
  Future<void> initializeErrorHandlers() async {
    if (Firebase.apps.isEmpty) {
      debugPrint('[Crashlytics] Skipped setup because Firebase is not initialized.');
      return;
    }

    try {
      final crashlytics = FirebaseCrashlytics.instance;

      // Di mode debug, kita tetap mengaktifkan collection kecuali jika diinginkan mati
      // Agar developer dapat menguji via crashlytics.crash() jika diperlukan
      await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

      // Tangkap semua uncaught "fatal" errors dari framework Flutter
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        crashlytics.recordFlutterFatalError(details);
      };

      // Tangkap asynchronous error di luar framework Flutter (PlatformDispatcher)
      PlatformDispatcher.instance.onError = (error, stack) {
        crashlytics.recordError(error, stack, fatal: true);
        return true;
      };

      debugPrint('[Crashlytics] Global error handlers successfully attached.');
    } catch (e) {
      debugPrint('[Crashlytics] Failed to initialize error handlers: $e');
    }
  }

  /// Mencatat non-fatal exception secara terprogram.
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    dynamic reason,
    Iterable<Object> information = const [],
    bool fatal = false,
  }) async {
    try {
      final crashlytics = _crashlytics;
      if (crashlytics == null) return;
      await crashlytics.recordError(
        exception,
        stack,
        reason: reason,
        information: information,
        fatal: fatal,
      );
    } catch (e) {
      debugPrint('[Crashlytics] Error recording exception: $e');
    }
  }

  /// Menambahkan custom log message ke session Crashlytics berikutnya.
  Future<void> log(String message) async {
    try {
      final crashlytics = _crashlytics;
      if (crashlytics == null) return;
      await crashlytics.log(message);
    } catch (e) {
      debugPrint('[Crashlytics] Error logging message: $e');
    }
  }

  /// Menetapkan custom key-value untuk analisis mendalam saat terjadi crash.
  Future<void> setCustomKey(String key, Object value) async {
    try {
      final crashlytics = _crashlytics;
      if (crashlytics == null) return;
      await crashlytics.setCustomKey(key, value);
    } catch (e) {
      debugPrint('[Crashlytics] Error setting custom key: $e');
    }
  }

  /// Mengaitkan user id pada pelaporan crashlytics.
  Future<void> setUserIdentifier(String identifier) async {
    try {
      final crashlytics = _crashlytics;
      if (crashlytics == null) return;
      await crashlytics.setUserIdentifier(identifier);
    } catch (e) {
      debugPrint('[Crashlytics] Error setting user identifier: $e');
    }
  }
}
