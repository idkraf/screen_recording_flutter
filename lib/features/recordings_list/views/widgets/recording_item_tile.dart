import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/drive_sync_provider.dart';
import '../../../recorder/models/recording_model.dart';
import '../../models/drive_upload_task.dart';

class RecordingItemTile extends StatelessWidget {
  final RecordingModel recording;
  final VoidCallback onPlay;
  final VoidCallback? onTap;
  final VoidCallback? onOptions;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const RecordingItemTile({
    super.key,
    required this.recording,
    required this.onPlay,
    this.onTap,
    this.onOptions,
    this.onShare,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final driveSync = context.watch<DriveSyncProvider>();
    final driveTask = driveSync.getTaskForRecording(recording.id);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap ?? onPlay,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    // Thumbnail / Video Icon Preview (Tap to quick-play)
                    GestureDetector(
                      onTap: onPlay,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF3B82F6),
                                  Color(0xFF1E1B4B),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.movie_creation_rounded,
                              color: Colors.white70,
                              size: 30,
                            ),
                          ),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 14),

                    // Info File (Nama, Tanggal, Ukuran, Durasi)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recording.fileName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            recording.formattedDate,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  recording.formattedSize,
                                  style: const TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (recording.duration > Duration.zero)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    recording.formattedDuration,
                                    style: const TextStyle(
                                      color: AppColors.resume,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Indikator Ringkas Drive (Jika Sedang Aktif / Tersimpan)
                    if (driveTask != null) _buildDriveCompactBadge(driveTask),

                    // Tombol Menu Opsi (Membuka Modal Bottom Sheet Tindakan)
                    IconButton(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: AppColors.textSecondary,
                        size: 22,
                      ),
                      tooltip: 'Pilihan Tindakan Rekaman',
                      onPressed: onOptions ?? onTap ?? onPlay,
                    ),
                  ],
                ),

                // Indikator Progress Unggah / Status Drive jika ada task aktif
                if (driveTask != null) _buildDriveStatusRow(driveTask),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDriveCompactBadge(DriveUploadTask task) {
    if (task.isPending) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
          ),
        ),
      );
    }

    if (task.isUploading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            value: task.progress > 0 ? task.progress : null,
            strokeWidth: 2.2,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            backgroundColor: AppColors.surfaceLight,
          ),
        ),
      );
    }

    if (task.isCompleted) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Icon(
          Icons.cloud_done_rounded,
          color: AppColors.resume,
          size: 20,
        ),
      );
    }

    if (task.isFailed) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Icon(
          Icons.error_outline_rounded,
          color: AppColors.stop,
          size: 20,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDriveStatusRow(DriveUploadTask task) {
    if (task.isUploading) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: task.progress > 0 ? task.progress : null,
                backgroundColor: AppColors.surfaceLight,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Mengunggah ke Drive... ${(task.progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${(task.uploadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB / ${(task.fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (task.isPending) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 12),
            SizedBox(width: 4),
            Text(
              'Menunggu giliran di antrean unggah...',
              style: TextStyle(color: Colors.amber, fontSize: 10),
            ),
          ],
        ),
      );
    }

    if (task.isFailed) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.stop, size: 12),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                task.errorMessage ?? 'Gagal mencadangkan ke Drive.',
                style: const TextStyle(color: AppColors.stop, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

