import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/game_controller.dart';
import '../../../core/theme/theme.dart';
import '../../../domain/entities/entities.dart';
import '../../widgets/section_header.dart';
import '../../widgets/soft_card.dart';

/// **Kapsüller & Ödüller** sekmesindeki dört anlık duygu kapsülü.
///
/// Her kapsül dokununca Yusuf ve Ceyda'dan sıcak bir not gösterir. Kullanıcı
/// notu olduğu gibi ya da kendi yazdığı metinle sohbete gönderebilir. İçerik
/// tamamen yereldir; internet veya ek veri gerektirmez.
class MoodCapsulesSection extends ConsumerWidget {
  const MoodCapsulesSection({super.key});

  static const List<_MoodCapsule> _capsules = <_MoodCapsule>[
    _MoodCapsule(
      id: 'morale',
      emoji: '💌',
      title: 'Moralin Bozuksa Aç',
      subtitle: 'Bir nefes al, ben buradayım.',
      color: CouplePalette.ceyda,
      notes: <_MoodNote>[
        _MoodNote(
          from: 'Yusuf 💻',
          text:
              'Bugün her şey üst üste gelmiş olabilir. Derin bir nefes al; '
              'seninle gurur duyuyorum. Akşam seni gülümsetecek küçük bir '
              'şey planlayacağım. 💙',
        ),
        _MoodNote(
          from: 'Ceyda 🌸',
          text:
              'Kötü bir gün, kötü bir hayat demek değil. Kendine biraz zaman '
              'ver; ben hep yanındayım. İstersen hiç konuşmadan sadece '
              'oturalım. 🌸',
        ),
      ],
    ),
    _MoodCapsule(
      id: 'missing',
      emoji: '🥰',
      title: 'Beni Özlediysen Aç',
      subtitle: 'Mesafe varsa da kalbim yanında.',
      color: AppColors.primary,
      notes: <_MoodNote>[
        _MoodNote(
          from: 'Yusuf 💻',
          text:
              'Şu an yanında olamasam da aklımın bir köşesinde hep sen '
              'varsın. Bir sonraki buluşmamız için geri sayıyorum. 💫',
        ),
        _MoodNote(
          from: 'Ceyda 🌸',
          text:
              'Seni özledim demek istedim. Gözlerini kapat ve bugünkü '
              'kahvemizi birlikte içtiğimizi hayal et; çok yakında gerçek '
              'olacak. ☕💖',
        ),
      ],
    ),
    _MoodCapsule(
      id: 'motivation',
      emoji: '🔥',
      title: 'Motivasyon Lazımsa Aç',
      subtitle: 'Küçük bir adım yeter.',
      color: AppColors.streak,
      notes: <_MoodNote>[
        _MoodNote(
          from: 'Yusuf 💻',
          text:
              'Bugünün tek hedefi dünkü halinden bir adım ileri gitmek. '
              'Mükemmel olmak zorunda değilsin; devam etmen yeter. Hadi '
              'bir tane daha! 💪',
        ),
        _MoodNote(
          from: 'Ceyda 🌸',
          text:
              'Unutma, birlikte çok daha güçlüyüz. Sen kendi yolunda '
              'ilerlerken ben de senin arkandayım. Bugün küçük bir zafer '
              'kazan ve gel bana anlat. 🌟',
        ),
      ],
    ),
    _MoodCapsule(
      id: 'birthday',
      emoji: '🎂',
      title: 'Doğum Günü Mektubun',
      subtitle: 'İyi ki doğdun, iyi ki varsın.',
      color: AppColors.xp,
      notes: <_MoodNote>[
        _MoodNote(
          from: 'Yusuf 💻',
          text:
              'İyi ki doğdun sevgilim. Hayatıma kattığın her renk için, '
              'gülüşün için ve bana kendimi daha iyi hissettirdiğin her an '
              'için teşekkür ederim. Bu yıl birlikte daha çok anı '
              'biriktirelim. ❤️',
        ),
        _MoodNote(
          from: 'Ceyda 🌸',
          text:
              'Bu mektup benim için saklı bir hazine. Seninle geçen her yaş '
              'daha güzel. Nice mutlu, sağlıklı ve bizimle dolu yıllara! '
              '🎂✨',
        ),
      ],
    ),
  ];

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    _MoodCapsule capsule,
  ) async {
    final String? note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
      builder: (BuildContext sheetContext) =>
          _MoodCapsuleSheet(capsule: capsule),
    );
    final String text = (note ?? '').trim();
    if (text.isEmpty || !context.mounted) return;

    final ChatMessage? sent = ref
        .read(gameProvider.notifier)
        .sendLoveMessage(text);
    if (sent == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${capsule.emoji} Notun sohbete düştü 💌'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  /// Tek kapsül kartı: iki sütunda eşit yükseklik, içerik kadar yer kaplar.
  Widget _capsuleTile(
    BuildContext context,
    WidgetRef ref,
    _MoodCapsule capsule,
  ) {
    return SoftCard(
      key: Key('mood-capsule-${capsule.id}'),
      onTap: () => _open(context, ref, capsule),
      padding: const EdgeInsets.all(AppSpacing.md),
      gradient: AppGradients.aura(capsule.color, peakOpacity: 0.13),
      borderColor: capsule.color.withValues(alpha: 0.24),
      shadows: const <BoxShadow>[],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(capsule.emoji, style: const TextStyle(fontSize: 21)),
              const Spacer(),
              Icon(
                Icons.lock_open_rounded,
                size: 14,
                color: capsule.color.withValues(alpha: 0.70),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            capsule.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.subtitle.copyWith(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            capsule.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              fontSize: 9.5,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          title: 'Anlık Duygu Kapsülleri',
          subtitle: 'Zor bir gün mü? Doğru kapsülü aç.',
        ),
        // 360×640 + 1.3× yazı ölçeğinde sabit `childAspectRatio` taşma
        // üretiyordu; kartlar artık içeriğe göre büyür (IntrinsicHeight).
        for (int i = 0; i < _capsules.length; i += 2) ...<Widget>[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: _capsuleTile(context, ref, _capsules[i])),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: i + 1 < _capsules.length
                      ? _capsuleTile(context, ref, _capsules[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Duygu kapsülünün açtığı sıcak not sayfası.
class _MoodCapsuleSheet extends StatefulWidget {
  const _MoodCapsuleSheet({required this.capsule});

  final _MoodCapsule capsule;

  @override
  State<_MoodCapsuleSheet> createState() => _MoodCapsuleSheetState();
}

class _MoodCapsuleSheetState extends State<_MoodCapsuleSheet> {
  final TextEditingController _custom = TextEditingController();

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _send() {
    final String custom = _custom.text.trim();
    Navigator.of(
      context,
    ).pop(custom.isEmpty ? widget.capsule.notes.first.text : custom);
  }

  @override
  Widget build(BuildContext context) {
    final _MoodCapsule capsule = widget.capsule;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.lg,
          AppSpacing.xxl,
          AppSpacing.xxl + MediaQuery.of(context).viewInsets.bottom,
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
                  color: AppColors.border,
                  borderRadius: AppRadii.pillAll,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Text(capsule.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        capsule.title,
                        style: AppTypography.title.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 19,
                        ),
                      ),
                      Text(
                        capsule.subtitle,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('mood-sheet-close'),
                  tooltip: 'Kapat',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final _MoodNote note in capsule.notes)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: SoftCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  color: AppColors.surfaceMuted,
                  shadows: const <BoxShadow>[],
                  borderColor: AppColors.divider,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        note.from,
                        style: AppTypography.caption.copyWith(
                          color: capsule.color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        note.text,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('mood-custom-input'),
              controller: _custom,
              maxLines: 2,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'Kendi notunu yaz (opsiyonel)',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: Key('mood-send-${capsule.id}'),
                onPressed: _send,
                style: FilledButton.styleFrom(
                  backgroundColor: capsule.color,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm + 2,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadii.pillAll,
                  ),
                ),
                child: Text(
                  '💌 Sohbete Gönder',
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Center(
              child: TextButton(
                key: Key('mood-close-${capsule.id}'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kapat'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodCapsule {
  const _MoodCapsule({
    required this.id,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.notes,
  });

  final String id;
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final List<_MoodNote> notes;
}

class _MoodNote {
  const _MoodNote({required this.from, required this.text});

  final String from;
  final String text;
}
