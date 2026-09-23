import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static const MethodChannel _channel = MethodChannel('com.screenrecording.app/recorder');

  /// Meminta seluruh izin yang dibutuhkan untuk perekaman layar dan penyimpanan
  static Future<bool> requestRecordingPermissions() async {
    // 1. Microphone Permission
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted && !micStatus.isLimited) {
      return false;
    }

    // 2. Notification Permission (Wajib untuk Foreground Service di Android 13+)
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }

    // 3. Storage / Media Video Permissions
    if (Platform.isAndroid) {
      // Android 13 (SDK 33) ke atas menggunakan READ_MEDIA_VIDEO
      final videosStatus = await Permission.videos.status;
      if (videosStatus.isDenied) {
        await Permission.videos.request();
      }

      // Untuk Android 12 ke bawah
      final storageStatus = await Permission.storage.status;
      if (storageStatus.isDenied) {
        await Permission.storage.request();
      }
    }

    return true;
  }

  /// Cek apakah izin mikrofon sudah aktif
  static Future<bool> hasMicrophonePermission() async {
    return await Permission.microphone.isGranted;
  }

  /// Memeriksa apakah aplikasi memiliki izin Floating Overlay (SYSTEM_ALERT_WINDOW)
  static Future<bool> hasOverlayPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool? hasPerm = await _channel.invokeMethod<bool>('checkOverlayPermission');
      return hasPerm ?? false;
    } catch (_) {
      return await Permission.systemAlertWindow.isGranted;
    }
  }

  /// Membuka halaman pengaturan sistem untuk memberikan izin Floating Overlay
  static Future<void> requestOverlayPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) {
      await Permission.systemAlertWindow.request();
    }
  }
}

