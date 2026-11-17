import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_gradients.dart';
import 'app_shadows.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Uygulamanın tek tema giriş noktası — **aydınlık** varyant.
///
/// Renk, tipografi, buton ve input stilleri burada merkezîleştirilir; hiçbir
/// ekran kendi `ThemeData`'sını üretmez. Koyu tema tamamen kaldırıldı: uygulama
/// her zaman `AppTheme.light()` ile açılır.
abstract final class AppTheme {
  static ThemeData light() {
    const ColorScheme scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.textOnAccent,
      primaryContainer: Color(0xFFEEF2FF),
      onPrimaryContainer: Color(0xFF312E81),
      secondary: AppColors.accentBlue,
      onSecondary: AppColors.textOnAccent,
      secondaryContainer: Color(0xFFE0F2FE),
      onSecondaryContainer: Color(0xFF075985),
      tertiary: AppColors.primaryBright,
      onTertiary: AppColors.textOnAccent,
      tertiaryContainer: Color(0xFFF3E8FF),
      onTertiaryContainer: Color(0xFF5B21B6),
      error: AppColors.danger,
      onError: AppColors.textOnAccent,
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: Color(0xFF7F1D1D),
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.backgroundAlt,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.divider,
      shadow: Color(0x1A0F172A),
      scrim: AppColors.scrim,
      inverseSurface: AppColors.textPrimary,
      onInverseSurface: AppColors.surface,
      inversePrimary: AppColors.primaryBright,
    );

    final TextTheme textTheme = AppTypography.textTheme(
      primary: AppColors.textPrimary,
      secondary: AppColors.textSecondary,
      tertiary: AppColors.textTertiary,
    );

    final ThemeData base = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
    );

    return _applyComponentThemes(base);
  }

  /// Kart, buton, input gibi Material bileşenlerinin özel görünümleri.
  static ThemeData _applyComponentThemes(ThemeData base) {
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 22),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.title.copyWith(color: AppColors.textPrimary),
        iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 22),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Color(0x140F172A),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.card,
          side: BorderSide(color: AppColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnAccent,
          disabledBackgroundColor: AppColors.surfaceSunken,
          disabledForegroundColor: AppColors.textTertiary,
          elevation: 0,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          textStyle: AppTypography.subtitle,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnAccent,
          minimumSize: const Size(0, 52),
          textStyle: AppTypography.subtitle,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.surface,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          side: const BorderSide(color: AppColors.border),
          textStyle: AppTypography.subtitle,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTypography.subtitle,
          minimumSize: const Size(0, 44),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        hintStyle: AppTypography.body.copyWith(color: AppColors.textTertiary),
        labelStyle: AppTypography.body.copyWith(color: AppColors.textSecondary),
        prefixIconColor: AppColors.textTertiary,
        suffixIconColor: AppColors.textTertiary,
        border: _inputBorder(AppColors.border),
        enabledBorder: _inputBorder(AppColors.border),
        focusedBorder: _inputBorder(AppColors.primary, width: 1.6),
        errorBorder: _inputBorder(AppColors.danger),
        focusedErrorBorder: _inputBorder(AppColors.danger, width: 1.6),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceMuted,
        selectedColor: const Color(0xFFEEF2FF),
        side: const BorderSide(color: AppColors.border),
        labelStyle: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        secondaryLabelStyle:
            AppTypography.caption.copyWith(color: AppColors.primary),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.pillAll),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceSunken,
        circularTrackColor: AppColors.surfaceSunken,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: AppTypography.body.copyWith(color: AppColors.surface),
        elevation: 6,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: AppColors.scrim,
        showDragHandle: true,
        dragHandleColor: AppColors.borderStrong,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.sheet),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.xlAll),
        titleTextStyle: AppTypography.title.copyWith(color: AppColors.textPrimary),
        contentTextStyle:
            AppTypography.body.copyWith(color: AppColors.textSecondary),
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: AppTypography.caption.copyWith(color: AppColors.surface),
        decoration: const BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: AppRadii.smAll,
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: Color(0x334F46E5),
        selectionHandleColor: AppColors.primary,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: AppRadii.mdAll,
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// Standart beyaz kart: ince kenar + yumuşak gölge.
  static BoxDecoration cardDecoration({
    Color? tint,
    Color? borderColor,
    bool elevated = false,
    Gradient? gradient,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: tint ?? (gradient == null ? AppColors.surface : null),
      gradient: gradient,
      borderRadius: AppRadii.card,
      border: Border.all(color: borderColor ?? AppColors.border),
      boxShadow: shadows ?? (elevated ? AppShadows.floating : AppShadows.card),
    );
  }

  /// Stat rengine göre hafif tonlanmış yüzey (görev kartları için).
  static BoxDecoration statSurface(Color color, {bool elevated = false}) {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadii.card,
      border: Border.all(color: color.withValues(alpha: 0.22)),
      boxShadow: <BoxShadow>[
        ...AppShadows.tinted(color),
        if (elevated) ...AppShadows.floating,
      ],
    );
  }

  /// Ana marka gradient'iyle boyanmış "kahraman" panel.
  static BoxDecoration heroPanel({Gradient? gradient}) {
    return BoxDecoration(
      gradient: gradient ?? AppGradients.primary,
      borderRadius: AppRadii.lgAll,
      boxShadow: AppShadows.glow(
        AppColors.primary,
        opacity: 0.30,
        blur: 30,
        offset: const Offset(0, 16),
      ),
    );
  }
}
