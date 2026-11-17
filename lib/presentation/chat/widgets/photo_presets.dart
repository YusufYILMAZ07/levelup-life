import 'package:flutter/material.dart';

/// Hazır "anı kartı" fotoğrafları.
///
/// Uygulama dosya seçici / kamera paketi kullanmaz: anı albümü, gradient +
/// emoji kartlarıyla (`preset:<id>`) veya yapıştırılan bir görsel URL'siyle
/// (`data:image/…` ya da `https://…`) çalışır. Böylece her platformda aynı
/// deneyim elde edilir ve ek bağımlılık gerekmez.
final class PhotoPreset {
  const PhotoPreset({
    required this.id,
    required this.emoji,
    required this.label,
    required this.colors,
  });

  final String id;
  final String emoji;
  final String label;
  final List<Color> colors;

  /// `ChatMessage.photoDataOrUrl` içinde saklanan değer.
  String get source => 'preset:$id';

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: colors,
  );

  static const List<PhotoPreset> all = <PhotoPreset>[
    PhotoPreset(
      id: 'study-desk',
      emoji: '📚',
      label: 'Ders masası',
      colors: <Color>[Color(0xFF6366F1), Color(0xFF0EA5E9)],
    ),
    PhotoPreset(
      id: 'coffee',
      emoji: '☕',
      label: 'Kahve molası',
      colors: <Color>[Color(0xFFB45309), Color(0xFFF59E0B)],
    ),
    PhotoPreset(
      id: 'sunset',
      emoji: '🌅',
      label: 'Gün batımı',
      colors: <Color>[Color(0xFFF97316), Color(0xFFDB2777)],
    ),
    PhotoPreset(
      id: 'gym',
      emoji: '🏋️',
      label: 'Antrenman',
      colors: <Color>[Color(0xFF0F766E), Color(0xFF10B981)],
    ),
    PhotoPreset(
      id: 'campus',
      emoji: '🎓',
      label: 'Kampüs',
      colors: <Color>[Color(0xFF4338CA), Color(0xFF8B5CF6)],
    ),
    PhotoPreset(
      id: 'picnic',
      emoji: '🧺',
      label: 'Piknik',
      colors: <Color>[Color(0xFF15803D), Color(0xFF84CC16)],
    ),
    PhotoPreset(
      id: 'movie',
      emoji: '🎬',
      label: 'Film gecesi',
      colors: <Color>[Color(0xFF1E293B), Color(0xFF6366F1)],
    ),
    PhotoPreset(
      id: 'walk',
      emoji: '🚶',
      label: 'Yürüyüş',
      colors: <Color>[Color(0xFF0EA5E9), Color(0xFF22D3EE)],
    ),
    PhotoPreset(
      id: 'cake',
      emoji: '🎂',
      label: 'Kutlama',
      colors: <Color>[Color(0xFFDB2777), Color(0xFFF59E0B)],
    ),
  ];

  static PhotoPreset? byId(String id) {
    for (final PhotoPreset preset in all) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  /// `preset:study-desk` → [PhotoPreset]; diğer biçimlerde `null`.
  static PhotoPreset? fromSource(String? source) {
    if (source == null || !source.startsWith('preset:')) return null;
    return byId(source.substring('preset:'.length));
  }
}
