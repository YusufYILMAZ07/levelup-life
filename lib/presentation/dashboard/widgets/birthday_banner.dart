import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../domain/entities/entities.dart';
import '../../birthday/birthday_modal.dart';
import '../../widgets/section_header.dart';
import '../../widgets/soft_card.dart';

/// Bugün sekmesindeki doğum günü kartı.
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
    final bool today = BirthdayConfig.ceyda.isToday(at);
    final int daysLeft = BirthdayConfig.ceyda.daysUntil(at);

    return SoftCard(
      onTap: () => showBirthdayExperience(context),
      gradient: AppGradients.aura(CouplePalette.ceyda, peakOpacity: 0.16),
      borderColor: CouplePalette.ceyda.withValues(alpha: 0.25),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          const Medallion(
            icon: Icons.cake_rounded,
            gradient: AppGradients.legendary,
            size: 40,
            iconSize: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  today
                      ? 'Bugün Ceyda\'nın doğum günü 🎂'
                      : 'Ceyda\'nın doğum günü sürprizi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.subtitle.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  today
                      ? 'Kutlamayı aç · mektup ve yılın özeti'
                      : '${BirthdayConfig.ceyda.dateLabel} · '
                            '$daysLeft gün kaldı · dokun',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: CouplePalette.ceyda),
        ],
      ),
    );
  }
}
