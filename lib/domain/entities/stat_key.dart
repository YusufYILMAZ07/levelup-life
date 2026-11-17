/// LevelUp Life karakterinin 5 temel özelliği.
///
/// Radar grafiği, XP dağılımı ve görev eşleştirmesi her zaman bu enum'un
/// sırasını ([StatKey.values]) referans alır — sıra değiştirilirse grafik de
/// döner, bu yüzden sıra sabittir.
enum StatKey {
  intelligence(
    code: 'INT',
    label: 'Zeka',
    arena: 'Akademik',
    description: 'Ders çalışma, okuma ve bölüm bazlı gelişim.',
  ),
  strength(
    code: 'STR',
    label: 'Güç',
    arena: 'Fiziksel',
    description: 'Spor, antrenman ve aktif yaşam.',
  ),
  vitality(
    code: 'VIT',
    label: 'Canlılık',
    arena: 'Sağlık',
    description: 'Su tüketimi, uyku düzeni, beslenme ve esneme.',
  ),
  productivity(
    code: 'PRO',
    label: 'Kariyer',
    arena: 'Üretkenlik',
    description: 'Projeler, portfolyo, GitHub ve derin odaklanma.',
  ),
  willpower(
    code: 'WIL',
    label: 'Disiplin',
    arena: 'Zihin',
    description: 'Erken kalkma, seri koruma, meditasyon ve alışkanlıklar.',
  );

  const StatKey({
    required this.code,
    required this.label,
    required this.arena,
    required this.description,
  });

  /// Kısa kod: INT, STR, VIT, PRO, WIL.
  final String code;

  /// Kullanıcıya gösterilen ad.
  final String label;

  /// Hangi yaşam alanını temsil ettiği.
  final String arena;

  /// Onboarding ve tooltip'lerde kullanılan açıklama.
  final String description;

  static StatKey fromCode(String code) {
    for (final StatKey stat in values) {
      if (stat.code == code || stat.name == code) return stat;
    }
    throw ArgumentError.value(code, 'code', 'Bilinmeyen stat kodu');
  }

  /// Bilinmeyen değerde null döner (bozuk cache verisi için güvenli okuma).
  static StatKey? tryFromCode(String? code) {
    if (code == null) return null;
    for (final StatKey stat in values) {
      if (stat.code == code || stat.name == code) return stat;
    }
    return null;
  }
}
