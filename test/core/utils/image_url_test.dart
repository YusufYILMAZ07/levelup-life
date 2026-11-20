import 'package:flutter_test/flutter_test.dart';
import 'package:levelup_life/core/utils/image_url.dart';

/// Linkten fotoğraf özelliğinin güvenli bağlantı doğrulaması.
void main() {
  group('normalizeImageUrl', () {
    test('http ve https bağlantılarını kabul eder', () {
      expect(
        normalizeImageUrl('https://example.com/couple.png'),
        'https://example.com/couple.png',
      );
      expect(
        normalizeImageUrl('http://example.com/couple.jpg'),
        'http://example.com/couple.jpg',
      );
    });

    test('baştaki ve sondaki boşlukları temizler', () {
      expect(
        normalizeImageUrl('  https://example.com/a.png  '),
        'https://example.com/a.png',
      );
    });

    test('data:image base64 adresini kabul eder', () {
      const String dataUrl = 'data:image/png;base64,iVBORw0KGgo=';
      expect(normalizeImageUrl(dataUrl), dataUrl);
    });

    test('boş ve geçersiz girdileri reddeder', () {
      expect(normalizeImageUrl(''), isNull);
      expect(normalizeImageUrl('   '), isNull);
      expect(normalizeImageUrl('sadece-metin'), isNull);
      expect(normalizeImageUrl('https://'), isNull);
      expect(normalizeImageUrl('ftp://example.com/a.png'), isNull);
      expect(normalizeImageUrl('javascript:alert(1)'), isNull);
      expect(normalizeImageUrl('file:///tmp/a.png'), isNull);
    });

    test('base64 olmayan data image adresini reddeder', () {
      expect(normalizeImageUrl('data:image/svg+xml,%3Csvg%3E'), isNull);
      expect(normalizeImageUrl('data:image/png;base64'), isNull);
    });
  });
}
