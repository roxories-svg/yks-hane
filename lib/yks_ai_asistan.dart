import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';

import 'gemini_service.dart';

class YksAiAsistanSayfasi extends StatefulWidget {
  final bool isDarkMode;

  const YksAiAsistanSayfasi({super.key, required this.isDarkMode});

  @override
  State<YksAiAsistanSayfasi> createState() => _YksAiAsistanSayfasiState();
}

class _YksAiAsistanSayfasiState extends State<YksAiAsistanSayfasi> {
  final TextEditingController _message = TextEditingController();
  final GeminiYksService _service = GeminiYksService();
  final ImagePicker _picker = ImagePicker();
  final List<_AiChatMessage> _messages = [];
  XFile? _selectedImage;
  bool _loading = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (image != null && mounted) {
      setState(() => _selectedImage = image);
    }
  }

  Future<void> _send() async {
    final prompt = _message.text.trim();
    if (prompt.isEmpty && _selectedImage == null) return;
    if (_loading) return;

    final userPrompt = prompt.isEmpty
        ? 'Bu soruyu/YKS gorselini inceleyip tum adimlariyla cozer misin?'
        : prompt;

    if (_selectedImage == null && GeminiYksService.isCasualChat(prompt)) {
      setState(() {
        _messages.add(_AiChatMessage.user(userPrompt, hasImage: false));
        _messages.add(_AiChatMessage.assistant(
          GeminiYksService.casualChatResponse(prompt),
        ));
        _message.clear();
        _selectedImage = null;
      });
      return;
    }

    Uint8List? imageBytes;
    String mimeType = 'image/jpeg';

    try {
      if (_selectedImage != null) {
        imageBytes = await _selectedImage!.readAsBytes();
        final lowerPath = _selectedImage!.path.toLowerCase();
        final lowerName = _selectedImage!.name.toLowerCase();
        if (lowerName.endsWith('.png') || lowerPath.endsWith('.png')) {
          mimeType = 'image/png';
        } else if (lowerName.endsWith('.webp') || lowerPath.endsWith('.webp')) {
          mimeType = 'image/webp';
        }
      }

      if (!mounted) return;
      setState(() {
        _loading = true;
        _messages.add(
          _AiChatMessage.user(userPrompt, hasImage: imageBytes != null),
        );
        _message.clear();
      });

      final answer = await _service.ask(
        prompt: userPrompt,
        imageBytes: imageBytes,
        imageMimeType: mimeType,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(_AiChatMessage.assistant(answer));
      });
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('StateError: ', '').trim();
      setState(() {
        _messages.add(_AiChatMessage.assistant(
          message.isEmpty || message.contains('TimeoutException')
              ? 'İstek zaman aşımına uğradı. İnternet bağlantını kontrol edip tekrar dene.'
              : 'Bağlantı kurulamadı: $message',
        ));
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _selectedImage = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final height = size.height < 700 ? size.height * .82 : size.height * .72;

    return Container(
      height: height.clamp(420, 720).toDouble(),
      decoration: const BoxDecoration(
        color: Color(0xFF090D1F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00F0FF), Color(0xFFA855F7)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white),
              ),
              title: const Text(
                'YKS AI Soru Çözücü',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: const Text(
                'Metin veya soru görseli gönder',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              trailing: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ),
            const Divider(height: 1, color: Colors.white10),
            Expanded(
              child: _messages.isEmpty
                  ? const _AiWelcome()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                      itemCount: _messages.length + (_loading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _loading) {
                          return const _AiThinking();
                        }
                        return _AiBubble(message: _messages[index]);
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedImage != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA855F7).withOpacity(.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFA855F7).withOpacity(.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.image_rounded,
                                color: Color(0xFFC084FC), size: 18),
                            const SizedBox(width: 6),
                            const Text(
                              'Soru görseli hazır',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              onPressed: () =>
                                  setState(() => _selectedImage = null),
                              icon: const Icon(Icons.close,
                                  color: Colors.white54, size: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Görsel ekle',
                        onPressed: _loading ? null : _pickImage,
                        icon: const Icon(Icons.add_photo_alternate_rounded),
                        color: const Color(0xFF00F0FF),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _message,
                          enabled: !_loading,
                          minLines: 1,
                          maxLines: 4,
                          style: const TextStyle(color: Colors.white),
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Sorunu yaz veya görselini yükle...',
                            hintStyle: const TextStyle(
                              color: Colors.white38,
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: const Color(0xFF1B2340),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: _loading ? null : _send,
                        icon: const Icon(Icons.send_rounded),
                        color: const Color(0xFFA855F7),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiChatMessage {
  final String text;
  final bool assistant;
  final bool hasImage;

  const _AiChatMessage({
    required this.text,
    required this.assistant,
    this.hasImage = false,
  });

  factory _AiChatMessage.user(String text, {required bool hasImage}) =>
      _AiChatMessage(text: text, assistant: false, hasImage: hasImage);

  factory _AiChatMessage.assistant(String text) =>
      _AiChatMessage(text: text, assistant: true);
}

class _AiBubble extends StatelessWidget {
  final _AiChatMessage message;

  const _AiBubble({required this.message});

  static String _normalizeAssistantText(String text) {
    var result = text.replaceAll('\r\n', '\n');
    result =
        result.replaceAll(RegExp(r'^\$\$\s*|\s*\$\$$', multiLine: true), '');
    result = result.replaceAllMapped(
      RegExp(r'\$([^$\n]+)\$'),
      (match) => match.group(1) ?? '',
    );
    result = result.replaceAll(RegExp(r'\\\[|\\\]|\\\(|\\\)'), '');

    result = result.replaceAllMapped(
      RegExp(r'\\frac\{([^{}]+)\}\{([^{}]+)\}'),
      (match) => '(${match.group(1)}/${match.group(2)})',
    );
    result = result.replaceAllMapped(
      RegExp(r'\\sqrt\{([^{}]+)\}'),
      (match) => '√(${match.group(1)})',
    );

    final replacements = <String, String>{
      r'\cdot': '·',
      r'\times': '×',
      r'\div': '÷',
      r'\pm': '±',
      r'\neq': '≠',
      r'\leq': '≤',
      r'\geq': '≥',
      r'\approx': '≈',
      r'\infty': '∞',
      r'\pi': 'π',
      r'\theta': 'θ',
      r'\alpha': 'α',
      r'\beta': 'β',
      r'\Delta': 'Δ',
      r'\sum': 'Σ',
      r'\left': '',
      r'\right': '',
      r'\,': ' ',
      r'\;': ' ',
      r'\!': '',
    };
    replacements.forEach((from, to) => result = result.replaceAll(from, to));

    result =
        result.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    result = result.replaceAll(RegExp(r'<[^>]+>'), '');
    result = result.replaceAll('&nbsp;', ' ');
    result = result.replaceAll('&amp;', '&');
    result = result.replaceAll('&lt;', '<');
    result = result.replaceAll('&gt;', '>');
    result = result.replaceAll(RegExp(r'\\([A-Za-z]+)'), r'$1');
    result = result.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return result.trim();
  }

  @override
  Widget build(BuildContext context) {
    final align =
        message.assistant ? Alignment.centerLeft : Alignment.centerRight;
    final color =
        message.assistant ? const Color(0xFF161E34) : const Color(0xFF6D28D9);
    return Align(
      alignment: align,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: message.assistant
                ? const Color(0xFFA855F7).withOpacity(.25)
                : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.hasImage)
              const Padding(
                padding: EdgeInsets.only(bottom: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image, size: 15, color: Color(0xFF00F0FF)),
                    SizedBox(width: 5),
                    Text(
                      'Görsel gönderildi',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            if (message.assistant)
              MarkdownBody(
                data: _normalizeAssistantText(message.text),
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.45,
                  ),
                  strong: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  h1: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                  h2: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                  h3: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  listBullet: const TextStyle(
                    color: Color(0xFFC084FC),
                    fontSize: 13,
                  ),
                  blockquote: const TextStyle(
                    color: Color(0xFFE9D5FF),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              )
            else
              Text(
                message.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AiWelcome extends StatelessWidget {
  const _AiWelcome();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00F0FF), Color(0xFFA855F7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.psychology_alt_rounded,
                  color: Colors.white, size: 38),
            ),
            const SizedBox(height: 14),
            const Text(
              'Merhaba! Hangi YKS sorusunda takıldın?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Soruyu yazabilir veya fotoğrafını ekleyebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiThinking extends StatelessWidget {
  const _AiThinking();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF161E34),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFA855F7),
              ),
            ),
            SizedBox(width: 8),
            Text(
              'YKS çözümü hazırlanıyor...',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
