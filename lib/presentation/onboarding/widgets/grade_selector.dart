import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// Sınıf seçimi için 1-4 arası numaralı segment butonlar.
class GradeSelector extends StatelessWidget {
  const GradeSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int grade = 1; grade <= 4; grade++)
          Expanded(
            child: Semantics(
              button: true,
              selected: value == grade,
              label: '$grade. sınıf',
              child: Padding(
                padding: EdgeInsets.only(right: grade == 4 ? 0 : AppSpacing.sm),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: AppRadii.mdAll,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onChanged(grade),
                    child: AnimatedContainer(
                      duration: AppMotion.fast,
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: value == grade
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : AppColors.surface,
                        borderRadius: AppRadii.mdAll,
                        border: Border.all(
                          color: value == grade
                              ? AppColors.primary
                              : AppColors.border,
                          width: value == grade ? 1.5 : 1,
                        ),
                        boxShadow: value == grade
                            ? AppShadows.selected(AppColors.primary)
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '$grade',
                            style: AppTypography.numeric.copyWith(
                              color: value == grade
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'sınıf',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textTertiary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Karakter avatarı: isim baş harfleri, gradient daire.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    required this.name,
    this.size = 56,
    this.gradient = AppGradients.primary,
    super.key,
  });

  final String name;
  final double size;
  final Gradient gradient;

  String get _initials {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return 'L';
    if (parts.length == 1) {
      final String single = parts.first;
      return (single.length >= 2 ? single.substring(0, 2) : single)
          .toUpperCase();
    }
    final String first = parts.first.substring(0, 1);
    final String last = parts.last.substring(0, 1);
    return '$first$last'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: gradient,
        shape: BoxShape.circle,
        boxShadow: AppShadows.glow(
          AppColors.primary,
          opacity: 0.28,
          blur: 18,
          offset: const Offset(0, 8),
        ),
      ),
      child: Text(
        _initials,
        style: AppTypography.numericLarge.copyWith(
          color: AppColors.textOnAccent,
          fontSize: size * 0.34,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
