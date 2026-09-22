import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/recording_state.dart';

class RecordingControlButton extends StatefulWidget {
  final RecordingState state;
  final int countdown;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback? onMinimize;

  const RecordingControlButton({
    super.key,
    required this.state,
    required this.countdown,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    this.onMinimize,
  });

  @override
  State<RecordingControlButton> createState() => _RecordingControlButtonState();
}

class _RecordingControlButtonState extends State<RecordingControlButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Widget Tombol Dinamis Utama (Dynamic Multi-Function Button)
        _buildDynamicMainButton(),

        const SizedBox(height: 16),

        // Keterangan status atau Tombol Pendukung "Selesai" (Kondisi 4)
        _buildActionHintOrStopButton(),
      ],
    );
  }

  Widget _buildDynamicMainButton() {
    switch (widget.state) {
      case RecordingState.idle:
        // Kondisi 1: Tombol "Mulai"
        return ScaleTransition(
          scale: _pulseAnimation,
          child: GestureDetector(
            onTap: widget.onStart,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFFFB7185),
                    AppColors.primary,
                    Color(0xFF9F1239),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    blurRadius: 28,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: const Icon(
                Icons.fiber_manual_record_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
        );

      case RecordingState.starting:
        // Transisi Persiapan & Hitung Mundur
        return Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceLight,
            border: Border.all(color: AppColors.primary, width: 3),
          ),
          child: Center(
            child: Text(
              widget.countdown > 0 ? '${widget.countdown}' : '...',
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        );

      case RecordingState.recording:
        // Kondisi 2: Tombol "Pause" (Jeda sementara)
        return GestureDetector(
          onTap: widget.onPause,
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.pause,
              boxShadow: [
                BoxShadow(
                  color: AppColors.pause.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.pause_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
        );

      case RecordingState.paused:
        // Kondisi 3: Tombol "Lanjutkan" (Resume)
        return GestureDetector(
          onTap: widget.onResume,
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.resume,
              boxShadow: [
                BoxShadow(
                  color: AppColors.resume.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
        );

      case RecordingState.stopping:
        // Status sedang memproses penyimpanan
        return Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceLight,
          ),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        );
    }
  }

  Widget _buildActionHintOrStopButton() {
    if (widget.state.isIdle) {
      return const Column(
        children: [
          Text(
            'MULAI REKAM',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Ketuk untuk memulai tangkapan layar',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      );
    }

    if (widget.state.isActive) {
      return Column(
        children: [
          Text(
            widget.state.isRecording ? 'Ketuk untuk Menjeda (Pause)' : 'Ketuk untuk Melanjutkan (Resume)',
            style: TextStyle(
              color: widget.state.isRecording ? AppColors.pause : AppColors.resume,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),

          // Kondisi 4: Tombol "Selesai" (Stop Recording)
          ElevatedButton.icon(
            onPressed: widget.onStop,
            icon: const Icon(Icons.stop_rounded, size: 24),
            label: const Text(
              'Selesai & Simpan',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.stop,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 4,
            ),
          ),
          const SizedBox(height: 10),
          // Tombol Kembali ke Layar Utama HP
          if (widget.onMinimize != null)
            TextButton.icon(
              onPressed: widget.onMinimize,
              icon: const Icon(Icons.home_rounded, size: 20, color: AppColors.accent),
              label: const Text(
                'Ke Layar Utama HP (Minimize)',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      );
    }

    if (widget.state.isStarting) {
      return const Text(
        'Bersiap-siap merekam...',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      );
    }

    return const Text(
      'Menyimpan file video...',
      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
    );
  }
}
