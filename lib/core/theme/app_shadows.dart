import 'package:flutter/material.dart';

/// Yumuşak, renkli gölge presetleri (aydınlık tema).
///
/// Aydınlık arayüzde gölge "siyah leke" değil, kartın altına düşen **renkli
/// derinlik**tir: her stat kartı kendi renginden hafif bir gölge alır, böylece
/// yüzeyler canlı kalır ama boğucu olmaz.
abstract final class AppShadows {
  /// Standart yüzen kart gölgesi — çok yumuşak, geniş.
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: Color(0x140F172A),
      blurRadius: 24,
      offset: Offset(0, 10),
      spreadRadius: -6,
    ),
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 6,
      offset: Offset(0, 2),
      spreadRadius: -1,
    ),
  ];

  /// Modal / hero kart gölgesi.
  static const List<BoxShadow> floating = <BoxShadow>[
    BoxShadow(
      color: Color(0x1F0F172A),
      blurRadius: 42,
      offset: Offset(0, 20),
      spreadRadius: -8,
    ),
    BoxShadow(
      color: Color(0x0F0F172A),
      blurRadius: 10,
      offset: Offset(0, 4),
      spreadRadius: -2,
    ),
  ];

  /// Seçili kart için renkli çerçeve gölgesi.
  static List<BoxShadow> selected(Color color) => <BoxShadow>[
    BoxShadow(
      color: color.withValues(alpha: 0.22),
      blurRadius: 22,
      offset: const Offset(0, 8),
      spreadRadius: -6,
    ),
  ];

  /// Gradient buton / XP bar için parıltı.
  static List<BoxShadow> glow(
    Color color, {
    double opacity = 0.38,
    double blur = 18,
    Offset offset = const Offset(0, 8),
  }) {
    return <BoxShadow>[
      BoxShadow(
        color: color.withValues(alpha: opacity),
        blurRadius: blur,
        offset: offset,
      ),
    ];
  }

  /// Stat rengine göre kartın altına düşen yumuşak renkli gölge.
  static List<BoxShadow> tinted(Color color) => <BoxShadow>[
    BoxShadow(
      color: color.withValues(alpha: 0.16),
      blurRadius: 26,
      offset: const Offset(0, 12),
      spreadRadius: -10,
    ),
    ...card,
  ];
}
