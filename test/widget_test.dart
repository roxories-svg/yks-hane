import 'package:flutter_test/flutter_test.dart';
import 'package:yks_yanlis_defteri/main.dart';
import 'package:yks_yanlis_defteri/gemini_service.dart';

void main() {
  test('SoruModel JSON round trip', () {
    final soru = SoruModel(
      id: '1',
      ders: 'Matematik',
      konu: 'Türev',
      soruResimBase64: 'abc',
      cozumResimBase64: 'xyz',
      eklenmeTarihi: DateTime(2026, 10, 28),
      cozuldu: true,
      tekrarAraligiGun: 5,
    );

    final restored = SoruModel.fromJson(soru.toJson());

    expect(restored.id, soru.id);
    expect(restored.ders, soru.ders);
    expect(restored.konu, soru.konu);
    expect(restored.soruResimBase64, soru.soruResimBase64);
    expect(restored.cozumResimBase64, soru.cozumResimBase64);
    expect(restored.cozuldu, true);
    expect(restored.tekrarAraligiGun, 5);
  });

  test('Normal sohbet metni soru olarak siniflandirilmaz', () {
    expect(GeminiYksService.isCasualChat('Selam'), isTrue);
    expect(GeminiYksService.isCasualChat('Merhaba, nasılsın?'), isTrue);
    expect(GeminiYksService.isCasualChat('Teşekkürler'), isTrue);
  });

  test('Gercek soru metni sohbet olarak siniflandirilmaz', () {
    expect(GeminiYksService.isCasualChat('2x + 4 = 10 ise x kaçtır?'), isFalse);
    expect(GeminiYksService.isCasualChat('Türevin geometrik anlamı nedir?'),
        isFalse);
  });
}
