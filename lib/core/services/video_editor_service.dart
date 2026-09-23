import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'storage_service.dart';

class VideoEditorService {
  static const MethodChannel _channel =
      MethodChannel('com.screenrecording.app/recorder');

  /// Menghapus rentang frame tertentu dari video (Cut / Delete Segment)
  /// [startDeleteMs] titik awal potongan dalam milidetik
  /// [endDeleteMs] titik akhir potongan dalam milidetik
  /// [totalDurationMs] total durasi video dalam milidetik
  /// [muteAudio] jika bernilai true, saluran audio akan dihilangkan/dibisukan
  static Future<String?> deleteRange({
    required String inputPath,
    required String outputPath,
    required int startDeleteMs,
    required int endDeleteMs,
    required int totalDurationMs,
    bool muteAudio = false,
  }) async {
    try {
      final String? result = await _channel.invokeMethod<String>(
        'editVideoDeleteRange',
        {
          'inputPath': inputPath,
          'outputPath': outputPath,
          'startDeleteMs': startDeleteMs,
          'endDeleteMs': endDeleteMs,
          'totalDurationMs': totalDurationMs,
          'muteAudio': muteAudio,
        },
      );
      return result;
    } on PlatformException catch (e) {
      debugPrint('PlatformException during deleteRange: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Unexpected error during deleteRange: $e');
      return null;
    }
  }

  /// Memotong video dan hanya mempertahankan rentang terpilih (Trim / Keep Selection)
  /// [muteAudio] jika bernilai true, saluran audio akan dihilangkan/dibisukan
  static Future<String?> trim({
    required String inputPath,
    required String outputPath,
    required int startMs,
    required int endMs,
    bool muteAudio = false,
  }) async {
    try {
      final String? result = await _channel.invokeMethod<String>(
        'trimVideo',
        {
          'inputPath': inputPath,
          'outputPath': outputPath,
          'startMs': startMs,
          'endMs': endMs,
          'muteAudio': muteAudio,
        },
      );
      return result;
    } on PlatformException catch (e) {
      debugPrint('PlatformException during trim: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Unexpected error during trim: $e');
      return null;
    }
  }

  /// Menghasilkan path penyimpanan untuk video hasil edit di direktori ScreenRecordings
  static Future<String> generateEditedFilePath(
    String originalPath, {
    String tag = 'edited',
  }) async {
    final dir = await StorageService.getRecordingsDirectory();
    final originalFile = File(originalPath);
    final originalNameWithoutExt =
        originalFile.uri.pathSegments.last.replaceAll('.mp4', '');
    final timestamp =
        DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    final newFileName = '${originalNameWithoutExt}_${tag}_$timestamp.mp4';
    return '${dir.path}/$newFileName';
  }
}
