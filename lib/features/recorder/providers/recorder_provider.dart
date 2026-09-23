import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/services/screen_recorder_service.dart';
import '../../../core/services/storage_service.dart';
import '../models/recording_model.dart';
import '../models/recording_state.dart';

class RecorderProvider extends ChangeNotifier {
  final ScreenRecorderService _recorderService = ScreenRecorderService();

  RecordingState _state = RecordingState.idle;
  RecordingState get state => _state;

  Duration _elapsedDuration = Duration.zero;
  Duration get elapsedDuration => _elapsedDuration;

  bool _isAudioEnabled = true;
  bool get isAudioEnabled => _isAudioEnabled;

  int _countdownSeconds = 0;
  int get countdownSeconds => _countdownSeconds;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Timer? _tickerTimer;

  void toggleAudio(bool value) {
    if (_state.isIdle) {
      _isAudioEnabled = value;
      notifyListeners();
    }
  }

  /// Mulai proses rekaman (Kondisi 1: "Mulai")
  Future<bool> startRecording({
    required BuildContext context,
    int width = 1080,
    int height = 1920,
  }) async {
    _errorMessage = null;

    // 1. Verifikasi Permissions
    final hasPermissions = await PermissionService.requestRecordingPermissions();
    if (!hasPermissions) {
      _errorMessage = 'Izin mikrofon atau penyimpanan ditolak oleh pengguna.';
      notifyListeners();
      return false;
    }

    _state = RecordingState.starting;
    _countdownSeconds = 3;
    notifyListeners();

    // Hitung mundur 3 detik untuk mempersiapkan pengguna
    while (_countdownSeconds > 0) {
      await Future.delayed(const Duration(seconds: 1));
      _countdownSeconds--;
      notifyListeners();
    }

    // Siapkan folder & nama file
    final dir = await StorageService.getRecordingsDirectory();
    final fileName = StorageService.generateFileName();

    final started = await _recorderService.start(
      fileName: fileName,
      dirPath: dir.path,
      audioEnable: _isAudioEnabled,
      width: width,
      height: height,
    );

    if (started) {
      _state = RecordingState.recording;
      _elapsedDuration = Duration.zero;
      _startTimer();
      notifyListeners();
      AnalyticsService.instance.logRecordingStarted(
        withAudio: _isAudioEnabled,
        resolution: '${width}x$height',
      );
      return true;
    } else {
      _state = RecordingState.idle;
      _errorMessage = 'Gagal memulai perekaman layar. Pastikan izin proyeksi layar disetujui.';
      notifyListeners();
      return false;
    }
  }

  /// Menjeda rekaman sementara (Kondisi 2: "Pause")
  Future<void> pauseRecording() async {
    if (!_state.isRecording) return;

    final paused = await _recorderService.pause();
    if (paused) {
      _stopTimer();
      _state = RecordingState.paused;
      notifyListeners();
    }
  }

  /// Melanjutkan rekaman (Kondisi 3: "Lanjutkan")
  Future<void> resumeRecording() async {
    if (!_state.isPaused) return;

    final resumed = await _recorderService.resume();
    if (resumed) {
      _startTimer();
      _state = RecordingState.recording;
      notifyListeners();
    }
  }

  /// Mengakhiri dan menyimpan rekaman (Kondisi 4: "Selesai")
  Future<RecordingModel?> stopRecording() async {
    if (!_state.isActive) return null;

    _stopTimer();
    final totalDuration = _elapsedDuration;
    _state = RecordingState.stopping;
    notifyListeners();

    final File? recordedFile = await _recorderService.stop();

    _state = RecordingState.idle;
    _elapsedDuration = Duration.zero;
    notifyListeners();

    if (recordedFile != null && await recordedFile.exists()) {
      final stat = await recordedFile.stat();
      final fileName = recordedFile.path.split(Platform.pathSeparator).last;

      AnalyticsService.instance.logRecordingSaved(
        durationSeconds: totalDuration.inSeconds,
        fileSizeBytes: stat.size,
      );

      return RecordingModel(
        id: recordedFile.path,
        fileName: fileName,
        filePath: recordedFile.path,
        fileSizeBytes: stat.size,
        duration: totalDuration,
        createdAt: stat.modified,
      );
    }

    return null;
  }

  void _startTimer() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedDuration += const Duration(seconds: 1);
      notifyListeners();
    });
  }

  void _stopTimer() {
    _tickerTimer?.cancel();
    _tickerTimer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}
