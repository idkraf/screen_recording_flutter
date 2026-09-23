/// Status proses unggah file video ke Google Drive
enum DriveUploadStatus {
  pending,
  uploading,
  completed,
  failed,
  cancelled,
}

/// Model untuk merepresentasikan satu tugas dalam antrean unggah Google Drive
class DriveUploadTask {
  final String id;
  final String filePath;
  final String fileName;
  final int fileSizeBytes;
  final DriveUploadStatus status;
  final double progress; // 0.0 sampai 1.0
  final int uploadedBytes;
  final String? driveFileId;
  final String? webViewLink;
  final String? errorMessage;
  final DateTime createdAt;

  const DriveUploadTask({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.fileSizeBytes,
    this.status = DriveUploadStatus.pending,
    this.progress = 0.0,
    this.uploadedBytes = 0,
    this.driveFileId,
    this.webViewLink,
    this.errorMessage,
    required this.createdAt,
  });

  bool get isPending => status == DriveUploadStatus.pending;
  bool get isUploading => status == DriveUploadStatus.uploading;
  bool get isCompleted => status == DriveUploadStatus.completed;
  bool get isFailed => status == DriveUploadStatus.failed;
  bool get isCancelled => status == DriveUploadStatus.cancelled;

  int get progressPercentage => (progress * 100).clamp(0, 100).toInt();

  DriveUploadTask copyWith({
    String? id,
    String? filePath,
    String? fileName,
    int? fileSizeBytes,
    DriveUploadStatus? status,
    double? progress,
    int? uploadedBytes,
    String? driveFileId,
    String? webViewLink,
    String? errorMessage,
    DateTime? createdAt,
  }) {
    return DriveUploadTask(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      uploadedBytes: uploadedBytes ?? this.uploadedBytes,
      driveFileId: driveFileId ?? this.driveFileId,
      webViewLink: webViewLink ?? this.webViewLink,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
