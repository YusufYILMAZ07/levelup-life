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

/// Sohbet mesajının medya türü.
///
/// `none` → sadece metin, `image` → fotoğraf / hazır anı kartı / plan kanıtı,
/// `video` → gerçek cihazdan seçilmiş video.
enum ChatMediaType {
  none(code: 'none'),
  image(code: 'image'),
  video(code: 'video');

  const ChatMediaType({required this.code});

  final String code;

  static ChatMediaType fromCode(String? code) {
    for (final ChatMediaType type in values) {
      if (type.code == code || type.name == code) return type;
    }
    return ChatMediaType.none;
  }
}

/// Yusuf ↔ Ceyda sohbetindeki tek bir mesaj.
///
/// Medya `mediaPathOrUrl` alanında dört biçimden biriyle saklanır:
/// * `preset:<id>` → hazır "anı kartı" (gradient + emoji, assetsiz)
/// * `data:image/...;base64,...` / `data:video/...;base64,...` → gömülü medya
///   (Web'de kamera/galeri seçimi bu biçime çevrilir)
/// * `https://…` → uzak görsel / Supabase Storage URL'si
/// * `/var/mobile/…/media/…jpg` → cihazda kalıcı dosya yolu (iOS / Android)
///
/// Böylece Web, iOS ve Android aynı domain modelini paylaşır; `photoDataOrUrl`
/// eski kayıtlarla geriye dönük uyum için korunur.
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
    this.mediaType = ChatMediaType.none,
    this.thumbnailPath,
    this.replyToMessageId,
    this.replyPreviewText,
    this.isRead = false,
    this.durationSeconds = 0,
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

  /// Mesajın medya türü (metin / fotoğraf / video).
  final ChatMediaType mediaType;

  /// Video için küçük önizleme (opsiyonel, yerel yol).
  final String? thumbnailPath;

  /// Yanıtlanan mesajın kimliği (`↩️ Yanıtla`).
  final String? replyToMessageId;

  /// Yanıtlanan mesajın kısa önizlemesi — balonun içinde gösterilir.
  final String? replyPreviewText;

  /// Karşı taraf bu mesajı gördü mü? (✓ / ✓✓)
  final bool isRead;

  /// Video süresi (saniye) — süre rozeti için.
  final int durationSeconds;

  /// Medya alanının okunabilir adı (v4 API'si).
  String? get mediaPathOrUrl => photoDataOrUrl;

  bool get hasMedia =>
      photoDataOrUrl != null && photoDataOrUrl!.trim().isNotEmpty;

  /// Geriye dönük uyum: eski çağrılar fotoğraf varlığını böyle sorar.
  bool get hasPhoto => hasMedia;

  bool get hasVideo => hasMedia && effectiveMediaType == ChatMediaType.video;

  bool get hasImage => hasMedia && !hasVideo;

  /// Kayıtlı `mediaType` boşsa (v3 mesajları) içerikten çıkarılır.
  ChatMediaType get effectiveMediaType {
    if (mediaType != ChatMediaType.none) return mediaType;
    final String source = (photoDataOrUrl ?? '').toLowerCase();
    if (source.startsWith('data:video/') ||
        source.endsWith('.mp4') ||
        source.endsWith('.mov') ||
        source.endsWith('.m4v') ||
        source.endsWith('.webm')) {
      return ChatMediaType.video;
    }
    return hasMedia ? ChatMediaType.image : ChatMediaType.none;
  }

  bool get isReply => (replyToMessageId ?? '').trim().isNotEmpty;

  bool get isQuestShare => kind == ChatMessageKind.questShare;

  bool get isProof => kind == ChatMessageKind.proof;

  /// Liste önizlemesi (galeri kartı, bildirim metni, yanıt şeridi).
  String get preview {
    if (hasVideo) {
      return photoCaption?.trim().isNotEmpty == true
          ? '🎥 ${photoCaption!.trim()}'
          : '🎥 Video';
    }
    if (hasMedia) {
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
    ChatMediaType? mediaType,
    String? thumbnailPath,
    String? replyToMessageId,
    String? replyPreviewText,
    bool? isRead,
    int? durationSeconds,
    bool clearReply = false,
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
    mediaType: mediaType ?? this.mediaType,
    thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    replyToMessageId: clearReply
        ? null
        : (replyToMessageId ?? this.replyToMessageId),
    replyPreviewText: clearReply
        ? null
        : (replyPreviewText ?? this.replyPreviewText),
    isRead: isRead ?? this.isRead,
    durationSeconds: durationSeconds ?? this.durationSeconds,
  );

  ChatMessage toggleLike() => copyWith(isLiked: !isLiked);

  ChatMessage markRead() => isRead ? this : copyWith(isRead: true);

  ChatMessage withReply({required String messageId, required String preview}) =>
      copyWith(replyToMessageId: messageId, replyPreviewText: preview);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'sender_id': senderId,
    'text': text,
    'media_type': effectiveMediaType.code,
    'media_path_or_url': photoDataOrUrl,
    'photo_data_or_url': photoDataOrUrl,
    'thumbnail_path': thumbnailPath,
    'photo_caption': photoCaption,
    'quest_badge_title': questBadgeTitle,
    'earned_points': earnedPoints,
    'created_at': createdAt.toIso8601String(),
    'is_liked': isLiked,
    'is_read': isRead,
    'reply_to_message_id': replyToMessageId,
    'reply_preview_text': replyPreviewText,
    'duration_seconds': durationSeconds,
    'kind': kind.code,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final Object? rawMedia =
        json['media_path_or_url'] ?? json['photo_data_or_url'];
    final String? media = rawMedia == null ? null : JsonX.asString(rawMedia);
    return ChatMessage(
      id: JsonX.asString(json['id']),
      senderId: JsonX.asString(json['sender_id'], fallback: 'yusuf'),
      createdAt: JsonX.asDate(json['created_at']) ?? DateTime.now(),
      text: JsonX.asString(json['text']),
      photoDataOrUrl: media,
      photoCaption: json['photo_caption'] == null
          ? null
          : JsonX.asString(json['photo_caption']),
      questBadgeTitle: json['quest_badge_title'] == null
          ? null
          : JsonX.asString(json['quest_badge_title']),
      earnedPoints: JsonX.asInt(json['earned_points']),
      isLiked: JsonX.asBool(json['is_liked']),
      kind: ChatMessageKind.fromCode(JsonX.asString(json['kind'])),
      mediaType: ChatMediaType.fromCode(JsonX.asString(json['media_type'])),
      thumbnailPath: json['thumbnail_path'] == null
          ? null
          : JsonX.asString(json['thumbnail_path']),
      replyToMessageId: json['reply_to_message_id'] == null
          ? null
          : JsonX.asString(json['reply_to_message_id']),
      replyPreviewText: json['reply_preview_text'] == null
          ? null
          : JsonX.asString(json['reply_preview_text']),
      isRead: JsonX.asBool(json['is_read']),
      durationSeconds: JsonX.asInt(json['duration_seconds']),
    );
  }

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
      other.kind == kind &&
      other.mediaType == mediaType &&
      other.thumbnailPath == thumbnailPath &&
      other.replyToMessageId == replyToMessageId &&
      other.replyPreviewText == replyPreviewText &&
      other.isRead == isRead &&
      other.durationSeconds == durationSeconds;

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
    mediaType,
    thumbnailPath,
    replyToMessageId,
    replyPreviewText,
    isRead,
    durationSeconds,
  );

  @override
  String toString() => 'ChatMessage($senderId → "$preview")';
}
