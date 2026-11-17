import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

/// Beyaz, ince kenarlıklı ve yumuşak gölgeli standart yüzey.
///
/// Aydınlık temanın temel taşı: her kart aynı "fizik"i paylaşır, yalnızca
/// isteğe bağlı renk tonu / gradient / gölge değişir.
class SoftCard extends StatelessWidget {
  const SoftCard({
    required this.child,
    this.padding = AppSpacing.card,
    this.color,
    this.borderColor,
    this.gradient,
    this.shadows,
    this.radius,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final Gradient? gradient;
  final List<BoxShadow>? shadows;
  final BorderRadius? radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = radius ?? AppRadii.card;
    final BoxDecoration decoration = BoxDecoration(
      color: gradient == null ? (color ?? AppColors.surface) : null,
      gradient: gradient,
      borderRadius: borderRadius,
      border: Border.all(color: borderColor ?? AppColors.border),
      boxShadow: shadows ?? AppShadows.card,
    );

    final Widget content = Padding(padding: padding, child: child);

    if (onTap == null) {
      return DecoratedBox(decoration: decoration, child: content);
    }

    return DecoratedBox(
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: content,
        ),
      ),
    );
  }
}
