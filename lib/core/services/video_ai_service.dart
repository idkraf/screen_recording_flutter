import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../features/recordings_list/models/ai_analysis_model.dart';
import 'ai_service.dart';
import 'analytics_service.dart';
import 'api_key_storage_service.dart';
import 'crashlytics_service.dart';

/// Exception yang dilempar saat sesi user tidak aktif (Account-Bound Security Guard)
class UnauthenticatedException implements Exception {
  final String message;
  const UnauthenticatedException([
    this.message = 'Sesi akun Google tidak aktif. Anda wajib login via Firebase Auth untuk mengakses fitur AI.',
  ]);
  @override
  String toString() => message;
}

/// Service khusus untuk AI Video Editor Assistant Gemini
/// Terikat secara mutlak dengan sesi akun Google Firebase dan isolasi API Key per-user.
class VideoAiService {
  /// Memvalidasi status sesi akun Google yang aktif dan mengembalikan user aktif
  static User _requireAuthenticatedUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const UnauthenticatedException();
    }
    return user;
  }

  /// Mengambil Gemini API Key yang terisolasi spesifik untuk user yang sedang login
  static Future<String> _getAccountBoundApiKey(User user) async {
    final apiKey = await ApiKeyStorageService.getGeminiApiKey(user.uid);
    if (apiKey == null || apiKey.isEmpty) {
      throw const ApiKeyNotSetException(
        'Gemini API Key pribadi belum dikonfigurasi untuk akun ini. Silakan buka Halaman Profil untuk menambahkan key.',
      );
    }
    return apiKey;
  }

  /// 1. Smart Timeline Summarizer: Menganalisis video rekaman layar untuk menghasilkan
  /// ringkasan langkah-langkah dalam poin-poin dan chapters timeline otomatis.
  static Future<AiAnalysisResult> generateTimelineSummary({
    required String videoPath,
  }) async {
    // Validasi Sesi Pengguna Aktif
    final user = _requireAuthenticatedUser();
    final apiKey = await _getAccountBoundApiKey(user);

    final videoFile = File(videoPath);
    if (!await videoFile.exists()) {
      throw Exception('Berkas video tidak ditemukan di penyimpanan lokal.');
    }

    final fileSize = await videoFile.length();
    if (fileSize > 20 * 1024 * 1024) {
      throw const VideoTooLargeException(
        'Ukuran video melebihi 20 MB untuk pemrosesan langsung multimodal.',
      );
    }

    AnalyticsService.instance.logAiAnalysisRequested(
      analysisType: 'timeline_summary',
    );

    final videoBytes = await videoFile.readAsBytes();

    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.2,
      ),
    );

    const promptText = '''
Anda adalah AI Video Editor Assistant untuk aplikasi perekam layar Android "REKAM" milik pengguna terautentikasi.
Analisis rekaman layar ini secara menyeluruh untuk membantu proses peninjauan dan penyuntingan video.

Kembalikan hasil analisis dalam format JSON murni dengan skema:
{
  "summary": "Ringkasan kronologis dalam Bahasa Indonesia menggunakan poin-poin (•) mengenai apa saja aktivitas dan langkah-langkah yang dilakukan di layar.",
  "chapters": [
    {
      "timestamp": "00:00",
      "seconds": 0,
      "title": "Judul Aktivitas Singkat",
      "description": "Deskripsi singkat mengenai apa yang terjadi di titik waktu ini"
    }
  ]
}

Aturan penting:
1. "timestamp" harus berformat mm:ss (contoh: "00:05", "01:12").
2. "seconds" adalah posisi waktu dalam detik (integer).
3. Buatlah minimal 2 hingga 6 chapters berdasarkan transisi visual / perpindahan menu yang jelas.
4. "summary" harus tersusun rapi dengan poin-poin bertanda bullet (•).
''';

    try {
      final response = await model.generateContent([
        Content.multi([
          TextPart(promptText),
          DataPart('video/mp4', videoBytes),
        ]),
      ]);

      final rawText = response.text;
      if (rawText == null || rawText.isEmpty) {
        throw Exception('Gemini tidak memberikan respon analisis timeline.');
      }

      String cleanedJson = rawText.trim();
      if (cleanedJson.startsWith('```json')) {
        cleanedJson = cleanedJson.substring(7);
      } else if (cleanedJson.startsWith('```')) {
        cleanedJson = cleanedJson.substring(3);
      }
      if (cleanedJson.endsWith('```')) {
        cleanedJson = cleanedJson.substring(0, cleanedJson.length - 3);
      }

      final decoded = jsonDecode(cleanedJson.trim()) as Map<String, dynamic>;
      return AiAnalysisResult.fromJson(decoded);
    } on GenerativeAIException catch (e, stack) {
      debugPrint('GenerativeAIException (Timeline): ${e.message}');
      CrashlyticsService.instance.recordError(e, stack, reason: 'Gemini Timeline Analysis GenerativeAIException');
      if (e.message.contains('API_KEY_INVALID') || e.message.contains('API key not valid')) {
        throw Exception('API Key Gemini tidak valid. Harap perbarui di Halaman Profil.');
      } else if (e.message.contains('RESOURCE_EXHAUSTED') || e.message.contains('quota')) {
        throw Exception('Kuota Gemini API Key Anda telah habis.');
      }
      throw Exception('Gagal memproses analisis timeline: ${e.message}');
    } catch (e, stack) {
      debugPrint('Error generateTimelineSummary: $e');
      if (e is! UnauthenticatedException &&
          e is! ApiKeyNotSetException &&
          e is! VideoTooLargeException) {
        CrashlyticsService.instance.recordError(e, stack, reason: 'generateTimelineSummary failure');
      }
      if (e is UnauthenticatedException ||
          e is ApiKeyNotSetException ||
          e is VideoTooLargeException) {
        rethrow;
      }
      throw Exception('Terjadi kendala saat menganalisis timeline video: $e');
    }
  }

  /// 2. Command-Based Assistant: Menerima prompt teks dari user (misal: "Carikan timestamp saat saya membuka pengaturan"),
  /// lalu Gemini mengembalikan analisis berbasis waktu beserta detik navigasi otomatis.
  static Future<AiCommandResponse> queryCommandAssistant({
    required String videoPath,
    required String userPrompt,
    List<VideoChapter>? existingChapters,
  }) async {
    // Validasi Sesi Pengguna Aktif
    final user = _requireAuthenticatedUser();
    final apiKey = await _getAccountBoundApiKey(user);

    final videoFile = File(videoPath);
    if (!await videoFile.exists()) {
      throw Exception('Berkas video tidak ditemukan di penyimpanan lokal.');
    }

    final fileSize = await videoFile.length();
    AnalyticsService.instance.logAiCommandExecuted(
      commandLength: userPrompt.length,
    );

    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.3,
      ),
    );

    // Siapkan konteks chapter yang sudah ada jika tersedia
    String contextChapters = '';
    if (existingChapters != null && existingChapters.isNotEmpty) {
      final chaptersList = existingChapters
          .map((c) => '- [${c.timestamp}] ${c.title}: ${c.description ?? ""}')
          .join('\n');
      contextChapters = 'Daftar babak/transisi yang sudah terdeteksi sebelumnya:\n$chaptersList';
    }

    final systemInstruction = '''
Anda adalah AI Video Editor Assistant cerdas di aplikasi "REKAM".
Pengguna mengajukan pertanyaan atau perintah terkait video rekaman layar mereka.
Pertanyaan pengguna: "$userPrompt"

$contextChapters

Tugas Anda:
1. Temukan jawaban paling tepat dan spesifik atas pertanyaan/perintah pengguna.
2. Jika pengguna meminta timestamp / lokasi kejadian (misal: kapan menu dibuka, kapan error terjadi), tentukan estimasi detik yang paling tepat.
3. Berikan saran aksi penyuntingan video yang relevan (misal: "Lompat ke detik 00:15", "Gunakan fitur potong frame dari 00:10 ke 00:25").

Kembalikan jawaban DALAM FORMAT JSON MURNI:
{
  "answer": "Jawaban penjelasan Anda dalam Bahasa Indonesia yang ramah dan langsung ke inti.",
  "targetTimestamp": "mm:ss atau null jika pertanyaan bersifat umum",
  "targetSeconds": 15,
  "actionSuggestion": "Saran aksi singkat, misal: 'Lompat ke detik 00:15' atau null"
}
''';

    try {
      List<Part> parts = [TextPart(systemInstruction)];

      // Jika ukuran video <= 20 MB, sertakan byte video aktual untuk analisis visual
      if (fileSize <= 20 * 1024 * 1024) {
        final videoBytes = await videoFile.readAsBytes();
        parts.add(DataPart('video/mp4', videoBytes));
      }

      final response = await model.generateContent([Content.multi(parts)]);
      final rawText = response.text;
      if (rawText == null || rawText.isEmpty) {
        throw Exception('Gemini tidak memberikan jawaban atas perintah Anda.');
      }

      String cleanedJson = rawText.trim();
      if (cleanedJson.startsWith('```json')) {
        cleanedJson = cleanedJson.substring(7);
      } else if (cleanedJson.startsWith('```')) {
        cleanedJson = cleanedJson.substring(3);
      }
      if (cleanedJson.endsWith('```')) {
        cleanedJson = cleanedJson.substring(0, cleanedJson.length - 3);
      }

      final decoded = jsonDecode(cleanedJson.trim()) as Map<String, dynamic>;
      return AiCommandResponse.fromJson(decoded);
    } on GenerativeAIException catch (e, stack) {
      debugPrint('GenerativeAIException (Command): ${e.message}');
      CrashlyticsService.instance.recordError(e, stack, reason: 'Gemini Command Assistant GenerativeAIException');
      if (e.message.contains('API_KEY_INVALID') || e.message.contains('API key not valid')) {
        throw Exception('API Key Gemini tidak valid. Harap perbarui di Halaman Profil.');
      } else if (e.message.contains('RESOURCE_EXHAUSTED') || e.message.contains('quota')) {
        throw Exception('Kuota Gemini API Key Anda telah habis.');
      }
      throw Exception('Gagal mengeksekusi perintah AI: ${e.message}');
    } catch (e, stack) {
      debugPrint('Error queryCommandAssistant: $e');
      if (e is! UnauthenticatedException && e is! ApiKeyNotSetException) {
        CrashlyticsService.instance.recordError(e, stack, reason: 'queryCommandAssistant failure');
      }
      if (e is UnauthenticatedException || e is ApiKeyNotSetException) {
        rethrow;
      }
      throw Exception('Terjadi kendala saat memproses perintah AI: $e');
    }
  }
}
