import '../../../core/utils/formatters.dart';

class RecordingModel {
  final String id;
  final String fileName;
  final String filePath;
  final int fileSizeBytes;
  final Duration duration;
  final DateTime createdAt;

  RecordingModel({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.fileSizeBytes,
    required this.duration,
    required this.createdAt,
  });

  String get formattedDuration => Formatters.formatDuration(duration);
  String get formattedSize => Formatters.formatFileSize(fileSizeBytes);
  String get formattedDate => Formatters.formatDate(createdAt);

  RecordingModel copyWith({
    String? id,
    String? fileName,
    String? filePath,
    int? fileSizeBytes,
    Duration? duration,
    DateTime? createdAt,
  }) {
    return RecordingModel(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
