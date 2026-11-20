import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/game_controller.dart';
import '../../../application/game_state.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/image_url.dart';
import '../../../domain/entities/entities.dart';
import 'photo_presets.dart';

/// Medya seçim sayfasının dönüş değeri.
enum ChatMediaAction {
  cameraPhoto,
  galleryPhoto,
  imageUrl,
  galleryVideo,
  cameraVideo,
  scheduleProof,
  preset,
}

final class ChatMediaChoice {
  const ChatMediaChoice(this.action, {this.preset, this.url});

  final ChatMediaAction action;
  final PhotoPreset? preset;

  /// [ChatMediaAction.imageUrl] seçildiğinde doğrulanmış görsel bağlantısı.
  final String? url;
}

/// Kamera / galeri / plan kanıtı seçeneklerini sunan temiz alt sayfa.
Future<ChatMediaChoice?> showChatMediaSheet(BuildContext context) {
  return showModalBottomSheet<ChatMediaChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
    builder: (BuildContext sheetContext) => const ChatMediaSheet(),
  );
}

enum VideoSourceChoice { gallery, camera }

/// Video kaynağı (galeri mi kamera mı) seçimi.
Future<VideoSourceChoice?> showVideoSourceSheet(BuildContext context) {
  return showModalBottomSheet<VideoSourceChoice>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
    builder: (BuildContext sheetContext) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            key: const Key('video-gallery'),
            leading: const Text('🎞️', style: TextStyle(fontSize: 22)),
            title: const Text('Galeriden video seç'),
            onTap: () =>
                Navigator.of(sheetContext).pop(VideoSourceChoice.gallery),
          ),
          ListTile(
            key: const Key('video-camera'),
            leading: const Text('🎥', style: TextStyle(fontSize: 22)),
            title: const Text('Kamerayla video çek'),
            subtitle: const Text('En fazla 60 saniye'),
            onTap: () =>
                Navigator.of(sheetContext).pop(VideoSourceChoice.camera),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}

class ChatMediaSheet extends ConsumerWidget {
  const ChatMediaSheet({super.key});

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
              'Bir anı paylaş',
              style: AppTypography.title.copyWith(
                color: AppColors.textPrimary,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Kameradan çek, galeriden seç ya da planından kanıt at. '
              'Her şey yalnızca ikimize görünür.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _MediaTile(
              key: const Key('media-camera-photo'),
              emoji: '📷',
              title: 'Kameradan Fotoğraf Çek',
              subtitle: 'Anı yakala, hemen gönder',
              accent: CouplePalette.ceyda,
              onTap: () => Navigator.of(
                context,
              ).pop(const ChatMediaChoice(ChatMediaAction.cameraPhoto)),
            ),
            const SizedBox(height: AppSpacing.sm),
            _MediaTile(
              key: const Key('media-gallery-photo'),
              emoji: '🖼️',
              title: 'Galeriden Fotoğraf Seç',
              subtitle: 'Telefonundaki karelerden birini paylaş',
              accent: AppColors.info,
              onTap: () => Navigator.of(
                context,
              ).pop(const ChatMediaChoice(ChatMediaAction.galleryPhoto)),
            ),
            const SizedBox(height: AppSpacing.sm),
            _MediaTile(
              key: const Key('media-image-url'),
              emoji: '🔗',
              title: 'Linkten Fotoğraf Yükle',
              subtitle: 'Herkese açık bir görsel bağlantısı yapıştır',
              accent: AppColors.statIntelligence,
              onTap: () async {
                final String? url = await showImageUrlDialog(context);
                if (url == null || !context.mounted) return;
                Navigator.of(
                  context,
                ).pop(ChatMediaChoice(ChatMediaAction.imageUrl, url: url));
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            _MediaTile(
              key: const Key('media-video'),
              emoji: '🎥',
              title: 'Galeriden / Kameradan Video Gönder',
              subtitle: 'En fazla 60 saniye · sesli',
              accent: AppColors.statProductivity,
              onTap: () => Navigator.of(
                context,
              ).pop(const ChatMediaChoice(ChatMediaAction.galleryVideo)),
            ),
            const SizedBox(height: AppSpacing.sm),
            _MediaTile(
              key: const Key('send-schedule-proof'),
              emoji: '📅',
              title: 'Şu Anki Planımdan Kanıt Kartı At',
              subtitle: block == null
                  ? 'Önce haftalık plana bir blok ekle'
                  : '${block.weekdayShortLabel} · ${block.timeRangeLabel} · '
                        '${block.category.emoji} ${block.category.shortLabel}',
              accent: AppColors.primary,
              enabled: block != null,
              onTap: () => Navigator.of(
                context,
              ).pop(const ChatMediaChoice(ChatMediaAction.scheduleProof)),
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
                  onTap: () => Navigator.of(context).pop(
                    ChatMediaChoice(ChatMediaAction.preset, preset: preset),
                  ),
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

class _MediaTile extends StatelessWidget {
  const _MediaTile({
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
    final Color effective = enabled ? accent : AppColors.textTertiary;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadii.mdAll,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: AppRadii.mdAll,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: AppRadii.mdAll,
              border: Border.all(color: effective.withValues(alpha: 0.22)),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[
                  effective.withValues(alpha: 0.08),
                  AppColors.surface,
                ],
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: effective.withValues(alpha: 0.12),
                    borderRadius: AppRadii.smAll,
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: AppTypography.subtitle.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: effective.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kullanıcıdan görsel bağlantısı ister; boş/geçersiz girdiyi kabul etmez.
Future<String?> showImageUrlDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) => const _ImageUrlDialog(),
  );
}

class _ImageUrlDialog extends StatefulWidget {
  const _ImageUrlDialog();

  @override
  State<_ImageUrlDialog> createState() => _ImageUrlDialogState();
}

class _ImageUrlDialogState extends State<_ImageUrlDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String? url = normalizeImageUrl(_controller.text);
    if (url == null) {
      setState(
        () => _error = 'Geçerli bir http(s) görsel bağlantısı yapıştır.',
      );
      return;
    }
    Navigator.of(context).pop(url);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('🔗 Linkten Fotoğraf'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Herkese açık bir görsel bağlantısı ya da data:image adresi yapıştır.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('image-url-input'),
            controller: _controller,
            autofocus: true,
            maxLines: 2,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              hintText: 'https://ornek.com/foto.jpg',
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _error!,
              key: const Key('image-url-error'),
              style: TextStyle(
                color: AppColors.danger,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        TextButton(
          key: const Key('image-url-confirm'),
          onPressed: _submit,
          child: const Text('Ekle'),
        ),
      ],
    );
  }
}
