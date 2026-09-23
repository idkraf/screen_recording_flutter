import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../features/recordings_list/models/ai_analysis_model.dart';
import 'api_key_storage_service.dart';

class ApiKeyNotSetException implements Exception {
  final String message;
  const ApiKeyNotSetException([this.message = 'Gemini API Key belum diatur.']);
  @override
  String toString() => message;
}

class VideoTooLargeException implements Exception {
  final String message;
  const VideoTooLargeException([this.message = 'Ukuran video terlalu besar untuk diproses langsung (maksimal 20 MB).']);
  @override
  String toString() => message;
}

class AIService {
  /// Menguji apakah Gemini API Key valid dan aktif
  static Future<bool> testApiKey(String apiKey) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey.trim(),
      );
      final response = await model.generateContent([
        Content.text('Balas satu kata: OK'),
      ]);
      return response.text != null && response.text!.isNotEmpty;
    } catch (e) {
      debugPrint('Error testing Gemini API Key: $e');
      return false;
    }
  }

  /// Menganalisis video rekaman layar menggunakan model multimodal Gemini 1.5 Flash
  /// Mengembalikan Smart Chapters dan Ringkasan Langkah-langkah
  static Future<AiAnalysisResult> analyzeVideo({
    required String videoPath,
  }) async {
    final apiKey = await ApiKeyStorageService.getGeminiApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const ApiKeyNotSetException();
    }

    final videoFile = File(videoPath);
    if (!await videoFile.exists()) {
      throw Exception('File video tidak ditemukan di penyimpanan lokal.');
    }

    final fileSize = await videoFile.length();
    // Batas aman inline payload Gemini (20 MB)
    if (fileSize > 20 * 1024 * 1024) {
      throw const VideoTooLargeException();
    }

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
Anda adalah AI Intelligence Assistant untuk aplikasi perekam layar Android "REKAM".
Analisis video rekaman layar ini secara menyeluruh (visual antarmuka dan konteks aktivitas yang terjadi).

Kembalikan hasil analisis dalam format JSON murni dengan skema berikut:
{
  "summary": "Ringkasan ringkas dalam bahasa Indonesia dalam bentuk poin-poin mengenai apa yang terjadi dan langkah-langkah yang dilakukan pengguna selama rekaman layar.",
  "chapters": [
    {
      "timestamp": "00:00",
      "seconds": 0,
      "title": "Judul Aktivitas Singkat",
      "description": "Penjelasan singkat aktivitas di frame/layar tersebut"
    }
  ]
}

Aturan penting:
1. "timestamp" harus berformat mm:ss (contoh: "00:04", "01:20").
2. "seconds" adalah posisi waktu dalam detik (integer).
3. Buatlah minimal 2 hingga 6 chapters berdasarkan perubahan layar / transisi menu yang signifikan di dalam video.
4. "summary" harus informatif, terstruktur dengan poin-poin jelas menggunakan tanda bullet (•).
5. Bahasa output harus Bahasa Indonesia yang ramah dan profesional.
''';

    final prompt = TextPart(promptText);
    final videoPart = DataPart('video/mp4', videoBytes);

    try {
      final response = await model.generateContent([
        Content.multi([prompt, videoPart]),
      ]);

      final rawText = response.text;
      if (rawText == null || rawText.isEmpty) {
        throw Exception('Gemini tidak memberikan respon analisis.');
      }

      // Bersihkan codeblock markdown jika ada
      String cleanedJson = rawText.trim();
      if (cleanedJson.startsWith('```json')) {
        cleanedJson = cleanedJson.substring(7);
      } else if (cleanedJson.startsWith('```')) {
        cleanedJson = cleanedJson.substring(3);
      }
      if (cleanedJson.endsWith('```')) {
        cleanedJson = cleanedJson.substring(0, cleanedJson.length - 3);
      }
      cleanedJson = cleanedJson.trim();

      final decoded = jsonDecode(cleanedJson) as Map<String, dynamic>;
      return AiAnalysisResult.fromJson(decoded);
    } on GenerativeAIException catch (e) {
      debugPrint('GenerativeAIException: ${e.message}');
      if (e.message.contains('API_KEY_INVALID') || e.message.contains('API key not valid')) {
        throw Exception('API Key Gemini tidak valid atau tidak memiliki izin akses.');
      } else if (e.message.contains('RESOURCE_EXHAUSTED') || e.message.contains('quota')) {
        throw Exception('Kuota penggunaan API Key Gemini Anda telah habis.');
      }
      throw Exception('Gagal memproses AI: ${e.message}');
    } catch (e) {
      debugPrint('Error analyzing video with AI: $e');
      if (e is ApiKeyNotSetException || e is VideoTooLargeException) {
        rethrow;
      }
      throw Exception('Terjadi kendala saat menganalisis rekaman: $e');
    }
  }
}
