import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/theme.dart';

/// Tam ekran ayar alt sayfalarının ortak iOS-tarzı iskeleti.
///
/// Başlık ve geri düğmesi her sayfada aynı yerde durur; içerik telefonlarda
/// tek sütun, geniş ekranlarda ortalanmış okunabilir bir sütun olarak akar.
class SettingsPageScaffold extends StatelessWidget {
  const SettingsPageScaffold({
    required this.title,
    required this.children,
    this.subtitle,
    this.backKey = const Key('settings-back'),
    this.trailing,
    this.pageKey,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Key backKey;
  final Widget? trailing;
  final Key? pageKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: pageKey,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          key: backKey,
          tooltip: 'Geri',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.title.copyWith(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
          ],
        ),
        actions: <Widget>[
          ?trailing,
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppConstants.maxContentWidth,
            ),
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.sm,
                AppSpacing.xxl,
                AppSpacing.huge,
              ),
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}
