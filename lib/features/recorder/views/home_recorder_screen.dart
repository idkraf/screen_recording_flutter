import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/drive_sync_provider.dart';
import '../../../core/services/ai_guard_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/services/screen_recorder_service.dart';
import '../../profile/views/profile_screen.dart';
import '../../recordings_list/providers/recordings_provider.dart';
import '../../recordings_list/views/recordings_list_screen.dart';
import '../models/recording_state.dart';
import '../providers/recorder_provider.dart';
import 'widgets/recording_control_button.dart';
import 'widgets/recording_stats_card.dart';
import 'widgets/recording_timer_badge.dart';
import 'widgets/user_profile_dialog.dart';

class HomeRecorderScreen extends StatefulWidget {
  const HomeRecorderScreen({super.key});

  @override
  State<HomeRecorderScreen> createState() => _HomeRecorderScreenState();
}

class _HomeRecorderScreenState extends State<HomeRecorderScreen> {
  @override
  void initState() {
    super.initState();
    // Inisialisasi daftar rekaman yang sudah ada
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecordingsProvider>().loadRecordings();
    });
  }

  void _handleStartRecording() async {
    final hasOverlay = await PermissionService.hasOverlayPermission();
    if (!hasOverlay && mounted) {
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF334155)),
          ),
          title: const Row(
            children: [
              Icon(Icons.layers_rounded, color: Color(0xFF38BDF8)),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Bubble Kontrol Mengambang',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: const Text(
            'Ingin mengaktifkan tombol kontrol mengambang (Floating Overlay) di atas aplikasi lain agar Anda dapat menjeda atau menghentikan rekaman dengan cepat?',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Lanjut Tanpa Bubble', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx, true);
                await PermissionService.requestOverlayPermission();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              child: const Text('Aktifkan'),
            ),
          ],
        ),
      );

      if (shouldProceed != true) return;
    }

    if (!mounted) return;
    final recorder = context.read<RecorderProvider>();
    final success = await recorder.startRecording(context: context);

    if (!mounted) return;

    if (!success && recorder.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(recorder.errorMessage!),
          backgroundColor: AppColors.stop,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handlePauseRecording() {
    context.read<RecorderProvider>().pauseRecording();
  }

  void _handleResumeRecording() {
    context.read<RecorderProvider>().resumeRecording();
  }

  void _handleStopRecording() async {
    final recorder = context.read<RecorderProvider>();
    final newRecording = await recorder.stopRecording();

    if (!mounted) return;

    if (newRecording != null) {
      // Tambahkan ke provider daftar rekaman
      final recordingsProvider = context.read<RecordingsProvider>();
      recordingsProvider.addRecording(newRecording);

      // Auto-Sync ke Google Drive jika diaktifkan pengguna
      final driveSync = context.read<DriveSyncProvider>();
      if (driveSync.isAutoSyncEnabled) {
        driveSync.enqueueUpload(newRecording);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Video berhasil disimpan: ${newRecording.fileName}'),
          backgroundColor: AppColors.resume,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

      // Alur Fungsional Spesifikasi: Otomatis diarahkan ke daftar hasil rekaman
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RecordingsListScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menyimpan video rekaman.'),
          backgroundColor: AppColors.stop,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final recorder = context.watch<RecorderProvider>();
    final totalRecordings = context.watch<RecordingsProvider>().recordings.length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('REKAM'),
        actions: [
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final user = auth.user;
              if (user != null) {
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfileScreen(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 15,
                            backgroundColor: AppColors.primary,
                            backgroundImage: user.photoURL != null
                                ? NetworkImage(user.photoURL!)
                                : null,
                            child: user.photoURL == null
                                ? Text(
                                    user.displayName?.isNotEmpty == true
                                        ? user.displayName![0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF0F172A),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return IconButton(
                icon: const Icon(Icons.account_circle_outlined,
                    color: AppColors.textSecondary),
                tooltip: 'Login Google untuk Akses Profil',
                onPressed: () => UserProfileDialog.show(context),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.key_rounded, color: AppColors.accent),
            tooltip: 'Setup Gemini API Key (Profil)',
            onPressed: () {
              final auth = context.read<AuthProvider>();
              if (!auth.isLoggedIn) {
                AiGuardService.showRequirementDialog(
                  context: context,
                  status: AiGuardStatus.needGoogleLogin,
                  onLoginRequested: () => UserProfileDialog.show(context),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              }
            },
          ),
          // Tombol menuju Halaman Daftar Hasil Rekaman dengan counter badge
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.video_library_rounded, size: 26),
                  tooltip: 'Daftar Hasil Rekaman',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RecordingsListScreen(),
                      ),
                    );
                  },
                ),
                if (totalRecordings > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$totalRecordings',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
              Color(0xFF0F172A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),

              // 1. Badge Durasi Rekaman (Live Timer)
              RecordingTimerBadge(
                duration: recorder.elapsedDuration,
                state: recorder.state,
              ),

              const Spacer(),

              // 2. Tombol Utama Dinamis (Dynamic Multi-Function Button 4-in-1)
              RecordingControlButton(
                state: recorder.state,
                countdown: recorder.countdownSeconds,
                onStart: _handleStartRecording,
                onPause: _handlePauseRecording,
                onResume: _handleResumeRecording,
                onStop: _handleStopRecording,
                onMinimize: () => ScreenRecorderService().minimizeApp(),
              ),

              const Spacer(),

              // 3. Status Card & Pengaturan Audio
              RecordingStatsCard(
                isAudioEnabled: recorder.isAudioEnabled,
                onToggleAudio: recorder.toggleAudio,
                isRecordingActive: recorder.state.isActive,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
