import 'dart:io';
import 'package:flutter/material.dart';
import '../../features/recorder/models/recording_model.dart';
import '../../features/recordings_list/models/drive_upload_task.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../services/google_drive_service.dart';

/// Provider pengelola antrean unggah latar belakang (Background Sync Queue) ke Google Drive
/// Menerapkan pola Sequential FIFO Queue untuk stabilitas memori dan bebas freeze.
class DriveSyncProvider extends ChangeNotifier {
  final Map<String, DriveUploadTask> _tasks = {};
  bool _isAutoSyncEnabled = false;
  bool _isProcessing = false;
  DateTime? _lastProgressNotifyTime;

  List<DriveUploadTask> get tasks => _tasks.values.toList();

  bool get isAutoSyncEnabled => _isAutoSyncEnabled;

  /// Task yang saat ini sedang aktif mentransmisikan data
  DriveUploadTask? get activeTask {
    for (final task in _tasks.values) {
      if (task.isUploading) return task;
    }
    return null;
  }

  /// Jumlah task yang sedang aktif atau menunggu giliran di antrean
  int get pendingOrActiveCount {
    return _tasks.values
        .where((t) => t.isPending || t.isUploading)
        .length;
  }

  /// Mengambil status task spesifik untuk sebuah berkas rekaman
  DriveUploadTask? getTaskForRecording(String recordingId) {
    return _tasks[recordingId];
  }

  /// Mengaktifkan atau menonaktifkan fitur pencadangan otomatis
  void toggleAutoSync(bool value) {
    _isAutoSyncEnabled = value;
    notifyListeners();
  }

  /// Memasukkan rekaman baru ke dalam antrean unggah
  Future<void> enqueueUpload(RecordingModel recording) async {
    // Jika task sudah ada dan sedang aktif/selesai, abaikan
    final existing = _tasks[recording.id];
    if (existing != null && (existing.isUploading || existing.isCompleted)) {
      return;
    }

    final task = DriveUploadTask(
      id: recording.id,
      filePath: recording.filePath,
      fileName: recording.fileName,
      fileSizeBytes: recording.fileSizeBytes,
      status: DriveUploadStatus.pending,
      createdAt: DateTime.now(),
    );

    _tasks[recording.id] = task;
    notifyListeners();

    _triggerQueueProcessing();
  }

  /// Mengulang kembali tugas unggah yang gagal
  Future<void> retryUpload(String recordingId) async {
    final task = _tasks[recordingId];
    if (task == null) return;

    _tasks[recordingId] = task.copyWith(
      status: DriveUploadStatus.pending,
      progress: 0.0,
      uploadedBytes: 0,
      errorMessage: null,
    );
    notifyListeners();

    _triggerQueueProcessing();
  }

  /// Membatalkan tugas unggah dari antrean
  void cancelUpload(String recordingId) {
    final task = _tasks[recordingId];
    if (task == null) return;

    if (task.isPending) {
      _tasks.remove(recordingId);
      notifyListeners();
    } else if (task.isUploading) {
      _tasks[recordingId] = task.copyWith(
        status: DriveUploadStatus.cancelled,
        errorMessage: 'Unggahan dibatalkan oleh pengguna.',
      );
      notifyListeners();
    }
  }

  /// Membersihkan daftar tugas yang telah selesai dari memori antrean
  void clearCompleted() {
    _tasks.removeWhere((key, task) => task.isCompleted || task.isCancelled);
    notifyListeners();
  }

  void _triggerQueueProcessing() {
    if (!_isProcessing) {
      _processQueue();
    }
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;

    // Cari tugas pertama yang berstatus pending (FIFO)
    DriveUploadTask? nextTask;
    for (final task in _tasks.values) {
      if (task.isPending) {
        nextTask = task;
        break;
      }
    }

    if (nextTask == null) {
      _isProcessing = false;
      notifyListeners();
      return;
    }

    _isProcessing = true;

    // Tandai status menjadi uploading
    _tasks[nextTask.id] = nextTask.copyWith(
      status: DriveUploadStatus.uploading,
      progress: 0.0,
      uploadedBytes: 0,
    );
    notifyListeners();

    final videoFile = File(nextTask.filePath);

    // Validasi sesi akun Google
    if (!AuthService.instance.isLoggedIn) {
      _tasks[nextTask.id] = nextTask.copyWith(
        status: DriveUploadStatus.failed,
        errorMessage: 'Sesi Google tidak aktif. Harap login terlebih dahulu.',
      );
      _isProcessing = false;
      notifyListeners();
      return;
    }

    final result = await GoogleDriveService.uploadRecordingWithProgress(
      videoFile: videoFile,
      fileName: nextTask.fileName,
      onProgress: (sentBytes, totalBytes) {
        if (!_tasks.containsKey(nextTask!.id)) return;
        final currentTask = _tasks[nextTask.id];
        if (currentTask == null || currentTask.isCancelled) return;

        final double currentProgress =
            totalBytes > 0 ? (sentBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

        _tasks[nextTask.id] = currentTask.copyWith(
          uploadedBytes: sentBytes,
          progress: currentProgress,
        );

        // Throttle pembaruan UI setiap 150ms agar thread rendering tidak terbebani
        final now = DateTime.now();
        if (_lastProgressNotifyTime == null ||
            now.difference(_lastProgressNotifyTime!).inMilliseconds > 150) {
          _lastProgressNotifyTime = now;
          notifyListeners();
        }
      },
    );

    // Cek apakah task sempat dibatalkan saat sedang mengunggah
    final currentTaskAfterUpload = _tasks[nextTask.id];
    if (currentTaskAfterUpload != null && currentTaskAfterUpload.isCancelled) {
      _isProcessing = false;
      _triggerQueueProcessing();
      return;
    }

    if (result.isSuccess) {
      _tasks[nextTask.id] = nextTask.copyWith(
        status: DriveUploadStatus.completed,
        progress: 1.0,
        uploadedBytes: nextTask.fileSizeBytes,
        driveFileId: result.fileId,
        webViewLink: result.webViewLink,
      );

      AnalyticsService.instance.logScreenView(
        screenName: 'drive_sync_success',
        screenClass: 'DriveSyncProvider',
      );
    } else {
      _tasks[nextTask.id] = nextTask.copyWith(
        status: DriveUploadStatus.failed,
        errorMessage: result.errorMessage ?? 'Gagal mengunggah video ke Drive.',
      );
    }

    notifyListeners();
    _isProcessing = false;

    // Lanjutkan proses ke task berikutnya di antrean
    _triggerQueueProcessing();
  }
}
