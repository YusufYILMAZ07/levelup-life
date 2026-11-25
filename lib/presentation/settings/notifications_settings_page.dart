import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'settings_page_scaffold.dart';
import 'settings_sections.dart';

/// Hatırlatıcılar, sessiz saatler ve test bildirimi.
class NotificationsSettingsPage extends StatelessWidget {
  const NotificationsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsPageScaffold(
      pageKey: Key('notifications-settings-page'),
      backKey: Key('notifications-back'),
      title: 'Bildirimler',
      subtitle: 'Sadece önemli anlarda nazikçe hatırlatalım.',
      children: <Widget>[
        NotificationSection(),
        SizedBox(height: AppSpacing.xxl),
        _NotificationFootnote(),
      ],
    );
  }
}

class _NotificationFootnote extends StatelessWidget {
  const _NotificationFootnote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadii.mdAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Bildirimler cihazında anlık banner olarak görünür. Test '
              'bildirimi partnerinin adıyla gelir; gerçek gönderim için '
              'sohbet veya görev akışını kullanabilirsin.',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
