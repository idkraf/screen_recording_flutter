import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/drive_sync_provider.dart';
import '../../recorder/models/recording_model.dart';
import '../providers/recordings_provider.dart';
import 'video_edit_screen.dart';
import 'video_player_screen.dart';
import 'widgets/recording_item_tile.dart';

class RecordingsListScreen extends StatefulWidget {
  const RecordingsListScreen({super.key});

  @override
  State<RecordingsListScreen> createState() => _RecordingsListScreenState();
}

class _RecordingsListScreenState extends State<RecordingsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecordingsProvider>().loadRecordings();
    });
  }

  void _confirmDelete(RecordingModel recording) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Hapus Rekaman?',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus "${recording.fileName}" secara permanen?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success =
                  await context.read<RecordingsProvider>().deleteRecording(recording);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Video berhasil dihapus.'
                          : 'Gagal menghapus video.',
                    ),
                    backgroundColor: success ? AppColors.resume : AppColors.stop,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.stop,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordingsProvider>();
    final driveSync = context.watch<DriveSyncProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('DAFTAR HASIL REKAMAN'),
        actions: [
          IconButton(
            icon: Icon(
              driveSync.isAutoSyncEnabled
                  ? Icons.cloud_sync_rounded
                  : Icons.cloud_outlined,
              color: driveSync.isAutoSyncEnabled
                  ? AppColors.resume
                  : AppColors.textPrimary,
            ),
            tooltip: 'Sinkronisasi Google Drive',
            onPressed: () => _showDriveSettings(context, driveSync),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Perbarui Daftar',
            onPressed: () => provider.loadRecordings(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.loadRecordings(),
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: _buildContent(provider),
      ),
      bottomNavigationBar: _buildActiveSyncBanner(driveSync),
    );
  }

  Widget _buildContent(RecordingsProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (provider.recordings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.videocam_off_rounded,
                  size: 64,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Belum Ada Rekaman Layar',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hasil rekaman layar Anda akan otomatis tersimpan dan ditampilkan di sini.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.fiber_manual_record_rounded, size: 20),
                label: const Text('Mulai Merekam Sekarang'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: provider.recordings.length,
      itemBuilder: (context, index) {
        final item = provider.recordings[index];
        return RecordingItemTile(
          recording: item,
          onPlay: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VideoPlayerScreen(recording: item),
              ),
            );
          },
          onEdit: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VideoEditScreen(recording: item),
              ),
            );
          },
          onShare: () => provider.shareRecording(item),
          onDelete: () => _confirmDelete(item),
        );
      },
    );
  }

  Widget? _buildActiveSyncBanner(DriveSyncProvider driveSync) {
    final activeTask = driveSync.activeTask;
    if (activeTask == null && driveSync.pendingOrActiveCount == 0) {
      return null;
    }

    final pendingCount = driveSync.pendingOrActiveCount;
    final progress = activeTask?.progress ?? 0.0;
    final fileName = activeTask?.fileName ?? 'Menyiapkan berkas...';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeTask != null
                            ? 'Mengunggah: $fileName'
                            : 'Memproses antrean Drive...',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        activeTask != null
                            ? '${(progress * 100).toInt()}% • $pendingCount berkas dalam antrean'
                            : '$pendingCount berkas menunggu giliran',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (activeTask != null)
                  TextButton(
                    onPressed: () => driveSync.cancelUpload(activeTask.id),
                    child: const Text(
                      'Batal',
                      style: TextStyle(color: AppColors.stop, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                backgroundColor: AppColors.surfaceLight,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDriveSettings(BuildContext context, DriveSyncProvider driveSync) {
    final auth = context.read<AuthProvider>();
    final recordings = context.read<RecordingsProvider>().recordings;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.cloud_sync_rounded,
                          color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pencadangan Google Drive',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Folder: "REKAM Screen Recordings"',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Status Akun Google
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        auth.isLoggedIn
                            ? Icons.account_circle_rounded
                            : Icons.no_accounts_rounded,
                        color: auth.isLoggedIn
                            ? AppColors.resume
                            : AppColors.textMuted,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          auth.isLoggedIn
                              ? 'Akun: ${auth.user?.email ?? "Terhubung"}'
                              : 'Belum login Google Sign-In',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!auth.isLoggedIn)
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await auth.signInWithGoogle();
                          },
                          child: const Text('Login',
                              style: TextStyle(color: AppColors.accent)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Switch Otomatis Cadangkan
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Cadangkan Otomatis',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: const Text(
                    'Otomatis mengunggah ke Drive setelah selesai rekam',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  value: driveSync.isAutoSyncEnabled,
                  activeThumbColor: AppColors.resume,
                  onChanged: (val) {
                    driveSync.toggleAutoSync(val);
                    setModalState(() {});
                  },
                ),
                const SizedBox(height: 14),

                // Tombol Cadangkan Seluruh Rekaman
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: recordings.isEmpty
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            int enqueuedCount = 0;
                            for (final rec in recordings) {
                              final existing = driveSync.getTaskForRecording(rec.id);
                              if (existing == null ||
                                  (!existing.isUploading &&
                                      !existing.isCompleted)) {
                                driveSync.enqueueUpload(rec);
                                enqueuedCount++;
                              }
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  enqueuedCount > 0
                                      ? '$enqueuedCount rekaman ditambahkan ke antrean unggah.'
                                      : 'Semua rekaman sudah ada dalam antrean atau selesai.',
                                ),
                                backgroundColor: AppColors.resume,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                    icon: const Icon(Icons.cloud_upload_rounded, size: 20),
                    label: const Text('Cadangkan Semua Rekaman'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }
}
