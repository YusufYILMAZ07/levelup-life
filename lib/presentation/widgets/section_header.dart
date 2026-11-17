import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

/// Bölüm başlığı: sol tarafta başlık + opsiyonel alt başlık, sağda eylem.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.md),
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: AppTypography.title.copyWith(color: AppColors.textPrimary),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Küçük, renkli bilgi etiketi (stat kodu, süre, enerji modu…).
class InfoPill extends StatelessWidget {
  const InfoPill({
    required this.label,
    this.color = AppColors.textSecondary,
    this.icon,
    this.background,
    this.iconSize = 13,
    this.dense = false,
    super.key,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final Color? background;
  final double iconSize;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : AppSpacing.md,
        vertical: dense ? AppSpacing.xxs + 1 : AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.10),
        borderRadius: AppRadii.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: iconSize, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// İkon madalyonu: gradient zemin + beyaz ikon (stat, hedef, rol kartları).
class Medallion extends StatelessWidget {
  const Medallion({
    required this.icon,
    required this.gradient,
    this.size = 44,
    this.iconSize = 22,
    this.radius,
    super.key,
  });

  final IconData icon;
  final Gradient gradient;
  final double size;
  final double iconSize;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius ?? size * 0.34),
        boxShadow: AppShadows.glow(
          AppColors.primary,
          opacity: 0.18,
          blur: 12,
          offset: const Offset(0, 6),
        ),
      ),
      child: Icon(icon, size: iconSize, color: AppColors.textOnAccent),
    );
  }
}
