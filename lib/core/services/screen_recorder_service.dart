import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ScreenRecorderService {
  static const MethodChannel _channel =
      MethodChannel('com.screenrecording.app/recorder');

  /// Memulai perekaman layar menggunakan native Android MediaProjection API
  Future<bool> start({
    required String fileName,
    required String dirPath,
    bool audioEnable = true,
    int width = 1080,
    int height = 1920,
    int videoBitrate = 3000000,
    int videoFrame = 30,
  }) async {
    try {
      final outputPath = '$dirPath/$fileName.mp4';
      final bool? success = await _channel.invokeMethod<bool>('startRecording', {
        'outputPath': outputPath,
        'enableAudio': audioEnable,
        'width': width,
        'height': height,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('Error starting native screen recording: $e');
      return false;
    }
  }

  /// Menjeda perekaman layar (Pause)
  Future<bool> pause() async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('pauseRecording');
      return success ?? false;
    } catch (e) {
      debugPrint('Error pausing native screen recording: $e');
      return false;
    }
  }

  /// Melanjutkan rekaman layar dari status jeda (Resume)
  Future<bool> resume() async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('resumeRecording');
      return success ?? false;
    } catch (e) {
      debugPrint('Error resuming native screen recording: $e');
      return false;
    }
  }

  /// Menghentikan perekaman layar dan mengambil file hasil rekaman
  Future<File?> stop() async {
    try {
      final String? path = await _channel.invokeMethod<String>('stopRecording');
      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          return file;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error stopping native screen recording: $e');
      return null;
    }
  }

  /// Minimalkan aplikasi ke layar utama (Home) HP
  Future<void> minimizeApp() async {
    try {
      await _channel.invokeMethod('minimizeApp');
    } catch (e) {
      debugPrint('Error minimizing app: $e');
    }
  }
}
