import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../application/game_controller.dart';
import '../../../core/platform/local_media.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/format_x.dart';
import '../../../domain/entities/entities.dart';
import '../../widgets/partner_avatar.dart';
import 'couple_photo.dart';

/// Fotoğrafı / videoyu tam ekran (lightbox) açar.
///
/// * Fotoğraf → [InteractiveViewer] ile iki parmakla yakınlaştırma
/// * Video → tam ekran oynatıcı + ilerleme çubuğu
/// * Kalp ile beğeni anında kaydedilir.
Future<void> showPhotoLightbox(BuildContext context, ChatMessage message) {
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.scrim,
    builder: (BuildContext dialogContext) =>
        _PhotoLightbox(messageId: message.id),
  );
}

/// Anı albümü: Tümü / Fotoğraflar / Videolar / Plan Kanıtları.
Future<void> showMemoryAlbum(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
    builder: (BuildContext sheetContext) => const _MemoryAlbumSheet(),
  );
}

class _PhotoLightbox extends ConsumerWidget {
  const _PhotoLightbox({required this.messageId});

  final String messageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CoupleState couple = ref.watch(coupleStateProvider);
    final ChatMessage? found = couple.messageById(messageId);
    if (found == null) return const SizedBox.shrink();
    final ChatMessage current = found;
    final Color accent = CouplePalette.colorOf(current.senderId);
    final bool isVideo = current.hasVideo;

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Stack(
              children: <Widget>[
                if (isVideo)
                  _FullscreenVideoPlayer(
                    message: current,
                    height: 320,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadii.lg),
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadii.lg),
                    ),
                    child: InteractiveViewer(
                      key: const Key('lightbox-zoom'),
                      minScale: 1,
                      maxScale: 4,
                      clipBehavior: Clip.hardEdge,
                      child: CouplePhoto(
                        source: current.photoDataOrUrl ?? '',
                        height: 320,
                        borderRadius: BorderRadius.zero,
                        imageCacheWidth: null,
                      ),
                    ),
                  ),
                Positioned(
                  right: AppSpacing.sm,
                  top: AppSpacing.sm,
                  child: IconButton(
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textOnAccent,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.shadow.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                if (current.isProof)
                  Positioned(
                    left: AppSpacing.sm,
                    top: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.shadow.withValues(alpha: 0.35),
                        borderRadius: AppRadii.pillAll,
                      ),
                      child: Text(
                        '📅 Plan Kanıtı',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textOnAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      PartnerAvatar(partnerId: current.senderId, size: 28),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '${CouplePalette.nameOf(current.senderId)} · '
                          '${FormatX.shortDate(current.createdAt)}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('lightbox-like'),
                        onPressed: () => ref
                            .read(gameProvider.notifier)
                            .likeMessage(current.id),
                        icon: Icon(
                          current.isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: current.isLiked
                              ? accent
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  if ((current.photoCaption ?? '').isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      current.photoCaption!,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                  if (!isVideo) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'İki parmakla yakınlaştırabilirsin 🔍',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Anı albümü filtreleri (anahtar adları geriye dönük uyumludur).
enum _AlbumFilter {
  all('Tümü', '✨'),
  proofs('Plan & Görev Kanıtları', '📅'),
  memories('Çift Anılarımız', '💑'),
  videos('Videolar', '🎥');

  const _AlbumFilter(this.label, this.emoji);

  final String label;
  final String emoji;

  bool matches(ChatMessage message) => switch (this) {
    _AlbumFilter.all => true,
    _AlbumFilter.memories => !message.isProof && !message.hasVideo,
    _AlbumFilter.videos => message.hasVideo,
    _AlbumFilter.proofs => message.isProof,
  };
}

class _MemoryAlbumSheet extends ConsumerStatefulWidget {
  const _MemoryAlbumSheet();

  @override
  ConsumerState<_MemoryAlbumSheet> createState() => _MemoryAlbumSheetState();
}

class _MemoryAlbumSheetState extends ConsumerState<_MemoryAlbumSheet> {
  _AlbumFilter _filter = _AlbumFilter.all;

  @override
  Widget build(BuildContext context) {
    final CoupleState couple = ref.watch(coupleStateProvider);
    final List<ChatMessage> all = couple.photoMessages;
    final List<ChatMessage> photos = all
        .where(_filter.matches)
        .toList(growable: false);

    return SafeArea(
      top: false,
      child: Padding(
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
              'Anı Albümü',
              style: AppTypography.title.copyWith(
                color: AppColors.textPrimary,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Ortak fotoğraf & video galerimiz',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${photos.length}/${all.length} kare · '
              '${couple.likedPhotoCount} favori',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs + 1,
              runSpacing: AppSpacing.xs + 1,
              children: <Widget>[
                for (final _AlbumFilter filter in _AlbumFilter.values)
                  _AlbumFilterChip(
                    key: Key('album-filter-${filter.name}'),
                    filter: filter,
                    selected: _filter == filter,
                    count: all.where(filter.matches).length,
                    onTap: () => setState(() => _filter = filter),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (photos.isEmpty)
              Text(
                switch (_filter) {
                  _AlbumFilter.proofs =>
                    'Henüz kanıt yok. Haftalık plandan ya da sohbetten '
                        '"📅 Kanıt" gönder.',
                  _AlbumFilter.videos =>
                    'Henüz video yok. Sohbetten "🎥 Video" ile ilk klibi '
                        'paylaş.',
                  _AlbumFilter.memories =>
                    'Henüz çekilmiş fotoğraf yok. Kameradan ilk kareyi '
                        'gönder.',
                  _AlbumFilter.all =>
                    'Henüz anı yok. Sohbetten kamerayla ilk kareyi yakala.',
                },
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              )
            else
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: photos.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 0.9,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    final ChatMessage message = photos[index];
                    return GestureDetector(
                      key: Key('album-${message.id}'),
                      onTap: () => showPhotoLightbox(context, message),
                      child: ClipRRect(
                        borderRadius: AppRadii.mdAll,
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            if (message.hasVideo)
                              const _VideoThumb()
                            else
                              CouplePhoto(
                                source: message.photoDataOrUrl ?? '',
                                height: 120,
                              ),
                            if (message.isLiked)
                              const Positioned(
                                right: AppSpacing.xs,
                                top: AppSpacing.xs,
                                child: Icon(
                                  Icons.favorite_rounded,
                                  color: AppColors.textOnAccent,
                                  size: 16,
                                ),
                              ),
                            if (message.hasVideo)
                              Positioned(
                                left: AppSpacing.xs,
                                bottom: AppSpacing.xs,
                                child: _AlbumBadge(
                                  text: '🎥 Video',
                                  color: AppColors.statProductivity,
                                ),
                              )
                            else if (message.isProof)
                              Positioned(
                                left: AppSpacing.xs,
                                bottom: AppSpacing.xs,
                                child: _AlbumBadge(
                                  text: '📅 Kanıt',
                                  color: AppColors.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AlbumFilterChip extends StatelessWidget {
  const _AlbumFilterChip({
    required this.filter,
    required this.selected,
    required this.count,
    required this.onTap,
    super.key,
  });

  final _AlbumFilter filter;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: AppRadii.pillAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.pillAll,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 2,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadii.pillAll,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(filter.emoji, style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
              Text(
                filter.label,
                style: AppTypography.caption.copyWith(
                  color: selected
                      ? AppColors.textOnAccent
                      : AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: AppTypography.caption.copyWith(
                  color: selected
                      ? AppColors.textOnAccent.withValues(alpha: 0.8)
                      : AppColors.textTertiary,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumBadge extends StatelessWidget {
  const _AlbumBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.shadow.withValues(alpha: 0.4),
        borderRadius: AppRadii.pillAll,
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: AppColors.textOnAccent,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _VideoThumb extends StatelessWidget {
  const _VideoThumb();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF1E293B), Color(0xFF64748B)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.play_circle_fill_rounded,
          color: AppColors.textOnAccent,
          size: 34,
        ),
      ),
    );
  }
}

/// Lightbox içindeki tam ekran video oynatıcı (oynat/duraklat + ilerleme).
class _FullscreenVideoPlayer extends StatefulWidget {
  const _FullscreenVideoPlayer({
    required this.message,
    required this.height,
    required this.borderRadius,
  });

  final ChatMessage message;
  final double height;
  final BorderRadius borderRadius;

  @override
  State<_FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<_FullscreenVideoPlayer> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final String source = widget.message.mediaPathOrUrl ?? '';
    try {
      final VideoPlayerController controller = isLocalMediaPath(source)
          ? createLocalVideoController(source)
          : VideoPlayerController.networkUrl(Uri.parse(source));
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final VideoPlayerController? controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      if (controller.value.position >= controller.value.duration) {
        await controller.seekTo(Duration.zero);
      }
      await controller.play();
    }
  }

  String _format(Duration duration) {
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: ColoredBox(
          color: AppColors.shadow,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (_failed)
                Center(
                  child: Text(
                    'Video oynatılamadı 🎥',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textOnAccent,
                    ),
                  ),
                )
              else if (_loading)
                const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.textOnAccent,
                    strokeWidth: 2.4,
                  ),
                )
              else if (_controller != null)
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: _controller!,
                  builder:
                      (
                        BuildContext context,
                        VideoPlayerValue value,
                        Widget? child,
                      ) {
                        final int totalMs = value.duration.inMilliseconds;
                        final int positionMs = value.position.inMilliseconds
                            .clamp(0, totalMs == 0 ? 1 : totalMs);
                        return Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width: value.size.width == 0
                                    ? 320
                                    : value.size.width,
                                height: value.size.height == 0
                                    ? 180
                                    : value.size.height,
                                child: VideoPlayer(_controller!),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: <Color>[
                                      Colors.transparent,
                                      AppColors.shadow.withValues(alpha: 0.65),
                                    ],
                                  ),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    IconButton(
                                      key: const Key('lightbox-video-play'),
                                      onPressed: _toggle,
                                      icon: Icon(
                                        value.isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: AppColors.textOnAccent,
                                      ),
                                    ),
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 2,
                                          thumbShape:
                                              const RoundSliderThumbShape(
                                                enabledThumbRadius: 5,
                                              ),
                                          overlayShape:
                                              const RoundSliderOverlayShape(
                                                overlayRadius: 12,
                                              ),
                                          activeTrackColor: CouplePalette.ceyda,
                                          inactiveTrackColor: AppColors
                                              .textOnAccent
                                              .withValues(alpha: 0.35),
                                          thumbColor: AppColors.textOnAccent,
                                        ),
                                        child: Slider(
                                          key: const Key(
                                            'lightbox-video-slider',
                                          ),
                                          value: positionMs.toDouble(),
                                          max: totalMs == 0
                                              ? 1
                                              : totalMs.toDouble(),
                                          onChanged: totalMs == 0
                                              ? null
                                              : (double next) =>
                                                    _controller!.seekTo(
                                                      Duration(
                                                        milliseconds: next
                                                            .round(),
                                                      ),
                                                    ),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${_format(value.position)} / '
                                      '${_format(value.duration)}',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.textOnAccent,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
