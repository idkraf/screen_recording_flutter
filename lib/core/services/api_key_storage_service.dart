import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service untuk menyimpan dan mengelola BYOK Gemini API Key secara aman di Android Keystore
/// Mendukung isolasi multi-user berdasarkan UID Firebase Auth pengguna.
class ApiKeyStorageService {
  static const _storage = FlutterSecureStorage();

  static const String _legacyGeminiApiKeyKey = 'gemini_api_key';

  /// Mendapatkan nama kunci secure storage spesifik per-user
  static String _getKeyForUser([String? userId]) {
    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      return 'gemini_api_key_$uid';
    }
    return _legacyGeminiApiKeyKey;
  }

  /// Mengambil Gemini API Key yang tersimpan untuk user yang sedang aktif atau UID tertentu
  static Future<String?> getGeminiApiKey([String? userId]) async {
    try {
      final keyName = _getKeyForUser(userId);
      final key = await _storage.read(key: keyName);
      if (key != null && key.trim().isNotEmpty) {
        return key.trim();
      }

      // Migrasi aman: jika belum tersimpan per-user, periksa legacy key
      if (keyName != _legacyGeminiApiKeyKey) {
        final legacyKey = await _storage.read(key: _legacyGeminiApiKeyKey);
        if (legacyKey != null && legacyKey.trim().isNotEmpty) {
          // Salin ke slot user spesifik
          await _storage.write(key: keyName, value: legacyKey.trim());
          return legacyKey.trim();
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error reading Gemini API Key: $e');
      return null;
    }
  }

  /// Menyimpan Gemini API Key ke Android Keystore untuk user yang sedang aktif atau UID tertentu
  static Future<bool> saveGeminiApiKey(String apiKey, [String? userId]) async {
    try {
      final keyName = _getKeyForUser(userId);
      await _storage.write(key: keyName, value: apiKey.trim());
      return true;
    } catch (e) {
      debugPrint('Error saving Gemini API Key: $e');
      return false;
    }
  }

  /// Menghapus Gemini API Key yang tersimpan untuk user yang sedang aktif atau UID tertentu
  static Future<bool> deleteGeminiApiKey([String? userId]) async {
    try {
      final keyName = _getKeyForUser(userId);
      await _storage.delete(key: keyName);
      return true;
    } catch (e) {
      debugPrint('Error deleting Gemini API Key: $e');
      return false;
    }
  }

  /// Mengecek apakah pengguna aktif telah menyimpan Gemini API Key
  static Future<bool> hasGeminiApiKey([String? userId]) async {
    final key = await getGeminiApiKey(userId);
    return key != null && key.isNotEmpty;
  }
}
