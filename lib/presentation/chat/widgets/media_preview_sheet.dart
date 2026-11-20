import 'package:flutter/material.dart';

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
    builder: (BuildContext sheetContext) => _MediaPreviewSheet(media: media),
  );
}

class _MediaPreviewSheet extends StatefulWidget {
  const _MediaPreviewSheet({required this.media});

  final PickedMedia media;

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
                      color: CouplePalette.softOf(CouplePartner.ceydaId),
                      borderRadius: AppRadii.pillAll,
                    ),
                    child: Text(
                      isVideo ? '🎥 Video' : '📷 Fotoğraf',
                      style: AppTypography.caption.copyWith(
                        color: CouplePalette.ceyda,
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
