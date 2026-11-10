import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phia_flutter/core/theme/app_colors.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';

/// Light and dark Material 3 themes built from [AppColors].
///
/// Components (buttons, cards, inputs, sheets, snack bars, navigation bar)
/// are styled once here so screens don't repeat styling and stay consistent.
abstract final class AppTheme {
  static ThemeData get light => _build(AppColors.light, Brightness.light);
  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);

  /// Headings: Plus Jakarta Sans. Body and labels: Inter.
  /// No size is below 12sp, so text stays readable.
  static TextTheme textTheme(AppColors c) {
    TextStyle heading(double size, FontWeight weight, {double spacing = 0}) =>
        GoogleFonts.plusJakartaSans(
          fontSize: size,
          fontWeight: weight,
          color: c.textPrimary,
          letterSpacing: spacing,
          height: 1.25,
        );
    TextStyle body(double size, FontWeight weight, Color color, {double height = 1.45}) =>
        GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color, height: height);

    return TextTheme(
      displaySmall: heading(32, FontWeight.w700, spacing: -0.5),
      headlineMedium: heading(26, FontWeight.w700, spacing: -0.3),
      headlineSmall: heading(22, FontWeight.w700, spacing: -0.2),
      titleLarge: heading(19, FontWeight.w700),
      titleMedium: heading(16, FontWeight.w700),
      titleSmall: heading(14, FontWeight.w700),
      bodyLarge: body(16, FontWeight.w400, c.textPrimary),
      bodyMedium: body(14, FontWeight.w400, c.textSecondary),
      bodySmall: body(12, FontWeight.w400, c.textMuted, height: 1.35),
      labelLarge: body(15, FontWeight.w600, c.textPrimary, height: 1.2),
      labelMedium: body(13, FontWeight.w600, c.textSecondary, height: 1.2),
      labelSmall: body(12, FontWeight.w600, c.textMuted, height: 1.2),
    );
  }

  static ThemeData _build(AppColors c, Brightness brightness) {
    final text = textTheme(c);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primaryContainer,
      onPrimaryContainer: c.onPrimaryContainer,
      secondary: c.brandNavy,
      onSecondary: c.onBrandNavy,
      tertiary: c.vitalActive,
      onTertiary: c.onPrimary,
      error: c.danger.foreground,
      onError: brightness == Brightness.light ? Colors.white : c.background,
      errorContainer: c.danger.background,
      onErrorContainer: c.danger.foreground,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.background,
      surfaceContainer: c.surfaceMuted,
      surfaceContainerHigh: c.surfaceMuted,
      surfaceContainerHighest: c.surfaceMuted,
      outline: c.borderStrong,
      outlineVariant: c.border,
    );

    const buttonShape = RoundedRectangleBorder(borderRadius: AppRadius.mdAll);
    const buttonSize = Size(64, AppSizes.buttonHeight);
    final buttonText = text.labelLarge!.copyWith();

    OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [c],
      scaffoldBackgroundColor: c.background,
      textTheme: text,
      fontFamily: GoogleFonts.inter().fontFamily,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          // Material 3 page transition; also drives Android's predictive back.
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: c.textPrimary),
        // Edge-to-edge: transparent system bars, icons that suit the theme.
        systemOverlayStyle: systemBarsStyle(brightness),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: c.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.border,
          disabledForegroundColor: c.textMuted,
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: buttonText,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.border,
          disabledForegroundColor: c.textMuted,
          elevation: 0,
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: buttonText,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          minimumSize: buttonSize,
          shape: buttonShape,
          side: BorderSide(color: c.borderStrong),
          textStyle: buttonText,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: const Size(AppSizes.minTouchTarget, AppSizes.minTouchTarget),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(AppSizes.minTouchTarget, AppSizes.minTouchTarget),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
        labelStyle: text.bodyMedium,
        hintStyle: text.bodyMedium!.copyWith(color: c.textMuted),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall!.copyWith(color: c.danger.foreground),
        border: inputBorder(c.border),
        enabledBorder: inputBorder(c.border),
        focusedBorder: inputBorder(c.primary, 2),
        errorBorder: inputBorder(c.danger.foreground),
        focusedErrorBorder: inputBorder(c.danger.foreground, 2),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.primaryContainer,
        labelStyle: text.labelMedium,
        side: BorderSide(color: c.border),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodyMedium,
        minVerticalPadding: AppSpacing.md,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.borderStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.light ? c.brandNavy : c.surfaceMuted,
        contentTextStyle: text.bodyMedium!.copyWith(color: Colors.white),
        actionTextColor: c.accentSky,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.primaryContainer,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelSmall!.copyWith(
            color: states.contains(WidgetState.selected) ? c.textPrimary : c.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? c.onPrimaryContainer : c.textSecondary,
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.surfaceMuted,
        circularTrackColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.surfaceMuted,
        ),
      ),
    );
  }
}

/// Transparent status and navigation bars (the app draws edge-to-edge),
/// with dark icons on light screens and light icons on dark screens.
SystemUiOverlayStyle systemBarsStyle(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: brightness, // iOS
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );
}
