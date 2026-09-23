import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/api_key_storage_service.dart';
import '../../recordings_list/views/widgets/gemini_api_key_dialog.dart';

/// Halaman Profil Eksklusif Pengguna (Hanya dapat diakses jika telah login Google via Firebase Auth)
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _hasGeminiKey = false;
  String? _maskedKey;
  bool _isLoadingKey = true;
  bool _isTestingKey = false;
  String? _testResult;
  bool _isTestSuccess = false;

  @override
  void initState() {
    super.initState();
    _refreshKeyStatus();
  }

  Future<void> _refreshKeyStatus() async {
    setState(() => _isLoadingKey = true);
    final key = await ApiKeyStorageService.getGeminiApiKey();
    if (!mounted) return;

    setState(() {
      _hasGeminiKey = key != null && key.isNotEmpty;
      if (_hasGeminiKey) {
        if (key!.length > 8) {
          _maskedKey = '${key.substring(0, 6)}••••••••${key.substring(key.length - 3)}';
        } else {
          _maskedKey = '••••••••';
        }
      } else {
        _maskedKey = null;
      }
      _isLoadingKey = false;
    });
  }

  Future<void> _openApiKeySetup() async {
    final changed = await GeminiApiKeyDialog.show(context);
    if (changed == true && mounted) {
      _refreshKeyStatus();
      setState(() => _testResult = null);
    }
  }

  Future<void> _testApiKey() async {
    final key = await ApiKeyStorageService.getGeminiApiKey();
    if (!mounted) return;
    if (key == null || key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum ada Gemini API Key yang tersimpan.'),
          backgroundColor: AppColors.stop,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isTestingKey = true;
      _testResult = null;
    });

    final success = await AIService.testApiKey(key);
    if (!mounted) return;

    setState(() {
      _isTestingKey = false;
      _isTestSuccess = success;
      _testResult = success
          ? 'Koneksi ke Gemini AI berhasil! Model responsif dan siap digunakan.'
          : 'Gagal terhubung ke Gemini AI. Harap periksa kembali validitas API Key Anda.';
    });
  }

  Future<void> _confirmDeleteKey() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber),
            SizedBox(width: 10),
            Text(
              'Hapus API Key?',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Gemini API Key Anda akan dihapus secara permanen dari Android Keystore perangkat ini. Fitur AI Assistant akan otomatis terkunci.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.stop,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus Key'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ApiKeyStorageService.deleteGeminiApiKey();
      _refreshKeyStatus();
      setState(() => _testResult = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gemini API Key telah dihapus dari Android Keystore.'),
            backgroundColor: AppColors.stop,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleSignOut(AuthProvider auth) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.stop),
            SizedBox(width: 10),
            Text(
              'Keluar Akun',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun Google? Halaman profil dan akses fitur AI akan dikunci hingga Anda login kembali.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.stop,
              foregroundColor: Colors.white,
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await auth.signOut();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    // Strict Auth Guard: Jika tidak login, tampilkan fallback guard proteksi
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Profil Pengguna'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Colors.amber,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Akses Halaman Terkunci',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Halaman profil hanya dapat diakses oleh pengguna yang telah login menggunakan akun Google via Firebase Authentication.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    final success = await auth.signInWithGoogle();
                    if (success && mounted) {
                      _refreshKeyStatus();
                    }
                  },
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Login dengan Google'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isAiFullyUnlocked = _hasGeminiKey;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Profil & AI Settings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
            tooltip: 'Keluar Akun',
            onPressed: () => _handleSignOut(auth),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. User Profile Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF334155)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: const Color(0xFF205080),
                        backgroundImage: user.photoURL != null
                            ? NetworkImage(user.photoURL!)
                            : null,
                        child: user.photoURL == null
                            ? Text(
                                user.displayName?.isNotEmpty == true
                                    ? user.displayName![0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0F172A),
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName ?? 'Pengguna REKAM',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email ?? '-',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                color: Color(0xFF4ADE80),
                                size: 14,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Google Verified (Firebase)',
                                style: TextStyle(
                                  color: Color(0xFF4ADE80),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
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
            ),

            const SizedBox(height: 24),

            // 2. Strict AI Access Guard Status Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isAiFullyUnlocked
                    ? const Color(0xFF064E3B).withValues(alpha: 0.35)
                    : const Color(0xFF78350F).withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isAiFullyUnlocked
                      ? const Color(0xFF059669)
                      : const Color(0xFFD97706),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isAiFullyUnlocked
                            ? Icons.auto_awesome_rounded
                            : Icons.lock_outline_rounded,
                        color: isAiFullyUnlocked
                            ? Colors.greenAccent
                            : Colors.amber,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isAiFullyUnlocked
                            ? 'AI Assistant Siap Digunakan'
                            : 'AI Assistant Masih Terkunci',
                        style: TextStyle(
                          color: isAiFullyUnlocked
                              ? Colors.greenAccent
                              : Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isAiFullyUnlocked
                        ? 'Semua syarat ketat telah terpenuhi. Fitur Smart Video Chaptering dan Summarizer aktif di Pemutar Video.'
                        : 'Untuk mengaktifkan AI Assistant, Anda wajib melengkapi kedua syarat ketat di bawah ini:',
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Check 1: Google Sign-in
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.greenAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '1. Login Google Terautentikasi (${user.email})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Check 2: Gemini API Key
                  Row(
                    children: [
                      Icon(
                        _hasGeminiKey
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: _hasGeminiKey
                            ? Colors.greenAccent
                            : const Color(0xFFF87171),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _hasGeminiKey
                              ? '2. BYOK Gemini API Key Terdaftar di Keystore'
                              : '2. BYOK Gemini API Key Belum Dikonfigurasi',
                          style: TextStyle(
                            color: _hasGeminiKey
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: _hasGeminiKey
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. Menu Setup Gemini API Key (BYOK)
            const Text(
              'PENGATURAN INTELLIGENCE LAYER',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.key_rounded,
                            color: Color(0xFF38BDF8),
                            size: 22,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Gemini API Key (BYOK)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (_isLoadingKey)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        )
                      else if (_hasGeminiKey)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Text(
                            'Tersimpan',
                            style: TextStyle(
                              color: Color(0xFF4ADE80),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Text(
                            'Belum Ada',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _hasGeminiKey
                        ? 'Key Anda tersimpan aman dan terenkripsi menggunakan Android Keystore (flutter_secure_storage).'
                        : 'Aplikasi REKAM menganut arsitektur BYOK (Bring Your Own Key). Masukkan API Key pribadi Anda dari Google AI Studio untuk mengaktifkan analisis video cerdas.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  if (_maskedKey != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline, color: Color(0xFF64748B), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _maskedKey!,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_testResult != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isTestSuccess
                            ? const Color(0xFF064E3B).withValues(alpha: 0.5)
                            : const Color(0xFF7F1D1D).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isTestSuccess
                              ? const Color(0xFF059669)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isTestSuccess
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                            color: _isTestSuccess
                                ? Colors.greenAccent
                                : const Color(0xFFF87171),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _testResult!,
                              style: TextStyle(
                                color: _isTestSuccess
                                    ? Colors.greenAccent
                                    : const Color(0xFFFCA5A5),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Actions row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _openApiKeySetup,
                        icon: Icon(
                          _hasGeminiKey ? Icons.edit_rounded : Icons.add_rounded,
                          size: 16,
                        ),
                        label: Text(_hasGeminiKey ? 'Ubah API Key' : 'Setup API Key'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      if (_hasGeminiKey) ...[
                        OutlinedButton.icon(
                          onPressed: _isTestingKey ? null : _testApiKey,
                          icon: _isTestingKey
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.flash_on_rounded, size: 16),
                          label: Text(_isTestingKey ? 'Menguji...' : 'Uji Koneksi'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF38BDF8),
                            side: const BorderSide(color: Color(0xFF0284C7)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _confirmDeleteKey,
                          icon: const Icon(Icons.delete_outline_rounded, size: 16),
                          label: const Text('Hapus'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFF7F1D1D)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 4. Google Drive Storage Policy Card
            const Text(
              'PENYIMPANAN PRIBADI (PERSONAL STORAGE)',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.cloud_done_rounded,
                        color: Color(0xFF60A5FA),
                        size: 22,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Google Drive Personal',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Video hasil rekaman yang Anda backup akan disimpan langsung ke Google Drive pribadi Anda melalui scope resmi "drive.file". Aplikasi ini tidak menggunakan Service Account developer terpusat, menjaga 100% privasi dan kepemilikan data Anda.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
