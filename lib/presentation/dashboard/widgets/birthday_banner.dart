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
    final bool today = BirthdayConfig.ceyda.isToday(at);
    final int daysLeft = BirthdayConfig.ceyda.daysUntil(at);

    return SoftCard(
      onTap: () => showBirthdayExperience(context),
      gradient: AppGradients.aura(CouplePalette.ceyda, peakOpacity: 0.14),
      borderColor: CouplePalette.ceyda.withValues(alpha: 0.22),
      radius: AppRadii.pillAll,
      shadows: const <BoxShadow>[],
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      child: Row(
        children: <Widget>[
          const Text('🎂', style: TextStyle(fontSize: 13)),
          const SizedBox(width: AppSpacing.xs + 1),
          Expanded(
            child: Text(
              today
                  ? 'Bugün Ceyda\'nın doğum günü! 🎉'
                  : 'Ceyda\'nın doğum gününe $daysLeft gün',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: CouplePalette.ceyda,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            today ? 'Kutla' : 'Sürpriz',
            maxLines: 1,
            style: AppTypography.caption.copyWith(
              color: CouplePalette.ceyda,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 16,
            color: CouplePalette.ceyda,
          ),
        ],
      ),
    );
  }
}
