import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../features/recorder/models/recording_model.dart';

class StorageService {
  /// Mendapatkan direktori penyimpanan hasil rekaman video
  static Future<Directory> getRecordingsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory('${appDir.path}/ScreenRecordings');
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }
    return recordingsDir;
  }

  /// Menghasilkan nama file video unik berdasarkan timestamp
  static String generateFileName() {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${_twoDigits(now.month)}${_twoDigits(now.day)}_${_twoDigits(now.hour)}${_twoDigits(now.minute)}${_twoDigits(now.second)}';
    return 'REC_$dateStr';
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');

  /// Mengambil semua file video hasil rekaman yang tersimpan
  static Future<List<RecordingModel>> fetchAllRecordings() async {
    try {
      final dir = await getRecordingsDirectory();
      final List<FileSystemEntity> entities = await dir.list().toList();

      final List<RecordingModel> recordings = [];

      for (var entity in entities) {
        if (entity is File && entity.path.endsWith('.mp4')) {
          final stat = await entity.stat();
          final fileName = entity.path.split(Platform.pathSeparator).last;
          
          recordings.add(
            RecordingModel(
              id: entity.path,
              fileName: fileName,
              filePath: entity.path,
              fileSizeBytes: stat.size,
              duration: Duration.zero, // Default durasi, dapat diupdate saat playback
              createdAt: stat.modified,
            ),
          );
        }
      }

      // Urutkan dari yang paling baru
      recordings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return recordings;
    } catch (e) {
      return [];
    }
  }

  /// Menghapus file rekaman dari penyimpanan lokal
  static Future<bool> deleteRecording(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
