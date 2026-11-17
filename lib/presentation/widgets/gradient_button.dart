import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

/// Gradient dolgulu, parıltılı ana eylem butonu.
///
/// Material `ElevatedButton` düz renk boyar; oyun hissi için marka gradient'i
/// + renkli gölge gerektiğinden bu bileşen kullanılır. Erişilebilirlik için
/// `Semantics(button: true)` ve minimum 56px yükseklik korunur.
class GradientButton extends StatelessWidget {
  const GradientButton({
    required this.label,
    this.onPressed,
    this.icon,
    this.gradient,
    this.expand = true,
    this.height = 56,
    this.trailing,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Gradient? gradient;
  final bool expand;
  final double height;

  /// Sağ tarafta küçük bir ek bilgi (ör. "4 görev").
  final Widget? trailing;

  bool get _enabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    final Gradient activeGradient = gradient ?? AppGradients.primary;
    final BorderRadius radius = BorderRadius.circular(18);

    final Widget content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 20, color: AppColors.textOnAccent),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.subtitle.copyWith(
              color: AppColors.textOnAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          trailing!,
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      child: Opacity(
        opacity: _enabled ? 1 : 0.45,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          height: height,
          width: expand ? double.infinity : null,
          decoration: BoxDecoration(
            gradient: activeGradient,
            borderRadius: radius,
            boxShadow: _enabled
                ? AppShadows.glow(
                    AppColors.primary,
                    opacity: 0.32,
                    blur: 22,
                    offset: const Offset(0, 10),
                  )
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              borderRadius: radius,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: expand ? AppSpacing.xl : AppSpacing.xxl,
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Yumuşak (beyaz) ikincil buton — "Geri", "Vazgeç" gibi eylemler.
class SoftButton extends StatelessWidget {
  const SoftButton({
    required this.label,
    this.onPressed,
    this.icon,
    this.color,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: color ?? AppColors.textSecondary,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
    );
  }
}
