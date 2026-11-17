import '../../core/utils/json_x.dart';

/// Sohbet balonunun türü — görsel stil ve rozet buna göre değişir.
enum ChatMessageKind {
  text(code: 'text'),
  photo(code: 'photo'),
  questShare(code: 'quest_share'),
  nudge(code: 'nudge'),
  loveNote(code: 'love_note'),

  /// Haftalık plandan üretilen kanıt kartı (fotoğraf gibi görünür).
  proof(code: 'proof');

  const ChatMessageKind({required this.code});

  final String code;

  static ChatMessageKind fromCode(String? code) {
    for (final ChatMessageKind kind in values) {
      if (kind.code == code || kind.name == code) return kind;
    }
    return ChatMessageKind.text;
  }
}

/// Yusuf ↔ Ceyda sohbetindeki tek bir mesaj.
///
/// Fotoğraflar `photoDataOrUrl` alanında üç biçimden biriyle saklanır:
/// * `preset:<id>` → hazır "anı kartı" (gradient + emoji, assetsiz)
/// * `data:image/...;base64,...` → panodan/URL'den gelen gömülü görsel
/// * `https://…` → uzak görsel
///
/// Böylece Web / macOS / iOS'ta ek paket olmadan aynı kod çalışır.
final class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.createdAt,
    this.text = '',
    this.photoDataOrUrl,
    this.photoCaption,
    this.questBadgeTitle,
    this.earnedPoints = 0,
    this.isLiked = false,
    this.kind = ChatMessageKind.text,
  });

  final String id;

  /// `yusuf` veya `ceyda`.
  final String senderId;

  final DateTime createdAt;

  final String text;

  /// Fotoğraf verisi (data URL / uzak URL / preset anahtarı).
  final String? photoDataOrUrl;

  final String? photoCaption;

  /// Görev paylaşımı ise görev başlığı.
  final String? questBadgeTitle;

  /// Görev paylaşımında kazanılan XP.
  final int earnedPoints;

  /// Galeride/lightbox'ta kalp ile işaretlendi mi?
  final bool isLiked;

  final ChatMessageKind kind;

  bool get hasPhoto =>
      photoDataOrUrl != null && photoDataOrUrl!.trim().isNotEmpty;

  bool get isQuestShare => kind == ChatMessageKind.questShare;

  /// Liste önizlemesi (galeri kartı, bildirim metni).
  String get preview {
    if (hasPhoto) {
      return photoCaption?.trim().isNotEmpty == true
          ? photoCaption!.trim()
          : '📸 Fotoğraf';
    }
    if (text.trim().isNotEmpty) return text.trim();
    if (questBadgeTitle != null) return '🎯 $questBadgeTitle';
    return 'Mesaj';
  }

  ChatMessage copyWith({
    String? text,
    String? photoDataOrUrl,
    String? photoCaption,
    String? questBadgeTitle,
    int? earnedPoints,
    bool? isLiked,
    ChatMessageKind? kind,
  }) => ChatMessage(
    id: id,
    senderId: senderId,
    createdAt: createdAt,
    text: text ?? this.text,
    photoDataOrUrl: photoDataOrUrl ?? this.photoDataOrUrl,
    photoCaption: photoCaption ?? this.photoCaption,
    questBadgeTitle: questBadgeTitle ?? this.questBadgeTitle,
    earnedPoints: earnedPoints ?? this.earnedPoints,
    isLiked: isLiked ?? this.isLiked,
    kind: kind ?? this.kind,
  );

  ChatMessage toggleLike() => copyWith(isLiked: !isLiked);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'sender_id': senderId,
    'text': text,
    'photo_data_or_url': photoDataOrUrl,
    'photo_caption': photoCaption,
    'quest_badge_title': questBadgeTitle,
    'earned_points': earnedPoints,
    'created_at': createdAt.toIso8601String(),
    'is_liked': isLiked,
    'kind': kind.code,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: JsonX.asString(json['id']),
    senderId: JsonX.asString(json['sender_id'], fallback: 'yusuf'),
    createdAt: JsonX.asDate(json['created_at']) ?? DateTime.now(),
    text: JsonX.asString(json['text']),
    photoDataOrUrl: json['photo_data_or_url'] == null
        ? null
        : JsonX.asString(json['photo_data_or_url']),
    photoCaption: json['photo_caption'] == null
        ? null
        : JsonX.asString(json['photo_caption']),
    questBadgeTitle: json['quest_badge_title'] == null
        ? null
        : JsonX.asString(json['quest_badge_title']),
    earnedPoints: JsonX.asInt(json['earned_points']),
    isLiked: JsonX.asBool(json['is_liked']),
    kind: ChatMessageKind.fromCode(JsonX.asString(json['kind'])),
  );

  @override
  bool operator ==(Object other) =>
      other is ChatMessage &&
      other.id == id &&
      other.senderId == senderId &&
      other.createdAt == createdAt &&
      other.text == text &&
      other.photoDataOrUrl == photoDataOrUrl &&
      other.photoCaption == photoCaption &&
      other.questBadgeTitle == questBadgeTitle &&
      other.earnedPoints == earnedPoints &&
      other.isLiked == isLiked &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(
    id,
    senderId,
    createdAt,
    text,
    photoDataOrUrl,
    photoCaption,
    questBadgeTitle,
    earnedPoints,
    isLiked,
    kind,
  );

  @override
  String toString() => 'ChatMessage($senderId → "$preview")';
}
