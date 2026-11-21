import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/platform/local_media.dart';
import '../../../core/theme/theme.dart';
import 'photo_presets.dart';

/// `ChatMessage.photoDataOrUrl` değerini görsele çeviren ortak yüzey.
///
/// Üç biçimi destekler:
/// * `preset:<id>` → gradient + emoji anı kartı
/// * `data:image/…;base64,…` → gömülü görsel
/// * `http(s)://…` → uzak görsel
class CouplePhoto extends StatelessWidget {
  const CouplePhoto({
    required this.source,
    this.caption,
    this.height = 190,
    this.borderRadius,
    this.imageCacheWidth = 600,
    super.key,
  });

  final String source;
  final String? caption;
  final double height;
  final BorderRadius? borderRadius;

  /// Sohbet/albüm küçük görselleri 600 px'e çözülür. Lightbox `null` geçerek
  /// tam çözünürlüklü görüntüyü `InteractiveViewer` içinde açar.
  final int? imageCacheWidth;

  static bool isDataUrl(String source) => source.startsWith('data:image/');

  static bool isHttpUrl(String source) =>
      source.startsWith('http://') || source.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = borderRadius ?? AppRadii.mdAll;
    final PhotoPreset? preset = PhotoPreset.fromSource(source);

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (preset != null)
              _PresetSurface(preset: preset)
            else if (isDataUrl(source))
              _MemorySurface(dataUrl: source, cacheWidth: imageCacheWidth)
            else if (isHttpUrl(source))
              Image.network(
                source,
                fit: BoxFit.cover,
                cacheWidth: imageCacheWidth,
                errorBuilder: (_, _, _) => const _PhotoFallback(),
                loadingBuilder:
                    (
                      BuildContext context,
                      Widget child,
                      ImageChunkEvent? progress,
                    ) => progress == null ? child : const _PhotoFallback(),
              )
            else if (isLocalMediaPath(source))
              _LocalFileSurface(path: source, cacheWidth: imageCacheWidth)
            else
              const _PhotoFallback(),
            if (caption != null && caption!.trim().isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.transparent,
                        AppColors.shadow.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: Text(
                      caption!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textOnAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PresetSurface extends StatelessWidget {
  const _PresetSurface({required this.preset});

  final PhotoPreset preset;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: preset.gradient),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -20,
            top: -20,
            child: Text(
              preset.emoji,
              style: TextStyle(
                fontSize: 96,
                color: Colors.white.withValues(alpha: 0.22),
              ),
            ),
          ),
          Center(
            child: Text(preset.emoji, style: const TextStyle(fontSize: 44)),
          ),
          Positioned(
            left: AppSpacing.md,
            top: AppSpacing.md,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.shadow.withValues(alpha: 0.24),
                borderRadius: AppRadii.pillAll,
              ),
              child: Text(
                preset.label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textOnAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemorySurface extends StatelessWidget {
  const _MemorySurface({required this.dataUrl, this.cacheWidth});

  final String dataUrl;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    try {
      final int comma = dataUrl.indexOf(',');
      final String encoded = comma < 0 ? dataUrl : dataUrl.substring(comma + 1);
      return Image.memory(
        base64Decode(encoded),
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) => const _PhotoFallback(),
      );
    } on FormatException {
      return const _PhotoFallback();
    }
  }
}

/// iOS / Android'de uygulamanın `media/` klasöründen okunan gerçek fotoğraf.
class _LocalFileSurface extends StatelessWidget {
  const _LocalFileSurface({required this.path, this.cacheWidth});

  final String path;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final ImageProvider<Object>? provider = localImageProvider(path);
    if (provider == null) return const _PhotoFallback();
    return Image(
      image: cacheWidth == null
          ? provider
          : ResizeImage.resizeIfNeeded(cacheWidth, null, provider),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const _PhotoFallback(),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.surfaceSunken),
      child: Center(
        child: Icon(
          Icons.image_not_supported_rounded,
          color: AppColors.textTertiary,
          size: 28,
        ),
      ),
    );
  }
}
