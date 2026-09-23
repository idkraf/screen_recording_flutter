import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Service terpusat untuk pelaporan data event dan metrik ke Google Analytics.
/// Didesain aman (graceful fallback) jika Firebase belum diinisialisasi atau offline.
class AnalyticsService {
  AnalyticsService._internal();

  static final AnalyticsService _instance = AnalyticsService._internal();
  static AnalyticsService get instance => _instance;

  FirebaseAnalytics? get _analytics {
    if (Firebase.apps.isEmpty) {
      return null;
    }
    return FirebaseAnalytics.instance;
  }

  /// Observer untuk mencatat navigasi route/layar secara otomatis pada MaterialApp.
  FirebaseAnalyticsObserver? get observer {
    if (Firebase.apps.isNotEmpty) {
      return FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance);
    }
    return null;
  }

  /// Mencatat tampilan layar (screen view).
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      final analytics = _analytics;
      if (analytics == null) return;
      await analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
      debugPrint('[Analytics] ScreenView: $screenName');
    } catch (e) {
      debugPrint('[Analytics] Error logging screen view: $e');
    }
  }

  /// Mencatat saat sesi perekaman layar dimulai.
  Future<void> logRecordingStarted({
    required bool withAudio,
    String? resolution,
  }) async {
    try {
      final analytics = _analytics;
      if (analytics == null) return;
      final parameters = <String, Object>{
        'with_audio': withAudio ? 1 : 0,
      };
      if (resolution != null) {
        parameters['resolution'] = resolution;
      }
      await analytics.logEvent(
        name: 'recording_started',
        parameters: parameters,
      );
      debugPrint('[Analytics] Event: recording_started (audio: $withAudio)');
    } catch (e) {
      debugPrint('[Analytics] Error logging recording_started: $e');
    }
  }

  /// Mencatat saat perekaman layar berhasil disimpan.
  Future<void> logRecordingSaved({
    required int durationSeconds,
    required int fileSizeBytes,
  }) async {
    try {
      final analytics = _analytics;
      if (analytics == null) return;
      await analytics.logEvent(
        name: 'recording_saved',
        parameters: {
          'duration_seconds': durationSeconds,
          'file_size_bytes': fileSizeBytes,
        },
      );
      debugPrint(
        '[Analytics] Event: recording_saved (dur: ${durationSeconds}s, size: $fileSizeBytes bytes)',
      );
    } catch (e) {
      debugPrint('[Analytics] Error logging recording_saved: $e');
    }
  }

  /// Mencatat saat user meminta analisis AI pada video rekaman.
  Future<void> logAiAnalysisRequested({
    required String analysisType,
    int? videoDurationSeconds,
  }) async {
    try {
      final analytics = _analytics;
      if (analytics == null) return;
      final parameters = <String, Object>{
        'analysis_type': analysisType,
      };
      if (videoDurationSeconds != null) {
        parameters['video_duration_seconds'] = videoDurationSeconds;
      }
      await analytics.logEvent(
        name: 'ai_analysis_requested',
        parameters: parameters,
      );
      debugPrint('[Analytics] Event: ai_analysis_requested ($analysisType)');
    } catch (e) {
      debugPrint('[Analytics] Error logging ai_analysis_requested: $e');
    }
  }

  /// Mencatat saat user mengeksekusi perintah pada AI Assistant (Command Assistant).
  Future<void> logAiCommandExecuted({
    required int commandLength,
  }) async {
    try {
      final analytics = _analytics;
      if (analytics == null) return;
      await analytics.logEvent(
        name: 'ai_command_executed',
        parameters: {
          'command_char_length': commandLength,
        },
      );
      debugPrint('[Analytics] Event: ai_command_executed');
    } catch (e) {
      debugPrint('[Analytics] Error logging ai_command_executed: $e');
    }
  }

  /// Mencatat status login akun Google.
  Future<void> logUserLogin({required String method}) async {
    try {
      final analytics = _analytics;
      if (analytics == null) return;
      await analytics.logLogin(loginMethod: method);
      debugPrint('[Analytics] Event: login ($method)');
    } catch (e) {
      debugPrint('[Analytics] Error logging login: $e');
    }
  }

  /// Mencatat status logout akun.
  Future<void> logUserLogout() async {
    try {
      final analytics = _analytics;
      if (analytics == null) return;
      await analytics.logEvent(name: 'user_logout');
      debugPrint('[Analytics] Event: user_logout');
    } catch (e) {
      debugPrint('[Analytics] Error logging logout: $e');
    }
  }

  /// Menetapkan User ID pada Google Analytics.
  Future<void> setUserId(String? userId) async {
    try {
      final analytics = _analytics;
      if (analytics == null) return;
      await analytics.setUserId(id: userId);
    } catch (e) {
      debugPrint('[Analytics] Error setting userId: $e');
    }
  }

  /// Menetapkan properti pengguna (User Property).
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    try {
      final analytics = _analytics;
      if (analytics == null) return;
      await analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      debugPrint('[Analytics] Error setting user property $name: $e');
    }
  }
}
