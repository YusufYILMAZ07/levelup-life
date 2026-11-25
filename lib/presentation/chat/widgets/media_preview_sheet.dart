import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/game_controller.dart';
import '../../../core/theme/theme.dart';
import '../../../domain/entities/entities.dart';
import '../../../services/media_service.dart';
import 'couple_photo.dart';
import 'video_message_bubble.dart';

/// Seçilen fotoğraf / videoyu göndermeden önce not ekleme sayfası.
Future<String?> showMediaPreviewSheet(BuildContext context, PickedMedia media) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
    builder: (BuildContext sheetContext) => Consumer(
      builder: (BuildContext context, WidgetRef ref, Widget? child) {
        // Kart, mesajı gönderecek **aktif partnerin** rengini kullanır.
        final String activeId = ref.watch(
          gameProvider.select((state) => state.activePartnerId),
        );
        return _MediaPreviewSheet(
          media: media,
          accent: CouplePalette.colorOf(activeId),
          soft: CouplePalette.softOf(activeId),
        );
      },
    ),
  );
}

class _MediaPreviewSheet extends StatefulWidget {
  const _MediaPreviewSheet({
    required this.media,
    required this.accent,
    required this.soft,
  });

  final PickedMedia media;
  final Color accent;
  final Color soft;

  @override
  State<_MediaPreviewSheet> createState() => _MediaPreviewSheetState();
}

class _MediaPreviewSheetState extends State<_MediaPreviewSheet> {
  final TextEditingController _caption = TextEditingController();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  void _send() => Navigator.of(context).pop(_caption.text.trim());

  @override
  Widget build(BuildContext context) {
    final bool isVideo = widget.media.isVideo;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.sm,
            AppSpacing.xxl,
            AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: AppRadii.pillAll,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      isVideo ? 'Videoyu gönder' : 'Fotoğrafı gönder',
                      style: AppTypography.title.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 19,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: widget.soft,
                      borderRadius: AppRadii.pillAll,
                    ),
                    child: Text(
                      isVideo ? '🎥 Video' : '📷 Fotoğraf',
                      style: AppTypography.caption.copyWith(
                        color: widget.accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Yusuf & Ceyda anı albümüne eklenecek · yalnızca ikimize '
                'görünür.',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (isVideo)
                VideoMessageBubble(
                  message: ChatMessage(
                    id: 'preview',
                    senderId: CouplePartner.yusufId,
                    createdAt: DateTime.now(),
                    photoDataOrUrl: widget.media.source,
                    mediaType: ChatMediaType.video,
                    durationSeconds: widget.media.durationSeconds,
                  ),
                  onOpenFullscreen: () {},
                  height: 220,
                )
              else if (widget.media.source.trim().isEmpty &&
                  widget.media.bytes != null)
                // Web: yükleme öncesi base64/data URL üretilmez; seçilen ham
                // baytlar doğrudan önizlenir.
                ClipRRect(
                  borderRadius: AppRadii.mdAll,
                  child: SizedBox(
                    height: 220,
                    width: double.infinity,
                    child: Image.memory(widget.media.bytes!, fit: BoxFit.cover),
                  ),
                )
              else
                CouplePhoto(source: widget.media.source, height: 220),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('media-caption-input'),
                controller: _caption,
                maxLines: 2,
                maxLength: 180,
                textCapitalization: TextCapitalization.sentences,
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Bir not ekle… (opsiyonel)',
                  hintStyle: AppTypography.body.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceMuted,
                  counterStyle: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                  ),
                  border: const OutlineInputBorder(
                    borderRadius: AppRadii.mdAll,
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: AppRadii.mdAll,
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: AppRadii.mdAll,
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Vazgeç'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      key: const Key('media-send'),
                      onPressed: _send,
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        isVideo ? 'Videoyu Gönder' : 'Fotoğrafı Gönder',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
