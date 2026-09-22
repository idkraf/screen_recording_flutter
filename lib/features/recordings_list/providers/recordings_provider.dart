import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/services/storage_service.dart';
import '../../recorder/models/recording_model.dart';

class RecordingsProvider extends ChangeNotifier {
  List<RecordingModel> _recordings = [];
  bool _isLoading = false;

  List<RecordingModel> get recordings => _recordings;
  bool get isLoading => _isLoading;

  /// Memuat semua hasil rekaman dari storage lokal
  Future<void> loadRecordings() async {
    _isLoading = true;
    notifyListeners();

    _recordings = await StorageService.fetchAllRecordings();

    _isLoading = false;
    notifyListeners();
  }

  /// Menambahkan rekaman baru yang baru saja disimpan
  void addRecording(RecordingModel newRecording) {
    _recordings.insert(0, newRecording);
    notifyListeners();
  }

  /// Menghapus file rekaman
  Future<bool> deleteRecording(RecordingModel recording) async {
    final success = await StorageService.deleteRecording(recording.filePath);
    if (success) {
      _recordings.removeWhere((item) => item.id == recording.id);
      notifyListeners();
    }
    return success;
  }

  /// Berbagi video rekaman ke aplikasi lain (WhatsApp, Drive, dll)
  Future<void> shareRecording(RecordingModel recording) async {
    try {
      final params = ShareParams(
        files: [XFile(recording.filePath)],
        text: 'Hasil Rekaman Layar: ${recording.fileName}',
      );
      await SharePlus.instance.share(params);
    } catch (e) {
      debugPrint('Error sharing recording: $e');
    }
  }
}
