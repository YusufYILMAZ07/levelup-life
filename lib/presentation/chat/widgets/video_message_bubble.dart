import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/platform/local_media.dart';
import '../../../core/theme/theme.dart';
import '../../../domain/entities/entities.dart';

/// Sohbet içindeki gerçek video balonu.
///
/// * ilk karede duraklar (veri tasarrufu),
/// * ortadaki butonla oynat/duraklat,
/// * dokununca tam ekran oynatıcı açılır ([onOpenFullscreen]).
class VideoMessageBubble extends StatefulWidget {
  const VideoMessageBubble({
    required this.message,
    required this.onOpenFullscreen,
    this.height = 168,
    super.key,
  });

  final ChatMessage message;
  final VoidCallback onOpenFullscreen;
  final double height;

  @override
  State<VideoMessageBubble> createState() => _VideoMessageBubbleState();
}

class _VideoMessageBubbleState extends State<VideoMessageBubble> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant VideoMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Medya değiştiyse (örn. yükleme sonrası URL) oynatıcıyı tazele.
    if (oldWidget.message.mediaPathOrUrl != widget.message.mediaPathOrUrl) {
      final VideoPlayerController? previous = _controller;
      _controller = null;
      unawaited(previous?.dispose());
      setState(() {
        _loading = true;
        _failed = false;
      });
      _init();
    }
  }

  Future<void> _init() async {
    if (!mounted) return;
    final String source = widget.message.mediaPathOrUrl ?? '';
    if (source.trim().isEmpty) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    try {
      final VideoPlayerController controller = isLocalMediaPath(source)
          ? createLocalVideoController(source)
          : VideoPlayerController.networkUrl(Uri.parse(source));
      await controller.initialize();
      await controller.setLooping(false);
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

  Future<void> _togglePlay() async {
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
    if (mounted) setState(() {});
  }

  String get _durationLabel {
    final VideoPlayerController? controller = _controller;
    final Duration duration =
        controller?.value.duration ??
        Duration(seconds: widget.message.durationSeconds);
    if (duration.inSeconds <= 0) return 'Video';
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds % 60;
    return minutes > 0
        ? '$minutes:${seconds.toString().padLeft(2, '0')}'
        : '0:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onOpenFullscreen,
      child: ClipRRect(
        borderRadius: AppRadii.mdAll,
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0xFF1E293B), Color(0xFF475569)],
                  ),
                ),
              ),
              if (_failed)
                const _VideoFallback()
              else if (_loading)
                const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.textOnAccent,
                    ),
                  ),
                )
              else if (_controller != null)
                FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _controller!.value.size.width == 0
                        ? 320
                        : _controller!.value.size.width,
                    height: _controller!.value.size.height == 0
                        ? 180
                        : _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              Positioned(
                left: AppSpacing.xs,
                bottom: AppSpacing.xs,
                child: _Badge(text: '🎥 $_durationLabel'),
              ),
              if (!_loading && !_failed)
                Center(
                  child: Material(
                    color: AppColors.shadow.withValues(alpha: 0.36),
                    shape: const CircleBorder(),
                    child: InkWell(
                      key: Key('video-toggle-${widget.message.id}'),
                      customBorder: const CircleBorder(),
                      onTap: _togglePlay,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm + 2),
                        child: Icon(
                          _controller?.value.isPlaying ?? false
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: AppColors.textOnAccent,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.shadow.withValues(alpha: 0.45),
        borderRadius: AppRadii.pillAll,
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: AppColors.textOnAccent,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _VideoFallback extends StatelessWidget {
  const _VideoFallback();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.videocam_off_rounded,
            color: AppColors.textOnAccent,
            size: 26,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Video şu an oynatılamıyor',
            style: AppTypography.caption.copyWith(
              color: AppColors.textOnAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
