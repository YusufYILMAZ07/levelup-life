/// Kullanıcının "bugünkü kapasitesi".
///
/// Enerji modu, görev motorunun ağır görevleri mikro varyantlara çevirmesini
/// sağlar. Amaç: kullanıcı uygulamayı kapatsa bile serisini (streak) kaybetmemesi.
enum EnergyMode {
  balanced(
    code: 'balanced',
    label: 'Dengeli',
    tagline: 'Normal mod',
    description: 'Görevler tam kapsamıyla aktif.',
  ),
  lowEnergy(
    code: 'low_energy',
    label: 'Enerjim Düşük',
    tagline: 'Mikro görevler',
    description:
        'Ağır görevler 10 dakikalık mikro adımlara bölünür; serin korunur.',
  ),
  examWeek(
    code: 'exam_week',
    label: 'Sınav Haftası',
    tagline: 'Odak modu',
    description:
        'Akademik odak öne çıkar, diğer yükler mikro varyantlara iner.',
  ),
  overloaded(
    code: 'overloaded',
    label: 'Çok Yoğunum',
    tagline: 'Minimum sürdürme',
    description: 'Sadece seriyi koruyan en kısa görevler önerilir.',
  );

  const EnergyMode({
    required this.code,
    required this.label,
    required this.tagline,
    required this.description,
  });

  final String code;
  final String label;
  final String tagline;
  final String description;

  bool get isBalanced => this == EnergyMode.balanced;

  /// Mikro varyantı olan görevlerin dönüştürülüp dönüştürülmeyeceği.
  bool get convertsToMicro => !isBalanced;

  static EnergyMode fromCode(String? code) {
    for (final EnergyMode mode in values) {
      if (mode.code == code || mode.name == code) return mode;
    }
    return EnergyMode.balanced;
  }
}
