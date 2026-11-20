import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_controller.dart';
import '../../application/game_state.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/format_x.dart';
import '../../domain/entities/entities.dart';
import 'widgets/couple_photo.dart';
import 'widgets/photo_lightbox_modal.dart';
import 'widgets/photo_presets.dart';

/// Sohbet & anı albümü sekmesi.
///
/// Sohbet iki partner arasında paylaşılır: mesajlar **gönderenin** renginde
/// görünür, aktif partner üst bardan değiştirilince yazma hakkı da ona geçer
/// (herkes kendi adına konuşur). Fotoğraflar galeride toplanır, dokununca
/// lightbox açılır ve kalp ile favorilenir.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({this.now, super.key});

  final DateTime? now;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _jumpToEnd(animate: false),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
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

  void _send() {
    final ChatMessage? message = ref
        .read(gameProvider.notifier)
        .sendMessage(_input.text);
    if (message == null) return;
    _input.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEnd());
  }

  Future<String?> _askCaption(PhotoPreset preset) async {
    final TextEditingController controller = TextEditingController();
    final String? caption = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('${preset.emoji} ${preset.label}'),
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

  Future<_PhotoSource?> _askImageSource() async {
    final TextEditingController source = TextEditingController();
    final TextEditingController caption = TextEditingController();
    String? error;

    final _PhotoSource? result = await showDialog<_PhotoSource>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          void submit() {
            final String value = source.text.trim();
            if (!CouplePhoto.isDataUrl(value) &&
                !CouplePhoto.isHttpUrl(value)) {
              setState(() => error = 'https://… ya da data:image/… bekleniyor');
              return;
            }
            Navigator.of(
              dialogContext,
            ).pop(_PhotoSource(url: value, caption: caption.text.trim()));
          }

          return AlertDialog(
            title: const Text('🖼️ Görsel Ekle'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  key: const Key('photo-source-input'),
                  controller: source,
                  autofocus: true,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'https://… veya data:image/…;base64,…',
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Panoya kopyaladığın görsel bağlantısını ya da base64 '
                  'veri URL’sini yapıştır.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const Key('photo-source-caption'),
                  controller: caption,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Bir not ekle (opsiyonel)',
                  ),
                ),
                if (error != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    error!,
                    key: const Key('photo-source-error'),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Vazgeç'),
              ),
              TextButton(
                key: const Key('photo-source-confirm'),
                onPressed: submit,
                child: const Text('Paylaş'),
              ),
            ],
          );
        },
      ),
    );
    source.dispose();
    caption.dispose();
    return result;
  }

  Future<void> _pickPhoto() async {
    final _PhotoChoice? choice = await showModalBottomSheet<_PhotoChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
      builder: (BuildContext sheetContext) => const _PhotoPresetSheet(),
    );
    if (choice == null || !mounted) return;

    if (choice.kind == _PhotoChoiceKind.scheduleProof) {
      final ChatMessage? proof = ref
          .read(gameProvider.notifier)
          .sendScheduleProof();
      if (proof == null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Aktif ya da sıradaki plan bulunamadı 📅'),
              duration: Duration(seconds: 2),
            ),
          );
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEnd());
      return;
    }

    if (choice.kind == _PhotoChoiceKind.image) {
      final _PhotoSource? picked = await _askImageSource();
      if (picked == null || !mounted) return;
      ref
          .read(gameProvider.notifier)
          .sendPhoto(photoDataOrUrl: picked.url, caption: picked.caption);
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEnd());
      return;
    }

    final PhotoPreset? preset = choice.preset;
    if (preset == null) return;
    final String? caption = await _askCaption(preset);
    if (caption == null || !mounted) return;
    ref
        .read(gameProvider.notifier)
        .sendPhoto(photoDataOrUrl: preset.source, caption: caption);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEnd());
  }

  @override
  Widget build(BuildContext context) {
    final GameState state = ref.watch(gameProvider);
    final CoupleState couple = state.couple;

    ref.listen<GameState>(gameProvider, (GameState? previous, GameState next) {
      if (previous?.couple.messages.length != next.couple.messages.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEnd());
      }
    });

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
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                    AppSpacing.md,
                  ),
                  child: Row(
                    children: <Widget>[
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
                      Material(
                        color: AppColors.surface,
                        borderRadius: AppRadii.pillAll,
                        child: InkWell(
                          key: const Key('open-album'),
                          onTap: () => showMemoryAlbum(context),
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
                ),
                Expanded(child: _buildMessages(state, couple)),
                _ChatComposer(
                  controller: _input,
                  onSend: _send,
                  onPhoto: _pickPhoto,
                  onNudge: () {
                    final ChatMessage? message = ref
                        .read(gameProvider.notifier)
                        .nudgePartner();
                    if (message == null) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text('💫 Dürtme gönderildi · +10 XP'),
                          duration: Duration(seconds: 2),
                        ),
                      );
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

  Widget _buildMessages(GameState state, CoupleState couple) {
    if (couple.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text(
            'Henüz mesaj yok. İlk mesajı sen yaz 💌',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.sm,
        AppSpacing.xxl,
        AppSpacing.md,
      ),
      itemCount: couple.messages.length,
      itemBuilder: (BuildContext context, int index) {
        final ChatMessage message = couple.messages[index];
        return _MessageBubble(
          key: ValueKey<String>('chat-${message.id}'),
          message: message,
          isMine: message.senderId == state.activePartnerId,
          onLike: () => ref.read(gameProvider.notifier).likeMessage(message.id),
          onPhotoTap: () => showPhotoLightbox(context, message),
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
    required this.onPhotoTap,
    super.key,
  });

  final ChatMessage message;
  final bool isMine;
  final VoidCallback onLike;
  final VoidCallback onPhotoTap;

  static String _two(int value) => value.toString().padLeft(2, '0');

  String get _timeLabel =>
      '${FormatX.shortDate(message.createdAt)} · '
      '${_two(message.createdAt.hour)}:${_two(message.createdAt.minute)}';

  @override
  Widget build(BuildContext context) {
    final bool hasPhoto =
        message.hasPhoto && (message.photoDataOrUrl ?? '').isNotEmpty;
    final Color textColor = isMine
        ? AppColors.textOnAccent
        : AppColors.textPrimary;
    final Color mutedColor = isMine
        ? AppColors.textOnAccent.withValues(alpha: 0.85)
        : AppColors.textTertiary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (!isMine) ...<Widget>[
            _Avatar(partnerId: message.senderId),
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
                  padding: hasPhoto
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
                    border: isMine ? null : Border.all(color: AppColors.border),
                    boxShadow: AppShadows.card,
                  ),
                  child: hasPhoto
                      ? _photoBody()
                      : _textBody(textColor, mutedColor),
                ),
                const SizedBox(height: 2),
                Text(
                  _timeLabel,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (isMine) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            _Avatar(partnerId: message.senderId),
          ],
        ],
      ),
    );
  }

  Widget _photoBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Stack(
          children: <Widget>[
            GestureDetector(
              onTap: onPhotoTap,
              child: CouplePhoto(
                source: message.photoDataOrUrl ?? '',
                height: 168,
                caption: null,
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
        if ((message.photoCaption ?? '').isNotEmpty)
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.partnerId});

  final String partnerId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: CouplePalette.softOf(partnerId),
        shape: BoxShape.circle,
      ),
      child: Text(
        CouplePalette.emojiOf(partnerId),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.onSend,
    required this.onPhoto,
    required this.onNudge,
    required this.onLoveNote,
  });

  final TextEditingController controller;
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
                    emoji: '📸',
                    label: 'Anı ekle',
                    onTap: onPhoto,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const Key('chat-input'),
                    controller: controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ceyda\'ya bir şey yaz…',
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

class _PhotoPresetSheet extends ConsumerWidget {
  const _PhotoPresetSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GameState state = ref.watch(gameProvider);
    final DateTime now = DateTime.now();
    final ScheduleBlock? block =
        state.couple.currentBlockFor(state.activePartnerId, now) ??
        state.couple.nextBlockFor(state.activePartnerId, now);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.lg,
          AppSpacing.xxl,
          AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Anı ekle',
              style: AppTypography.title.copyWith(
                color: AppColors.textPrimary,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Planından kanıt gönder, görsel bağlantısı ekle ya da hazır '
              'anı kartlarından birini seç.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _GhostAction(
              key: const Key('send-schedule-proof'),
              emoji: '📅',
              title: 'Şu Anki Planımdan Kanıt Kartı Gönder',
              subtitle: block == null
                  ? 'Önce haftalık plana bir blok ekle'
                  : '${block.weekdayShortLabel} · ${block.timeRangeLabel} · '
                        '${block.category.emoji} ${block.category.shortLabel}',
              accent: AppColors.primary,
              enabled: block != null,
              onTap: () =>
                  Navigator.of(context).pop(const _PhotoChoice.proof()),
            ),
            const SizedBox(height: AppSpacing.sm),
            _GhostAction(
              key: const Key('pick-photo-source'),
              emoji: '🖼️',
              title: 'Görsel Bağlantısı / Base64 Ekle',
              subtitle: 'https://… ya da data:image/… yapıştır',
              accent: AppColors.info,
              onTap: () =>
                  Navigator.of(context).pop(const _PhotoChoice.image()),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Hazır anı kartları',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: AppSpacing.xs + 1),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: PhotoPreset.all.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 1.05,
              ),
              itemBuilder: (BuildContext context, int index) {
                final PhotoPreset preset = PhotoPreset.all[index];
                return GestureDetector(
                  key: Key('preset-${preset.id}'),
                  onTap: () =>
                      Navigator.of(context).pop(_PhotoChoice.preset(preset)),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: preset.gradient,
                      borderRadius: AppRadii.mdAll,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          preset.emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          preset.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textOnAccent,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

enum _PhotoChoiceKind { preset, image, scheduleProof }

/// Anı ekleme sayfasının dönüş değeri.
final class _PhotoChoice {
  const _PhotoChoice.preset(this.preset) : kind = _PhotoChoiceKind.preset;
  const _PhotoChoice.image() : kind = _PhotoChoiceKind.image, preset = null;
  const _PhotoChoice.proof()
    : kind = _PhotoChoiceKind.scheduleProof,
      preset = null;

  final _PhotoChoiceKind kind;
  final PhotoPreset? preset;
}

/// Panodan/yapıştırmayla eklenen görselin adresi ve notu.
final class _PhotoSource {
  const _PhotoSource({required this.url, this.caption = ''});

  final String url;
  final String caption;
}

class _GhostAction extends StatelessWidget {
  const _GhostAction({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadii.mdAll,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: AppRadii.mdAll,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.06),
              borderRadius: AppRadii.mdAll,
              border: Border.all(color: accent.withValues(alpha: 0.32)),
            ),
            child: Row(
              children: <Widget>[
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
