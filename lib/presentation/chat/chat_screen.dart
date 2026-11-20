import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../application/game_controller.dart';
import '../../application/game_state.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/theme.dart';
import '../../domain/entities/entities.dart';
import '../../services/app_settings.dart';
import '../../services/cloud_sync_coordinator.dart';
import '../../services/media_service.dart';
import '../widgets/partner_avatar.dart';
import 'widgets/couple_photo.dart';
import 'widgets/media_picker_sheet.dart';
import 'widgets/media_preview_sheet.dart';
import 'widgets/photo_lightbox_modal.dart';
import 'widgets/photo_presets.dart';
import 'widgets/video_message_bubble.dart';

/// Yusuf ↔ Ceyda sohbeti ve ortak anı albümü.
///
/// v4 özellikleri:
/// * gerçek kamera / galeri fotoğraf + video (Web'de data URL)
/// * yanıtla (uzun bas veya sağa kaydır), beğen, kopyala, sil
/// * gün ayırıcıları ve ✓ / ✓✓ okundu bilgisi
/// * başlıkta canlı arama
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({this.now, super.key});

  final DateTime? now;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _input = TextEditingController();
  final TextEditingController _search = TextEditingController();
  final MediaService _media = MediaService();

  ChatMessage? _replyTarget;
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToEnd(animate: false);
      // Sohbeti açan partner, karşıdan gelen mesajları görmüş olur (✓✓).
      ref.read(gameProvider.notifier).markConversationRead();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    _search.dispose();
    super.dispose();
  }

  void _jumpToEnd({bool animate = true}) {
    if (!_scroll.hasClients) return;
    final double target = _scroll.position.maxScrollExtent;
    if (animate) {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 240),
        curve: AppMotion.enter,
      );
    } else {
      _scroll.jumpTo(target);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  void _send() {
    final ChatMessage? message = ref
        .read(gameProvider.notifier)
        .sendMessage(_input.text, replyTo: _replyTarget);
    if (message == null) return;
    _input.clear();
    setState(() => _replyTarget = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEnd());
  }

  void _startReply(ChatMessage message) {
    setState(() => _replyTarget = message);
  }

  Future<void> _copyMessage(ChatMessage message) async {
    final String text = message.text.trim().isNotEmpty
        ? message.text.trim()
        : message.preview;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _snack('📋 Mesaj kopyalandı');
  }

  void _deleteMessage(ChatMessage message) {
    ref.read(gameProvider.notifier).deleteMessage(message.id);
    if (_replyTarget?.id == message.id) {
      setState(() => _replyTarget = null);
    }
    _snack('🗑️ Mesaj silindi');
  }

  Future<void> _openActions(ChatMessage message) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
      builder: (BuildContext sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: AppRadii.pillAll,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.md,
                AppSpacing.xxl,
                AppSpacing.xs,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      message.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              key: const Key('chat-action-reply'),
              leading: const Text('↩️', style: TextStyle(fontSize: 20)),
              title: const Text('Yanıtla'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _startReply(message);
              },
            ),
            ListTile(
              key: const Key('chat-action-like'),
              leading: Text(
                message.isLiked ? '💔' : '❤️',
                style: const TextStyle(fontSize: 20),
              ),
              title: Text(message.isLiked ? 'Beğeniyi kaldır' : 'Beğen'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ref.read(gameProvider.notifier).likeMessage(message.id);
              },
            ),
            ListTile(
              key: const Key('chat-action-copy'),
              leading: const Text('📋', style: TextStyle(fontSize: 20)),
              title: const Text('Kopyala'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _copyMessage(message);
              },
            ),
            ListTile(
              key: const Key('chat-action-delete'),
              leading: const Text('🗑️', style: TextStyle(fontSize: 20)),
              title: const Text('Sil'),
              textColor: AppColors.danger,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _deleteMessage(message);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Future<String?> _askCaption({required String title}) async {
    final TextEditingController controller = TextEditingController();
    final String? caption = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          key: const Key('photo-caption-input'),
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Bir not ekle (opsiyonel)',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Paylaş'),
          ),
        ],
      ),
    );
    controller.dispose();
    return caption;
  }

  Future<void> _pickPhoto() async {
    final ChatMediaChoice? choice = await showChatMediaSheet(context);
    if (choice == null || !mounted) return;

    if (choice.action == ChatMediaAction.scheduleProof) {
      final ChatMessage? proof = ref
          .read(gameProvider.notifier)
          .sendScheduleProof();
      if (proof == null) {
        _snack('Aktif ya da sıradaki plan bulunamadı 📅');
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEnd());
      return;
    }

    if (choice.action == ChatMediaAction.preset) {
      final PhotoPreset? preset = choice.preset;
      if (preset == null) return;
      final String? caption = await _askCaption(
        title: '${preset.emoji} ${preset.label}',
      );
      if (caption == null || !mounted) return;
      ref
          .read(gameProvider.notifier)
          .sendPhoto(
            photoDataOrUrl: preset.source,
            caption: caption,
            replyTo: _replyTarget,
          );
      setState(() => _replyTarget = null);
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEnd());
      return;
    }

    if (choice.action == ChatMediaAction.cameraPhoto) {
      await _pickDeviceImage(ImageSource.camera);
      return;
    }
    if (choice.action == ChatMediaAction.galleryPhoto) {
      await _pickDeviceImage(ImageSource.gallery);
      return;
    }
    if (choice.action == ChatMediaAction.galleryVideo) {
      final VideoSourceChoice? source = await showVideoSourceSheet(context);
      if (source == null || !mounted) return;
      await _pickDeviceVideo(
        source == VideoSourceChoice.camera
            ? ImageSource.camera
            : ImageSource.gallery,
      );
      return;
    }
    if (choice.action == ChatMediaAction.cameraVideo) {
      await _pickDeviceVideo(ImageSource.camera);
    }
  }

  Future<void> _pickDeviceImage(ImageSource source) async {
    try {
      final PickedMedia? picked = await _media.pickImage(source: source);
      if (picked == null || !mounted) return;
      final String? caption = await showMediaPreviewSheet(context, picked);
      if (caption == null || !mounted) return;
      await _sendPickedMedia(picked, caption);
    } on MediaPickException catch (error) {
      _snack(error.message);
    }
  }

  Future<void> _pickDeviceVideo(ImageSource source) async {
    try {
      final PickedMedia? picked = await _media.pickVideo(
        source: source,
        includeBytes: ref.read(appSettingsProvider).isCloudConfigured,
      );
      if (picked == null || !mounted) return;
      final String? caption = await showMediaPreviewSheet(context, picked);
      if (caption == null || !mounted) return;
      await _sendPickedMedia(picked, caption);
    } on MediaPickException catch (error) {
      _snack(error.message);
    }
  }

  Future<void> _sendPickedMedia(PickedMedia picked, String caption) async {
    String source = picked.source;
    final bytes = picked.bytes;
    if (bytes != null) {
      _snack(
        picked.isVideo ? '🎥 Video hazırlanıyor…' : '📸 Fotoğraf hazırlanıyor…',
      );
      final String? uploaded = await ref
          .read(cloudSyncProvider)
          .uploadMediaBytes(
            bytes: bytes,
            fileName: picked.isVideo ? 'clip.mp4' : 'photo.jpg',
            contentType: picked.isVideo ? 'video/mp4' : 'image/jpeg',
          );
      if (uploaded != null) source = uploaded;
    }
    if (!mounted) return;
    final ChatMessage? message = ref
        .read(gameProvider.notifier)
        .sendMedia(
          mediaPathOrUrl: source,
          mediaType: picked.mediaType,
          caption: caption,
          durationSeconds: picked.durationSeconds,
          thumbnailPath: picked.thumbnailPath,
          replyTo: _replyTarget,
        );
    if (message == null) return;
    setState(() => _replyTarget = null);
    _snack(picked.isVideo ? '🎥 Video gönderildi' : '📸 Fotoğraf gönderildi');
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEnd());
  }

  @override
  Widget build(BuildContext context) {
    final GameState state = ref.watch(gameProvider);
    final CoupleState couple = state.couple;

    ref.listen<GameState>(gameProvider, (GameState? previous, GameState next) {
      if (previous == null) return;
      if (previous.couple.messages.length != next.couple.messages.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEnd());
      }
      final bool hasUnread = next.couple.messages.any(
        (ChatMessage message) =>
            message.senderId != next.activePartnerId && !message.isRead,
      );
      if (hasUnread) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => ref.read(gameProvider.notifier).markConversationRead(),
        );
      }
    });

    final String partnerName = CouplePalette.nameOf(
      CouplePartner.other(state.activePartnerId),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppConstants.maxContentWidth,
            ),
            child: Column(
              children: <Widget>[
                _ChatHeader(
                  couple: couple,
                  searching: _searching,
                  onToggleSearch: () {
                    setState(() {
                      _searching = !_searching;
                      if (!_searching) {
                        _search.clear();
                        _query = '';
                      }
                    });
                  },
                  onAlbum: () => showMemoryAlbum(context),
                ),
                if (_searching)
                  _ChatSearchBar(
                    controller: _search,
                    onChanged: (String value) => setState(() => _query = value),
                    onClose: () {
                      _search.clear();
                      setState(() {
                        _query = '';
                        _searching = false;
                      });
                    },
                  ),
                Expanded(child: _buildMessages(state, couple)),
                if (_replyTarget != null)
                  _ReplyBar(
                    message: _replyTarget!,
                    onCancel: () => setState(() => _replyTarget = null),
                  ),
                _ChatComposer(
                  controller: _input,
                  hintName: partnerName,
                  onSend: _send,
                  onPhoto: _pickPhoto,
                  onNudge: () {
                    final ChatMessage? message = ref
                        .read(gameProvider.notifier)
                        .nudgePartner();
                    if (message == null) return;
                    _snack('💫 Dürtme gönderildi · +10 XP');
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _jumpToEnd(),
                    );
                  },
                  onLoveNote: () {
                    final ChatMessage? message = ref
                        .read(gameProvider.notifier)
                        .sendLoveNote();
                    if (message == null) return;
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _jumpToEnd(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<ChatMessage> _visibleMessages(CoupleState couple) {
    final String query = _query.trim().toLowerCase();
    if (query.isEmpty) return couple.messages;
    return couple.messages
        .where((ChatMessage message) {
          return message.text.toLowerCase().contains(query) ||
              (message.photoCaption ?? '').toLowerCase().contains(query) ||
              (message.questBadgeTitle ?? '').toLowerCase().contains(query) ||
              message.preview.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  String _dayLabel(DateTime day) {
    final DateTime now = widget.now ?? DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final int diff = today.difference(day).inDays;
    if (diff == 0) return 'Bugün';
    if (diff == 1) return 'Dün';
    const List<String> months = <String>[
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    return '${day.day} ${months[day.month - 1]}';
  }

  Widget _buildMessages(GameState state, CoupleState couple) {
    final List<ChatMessage> visible = _visibleMessages(couple);
    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text(
            _query.trim().isEmpty
                ? 'Henüz mesaj yok. İlk mesajı sen yaz 💌'
                : 'Aramada mesaj bulunamadı 🔍',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final List<Object> rows = <Object>[];
    DateTime? lastDay;
    for (final ChatMessage message in visible) {
      final DateTime day = DateTime(
        message.createdAt.year,
        message.createdAt.month,
        message.createdAt.day,
      );
      if (lastDay == null || day != lastDay) {
        rows.add(day);
        lastDay = day;
      }
      rows.add(message);
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.sm,
        AppSpacing.xxl,
        AppSpacing.md,
      ),
      itemCount: rows.length,
      itemBuilder: (BuildContext context, int index) {
        final Object row = rows[index];
        if (row is DateTime) {
          return _DatePill(label: _dayLabel(row));
        }
        final ChatMessage message = row as ChatMessage;
        return _MessageBubble(
          key: ValueKey<String>('chat-${message.id}'),
          message: message,
          isMine: message.senderId == state.activePartnerId,
          onLike: () => ref.read(gameProvider.notifier).likeMessage(message.id),
          onOpen: () => showPhotoLightbox(context, message),
          onLongPress: () => _openActions(message),
          onSwipeReply: () => _startReply(message),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.onLike,
    required this.onOpen,
    required this.onLongPress,
    required this.onSwipeReply,
    super.key,
  });

  final ChatMessage message;
  final bool isMine;
  final VoidCallback onLike;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;
  final VoidCallback onSwipeReply;

  static String _two(int value) => value.toString().padLeft(2, '0');

  String get _timeLabel =>
      '${_two(message.createdAt.hour)}:${_two(message.createdAt.minute)}';

  @override
  Widget build(BuildContext context) {
    final bool hasMedia = message.hasMedia;
    final Color textColor = isMine
        ? AppColors.textOnAccent
        : AppColors.textPrimary;
    final Color mutedColor = isMine
        ? AppColors.textOnAccent.withValues(alpha: 0.85)
        : AppColors.textTertiary;

    return GestureDetector(
      onLongPress: onLongPress,
      onHorizontalDragEnd: (DragEndDetails details) {
        if ((details.primaryVelocity ?? 0) > 220) onSwipeReply();
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(
          mainAxisAlignment: isMine
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            if (!isMine) ...<Widget>[
              PartnerAvatar(partnerId: message.senderId, size: 30),
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    padding: hasMedia
                        ? const EdgeInsets.all(6)
                        : const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                    decoration: BoxDecoration(
                      color: isMine ? null : AppColors.surface,
                      gradient: isMine
                          ? CouplePalette.gradientOf(message.senderId)
                          : null,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMine ? 18 : 6),
                        bottomRight: Radius.circular(isMine ? 6 : 18),
                      ),
                      border: isMine
                          ? null
                          : Border.all(color: AppColors.border),
                      boxShadow: AppShadows.card,
                    ),
                    child: _bubbleContent(hasMedia, textColor, mutedColor),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        _timeLabel,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                      if (isMine) ...<Widget>[
                        const SizedBox(width: 3),
                        Text(
                          message.isRead ? '✓✓' : '✓',
                          key: Key('receipt-${message.id}'),
                          style: AppTypography.caption.copyWith(
                            color: message.isRead
                                ? CouplePalette.ceyda
                                : AppColors.textTertiary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isMine) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              PartnerAvatar(partnerId: message.senderId, size: 30),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bubbleContent(bool hasMedia, Color textColor, Color mutedColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (message.isReply) _quote(),
        if (hasMedia)
          _mediaBody(textColor, mutedColor)
        else
          _textBody(textColor, mutedColor),
      ],
    );
  }

  Widget _quote() {
    final Color tint = isMine
        ? AppColors.textOnAccent
        : CouplePalette.colorOf(message.senderId);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: isMine ? 0.18 : 0.08),
        borderRadius: AppRadii.smAll,
        border: Border(left: BorderSide(color: tint, width: 3)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.reply_rounded, size: 12, color: tint),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message.replyPreviewText ?? 'Yanıtlanan mesaj',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: tint,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mediaBody(Color textColor, Color mutedColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (message.hasVideo)
          VideoMessageBubble(
            message: message,
            onOpenFullscreen: onOpen,
            height: 168,
          )
        else
          Stack(
            children: <Widget>[
              GestureDetector(
                onTap: onOpen,
                child: CouplePhoto(
                  source: message.photoDataOrUrl ?? '',
                  height: 168,
                ),
              ),
              Positioned(
                right: AppSpacing.xs,
                bottom: AppSpacing.xs,
                child: Material(
                  color: AppColors.shadow.withValues(alpha: 0.35),
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: Key('like-${message.id}'),
                    customBorder: const CircleBorder(),
                    onTap: onLike,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs + 2),
                      child: Icon(
                        message.isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 16,
                        color: message.isLiked
                            ? const Color(0xFFFF6B8A)
                            : AppColors.textOnAccent,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        if ((message.photoCaption ?? '').trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text(
              message.photoCaption!,
              style: AppTypography.bodySmall.copyWith(
                color: isMine ? AppColors.textOnAccent : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _textBody(Color textColor, Color mutedColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (message.kind == ChatMessageKind.loveNote ||
            message.kind == ChatMessageKind.nudge) ...<Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                message.kind == ChatMessageKind.loveNote
                    ? Icons.favorite_rounded
                    : Icons.bolt_rounded,
                size: 13,
                color: mutedColor,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                message.kind == ChatMessageKind.loveNote
                    ? 'Aşk notu'
                    : 'Dürtme',
                style: AppTypography.caption.copyWith(
                  color: mutedColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
        ],
        if (message.questBadgeTitle != null) ...<Widget>[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.shadow.withValues(alpha: isMine ? 0.18 : 0.06),
              borderRadius: AppRadii.pillAll,
            ),
            child: Text(
              '🎯 ${message.questBadgeTitle}',
              style: AppTypography.caption.copyWith(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Text(
          message.text,
          style: AppTypography.body.copyWith(
            color: textColor,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
        if (message.earnedPoints > 0) ...<Widget>[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '+${message.earnedPoints} XP',
            style: AppTypography.numericSmall.copyWith(color: mutedColor),
          ),
        ],
      ],
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.couple,
    required this.searching,
    required this.onToggleSearch,
    required this.onAlbum,
  });

  final CoupleState couple;
  final bool searching;
  final VoidCallback onToggleSearch;
  final VoidCallback onAlbum;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.xxl,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 58,
            height: 40,
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: 0,
                  top: 2,
                  child: PartnerAvatar(
                    partnerId: CouplePartner.yusufId,
                    size: 34,
                    showRing: true,
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 2,
                  child: PartnerAvatar(
                    partnerId: CouplePartner.ceydaId,
                    size: 34,
                    showRing: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Sohbet',
                  style: AppTypography.headline.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Yusuf & Ceyda · ${couple.messages.length} mesaj · '
                  '${couple.photoMessages.length} anı',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('chat-search'),
            tooltip: searching ? 'Aramayı kapat' : 'Mesajlarda ara',
            onPressed: onToggleSearch,
            icon: Icon(
              searching ? Icons.close_rounded : Icons.search_rounded,
              color: AppColors.textSecondary,
            ),
          ),
          Material(
            color: AppColors.surface,
            borderRadius: AppRadii.pillAll,
            child: InkWell(
              key: const Key('open-album'),
              onTap: onAlbum,
              borderRadius: AppRadii.pillAll,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  borderRadius: AppRadii.pillAll,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.photo_library_rounded,
                      size: 16,
                      color: CouplePalette.ceyda,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${couple.photoMessages.length}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatSearchBar extends StatelessWidget {
  const _ChatSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        0,
        AppSpacing.xxl,
        AppSpacing.sm,
      ),
      child: TextField(
        key: const Key('chat-search-input'),
        controller: controller,
        autofocus: true,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: AppTypography.body.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Mesajlarda ara…',
          hintStyle: AppTypography.body.copyWith(color: AppColors.textTertiary),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.textTertiary,
          ),
          suffixIcon: IconButton(
            key: const Key('chat-search-close'),
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
          filled: true,
          fillColor: AppColors.surfaceMuted,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          border: const OutlineInputBorder(
            borderRadius: AppRadii.pillAll,
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: AppRadii.pillAll,
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: AppRadii.pillAll,
            borderSide: BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  const _ReplyBar({required this.message, required this.onCancel});

  final ChatMessage message;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final Color accent = CouplePalette.colorOf(message.senderId);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        0,
        AppSpacing.xxl,
        AppSpacing.xs,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: AppRadii.smAll,
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.reply_rounded, size: 15, color: accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${CouplePalette.nameOf(message.senderId)} mesajına yanıt',
                  style: AppTypography.caption.copyWith(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  message.preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('reply-cancel'),
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.pillAll,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.card,
          ),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.hintName,
    required this.onSend,
    required this.onPhoto,
    required this.onNudge,
    required this.onLoveNote,
  });

  final TextEditingController controller;
  final String hintName;
  final VoidCallback onSend;
  final VoidCallback onPhoto;
  final VoidCallback onNudge;
  final VoidCallback onLoveNote;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.sm,
          AppSpacing.xxl,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  _QuickChip(
                    key: const Key('chat-nudge'),
                    emoji: '💫',
                    label: 'Dürt',
                    onTap: onNudge,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _QuickChip(
                    key: const Key('chat-love'),
                    emoji: '💌',
                    label: 'Aşk notu',
                    onTap: onLoveNote,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _QuickChip(
                    key: const Key('chat-photo'),
                    emoji: '📷',
                    label: 'Kamera / Galeri',
                    onTap: onPhoto,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                IconButton(
                  key: const Key('chat-camera'),
                  tooltip: 'Fotoğraf veya video ekle',
                  onPressed: onPhoto,
                  icon: const Icon(
                    Icons.add_a_photo_rounded,
                    size: 21,
                    color: CouplePalette.ceyda,
                  ),
                ),
                Expanded(
                  child: TextField(
                    key: const Key('chat-input'),
                    controller: controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    textCapitalization: TextCapitalization.sentences,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: '$hintName için bir şey yaz…',
                      hintStyle: AppTypography.body.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceMuted,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      border: const OutlineInputBorder(
                        borderRadius: AppRadii.pillAll,
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderRadius: AppRadii.pillAll,
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: AppRadii.pillAll,
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Semantics(
                  button: true,
                  label: 'Mesajı gönder',
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      key: const Key('chat-send'),
                      customBorder: const CircleBorder(),
                      onTap: onSend,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          gradient: AppGradients.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          color: AppColors.textOnAccent,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.emoji,
    required this.label,
    required this.onTap,
    super.key,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: AppRadii.pillAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.pillAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(emoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
