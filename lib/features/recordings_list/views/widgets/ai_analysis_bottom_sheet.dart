import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/video_ai_service.dart';
import '../../models/ai_analysis_model.dart';

/// Bottom Sheet untuk AI Video Editor Assistant
/// Memiliki 2 Tab Interaktif:
/// 1. Smart Timeline & Chapters (Ringkasan langkah-langkah & navigasi cepat babak)
/// 2. Command-Based Assistant (Tanya jawab & pencarian timestamp cerdas berbasis teks)
class AiAnalysisBottomSheet extends StatefulWidget {
  final String videoPath;
  final AiAnalysisResult analysis;
  final Function(Duration position) onSeekTo;
  final VoidCallback onReanalyze;

  const AiAnalysisBottomSheet({
    super.key,
    required this.videoPath,
    required this.analysis,
    required this.onSeekTo,
    required this.onReanalyze,
  });

  static void show({
    required BuildContext context,
    required String videoPath,
    required AiAnalysisResult analysis,
    required Function(Duration position) onSeekTo,
    required VoidCallback onReanalyze,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AiAnalysisBottomSheet(
        videoPath: videoPath,
        analysis: analysis,
        onSeekTo: onSeekTo,
        onReanalyze: onReanalyze,
      ),
    );
  }

  @override
  State<AiAnalysisBottomSheet> createState() => _AiAnalysisBottomSheetState();
}

class _AiAnalysisBottomSheetState extends State<AiAnalysisBottomSheet> {
  final TextEditingController _commandController = TextEditingController();
  final List<Map<String, dynamic>> _conversation = [];
  bool _isProcessingCommand = false;

  final List<String> _quickPrompts = [
    'Carikan timestamp saat saya membuka menu pengaturan',
    'Kapan terjadi transisi layar yang paling mencolok?',
    'Kapan rekaman mulai aktif beroperasi?',
    'Apakah ada dialog atau notifikasi penting yang muncul?',
  ];

  @override
  void dispose() {
    _commandController.dispose();
    super.dispose();
  }

  Future<void> _handleSendCommand([String? customPrompt]) async {
    final prompt = (customPrompt ?? _commandController.text).trim();
    if (prompt.isEmpty) return;

    _commandController.clear();
    FocusScope.of(context).unfocus();

    setState(() {
      _conversation.add({
        'isUser': true,
        'text': prompt,
      });
      _isProcessingCommand = true;
    });

    try {
      final response = await VideoAiService.queryCommandAssistant(
        videoPath: widget.videoPath,
        userPrompt: prompt,
        existingChapters: widget.analysis.chapters,
      );

      if (!mounted) return;
      setState(() {
        _isProcessingCommand = false;
        _conversation.add({
          'isUser': false,
          'response': response,
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessingCommand = false;
        _conversation.add({
          'isUser': false,
          'error': e.toString().replaceAll('Exception: ', ''),
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.78,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.borderHighlight,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            // Header bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Video Editor Assistant',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Account-Bound Gemini Intelligence (Multi-Modal)',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 20),
                  tooltip: 'Analisis Ulang Timeline',
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onReanalyze();
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 2 Tabs Navigation
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(
                    icon: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.timeline_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text('Smart Timeline (${widget.analysis.chapters.length})'),
                      ],
                    ),
                  ),
                  const Tab(
                    icon: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Command Assistant'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Tab Views Content
            Expanded(
              child: TabBarView(
                children: [
                  _buildTimelineTab(context),
                  _buildCommandAssistantTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 1: Smart Timeline & Chapters + Ringkasan Langkah-langkah
  Widget _buildTimelineTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        // Ringkasan Kronologis Langkah-Langkah
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.notes_rounded, color: AppColors.accent, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Ringkasan Kronologis Langkah',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: AppColors.textSecondary, size: 16),
                    tooltip: 'Salin Ringkasan',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.analysis.summary));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ringkasan berhasil disalin!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                widget.analysis.summary,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Section Title
        const Text(
          'BABAK & TRANSISI LAYAR (SMART CHAPTERS)',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),

        if (widget.analysis.chapters.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                'Tidak ada chapter yang terdeteksi dalam rekaman ini.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          )
        else
          ...widget.analysis.chapters.map((chapter) {
            return Card(
              color: AppColors.cardBg,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  widget.onSeekTo(Duration(seconds: chapter.seconds));
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          chapter.timestamp,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chapter.title,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (chapter.description != null && chapter.description!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                chapter.description!,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(Icons.play_circle_outline_rounded,
                          color: AppColors.textSecondary, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  // TAB 2: Command-Based Assistant (Tanya AI & Navigasi Detik Otomatis)
  Widget _buildCommandAssistantTab(BuildContext context) {
    return Column(
      children: [
        // Quick Prompts Horizontal Scroll
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _quickPrompts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final prompt = _quickPrompts[index];
              return ActionChip(
                backgroundColor: AppColors.cardBg,
                side: const BorderSide(color: AppColors.border),
                label: Text(
                  prompt,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
                onPressed: _isProcessingCommand ? null : () => _handleSendCommand(prompt),
              );
            },
          ),
        ),

        const SizedBox(height: 10),

        // Conversation Messages
        Expanded(
          child: _conversation.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.psychology_alt_rounded,
                          size: 48,
                          color: AppColors.accent.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Tanyakan Apapun Tentang Video Ini',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Contoh: "Carikan timestamp saat saya membuka browser", atau "Di detik berapa tombol simpan ditekan?"',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _conversation.length,
                  itemBuilder: (context, index) {
                    final item = _conversation[index];
                    final isUser = item['isUser'] == true;

                    if (isUser) {
                      return Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10, left: 40),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            item['text'] as String,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      );
                    }

                    // Bot Response
                    if (item.containsKey('error')) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10, right: 40),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.stop.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.stop.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            item['error'] as String,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      );
                    }

                    final AiCommandResponse res = item['response'] as AiCommandResponse;
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12, right: 30),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.auto_awesome_rounded,
                                    size: 14, color: AppColors.accent),
                                const SizedBox(width: 6),
                                const Text(
                                  'Gemini AI Assistant',
                                  style: TextStyle(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                                const Spacer(),
                                if (res.targetTimestamp != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF38BDF8)),
                                    ),
                                    child: Text(
                                      res.targetTimestamp!,
                                      style: const TextStyle(
                                        color: Color(0xFF38BDF8),
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              res.answer,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            if (res.targetSeconds != null) ...[
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () {
                                  widget.onSeekTo(Duration(seconds: res.targetSeconds!));
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.play_circle_fill_rounded, size: 16),
                                label: Text('Lompat ke Detik ${res.targetTimestamp ?? "${res.targetSeconds}s"}'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        if (_isProcessingCommand)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                ),
                SizedBox(width: 10),
                Text(
                  'Gemini sedang menganalisis video untuk menjawab...',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),

        // Text input field bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commandController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _isProcessingCommand ? null : (_) => _handleSendCommand(),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Ketik perintah atau pertanyaan analisis...',
                    hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: AppColors.accent, size: 20),
                tooltip: 'Kirim Perintah',
                onPressed: _isProcessingCommand ? null : () => _handleSendCommand(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
