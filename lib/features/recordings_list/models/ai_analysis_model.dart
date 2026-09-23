class VideoChapter {
  final String timestamp; // Contoh: "00:12"
  final int seconds;       // Contoh: 12
  final String title;      // Contoh: "Membuka Menu Pengaturan"
  final String? description;

  const VideoChapter({
    required this.timestamp,
    required this.seconds,
    required this.title,
    this.description,
  });

  factory VideoChapter.fromJson(Map<String, dynamic> json) {
    int parsedSeconds = 0;
    final secRaw = json['seconds'];
    if (secRaw is int) {
      parsedSeconds = secRaw;
    } else if (secRaw is num) {
      parsedSeconds = secRaw.toInt();
    } else if (json['timestamp'] is String) {
      // Parse mm:ss atau hh:mm:ss
      final parts = (json['timestamp'] as String).split(':');
      if (parts.length == 2) {
        final m = int.tryParse(parts[0]) ?? 0;
        final s = int.tryParse(parts[1]) ?? 0;
        parsedSeconds = (m * 60) + s;
      } else if (parts.length == 3) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final s = int.tryParse(parts[2]) ?? 0;
        parsedSeconds = (h * 3600) + (m * 60) + s;
      }
    }

    return VideoChapter(
      timestamp: json['timestamp']?.toString() ?? '00:00',
      seconds: parsedSeconds,
      title: json['title']?.toString() ?? 'Chapter',
      description: json['description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'seconds': seconds,
        'title': title,
        'description': description,
      };
}

class AiAnalysisResult {
  final String summary;
  final List<VideoChapter> chapters;
  final DateTime analyzedAt;

  const AiAnalysisResult({
    required this.summary,
    required this.chapters,
    required this.analyzedAt,
  });

  factory AiAnalysisResult.fromJson(Map<String, dynamic> json) {
    final list = json['chapters'] as List<dynamic>? ?? [];
    final chapters = list
        .map((e) => VideoChapter.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return AiAnalysisResult(
      summary: json['summary']?.toString() ?? 'Ringkasan rekaman layar tidak tersedia.',
      chapters: chapters,
      analyzedAt: DateTime.now(),
    );
  }
}

/// Model untuk respon dari Command-Based Assistant Gemini
class AiCommandResponse {
  final String answer;
  final String? targetTimestamp; // Format mm:ss atau null jika bersifat umum
  final int? targetSeconds;       // Nilai detik untuk langsung seek video
  final String? actionSuggestion; // Saran aksi (misal: "Lompat ke detik 00:15", "Potong video")
  final DateTime timestamp;

  const AiCommandResponse({
    required this.answer,
    this.targetTimestamp,
    this.targetSeconds,
    this.actionSuggestion,
    required this.timestamp,
  });

  factory AiCommandResponse.fromJson(Map<String, dynamic> json) {
    int? parsedSeconds;
    final secRaw = json['targetSeconds'];
    if (secRaw is int) {
      parsedSeconds = secRaw;
    } else if (secRaw is num) {
      parsedSeconds = secRaw.toInt();
    } else if (json['targetTimestamp'] is String) {
      final parts = (json['targetTimestamp'] as String).split(':');
      if (parts.length == 2) {
        final m = int.tryParse(parts[0]) ?? 0;
        final s = int.tryParse(parts[1]) ?? 0;
        parsedSeconds = (m * 60) + s;
      }
    }

    return AiCommandResponse(
      answer: json['answer']?.toString() ?? 'Analisis perintah selesai.',
      targetTimestamp: json['targetTimestamp']?.toString(),
      targetSeconds: parsedSeconds,
      actionSuggestion: json['actionSuggestion']?.toString(),
      timestamp: DateTime.now(),
    );
  }
}

