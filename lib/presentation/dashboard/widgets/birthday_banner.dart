import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../domain/entities/entities.dart';
import '../../birthday/birthday_modal.dart';
import '../../widgets/soft_card.dart';

/// Bugün sekmesindeki kompakt doğum günü hapı.
///
/// Doğum günü geldiğinde kutlama moduna geçer; diğer günlerde geri sayım
/// gösterir. Her durumda dokunulunca [showBirthdayExperience] açılır, böylece
/// sürpriz istenen gün yaşanabilir.
class BirthdayBanner extends ConsumerWidget {
  const BirthdayBanner({this.now, super.key});

  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime at = now ?? DateTime.now();
    final SpecialDate next = CoupleSpecialDates.next(at);
    final bool today = next.isToday(at);
    final Color accent = next.partnerId == null
        ? AppColors.streak
        : CouplePalette.colorOf(next.partnerId!);

    return SoftCard(
      key: const Key('special-date-banner'),
      onTap: () => showBirthdayExperience(context),
      gradient: AppGradients.aura(accent, peakOpacity: 0.14),
      borderColor: accent.withValues(alpha: 0.22),
      radius: AppRadii.pillAll,
      shadows: const <BoxShadow>[],
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      child: Row(
        children: <Widget>[
          Text(next.emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: AppSpacing.xs + 1),
          Expanded(
            child: Text(
              next.bannerText(at),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            today ? 'Kutla' : 'Geri sayım',
            maxLines: 1,
            style: AppTypography.caption.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 16, color: accent),
        ],
      ),
    );
  }
}
