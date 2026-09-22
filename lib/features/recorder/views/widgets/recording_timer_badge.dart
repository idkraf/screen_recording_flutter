import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../models/recording_state.dart';

class RecordingTimerBadge extends StatefulWidget {
  final Duration duration;
  final RecordingState state;

  const RecordingTimerBadge({
    super.key,
    required this.duration,
    required this.state,
  });

  @override
  State<RecordingTimerBadge> createState() => _RecordingTimerBadgeState();
}

class _RecordingTimerBadgeState extends State<RecordingTimerBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = widget.state.isRecording;
    final isPaused = widget.state.isPaused;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isRecording
              ? AppColors.primary
              : (isPaused ? AppColors.pause : AppColors.border),
          width: 1.5,
        ),
        boxShadow: [
          if (isRecording)
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 16,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Blinking red dot when recording
          if (isRecording)
            FadeTransition(
              opacity: _blinkController,
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            )
          else if (isPaused)
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: AppColors.pause,
                shape: BoxShape.circle,
              ),
            )
          else
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: AppColors.textMuted,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 10),
          Text(
            Formatters.formatDuration(widget.duration),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
