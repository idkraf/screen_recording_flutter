import 'package:flutter_test/flutter_test.dart';
import 'package:screen_recorder_app/core/services/ai_guard_service.dart';
import 'package:screen_recorder_app/core/services/ai_service.dart';
import 'package:screen_recorder_app/core/services/analytics_service.dart';
import 'package:screen_recorder_app/core/services/crashlytics_service.dart';
import 'package:screen_recorder_app/core/services/video_ai_service.dart';
import 'package:screen_recorder_app/core/utils/formatters.dart';
import 'package:screen_recorder_app/features/recorder/models/recording_model.dart';
import 'package:screen_recorder_app/features/recorder/models/recording_state.dart';
import 'package:screen_recorder_app/features/recordings_list/models/ai_analysis_model.dart';
import 'package:screen_recorder_app/main.dart';

void main() {
  group('Formatters Unit Tests', () {
    test('formatDuration formats minutes and seconds correctly', () {
      expect(Formatters.formatDuration(const Duration(seconds: 45)), '00:45');
      expect(
        Formatters.formatDuration(const Duration(minutes: 5, seconds: 20)),
        '05:20',
      );
    });

    test('formatDuration formats hours correctly', () {
      expect(
        Formatters.formatDuration(
          const Duration(hours: 1, minutes: 2, seconds: 3),
        ),
        '01:02:03',
      );
    });

    test('formatFileSize formats units correctly', () {
      expect(Formatters.formatFileSize(0), '0 B');
      expect(Formatters.formatFileSize(500), '500 B');
      expect(Formatters.formatFileSize(1024), '1.0 KB');
      expect(Formatters.formatFileSize(1024 * 1024 * 5), '5.0 MB');
      expect(
        Formatters.formatFileSize((1024 * 1024 * 1024 * 1.5).round()),
        '1.50 GB',
      );
    });
  });

  group('RecordingModel Unit Tests', () {
    test('creates and formats recording model attributes', () {
      final now = DateTime(2026, 9, 23, 10, 30);
      final model = RecordingModel(
        id: 'rec_01',
        fileName: 'rekam_test.mp4',
        filePath: '/data/rekam_test.mp4',
        fileSizeBytes: 2 * 1024 * 1024,
        duration: const Duration(seconds: 75),
        createdAt: now,
      );

      expect(model.id, 'rec_01');
      expect(model.formattedDuration, '01:15');
      expect(model.formattedSize, '2.0 MB');

      final updated = model.copyWith(fileSizeBytes: 4 * 1024 * 1024);
      expect(updated.formattedSize, '4.0 MB');
      expect(updated.id, 'rec_01');
    });

    test('recording state enum definitions', () {
      expect(RecordingState.values, contains(RecordingState.idle));
      expect(RecordingState.values, contains(RecordingState.recording));
      expect(RecordingState.values, contains(RecordingState.paused));
    });
  });

  group('AI Models & Exceptions Unit Tests', () {
    test('VideoChapter parses seconds and timestamp accurately', () {
      final json = {
        'timestamp': '01:15',
        'seconds': 75,
        'title': 'Buka Pengaturan',
        'description': 'Navigasi ke menu setting',
      };
      final chapter = VideoChapter.fromJson(json);
      expect(chapter.timestamp, '01:15');
      expect(chapter.seconds, 75);
      expect(chapter.title, 'Buka Pengaturan');
      expect(chapter.description, 'Navigasi ke menu setting');
      expect(chapter.toJson(), equals(json));
    });

    test('AiAnalysisResult parses summary and chapter lists', () {
      final json = {
        'summary': '• Langkah 1\n• Langkah 2',
        'chapters': [
          {
            'timestamp': '00:00',
            'seconds': 0,
            'title': 'Mulai',
          },
          {
            'timestamp': '00:10',
            'seconds': 10,
            'title': 'Menu',
          }
        ],
      };
      final result = AiAnalysisResult.fromJson(json);
      expect(result.summary, contains('Langkah 1'));
      expect(result.chapters.length, 2);
      expect(result.chapters[1].seconds, 10);
    });

    test('AiCommandResponse parses timestamp and targetSeconds', () {
      final json = {
        'answer': 'Menu pengaturan dibuka pada detik 15.',
        'targetTimestamp': '00:15',
        'targetSeconds': 15,
        'actionSuggestion': 'Lompat ke detik 00:15',
      };
      final response = AiCommandResponse.fromJson(json);
      expect(response.answer, contains('detik 15'));
      expect(response.targetTimestamp, '00:15');
      expect(response.targetSeconds, 15);
      expect(response.actionSuggestion, 'Lompat ke detik 00:15');
    });

    test('AiCommandResponse parses fallback seconds from timestamp string', () {
      final json = {
        'answer': 'Event terjadi.',
        'targetTimestamp': '02:30',
      };
      final response = AiCommandResponse.fromJson(json);
      expect(response.targetSeconds, 150);
    });

    test('AI Security Guard & Service Exceptions', () {
      const unauth = UnauthenticatedException();
      expect(unauth.toString(), contains('Sesi akun Google tidak aktif'));

      const noKey = ApiKeyNotSetException();
      expect(noKey.toString(), contains('Gemini API Key belum diatur'));

      const tooLarge = VideoTooLargeException();
      expect(tooLarge.toString(), contains('terlalu besar'));

      expect(AiGuardStatus.values, contains(AiGuardStatus.granted));
      expect(AiGuardStatus.values, contains(AiGuardStatus.needGoogleLogin));
      expect(AiGuardStatus.values, contains(AiGuardStatus.needGeminiKey));
    });
  });

  group('Analytics & Crashlytics Services Unit Tests', () {
    test('AnalyticsService methods execute safely in offline/test environment', () async {
      final analytics = AnalyticsService.instance;
      expect(analytics.observer, isNull);

      // Pastikan pemanggilan method tidak melempar unhandled exception saat Firebase offline
      await analytics.logScreenView(screenName: 'HomeScreen');
      await analytics.logRecordingStarted(withAudio: true, resolution: '1080x1920');
      await analytics.logRecordingSaved(durationSeconds: 60, fileSizeBytes: 1024 * 1024);
      await analytics.logAiAnalysisRequested(analysisType: 'timeline_summary', videoDurationSeconds: 45);
      await analytics.logAiCommandExecuted(commandLength: 12);
      await analytics.logUserLogin(method: 'google');
      await analytics.logUserLogout();
      await analytics.setUserId('user_test_123');
      await analytics.setUserProperty(name: 'user_type', value: 'tester');
    });

    test('CrashlyticsService methods execute safely in offline/test environment', () async {
      final crashlytics = CrashlyticsService.instance;
      await crashlytics.initializeErrorHandlers();
      await crashlytics.recordError(Exception('Test non-fatal'), StackTrace.current);
      await crashlytics.log('Test log message');
      await crashlytics.setCustomKey('test_key', 'test_val');
      await crashlytics.setUserIdentifier('user_test_123');
    });
  });

  group('App Smoke Test', () {
    testWidgets('ScreenRecorderApp renders home screen with title', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ScreenRecorderApp());
      await tester.pump();

      // Memastikan judul AppBar 'REKAM' ditampilkan
      expect(find.text('REKAM'), findsOneWidget);
    });
  });
}
