import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/ai_guard_service.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/video_ai_service.dart';
import '../../../core/services/google_drive_service.dart';
import '../../../core/utils/formatters.dart';
import '../../profile/views/profile_screen.dart';
import '../../recorder/models/recording_model.dart';
import '../../recorder/views/widgets/user_profile_dialog.dart';
import '../models/ai_analysis_model.dart';
import 'video_edit_screen.dart';
import 'widgets/ai_analysis_bottom_sheet.dart';
import 'widgets/gemini_api_key_dialog.dart';

class VideoPlayerScreen extends StatefulWidget {
  final RecordingModel recording;

  const VideoPlayerScreen({
    super.key,
    required this.recording,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  bool _hasError = false;
  bool _isAiAnalyzing = false;
  AiAnalysisResult? _aiAnalysisResult;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      final file = File(widget.recording.filePath);
      if (!await file.exists()) {
        setState(() => _hasError = true);
        return;
      }

      _controller = VideoPlayerController.file(file);
      await _controller.initialize();
      _controller.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });

      setState(() {
        _isInitialized = true;
      });

      // Auto play saat dibuka
      _controller.play();
    } catch (e) {
      debugPrint('Error loading video: $e');
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  void _togglePlayPause() {
    if (!_isInitialized) return;
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  void _openEditScreen() {
    if (_isInitialized && _controller.value.isPlaying) {
      _controller.pause();
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoEditScreen(recording: widget.recording),
      ),
    );
  }

  Future<void> _handleAiAssistant() async {
    final status = await AiGuardService.checkStatus();

    if (status != AiGuardStatus.granted) {
      if (!mounted) return;
      await AiGuardService.showRequirementDialog(
        context: context,
        status: status,
        onLoginRequested: () {
          UserProfileDialog.show(context);
        },
        onKeyInputRequested: () async {
          final authProvider = context.read<AuthProvider>();
          if (!authProvider.isLoggedIn) {
            UserProfileDialog.show(context);
          } else {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
            if (mounted) {
              _handleAiAssistant();
            }
          }
        },
      );
      return;
    }

    if (_aiAnalysisResult != null) {
      _showAiResultSheet();
    } else {
      _runAiAnalysis();
    }
  }

  Future<void> _uploadToGoogleDrive() async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Login Google via Firebase diperlukan untuk backup ke Google Drive.',
          ),
          backgroundColor: const Color(0xFF2563EB),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Login',
            textColor: Colors.white,
            onPressed: () => UserProfileDialog.show(context),
          ),
        ),
      );
      return;
    }

    // Tampilkan dialog progress upload
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          color: Color(0xFF1E293B),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                ),
                SizedBox(width: 18),
                Text(
                  'Mengunggah ke Google Drive...',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final result = await GoogleDriveService.uploadRecording(
      videoFile: File(widget.recording.filePath),
      fileName: widget.recording.fileName,
    );

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // Tutup dialog
    }

    if (!mounted) return;

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Video berhasil di-backup ke Google Drive pribadi!',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.errorMessage ?? 'Gagal mengunggah video ke Google Drive.',
          ),
          backgroundColor: AppColors.stop,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _runAiAnalysis() async {
    if (_isInitialized && _controller.value.isPlaying) {
      _controller.pause();
    }

    setState(() {
      _isAiAnalyzing = true;
    });

    try {
      final result = await VideoAiService.generateTimelineSummary(
        videoPath: widget.recording.filePath,
      );

      if (!mounted) return;
      setState(() {
        _isAiAnalyzing = false;
        _aiAnalysisResult = result;
      });

      _showAiResultSheet();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAiAnalyzing = false;
      });

      if (e is ApiKeyNotSetException) {
        final saved = await GeminiApiKeyDialog.show(context);
        if (saved == true) {
          _runAiAnalysis();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.stop,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Setting Key',
              textColor: Colors.white,
              onPressed: () => GeminiApiKeyDialog.show(context),
            ),
          ),
        );
      }
    }
  }

  void _showAiResultSheet() {
    if (_aiAnalysisResult == null) return;
    AiAnalysisBottomSheet.show(
      context: context,
      videoPath: widget.recording.filePath,
      analysis: _aiAnalysisResult!,
      onSeekTo: (pos) {
        _controller.seekTo(pos);
        _controller.play();
      },
      onReanalyze: _runAiAnalysis,
    );
  }

  void _shareVideo() {
    final params = ShareParams(
      files: [XFile(widget.recording.filePath)],
      text: 'Tonton rekaman layar: ${widget.recording.fileName}',
    );
    SharePlus.instance.share(params);
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.6),
        title: Text(
          widget.recording.fileName,
          style: const TextStyle(fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              return FutureBuilder<AiGuardStatus>(
                future: AiGuardService.checkStatus(),
                builder: (context, snapshot) {
                  final status = snapshot.data ?? AiGuardStatus.needGoogleLogin;
                  final isUnlocked = status == AiGuardStatus.granted;

                  return IconButton(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: isUnlocked
                              ? AppColors.accent
                              : Colors.grey.shade400,
                        ),
                        if (!isUnlocked)
                          const Positioned(
                            right: -4,
                            bottom: -4,
                            child: Icon(
                              Icons.lock_rounded,
                              size: 13,
                              color: Colors.amber,
                            ),
                          ),
                      ],
                    ),
                    tooltip: isUnlocked
                        ? 'AI Video Editor Assistant (Timeline & Command)'
                        : (status == AiGuardStatus.needGoogleLogin
                            ? 'AI Terkunci (Wajib Login Google via Profil)'
                            : 'AI Terkunci (Setup Gemini Key di Profil)'),
                    onPressed: _isAiAnalyzing ? null : _handleAiAssistant,
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.cloud_upload_outlined,
              color: Color(0xFF60A5FA),
            ),
            tooltip: 'Backup ke Google Drive',
            onPressed: _uploadToGoogleDrive,
          ),
          IconButton(
            icon: const Icon(Icons.content_cut_rounded),
            tooltip: 'Potong Frame / Edit Video',
            onPressed: _openEditScreen,
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Bagikan Video',
            onPressed: _shareVideo,
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_hasError) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.stop, size: 54),
            SizedBox(height: 12),
            Text(
              'Gagal memutar video.',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
            ),
            SizedBox(height: 6),
            Text(
              'File mungkin telah dipindahkan atau rusak.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Video Player Viewport
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),

          // Central Play / Pause Button Overlay
          if (_showControls || !_controller.value.isPlaying)
            GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _controller.value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),

          // Bottom Controls & Scrubber Bar
          if (_showControls)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Slider Scrubber
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: AppColors.primary,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        trackHeight: 3,
                      ),
                      child: Slider(
                        min: 0.0,
                        max: _controller.value.duration.inMilliseconds.toDouble(),
                        value: _controller.value.position.inMilliseconds
                            .toDouble()
                            .clamp(
                              0.0,
                              _controller.value.duration.inMilliseconds.toDouble(),
                            ),
                        onChanged: (val) {
                          _controller.seekTo(Duration(milliseconds: val.toInt()));
                        },
                      ),
                    ),

                    // Waktu Berjalan & Total Durasi
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            Formatters.formatDuration(_controller.value.position),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            Formatters.formatDuration(_controller.value.duration),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Baris Quick Smart Chapter Chips (Opsi A)
          if (_showControls && _aiAnalysisResult != null && _aiAnalysisResult!.chapters.isNotEmpty)
            Positioned(
              left: 12,
              right: 12,
              bottom: 84,
              child: SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _aiAnalysisResult!.chapters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final ch = _aiAnalysisResult!.chapters[index];
                    final isActive = (_controller.value.position.inSeconds >= ch.seconds) &&
                        (index == _aiAnalysisResult!.chapters.length - 1 ||
                            _controller.value.position.inSeconds <
                                _aiAnalysisResult!.chapters[index + 1].seconds);
                    return ActionChip(
                      backgroundColor: isActive
                          ? AppColors.accent
                          : Colors.black.withValues(alpha: 0.65),
                      side: BorderSide(
                        color: isActive ? AppColors.accent : AppColors.borderHighlight,
                      ),
                      label: Text(
                        '${ch.timestamp} ${ch.title}',
                        style: TextStyle(
                          color: isActive ? Colors.white : AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      onPressed: () {
                        _controller.seekTo(Duration(seconds: ch.seconds));
                        _controller.play();
                      },
                    );
                  },
                ),
              ),
            ),

          // Loading Overlay saat analisis AI Gemini berlangsung
          if (_isAiAnalyzing)
            Container(
              color: Colors.black.withValues(alpha: 0.82),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.25),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.accent,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Menganalisis Rekaman Layar',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Gemini 1.5 Flash sedang memproses visual UI, menyusun smart chapters, dan merangkum aktivitas...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                          strokeWidth: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
