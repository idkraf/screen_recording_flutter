import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/ai_guard_service.dart';
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
