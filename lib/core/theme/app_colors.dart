import 'package:flutter/material.dart';

/// Aydınlık, ferah ve canlı tema için ham renk token'ları.
///
/// Referans estetik: Apple Health (temiz yüzeyler) + Duolingo (canlı vurgular)
/// + Linear (net hiyerarşi). Widget'ların içinde asla hex değeri kullanılmaz;
/// her zaman bu sınıf ya da bundan türeyen stat / rank / enerji paletleri
/// üzerinden gidilir.
abstract final class AppColors {
  // ── Zemin ────────────────────────────────────────────────────────────────
  /// Uygulamanın ana arka planı: sıcak beyaz / inci grisi.
  static const Color background = Color(0xFFF8FAFC);

  /// İkinci katman zemin (bölüm ayırıcı, sheet arka planı).
  static const Color backgroundAlt = Color(0xFFF1F5F9);

  /// Kart yüzeyi: saf beyaz.
  static const Color surface = Color(0xFFFFFFFF);

  /// Kart içinde hafifçe geri çekilmiş alan (input, track).
  static const Color surfaceMuted = Color(0xFFF8FAFC);
  static const Color surfaceSunken = Color(0xFFF1F5F9);

  // ── Kenarlıklar ──────────────────────────────────────────────────────────
  /// İnce, zarif kart kenarı.
  static const Color border = Color(0xFFE2E8F0);

  /// Seçili / vurgulu kenar.
  static const Color borderStrong = Color(0xFFCBD5E1);

  static const Color divider = Color(0xFFEDF1F7);

  // ── Metin ────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF94A3B8);

  /// Renkli zemin / gradient üzerindeki metin.
  static const Color textOnAccent = Color(0xFFFFFFFF);

  // ── Marka vurguları ──────────────────────────────────────────────────────
  /// Ana renk: canlı indigo.
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryBright = Color(0xFF6366F1);
  static const Color primaryDeep = Color(0xFF4338CA);

  /// Elektrik mavisi — gradient'in ikinci durağı.
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color secondary = Color(0xFF3B82F6);
  static const Color tertiary = Color(0xFF0EA5E9);

  // ── Stat vurguları ───────────────────────────────────────────────────────
  static const Color statIntelligence = Color(0xFF0EA5E9); // Gökyüzü mavisi
  static const Color statStrength = Color(0xFFF97316); // Enerjik mercan
  static const Color statVitality = Color(0xFF10B981); // Taze zümrüt
  static const Color statProductivity = Color(0xFF8B5CF6); // Asil mor
  static const Color statWillpower = Color(0xFFF59E0B); // Altın / kehribar

  // ── Anlamsal renkler ─────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF0EA5E9);
  static const Color xp = Color(0xFFF59E0B);
  static const Color streak = Color(0xFFF97316);
  static const Color level = Color(0xFF6366F1);

  // ── Katmanlar ────────────────────────────────────────────────────────────
  /// Modal arkası karartma (yumuşak, slate tonlu).
  static const Color scrim = Color(0x661E293B);

  static const Color shimmerBase = Color(0xFFEDF2F9);
  static const Color shimmerHighlight = Color(0xFFFFFFFF);

  /// Gölge çekirdek rengi (siyah yerine slate → daha yumuşak derinlik).
  static const Color shadow = Color(0xFF0F172A);
}
