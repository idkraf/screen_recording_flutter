import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/ai_service.dart';
import '../../../../core/services/api_key_storage_service.dart';

class GeminiApiKeyDialog extends StatefulWidget {
  const GeminiApiKeyDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => const GeminiApiKeyDialog(),
    );
  }

  @override
  State<GeminiApiKeyDialog> createState() => _GeminiApiKeyDialogState();
}

class _GeminiApiKeyDialogState extends State<GeminiApiKeyDialog> {
  final TextEditingController _keyController = TextEditingController();
  bool _obscureText = true;
  bool _isLoading = true;
  bool _isTesting = false;
  String? _statusMessage;
  bool _isSuccessStatus = false;

  @override
  void initState() {
    super.initState();
    _loadExistingKey();
  }

  Future<void> _loadExistingKey() async {
    final existingKey = await ApiKeyStorageService.getGeminiApiKey();
    if (mounted) {
      setState(() {
        if (existingKey != null) {
          _keyController.text = existingKey;
        }
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _testAndSaveKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _statusMessage = 'API Key tidak boleh kosong.';
        _isSuccessStatus = false;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _statusMessage = 'Memvalidasi API Key ke server Gemini...';
      _isSuccessStatus = false;
    });

    final isValid = await AIService.testApiKey(key);

    if (!mounted) return;

    if (isValid) {
      await ApiKeyStorageService.saveGeminiApiKey(key);
      setState(() {
        _isTesting = false;
        _isSuccessStatus = true;
        _statusMessage = 'API Key valid & berhasil disimpan dengan aman!';
      });

      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        Navigator.pop(context, true);
      }
    } else {
      setState(() {
        _isTesting = false;
        _isSuccessStatus = false;
        _statusMessage = 'API Key tidak valid atau tidak memiliki akses.';
      });
    }
  }

  Future<void> _deleteKey() async {
    await ApiKeyStorageService.deleteGeminiApiKey();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gemini API Key telah dihapus.'),
          backgroundColor: AppColors.resume,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 24),
          SizedBox(width: 10),
          Text(
            'Pengaturan Gemini Key',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: _isLoading
          ? const SizedBox(
              height: 120,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                ),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aplikasi menggunakan prinsip BYOK (Bring Your Own Key). API Key Anda disimpan terenkripsi di Android Keystore pribadi Anda.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _keyController,
                    obscureText: _obscureText,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Gemini API Key',
                      labelStyle: const TextStyle(color: AppColors.textMuted),
                      hintText: 'AIzaSy...',
                      hintStyle: const TextStyle(color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.key_rounded, color: AppColors.accent),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureText
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Dapatkan key gratis di Google AI Studio (aistudio.google.com).',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isTesting)
                          const Padding(
                            padding: EdgeInsets.only(right: 8, top: 2),
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(AppColors.accent),
                              ),
                            ),
                          )
                        else
                          Icon(
                            _isSuccessStatus
                                ? Icons.check_circle_rounded
                                : Icons.error_outline_rounded,
                            size: 16,
                            color: _isSuccessStatus
                                ? AppColors.resume
                                : AppColors.stop,
                          ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _statusMessage!,
                            style: TextStyle(
                              color: _isSuccessStatus
                                  ? AppColors.resume
                                  : AppColors.stop,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
      actions: [
        if (_keyController.text.isNotEmpty && !_isTesting)
          TextButton(
            onPressed: _deleteKey,
            child: const Text('Hapus Key', style: TextStyle(color: AppColors.stop)),
          ),
        TextButton(
          onPressed: _isTesting ? null : () => Navigator.pop(context),
          child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _isTesting ? null : _testAndSaveKey,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isTesting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Uji & Simpan'),
        ),
      ],
    );
  }
}
