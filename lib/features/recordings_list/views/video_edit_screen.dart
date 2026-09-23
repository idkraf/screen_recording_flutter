import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/video_editor_service.dart';
import '../../../core/utils/formatters.dart';
import '../../recorder/models/recording_model.dart';
import '../providers/recordings_provider.dart';
import 'video_player_screen.dart';

/// Mode penyuntingan video
enum VideoEditMode {
  /// Pangkas video dan hanya mempertahankan segmen yang dipilih
  trim,

  /// Potong dan buang segmen frame yang dipilih
  cut,
}

class VideoEditScreen extends StatefulWidget {
  final RecordingModel recording;

  const VideoEditScreen({
    super.key,
    required this.recording,
  });

  @override
  State<VideoEditScreen> createState() => _VideoEditScreenState();
}

class _VideoEditScreenState extends State<VideoEditScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isProcessing = false;
  bool _isPreviewing = false;

  VideoEditMode _editMode = VideoEditMode.trim;
  bool _isMuted = false;

  double _startMs = 0.0;
  double _endMs = 1000.0;
  double _totalDurationMs = 1000.0;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final file = File(widget.recording.filePath);
      if (!await file.exists()) {
        setState(() => _hasError = true);
        return;
      }

      _controller = VideoPlayerController.file(file);
      await _controller.initialize();

      final durationMs = _controller.value.duration.inMilliseconds.toDouble();
      setState(() {
        _isInitialized = true;
        _totalDurationMs = durationMs > 0 ? durationMs : 1000.0;
        // Inisialisasi rentang default
        if (_totalDurationMs > 3000) {
          _startMs = (_totalDurationMs * 0.1).clamp(0.0, _totalDurationMs - 1000);
          _endMs = (_totalDurationMs * 0.9).clamp(_startMs + 500, _totalDurationMs);
        } else {
          _startMs = 0.0;
          _endMs = _totalDurationMs;
        }
      });

      _controller.addListener(_videoListener);
    } catch (e) {
      debugPrint('Error loading video for editing: $e');
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  void _videoListener() {
    if (!mounted || !_isInitialized) return;

    if (_isPreviewing && _controller.value.isPlaying) {
      final currentPos = _controller.value.position.inMilliseconds.toDouble();

      if (_editMode == VideoEditMode.trim) {
        // Mode Trim: Putar hanya di antara _startMs dan _endMs
        if (currentPos < _startMs) {
          _controller.seekTo(Duration(milliseconds: _startMs.toInt()));
        } else if (currentPos >= _endMs) {
          // Ulangi dari awal segmen terpilih
          _controller.seekTo(Duration(milliseconds: _startMs.toInt()));
        }
      } else {
        // Mode Cut: Lewati otomatis bagian yang dibuang
        if (currentPos >= _startMs && currentPos < _endMs) {
          _controller.seekTo(Duration(milliseconds: _endMs.toInt()));
        }
      }
    }

    setState(() {});
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _controller.removeListener(_videoListener);
      _controller.dispose();
    }
    super.dispose();
  }

  void _togglePlayPause() {
    if (!_isInitialized) return;
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  void _stepTime(int deltaMs) {
    if (!_isInitialized) return;
    final currentMs = _controller.value.position.inMilliseconds;
    final targetMs = (currentMs + deltaMs).clamp(0, _totalDurationMs.toInt());
    _controller.seekTo(Duration(milliseconds: targetMs));
  }

  void _setStartRange() {
    final currentMs = _controller.value.position.inMilliseconds.toDouble();
    if (currentMs >= _endMs) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Titik awal harus sebelum titik akhir.'),
          backgroundColor: AppColors.stop,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      _startMs = currentMs;
    });
  }

  void _setEndRange() {
    final currentMs = _controller.value.position.inMilliseconds.toDouble();
    if (currentMs <= _startMs) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Titik akhir harus setelah titik awal.'),
          backgroundColor: AppColors.stop,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      _endMs = currentMs;
    });
  }

  void _toggleMuteAudio(bool value) {
    setState(() {
      _isMuted = value;
    });
    if (_isInitialized) {
      _controller.setVolume(_isMuted ? 0.0 : 1.0);
    }
  }

  String _formatPreciseDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final tenths = (duration.inMilliseconds.remainder(1000) / 100).floor();
    return '${twoDigits(minutes)}:${twoDigits(seconds)}.$tenths';
  }

  Future<void> _processEdit() async {
    final selectedDurationMs = _endMs - _startMs;
    final remainingDurationMs = _editMode == VideoEditMode.trim
        ? selectedDurationMs
        : (_totalDurationMs - selectedDurationMs);

    if (remainingDurationMs < 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Durasi video hasil terlalu singkat (minimal 0.5 detik).'),
          backgroundColor: AppColors.stop,
        ),
      );
      return;
    }

    if (_editMode == VideoEditMode.cut && selectedDurationMs < 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rentang frame yang dibuang terlalu singkat (minimal 0.2 detik).'),
          backgroundColor: AppColors.stop,
        ),
      );
      return;
    }

    if (_controller.value.isPlaying) {
      _controller.pause();
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final tag = _editMode == VideoEditMode.trim
          ? (_isMuted ? 'trimmed_muted' : 'trimmed')
          : (_isMuted ? 'cut_muted' : 'cut');

      final outputPath = await VideoEditorService.generateEditedFilePath(
        widget.recording.filePath,
        tag: tag,
      );

      final String? result;
      if (_editMode == VideoEditMode.trim) {
        result = await VideoEditorService.trim(
          inputPath: widget.recording.filePath,
          outputPath: outputPath,
          startMs: _startMs.toInt(),
          endMs: _endMs.toInt(),
          muteAudio: _isMuted,
        );
      } else {
        result = await VideoEditorService.deleteRange(
          inputPath: widget.recording.filePath,
          outputPath: outputPath,
          startDeleteMs: _startMs.toInt(),
          endDeleteMs: _endMs.toInt(),
          totalDurationMs: _totalDurationMs.toInt(),
          muteAudio: _isMuted,
        );
      }

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });

      if (result != null && await File(result).exists()) {
        final outputFile = File(result);
        final stat = await outputFile.stat();
        final fileName = result.split(Platform.pathSeparator).last;

        final newRecording = RecordingModel(
          id: result,
          fileName: fileName,
          filePath: result,
          fileSizeBytes: stat.size,
          duration: Duration(milliseconds: remainingDurationMs.toInt()),
          createdAt: DateTime.now(),
        );

        if (mounted) {
          context.read<RecordingsProvider>().addRecording(newRecording);
          _showSuccessDialog(newRecording);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal mengekspor video. Silakan coba kembali.'),
              backgroundColor: AppColors.stop,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan saat memproses: $e'),
            backgroundColor: AppColors.stop,
          ),
        );
      }
    }
  }

  void _showSuccessDialog(RecordingModel newRecording) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.resume, size: 28),
            const SizedBox(width: 10),
            Text(
              _editMode == VideoEditMode.trim
                  ? 'Berhasil Dipangkas!'
                  : 'Berhasil Dipotong!',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _editMode == VideoEditMode.trim
                  ? 'Segmen video terpilih berhasil disimpan. ${_isMuted ? "(Audio telah dibisukan)." : ""}'
                  : 'Bagian frame yang tidak diinginkan telah dibuang. ${_isMuted ? "(Audio telah dibisukan)." : ""}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _isMuted ? Icons.volume_off_rounded : Icons.movie_rounded,
                    color: AppColors.accent,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          newRecording.fileName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Durasi: ${Formatters.formatDuration(newRecording.duration)} • ${newRecording.formattedSize} ${_isMuted ? "• Audio Muted" : ""}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text(
              'Ke Daftar Rekaman',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => VideoPlayerScreen(recording: newRecording),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Tonton Hasil'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _editMode == VideoEditMode.trim
              ? 'PANGKAS VIDEO (TRIM)'
              : 'POTONG FRAME (CUT)',
        ),
        actions: [
          if (_isInitialized && !_isProcessing)
            TextButton.icon(
              onPressed: _processEdit,
              icon: const Icon(Icons.save_rounded, color: AppColors.resume, size: 20),
              label: const Text(
                'Simpan',
                style: TextStyle(
                  color: AppColors.resume,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_hasError) {
      return const Center(
        child: Text(
          'Gagal memuat video untuk diedit.',
          style: TextStyle(color: AppColors.stop),
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

    final selectedDurationMs = _endMs - _startMs;
    final finalDurationMs = _editMode == VideoEditMode.trim
        ? selectedDurationMs
        : (_totalDurationMs - selectedDurationMs).clamp(0.0, _totalDurationMs);

    final activeColor = _editMode == VideoEditMode.trim
        ? AppColors.resume
        : AppColors.stop;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Video Player Preview
              Container(
                color: Colors.black,
                height: 230,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                    GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _controller.value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),
                    // Indikator Posisi Saat Ini
                    Positioned(
                      bottom: 8,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _formatPreciseDuration(_controller.value.position),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    // Badge Muted di Pojok Atas Kanan
                    if (_isMuted)
                      Positioned(
                        top: 8,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.stop.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.volume_off_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'AUDIO MUTED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Stepper & Play/Pause Controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStepButton(label: '-1s', deltaMs: -1000),
                    _buildStepButton(label: '-100ms', deltaMs: -100),
                    IconButton.filled(
                      onPressed: _togglePlayPause,
                      icon: Icon(
                        _controller.value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    _buildStepButton(label: '+100ms', deltaMs: 100),
                    _buildStepButton(label: '+1s', deltaMs: 1000),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Mode Edit Selector (Pangkas vs Potong)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildModeTab(
                          title: 'Pangkas Rentang (Trim)',
                          subtitle: 'Ambil segmen terpilih',
                          mode: VideoEditMode.trim,
                          icon: Icons.crop_rounded,
                          selectedColor: AppColors.resume,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildModeTab(
                          title: 'Hapus Bagian (Cut)',
                          subtitle: 'Buang segmen terpilih',
                          mode: VideoEditMode.cut,
                          icon: Icons.content_cut_rounded,
                          selectedColor: AppColors.stop,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Card Visual Slider Rentang Frame
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: activeColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _editMode == VideoEditMode.trim
                                ? Icons.crop_rounded
                                : Icons.content_cut_rounded,
                            color: activeColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _editMode == VideoEditMode.trim
                                    ? 'Rentang Frame yang Dipertahankan'
                                    : 'Rentang Frame yang Dihapus',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _editMode == VideoEditMode.trim
                                    ? 'Geser slider untuk menentukan bagian awal dan akhir video'
                                    : 'Tentukan bagian yang ingin dibuang dari video',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Visual Range Slider
                    RangeSlider(
                      values: RangeValues(_startMs, _endMs),
                      min: 0.0,
                      max: _totalDurationMs,
                      activeColor: activeColor,
                      inactiveColor: AppColors.surfaceLight,
                      onChanged: (RangeValues values) {
                        setState(() {
                          _startMs = values.start;
                          _endMs = values.end;
                        });
                        _controller.seekTo(Duration(milliseconds: values.start.toInt()));
                      },
                    ),

                    // Indikator Waktu Awal & Akhir Rentang
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _editMode == VideoEditMode.trim ? 'Mulai Simpan:' : 'Mulai Hapus:',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                            Text(
                              _formatPreciseDuration(
                                Duration(milliseconds: _startMs.toInt()),
                              ),
                              style: TextStyle(
                                color: activeColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _editMode == VideoEditMode.trim ? 'Selesai Simpan:' : 'Selesai Hapus:',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                            Text(
                              _formatPreciseDuration(
                                Duration(milliseconds: _endMs.toInt()),
                              ),
                              style: TextStyle(
                                color: activeColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Tombol Set Awal & Set Akhir di Posisi Playhead
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _setStartRange,
                            icon: Icon(Icons.arrow_right_alt_rounded,
                                size: 18, color: activeColor),
                            label: const Text(
                              'Tandai Titik Awal',
                              style: TextStyle(fontSize: 11),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: activeColor,
                              side: BorderSide(color: activeColor),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _setEndRange,
                            icon: Icon(Icons.keyboard_tab_rounded,
                                size: 18, color: activeColor),
                            label: const Text(
                              'Tandai Titik Akhir',
                              style: TextStyle(fontSize: 11),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: activeColor,
                              side: BorderSide(color: activeColor),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Card Pengaturan Audio Mute (Toggle Hapus Audio)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _isMuted
                      ? AppColors.stop.withValues(alpha: 0.12)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isMuted ? AppColors.stop : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isMuted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          color: _isMuted ? AppColors.stop : AppColors.resume,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hapus Audio (Mute Video)',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              _isMuted
                                  ? 'Video akan diekspor tanpa suara'
                                  : 'Suara asli video dipertahankan',
                              style: TextStyle(
                                color: _isMuted ? AppColors.stop : AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: _isMuted,
                      activeThumbColor: AppColors.stop,
                      onChanged: _toggleMuteAudio,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Card Ringkasan Estimasi Durasi
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      label: 'Durasi Asli',
                      value: _formatPreciseDuration(
                        Duration(milliseconds: _totalDurationMs.toInt()),
                      ),
                      color: AppColors.textPrimary,
                    ),
                    Container(width: 1, height: 32, color: AppColors.border),
                    _buildStatItem(
                      label: _editMode == VideoEditMode.trim ? 'Dipilih' : 'Dibuang',
                      value: _formatPreciseDuration(
                        Duration(milliseconds: selectedDurationMs.toInt()),
                      ),
                      color: activeColor,
                    ),
                    Container(width: 1, height: 32, color: AppColors.border),
                    _buildStatItem(
                      label: 'Durasi Hasil',
                      value: _formatPreciseDuration(
                        Duration(milliseconds: finalDurationMs.toInt()),
                      ),
                      color: AppColors.resume,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Switch / Tombol Mode Pratinjau
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isPreviewing
                        ? AppColors.accent.withValues(alpha: 0.15)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isPreviewing ? AppColors.accent : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isPreviewing
                                ? Icons.visibility_rounded
                                : Icons.visibility_outlined,
                            color: _isPreviewing ? AppColors.accent : AppColors.textMuted,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pratinjau Hasil Edit',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                _editMode == VideoEditMode.trim
                                    ? 'Memutar hanya frame yang dipertahankan'
                                    : 'Melewati otomatis frame yang dibuang',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _isPreviewing,
                        activeThumbColor: AppColors.accent,
                        onChanged: (val) {
                          setState(() {
                            _isPreviewing = val;
                          });
                          if (val) {
                            final startPreview = _editMode == VideoEditMode.trim
                                ? _startMs
                                : (_startMs - 1500).clamp(0.0, _totalDurationMs);
                            _controller.seekTo(Duration(milliseconds: startPreview.toInt()));
                            _controller.play();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Tombol Ekspor / Simpan Video
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton.icon(
                  onPressed: _processEdit,
                  icon: Icon(
                    _editMode == VideoEditMode.trim
                        ? Icons.crop_rounded
                        : Icons.content_cut_rounded,
                    size: 20,
                  ),
                  label: Text(
                    _editMode == VideoEditMode.trim
                        ? (_isMuted ? 'Pangkas & Simpan (Bisu)' : 'Pangkas & Simpan Video')
                        : (_isMuted ? 'Potong & Simpan (Bisu)' : 'Potong & Simpan Video'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Loading Overlay saat proses pemrosesan Media3 berlangsung
        if (_isProcessing)
          Container(
            color: Colors.black.withValues(alpha: 0.85),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _editMode == VideoEditMode.trim
                        ? 'Memproses pemangkasan video...'
                        : 'Memproses pemotongan frame video...',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isMuted
                        ? 'Mengekspor video tanpa saluran audio via Media3 Transformer.'
                        : 'Mengekspor video dengan audio asli via Media3 Transformer.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildModeTab({
    required String title,
    required String subtitle,
    required VideoEditMode mode,
    required IconData icon,
    required Color selectedColor,
  }) {
    final isSelected = _editMode == mode;
    return InkWell(
      onTap: () {
        setState(() {
          _editMode = mode;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? selectedColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? selectedColor : AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? selectedColor : AppColors.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepButton({required String label, required int deltaMs}) {
    return InkWell(
      onTap: () => _stepTime(deltaMs),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
