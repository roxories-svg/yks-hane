import 'dart:async';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';

import 'generated_gemini_config.dart';

class GeminiYksService {
  static const List<String> _modelCandidates = [
    'gemini-3.8-flash',
    'gemini-flash-latest',
    'gemini-2.5-flash',
    'gemini-3-flash-preview',
  ];

  static const String _configuredApiKey =
      String.fromEnvironment('GEMINI_API_KEY');
  static const String _fallbackApiKey =
      String.fromEnvironment('GEMINI_API_KEY_FALLBACK');

  GenerativeModel? _model;

  static String get apiKey {
    final configured = _configuredApiKey.trim();
    if (configured.isNotEmpty) return configured;
    final fallback = _fallbackApiKey.trim();
    if (fallback.isNotEmpty) return fallback;
    return generatedGeminiApiKey.trim();
  }

  bool get isConfigured => apiKey.isNotEmpty;

  static bool isCasualChat(String prompt) {
    final text = prompt
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'''[^a-zA-ZçğıöşüÇĞİÖŞÜ0-9\s]'''), '')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return false;

    const shortGreeting = <String>{
      'merhaba',
      'selam',
      'hello',
      'hi',
      'hey',
      'gunaydin',
      'iyi aksamlar',
      'iyi geceler',
      'nasilsin',
      'naber',
      'tesekkurler',
      'tesekkur ederim',
      'sagol',
      'tamam',
      'ok',
      'cok tesekkur ederim',
    };
    if (shortGreeting.contains(text)) return true;

    return RegExp(
          r'^(merhaba|selam|hello|hi|hey|gunaydin|iyi aksamlar|iyi geceler)(?:lar)?(?: iyi)?(?:\b.*)?$',
        ).hasMatch(text) &&
        text.length <= 60 &&
        !RegExp(r'\?|(\d)|[xxy]\s*=').hasMatch(text);
  }

  static String casualChatResponse(String prompt) =>
      'Merhaba! YKS hazırlık sürecinde sana yardımcı olmak için buradayım. '
      'Bir soruyu yazabilir veya soru görseli yükleyebilirsin.';

  GenerativeModel _createModel(String modelName) {
    return GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      systemInstruction: Content.text(
        'Sen uzman bir YKS koçu ve öğretmenisin. '
        'Öğrencinin gönderdiği soru görselini veya metnini dikkatlice incele. '
        'Çözümü asla gelişi güzel yapma; önce sorunun hangi konuya ait olduğunu belirt, '
        'ardından mantığını anlatarak adım adım, anlaşılır ve detaylı bir şekilde çöz. '
        'Cevapları Türkçe ver. Önce verilenleri ve bilinmeyenleri belirt. '
        'Her mantık adımını ayrı bir başlık veya numaralandırılmış sıra halinde göster. '
        'Biçimlendirme için Markdown başlıkları, kalın metin ve madde işaretleri kullan. '
        'Matematiksel ifadeleri ham LaTeX veya dolar işaretleriyle yazma; Unicode sembollerini '
        '(√, ×, ÷, ·, π, ≤, ≥) ve okunabilir kesirleri kullan. '
        'Çoktan seçmeli sorularda şıkları incele ve doğru seçeneğin neden doğru olduğunu açıklarken '
        'yanlış seçeneklerin kısa gerekçelerini de belirt. Sonunda sonucu, kontrolünü ve '
        'öğrenilen YKS konusunu özetle.',
      ),
      generationConfig: GenerationConfig(
        temperature: 0.35,
        maxOutputTokens: 4096,
      ),
    );
  }

  void _ensureModel() {
    if (!isConfigured) {
      throw StateError(
        'Gemini API anahtarı tanımlı değil. GEMINI_API_KEY değerini '
        'gemini.local.json dosyasına ekleyip uygulamayı yeniden derleyin.',
      );
    }
    _model ??= _createModel(_modelCandidates.first);
  }

  Future<String> ask({
    required String prompt,
    Uint8List? imageBytes,
    String imageMimeType = 'image/jpeg',
  }) async {
    _ensureModel();

    final coachedPrompt =
        'Sen uzman bir YKS koçu ve öğretmenisin. Öğrencinin gönderdiği soru görselini veya metnini dikkatlice incele. '
        'Çözümü asla gelişi güzel yapma; önce sorunun hangi konuya ait olduğunu belirt, ardından mantığını anlatarak '
        'adım adım, anlaşılır ve detaylı bir şekilde çöz.\n\nÖğrenci sorusu/metni:\n$prompt';
    final parts = <Part>[TextPart(coachedPrompt)];
    if (imageBytes != null && imageBytes.isNotEmpty) {
      parts.add(DataPart(imageMimeType, imageBytes));
    }
    return _askWithCandidates(parts).timeout(const Duration(seconds: 120));
  }

  Future<String> _askWithCandidates(List<Part> parts) async {
    Object? lastError;
    for (final modelName in _modelCandidates) {
      try {
        final model = _createModel(modelName);
        final response = await model
            .generateContent([Content.multi(List.of(parts))]).timeout(
                const Duration(seconds: 45));
        final text = response.text?.trim();
        if (text != null && text.isNotEmpty) {
          _model = model;
          return text;
        }
        throw StateError('Gemini yanit uretemedi.');
      } catch (error) {
        lastError = error;
      }
    }
    throw StateError('Gemini modeli kullanilamadi: $lastError');
  }
}
