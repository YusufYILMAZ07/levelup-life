import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/game_controller.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/format_x.dart';
import '../../../domain/entities/entities.dart';
import 'couple_photo.dart';

/// Fotoğrafı tam ekran (lightbox) açar; kalp ile beğeni anında kaydedilir.
Future<void> showPhotoLightbox(BuildContext context, ChatMessage message) {
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.scrim,
    builder: (BuildContext dialogContext) =>
        _PhotoLightbox(messageId: message.id),
  );
}

/// Anı albümü: sohbetteki tüm fotoğraflar ızgarada, dokununca lightbox.
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
    ChatMessage? message;
    for (final ChatMessage item in couple.messages) {
      if (item.id == messageId) message = item;
    }
    if (message == null) return const SizedBox.shrink();

    final ChatMessage current = message;
    final Color accent = CouplePalette.colorOf(current.senderId);
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Stack(
              children: <Widget>[
                CouplePhoto(
                  source: current.photoDataOrUrl ?? '',
                  height: 300,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadii.lg),
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
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        CouplePalette.emojiOf(current.senderId),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: AppSpacing.xs),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Anı albümü filtreleri.
enum _AlbumFilter {
  all('Tümü', '📸'),
  proofs('Plan & Görev Kanıtları', '📅'),
  memories('Çift Anılarımız', '💑');

  const _AlbumFilter(this.label, this.emoji);

  final String label;
  final String emoji;

  bool matches(ChatMessage message) => switch (this) {
    _AlbumFilter.all => true,
    _AlbumFilter.proofs => message.kind == ChatMessageKind.proof,
    _AlbumFilter.memories => message.kind != ChatMessageKind.proof,
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
                _filter == _AlbumFilter.proofs
                    ? 'Henüz kanıt yok. Haftalık plandan ya da sohbetten '
                          '"📅 Kanıt" gönder.'
                    : _filter == _AlbumFilter.memories
                    ? 'Henüz çift anısı yok. Sohbetten "📸 Anı" ile ilk '
                          'kareyi ekle.'
                    : 'Henüz fotoğraf yok. Sohbetten "📸 Anı" ile ilk anıyı '
                          'ekle.',
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
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
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
                          if (message.kind == ChatMessageKind.proof)
                            Positioned(
                              left: AppSpacing.xs,
                              bottom: AppSpacing.xs,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.shadow.withValues(
                                    alpha: 0.35,
                                  ),
                                  borderRadius: AppRadii.pillAll,
                                ),
                                child: Text(
                                  '📅 Kanıt',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textOnAccent,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                        ],
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
