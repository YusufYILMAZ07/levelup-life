import '../../core/utils/json_x.dart';

/// Görev tamamlamanın doğrulama biçimi.
enum VerificationType {
  timer(code: 'timer', label: 'Zamanlayıcı', requiresProof: true),
  reflection(code: 'reflection', label: 'Mikro Yansıma', requiresProof: true),
  stepGoal(code: 'step_goal', label: 'Adım Hedefi', requiresProof: true),
  checklist(code: 'checklist', label: 'Kontrol Listesi', requiresProof: true),
  manual(code: 'manual', label: 'Manuel Onay', requiresProof: false);

  const VerificationType({
    required this.code,
    required this.label,
    required this.requiresProof,
  });

  final String code;
  final String label;

  /// Sahte işaretlemeyi engelleyen bir kanıt gerekiyor mu?
  final bool requiresProof;

  static VerificationType fromCode(String? code) {
    for (final VerificationType type in values) {
      if (type.code == code || type.name == code) return type;
    }
    return VerificationType.manual;
  }
}

/// Anti-cheat doğrulama modeli.
///
/// `sealed` olduğu için `switch` kullanıldığında derleyici yeni bir doğrulama
/// tipi eklendiğinde tüm ekranları uyarır — eksik modal kalmaz.
sealed class QuestVerification {
  const QuestVerification();

  VerificationType get type;

  /// Kart üzerinde gösterilecek kısa açıklama.
  String get summary;

  Map<String, dynamic> toJson();

  factory QuestVerification.timer({
    required int minutes,
    bool requiresForeground = true,
    int minSessionMinutes = 5,
  }) =>
      TimerVerification(
        minutes: minutes,
        requiresForeground: requiresForeground,
        minSessionMinutes: minSessionMinutes,
      );

  factory QuestVerification.reflection({
    required String prompt,
    int minCharacters = 40,
  }) =>
      ReflectionVerification(prompt: prompt, minCharacters: minCharacters);

  factory QuestVerification.stepGoal({
    required int targetSteps,
    String source = 'manual',
  }) =>
      StepGoalVerification(targetSteps: targetSteps, source: source);

  factory QuestVerification.checklist({required List<String> items}) =>
      ChecklistVerification(items: items);

  factory QuestVerification.manual({bool requiresNote = false}) =>
      ManualVerification(requiresNote: requiresNote);

  static QuestVerification fromJson(Map<String, dynamic> json) {
    final VerificationType type =
        VerificationType.fromCode(JsonX.asString(json['type']));
    return switch (type) {
      VerificationType.timer => TimerVerification(
          minutes: JsonX.asInt(json['minutes'], fallback: 25),
          requiresForeground: JsonX.asBool(json['requires_foreground'], fallback: true),
          minSessionMinutes: JsonX.asInt(json['min_session_minutes'], fallback: 5),
        ),
      VerificationType.reflection => ReflectionVerification(
          prompt: JsonX.asString(json['prompt']),
          minCharacters: JsonX.asInt(json['min_characters'], fallback: 40),
        ),
      VerificationType.stepGoal => StepGoalVerification(
          targetSteps: JsonX.asInt(json['target_steps'], fallback: 1000),
          source: JsonX.asString(json['source'], fallback: 'manual'),
        ),
      VerificationType.checklist => ChecklistVerification(
          items: JsonX.asStringList(json['items']),
        ),
      VerificationType.manual => ManualVerification(
          requiresNote: JsonX.asBool(json['requires_note']),
        ),
    };
  }
}

/// Uygulama içi sayaç: süre dolmadan görev tamamlanamaz.
final class TimerVerification extends QuestVerification {
  const TimerVerification({
    required this.minutes,
    this.requiresForeground = true,
    this.minSessionMinutes = 5,
  });

  /// Hedef süre (Pomodoro uzunluğu).
  final int minutes;

  /// Sayaç yalnızca uygulama ön plandayken ilerler (anti-cheat).
  final bool requiresForeground;

  /// Kesintisiz en az bu kadar dakika geçmeli.
  final int minSessionMinutes;

  @override
  VerificationType get type => VerificationType.timer;

  @override
  String get summary => '$minutes dk odak sayacı';

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type.code,
        'minutes': minutes,
        'requires_foreground': requiresForeground,
        'min_session_minutes': minSessionMinutes,
      };

  @override
  bool operator ==(Object other) =>
      other is TimerVerification &&
      other.minutes == minutes &&
      other.requiresForeground == requiresForeground &&
      other.minSessionMinutes == minSessionMinutes;

  @override
  int get hashCode => Object.hash(minutes, requiresForeground, minSessionMinutes);
}

/// Görev sonunda açılan "ne öğrendin?" modalı.
final class ReflectionVerification extends QuestVerification {
  const ReflectionVerification({required this.prompt, this.minCharacters = 40});

  final String prompt;
  final int minCharacters;

  @override
  VerificationType get type => VerificationType.reflection;

  @override
  String get summary => 'En az $minCharacters karakterlik yansıma';

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type.code,
        'prompt': prompt,
        'min_characters': minCharacters,
      };

  @override
  bool operator ==(Object other) =>
      other is ReflectionVerification &&
      other.prompt == prompt &&
      other.minCharacters == minCharacters;

  @override
  int get hashCode => Object.hash(prompt, minCharacters);
}

/// Adım hedefi (HealthKit / Google Fit simülasyonu).
final class StepGoalVerification extends QuestVerification {
  const StepGoalVerification({required this.targetSteps, this.source = 'manual'});

  final int targetSteps;

  /// `health_kit`, `google_fit` veya `manual`.
  final String source;

  @override
  VerificationType get type => VerificationType.stepGoal;

  @override
  String get summary => '$targetSteps adım hedefi';

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type.code,
        'target_steps': targetSteps,
        'source': source,
      };

  @override
  bool operator ==(Object other) =>
      other is StepGoalVerification &&
      other.targetSteps == targetSteps &&
      other.source == source;

  @override
  int get hashCode => Object.hash(targetSteps, source);
}

/// Alt maddeleri tek tek işaretlenen görevler (bölüm konusu bitirme vb.).
final class ChecklistVerification extends QuestVerification {
  const ChecklistVerification({required this.items});

  final List<String> items;

  @override
  VerificationType get type => VerificationType.checklist;

  @override
  String get summary => '${items.length} maddelik kontrol listesi';

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type.code,
        'items': items,
      };

  @override
  bool operator ==(Object other) {
    if (other is! ChecklistVerification || other.items.length != items.length) {
      return false;
    }
    for (int i = 0; i < items.length; i++) {
      if (other.items[i] != items[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(items);
}

/// Serbest onay — yalnızca düşük XP'li mikro görevlerde kullanılır.
final class ManualVerification extends QuestVerification {
  const ManualVerification({this.requiresNote = false});

  final bool requiresNote;

  @override
  VerificationType get type => VerificationType.manual;

  @override
  String get summary => requiresNote ? 'Not ile manuel onay' : 'Manuel onay';

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type.code,
        'requires_note': requiresNote,
      };

  @override
  bool operator ==(Object other) =>
      other is ManualVerification && other.requiresNote == requiresNote;

  @override
  int get hashCode => requiresNote.hashCode;
}
