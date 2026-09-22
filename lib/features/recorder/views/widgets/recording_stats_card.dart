import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class RecordingStatsCard extends StatelessWidget {
  final bool isAudioEnabled;
  final ValueChanged<bool> onToggleAudio;
  final bool isRecordingActive;

  const RecordingStatsCard({
    super.key,
    required this.isAudioEnabled,
    required this.onToggleAudio,
    required this.isRecordingActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isAudioEnabled
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.surfaceLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAudioEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                  color: isAudioEnabled ? AppColors.primary : AppColors.textMuted,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rekam Suara (Audio)',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      isAudioEnabled
                          ? 'Mikrofon aktif selama rekaman'
                          : 'Rekaman layar tanpa suara',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isAudioEnabled,
                onChanged: isRecordingActive ? null : onToggleAudio,
                activeTrackColor: AppColors.primary,
                activeThumbColor: Colors.white,
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(color: AppColors.border, thickness: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoItem(
                icon: Icons.hd_rounded,
                label: 'Resolusi',
                value: '1080p FHD',
              ),
              _buildInfoItem(
                icon: Icons.speed_rounded,
                label: 'Framerate',
                value: '30 FPS',
              ),
              _buildInfoItem(
                icon: Icons.video_file_rounded,
                label: 'Format',
                value: 'MP4 / H.264',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppColors.accent, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
