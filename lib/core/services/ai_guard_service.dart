import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'api_key_storage_service.dart';

/// Status kualifikasi akses fitur AI Assistant
enum AiGuardStatus {
  /// Syarat terpenuhi: Sudah Login Google DAN Memiliki Gemini API Key
  granted,

  /// Syarat 1 belum terpenuhi: Belum login Google via Firebase
  needGoogleLogin,

  /// Syarat 2 belum terpenuhi: Belum memasukkan Gemini API Key pribadi (BYOK)
  needGeminiKey,
}

/// Service untuk memvalidasi aturan akses ketat pada AI Assistant
class AiGuardService {
  /// Memeriksa status kelayakan akses AI
  static Future<AiGuardStatus> checkStatus() async {
    final User? user = AuthService.instance.currentUser;
    if (user == null) {
      return AiGuardStatus.needGoogleLogin;
    }

    final bool hasKey = await ApiKeyStorageService.hasGeminiApiKey(user.uid);
    if (!hasKey) {
      return AiGuardStatus.needGeminiKey;
    }

    return AiGuardStatus.granted;
  }

  /// Menampilkan dialog penjelas jika akses AI masih terkunci
  static Future<void> showRequirementDialog({
    required BuildContext context,
    required AiGuardStatus status,
    VoidCallback? onLoginRequested,
    VoidCallback? onKeyInputRequested,
  }) async {
    final isLoginRequired = status == AiGuardStatus.needGoogleLogin;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF334155)),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isLoginRequired
                      ? Colors.amber.withValues(alpha: 0.2)
                      : const Color(0xFF38BDF8).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isLoginRequired
                      ? Icons.lock_outline_rounded
                      : Icons.key_rounded,
                  color: isLoginRequired ? Colors.amber : const Color(0xFF38BDF8),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isLoginRequired ? 'Login Diperlukan' : 'Gemini Key Diperlukan',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isLoginRequired
                    ? 'Fitur AI Assistant (Smart Chapters & Video Summary) memerlukan autentikasi Google via Firebase untuk penggunaan personal yang aman.'
                    : 'Anda telah berhasil login! Untuk mengaktifkan AI Assistant, masukkan Gemini API Key pribadi Anda (Bring Your Own Key) melalui pengaturan aman.',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: !isLoginRequired ? Colors.greenAccent : Colors.grey,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '1. Login Akun Google via Firebase',
                        style: TextStyle(
                          color: !isLoginRequired ? Colors.white : const Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: !isLoginRequired ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.circle_outlined,
                      color: Colors.grey,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '2. BYOK Gemini API Key (Android Keystore)',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (isLoginRequired) {
                  onLoginRequested?.call();
                } else {
                  onKeyInputRequested?.call();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isLoginRequired
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF38BDF8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(isLoginRequired ? 'Login Sekarang' : 'Masukkan Key'),
            ),
          ],
        );
      },
    );
  }
}
