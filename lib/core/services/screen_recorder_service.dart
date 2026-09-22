import 'dart:io';
import 'package:ed_screen_recorder/ed_screen_recorder.dart';
import 'package:flutter/foundation.dart';

class ScreenRecorderService {
  final EdScreenRecorder _edScreenRecorder = EdScreenRecorder();

  /// Memulai perekaman layar menggunakan MediaProjection API Android
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
      final RecordOutput response = await _edScreenRecorder.startRecordScreen(
        fileName: fileName,
        dirPathToSave: dirPath,
        audioEnable: audioEnable,
        width: width,
        height: height,
        videoBitrate: videoBitrate,
        videoFrame: videoFrame,
      );

      return response.success;
    } catch (e) {
      debugPrint('Error starting screen record: $e');
      return false;
    }
  }

  /// Menjeda perekaman layar (Pause)
  Future<bool> pause() async {
    try {
      return await _edScreenRecorder.pauseRecord();
    } catch (e) {
      debugPrint('Error pausing screen record: $e');
      return false;
    }
  }

  /// Melanjutkan rekaman layar dari status jeda (Resume)
  Future<bool> resume() async {
    try {
      return await _edScreenRecorder.resumeRecord();
    } catch (e) {
      debugPrint('Error resuming screen record: $e');
      return false;
    }
  }

  /// Menghentikan perekaman layar dan mengambil file hasil rekaman
  Future<File?> stop() async {
    try {
      final RecordOutput response = await _edScreenRecorder.stopRecord();
      if (response.success) {
        return response.file;
      }
      return null;
    } catch (e) {
      debugPrint('Error stopping screen record: $e');
      return null;
    }
  }
}
