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
  bool _isPreviewingCut = false;

  double _startDeleteMs = 0.0;
  double _endDeleteMs = 1000.0;
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
        // Default potong 1 detik di tengah atau proporsional jika video pendek
        if (_totalDurationMs > 3000) {
          _startDeleteMs = (_totalDurationMs * 0.25).clamp(0.0, _totalDurationMs - 1000);
          _endDeleteMs = (_startDeleteMs + 2000).clamp(_startDeleteMs + 500, _totalDurationMs);
        } else {
          _startDeleteMs = 0.0;
          _endDeleteMs = (_totalDurationMs * 0.5).clamp(100.0, _totalDurationMs);
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

    // Logika Preview Mode: otomatis lewati bagian frame yang dihapus
    if (_isPreviewingCut && _controller.value.isPlaying) {
      final currentPos = _controller.value.position.inMilliseconds.toDouble();
      if (currentPos >= _startDeleteMs && currentPos < _endDeleteMs) {
        _controller.seekTo(Duration(milliseconds: _endDeleteMs.toInt()));
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

  void _setStartDelete() {
    final currentMs = _controller.value.position.inMilliseconds.toDouble();
    if (currentMs >= _endDeleteMs) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Awal potong harus sebelum akhir potong.'),
          backgroundColor: AppColors.stop,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      _startDeleteMs = currentMs;
    });
  }

  void _setEndDelete() {
    final currentMs = _controller.value.position.inMilliseconds.toDouble();
    if (currentMs <= _startDeleteMs) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akhir potong harus setelah awal potong.'),
          backgroundColor: AppColors.stop,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      _endDeleteMs = currentMs;
    });
  }

  String _formatPreciseDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final tenths = (duration.inMilliseconds.remainder(1000) / 100).floor();
    return '${twoDigits(minutes)}:${twoDigits(seconds)}.$tenths';
  }

  Future<void> _processCut() async {
    final deletedDurationMs = _endDeleteMs - _startDeleteMs;
    final remainingDurationMs = _totalDurationMs - deletedDurationMs;

    if (deletedDurationMs < 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rentang frame yang dihapus terlalu singkat (minimal 0.2s).'),
          backgroundColor: AppColors.stop,
        ),
      );
      return;
    }

    if (remainingDurationMs < 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video yang tersisa terlalu singkat (minimal 0.5s).'),
          backgroundColor: AppColors.stop,
        ),
      );
      return;
    }

    // Jeda video jika sedang berjalan
    if (_controller.value.isPlaying) {
      _controller.pause();
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final outputPath =
          await VideoEditorService.generateEditedFilePath(widget.recording.filePath);

      final result = await VideoEditorService.deleteRange(
        inputPath: widget.recording.filePath,
        outputPath: outputPath,
        startDeleteMs: _startDeleteMs.toInt(),
        endDeleteMs: _endDeleteMs.toInt(),
        totalDurationMs: _totalDurationMs.toInt(),
      );

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
              content: Text('Gagal memotong video. Silakan coba kembali.'),
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
            content: Text('Terjadi kesalahan: $e'),
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
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.resume, size: 28),
            SizedBox(width: 10),
            Text(
              'Berhasil Dipotong!',
              style: TextStyle(
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
            const Text(
              'Frame yang tidak diinginkan telah dihapus. File baru telah disimpan ke daftar rekaman Anda:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
                  const Icon(Icons.movie_rounded, color: AppColors.accent, size: 28),
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
                          'Durasi: ${Formatters.formatDuration(newRecording.duration)} • ${newRecording.formattedSize}',
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
              Navigator.pop(ctx); // Tutup dialog
              Navigator.pop(context); // Kembali dari edit screen
            },
            child: const Text('Ke Daftar Rekaman',
                style: TextStyle(color: AppColors.textSecondary)),
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
            child: const Text('Tonton Video Hasil'),
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
        title: const Text('POTONG FRAME / EDIT VIDEO'),
        actions: [
          if (_isInitialized && !_isProcessing)
            TextButton.icon(
              onPressed: _processCut,
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

    final deletedMs = _endDeleteMs - _startDeleteMs;
    final remainingMs = (_totalDurationMs - deletedMs).clamp(0.0, _totalDurationMs);

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
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                    // Tombol Play / Pause overlay
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
                          size: 40,
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
                          color: Colors.black.withValues(alpha: 0.7),
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
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Bagian Kontrol Frame Stepper & Navigasi Presisi
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

              const SizedBox(height: 16),

              // Card Seleksi Frame yang Dihapus
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
                            color: AppColors.stop.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.content_cut_rounded,
                            color: AppColors.stop,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bagian Frame yang Dihapus',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Tentukan frame awal dan akhir yang ingin dibuang',
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

                    const SizedBox(height: 16),

                    // RangeSlider Selector
                    RangeSlider(
                      values: RangeValues(_startDeleteMs, _endDeleteMs),
                      min: 0.0,
                      max: _totalDurationMs,
                      activeColor: AppColors.stop,
                      inactiveColor: AppColors.surfaceLight,
                      onChanged: (RangeValues values) {
                        setState(() {
                          _startDeleteMs = values.start;
                          _endDeleteMs = values.end;
                        });
                        // Seek ke frame yang sedang digeser
                        _controller.seekTo(Duration(milliseconds: values.start.toInt()));
                      },
                    ),

                    // Indikator Waktu Awal & Akhir Potong
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hapus Mulai:',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                            Text(
                              _formatPreciseDuration(
                                Duration(milliseconds: _startDeleteMs.toInt()),
                              ),
                              style: const TextStyle(
                                color: AppColors.stop,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Hapus Sampai:',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                            Text(
                              _formatPreciseDuration(
                                Duration(milliseconds: _endDeleteMs.toInt()),
                              ),
                              style: const TextStyle(
                                color: AppColors.stop,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Tombol Cepat: "Set Awal" dan "Set Akhir" di posisi playback saat ini
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _setStartDelete,
                            icon: const Icon(Icons.arrow_right_alt_rounded,
                                size: 18, color: AppColors.stop),
                            label: const Text(
                              'Tandai Awal Potong',
                              style: TextStyle(fontSize: 11, color: AppColors.stop),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.stop),
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
                            onPressed: _setEndDelete,
                            icon: const Icon(Icons.keyboard_tab_rounded,
                                size: 18, color: AppColors.stop),
                            label: const Text(
                              'Tandai Akhir Potong',
                              style: TextStyle(fontSize: 11, color: AppColors.stop),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.stop),
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
                      label: 'Dibuang',
                      value: '-${_formatPreciseDuration(Duration(milliseconds: deletedMs.toInt()))}',
                      color: AppColors.stop,
                    ),
                    Container(width: 1, height: 32, color: AppColors.border),
                    _buildStatItem(
                      label: 'Durasi Akhir',
                      value: _formatPreciseDuration(
                        Duration(milliseconds: remainingMs.toInt()),
                      ),
                      color: AppColors.resume,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Switch / Tombol Mode Pratinjau
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isPreviewingCut
                        ? AppColors.accent.withValues(alpha: 0.15)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isPreviewingCut ? AppColors.accent : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isPreviewingCut
                                ? Icons.visibility_rounded
                                : Icons.visibility_outlined,
                            color: _isPreviewingCut ? AppColors.accent : AppColors.textMuted,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pratinjau Hasil Potongan',
                                style: TextStyle(
                                  color: _isPreviewingCut
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const Text(
                                'Melewati otomatis bagian yang dipotong',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _isPreviewingCut,
                        activeThumbColor: AppColors.accent,
                        onChanged: (val) {
                          setState(() {
                            _isPreviewingCut = val;
                          });
                          if (val) {
                            // Mulai playback dari 1 detik sebelum cut untuk melihat transisi
                            final startPreview =
                                (_startDeleteMs - 1500).clamp(0.0, _totalDurationMs);
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
                  onPressed: _processCut,
                  icon: const Icon(Icons.content_cut_rounded, size: 20),
                  label: const Text(
                    'Potong & Simpan Video Baru',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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

        // Loading Overlay saat proses pemotongan berlangsung
        if (_isProcessing)
          Container(
            color: Colors.black.withValues(alpha: 0.8),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Memproses pemotongan frame video...',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Harap tunggu, video sedang diekspor secara presisi.',
                    style: TextStyle(
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
