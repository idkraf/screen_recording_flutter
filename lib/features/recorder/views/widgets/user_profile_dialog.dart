import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/api_key_storage_service.dart';
import '../../../recordings_list/views/widgets/gemini_api_key_dialog.dart';

/// Dialog profil pengguna untuk mengelola autentikasi Google Firebase & Gemini API Key
class UserProfileDialog extends StatefulWidget {
  const UserProfileDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const UserProfileDialog(),
    );
  }

  @override
  State<UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends State<UserProfileDialog> {
  bool _hasGeminiKey = false;

  @override
  void initState() {
    super.initState();
    _checkGeminiKey();
  }

  Future<void> _checkGeminiKey() async {
    final hasKey = await ApiKeyStorageService.hasGeminiApiKey();
    if (mounted) {
      setState(() {
        _hasGeminiKey = hasKey;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.account_circle_rounded,
              color: Color(0xFF60A5FA),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Akun Pengguna',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: authProvider.isLoading
          ? const SizedBox(
              height: 120,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (user == null) ...[
                  const Text(
                    'Masuk dengan Google untuk menghubungkan penyimpanan Google Drive pribadi dan membuka akses fitur AI Assistant.',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.cloud_upload_outlined,
                                size: 16, color: Color(0xFF38BDF8)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Backup ke Google Drive pribadi',
                                style: TextStyle(
                                    color: Color(0xFFE2E8F0), fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                size: 16, color: Color(0xFFA855F7)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Akses AI Chapters & Video Summary',
                                style: TextStyle(
                                    color: Color(0xFFE2E8F0), fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final success = await authProvider.signInWithGoogle();
                        if (context.mounted && !success) {
                          if (authProvider.errorMessage != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(authProvider.errorMessage!),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.login_rounded, size: 20),
                      label: const Text('Masuk dengan Google'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFF2563EB),
                        backgroundImage: user.photoURL != null
                            ? NetworkImage(user.photoURL!)
                            : null,
                        child: user.photoURL == null
                            ? Text(
                                user.displayName?.isNotEmpty == true
                                    ? user.displayName![0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName ?? 'Pengguna Google',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.email ?? '',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF334155)),
                  const SizedBox(height: 8),

                  // Status Gemini API Key
                  InkWell(
                    onTap: () async {
                      await GeminiApiKeyDialog.show(context);
                      _checkGeminiKey();
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _hasGeminiKey
                              ? Colors.greenAccent.withValues(alpha: 0.3)
                              : Colors.amber.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _hasGeminiKey
                                ? Icons.key_rounded
                                : Icons.key_off_rounded,
                            size: 18,
                            color: _hasGeminiKey
                                ? Colors.greenAccent
                                : Colors.amber,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Gemini API Key (BYOK)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _hasGeminiKey
                                      ? 'Tersimpan & Terenkripsi'
                                      : 'Belum diatur (Ketuk untuk atur)',
                                  style: TextStyle(
                                    color: _hasGeminiKey
                                        ? const Color(0xFF4ADE80)
                                        : const Color(0xFFFBBF24),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF94A3B8),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await authProvider.signOut();
                      },
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Keluar dari Akun'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup', style: TextStyle(color: Color(0xFF94A3B8))),
        ),
      ],
    );
  }
}
