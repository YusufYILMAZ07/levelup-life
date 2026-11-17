import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import '../../core/utils/format_x.dart';

/// Kalın, tam yuvarlatılmış, gradient dolgulu ve "parlayan" XP çubuğu.
///
/// Dolum animasyonu bir kez çalışır (sonsuz animasyon yok → testlerde
/// `pumpAndSettle` takılmaz). Değer arttığında shimmer bir kez süpürülür.
class XpBar extends StatefulWidget {
  const XpBar({
    required this.value,
    this.height = 16,
    this.gradient = AppGradients.xpBar,
    this.glowColor = AppColors.primary,
    this.trackColor = AppColors.surfaceSunken,
    this.trackBorderColor = AppColors.border,
    this.animate = true,
    this.showShimmer = true,
    this.showEndCap = true,
    super.key,
  }) : assert(value >= 0, 'İlerleme negatif olamaz');

  /// 0.0 → 1.0 arası ilerleme.
  final double value;

  /// Çubuk kalınlığı (brief: 14-18px).
  final double height;

  final Gradient gradient;
  final Color glowColor;
  final Color trackColor;
  final Color trackBorderColor;
  final bool animate;
  final bool showShimmer;
  final bool showEndCap;

  @override
  State<XpBar> createState() => _XpBarState();
}

class _XpBarState extends State<XpBar> with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _shimmer.forward();
  }

  @override
  void didUpdateWidget(covariant XpBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && widget.value > oldWidget.value + 0.0001) {
      _shimmer.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double target = widget.value.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: widget.animate ? 0 : target, end: target),
      duration: widget.animate ? AppMotion.xpFill : Duration.zero,
      curve: AppMotion.emphasize,
      builder: (BuildContext context, double value, Widget? child) {
        return SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double fillWidth =
                  (constraints.maxWidth * value).clamp(0.0, constraints.maxWidth);
              final BorderRadius radius =
                  BorderRadius.circular(widget.height / 2);
              return Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.trackColor,
                        borderRadius: radius,
                        border: Border.all(color: widget.trackBorderColor),
                      ),
                    ),
                  ),
                  if (fillWidth > 0)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: fillWidth,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: widget.gradient,
                          borderRadius: radius,
                          boxShadow: AppShadows.glow(
                            widget.glowColor,
                            opacity: 0.38,
                            blur: 16,
                            offset: const Offset(0, 5),
                          ),
                        ),
                      ),
                    ),
                  if (fillWidth > 0 && widget.showShimmer)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: fillWidth,
                      child: IgnorePointer(
                        child: ClipRRect(
                          borderRadius: radius,
                          child: AnimatedBuilder(
                            animation: _shimmer,
                            builder: (BuildContext context, Widget? _) {
                              final double progress = _shimmer.value;
                              return Stack(
                                children: <Widget>[
                                  Positioned(
                                    left: (progress * 2.2 - 1.1) * fillWidth,
                                    top: 0,
                                    bottom: 0,
                                    width: fillWidth * 0.55,
                                    child: const DecoratedBox(
                                      decoration:
                                          BoxDecoration(gradient: AppGradients.sheen),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  if (fillWidth > widget.height * 0.9 && widget.showEndCap)
                    Positioned(
                      left: fillWidth - widget.height * 0.62,
                      top: widget.height * 0.26,
                      child: IgnorePointer(
                        child: Container(
                          width: widget.height * 0.42,
                          height: widget.height * 0.42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),

                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// "450 / 1.000 XP" + "%45" etiketleri — barın hemen üstünde kullanılır.
class XpSummaryLabels extends StatelessWidget {
  const XpSummaryLabels({
    required this.current,
    required this.total,
    this.onDark = false,
    this.accent,
    super.key,
  });

  final int current;
  final int total;
  final bool onDark;
  final Color? accent;

  int get percent => total <= 0 ? 0 : ((current / total) * 100).round();

  @override
  Widget build(BuildContext context) {
    final Color primary =
        onDark ? AppColors.textOnAccent : (accent ?? AppColors.textPrimary);
    final Color secondary = onDark
        ? AppColors.textOnAccent.withValues(alpha: 0.75)
        : AppColors.textTertiary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Flexible(
          child: Text(
            FormatX.xpPair(current, total),
            overflow: TextOverflow.ellipsis,
            style: AppTypography.numericSmall.copyWith(color: secondary),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '%$percent',
          style: AppTypography.numericSmall.copyWith(
            color: primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
