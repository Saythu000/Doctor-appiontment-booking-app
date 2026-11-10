import 'package:flutter/material.dart';

/// Tone of a status chip, alert or message. Screens pick a tone; the theme
/// decides the actual colours, so light and dark mode both stay readable.
enum StatusTone { success, info, warning, danger, neutral, accent }

/// Foreground/background pair for one [StatusTone].
@immutable
class ToneColors {
  final Color foreground;
  final Color background;
  const ToneColors(this.foreground, this.background);
}

/// The app's semantic colour tokens (light and dark).
///
/// Read them with `context.colors` (see theme_extensions.dart). Never use raw
/// hex values in screens: every text/background pair here meets WCAG AA
/// (4.5:1) contrast, which raw values usually don't.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  // Canvas
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color borderStrong;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  // Brand
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color brandNavy;
  final Color onBrandNavy;
  final Color accentSky;

  // Status tones
  final ToneColors success;
  final ToneColors info;
  final ToneColors warning;
  final ToneColors danger;
  final ToneColors neutral;
  final ToneColors accent;

  // Vitals (charts and rings): clearly distinct hues.
  final Color vitalHeart;
  final Color vitalSteps;
  final Color vitalCalories;
  final Color vitalActive;
  final Color vitalSleep;
  final Color vitalOxygen;

  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.brandNavy,
    required this.onBrandNavy,
    required this.accentSky,
    required this.success,
    required this.info,
    required this.warning,
    required this.danger,
    required this.neutral,
    required this.accent,
    required this.vitalHeart,
    required this.vitalSteps,
    required this.vitalCalories,
    required this.vitalActive,
    required this.vitalSleep,
    required this.vitalOxygen,
  });

  static const light = AppColors(
    background: Color(0xFFF4F8FB),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEDF4F9),
    border: Color(0xFFDDE6ED),
    borderStrong: Color(0xFFBAC9D8),
    textPrimary: Color(0xFF1B2A3E),
    textSecondary: Color(0xFF4A5E78),
    textMuted: Color(0xFF5F7389),
    primary: Color(0xFF1A6FB0),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE1F2FC),
    onPrimaryContainer: Color(0xFF0B3F66),
    brandNavy: Color(0xFF102554),
    onBrandNavy: Color(0xFFFFFFFF),
    accentSky: Color(0xFF38A5E1),
    success: ToneColors(Color(0xFF166534), Color(0xFFDCFCE7)),
    info: ToneColors(Color(0xFF075985), Color(0xFFE0F2FE)),
    warning: ToneColors(Color(0xFF92400E), Color(0xFFFEF3C7)),
    danger: ToneColors(Color(0xFFB91C1C), Color(0xFFFEE2E2)),
    neutral: ToneColors(Color(0xFF475569), Color(0xFFF1F5F9)),
    accent: ToneColors(Color(0xFF5B21B6), Color(0xFFEDE9FE)),
    vitalHeart: Color(0xFFE5484D),
    vitalSteps: Color(0xFF1A6FB0),
    vitalCalories: Color(0xFFF08C00),
    vitalActive: Color(0xFF12A594),
    vitalSleep: Color(0xFF6E56CF),
    vitalOxygen: Color(0xFF0091FF),
  );

  static const dark = AppColors(
    background: Color(0xFF0B1220),
    surface: Color(0xFF131C2E),
    surfaceMuted: Color(0xFF1A2539),
    border: Color(0xFF26334A),
    borderStrong: Color(0xFF3A4A66),
    textPrimary: Color(0xFFE6EDF5),
    textSecondary: Color(0xFFA9B6C8),
    textMuted: Color(0xFF8494A9),
    primary: Color(0xFF7CC4F0),
    onPrimary: Color(0xFF0B1220),
    primaryContainer: Color(0xFF0F3352),
    onPrimaryContainer: Color(0xFFCDE8FA),
    brandNavy: Color(0xFF1B2E5C),
    onBrandNavy: Color(0xFFFFFFFF),
    accentSky: Color(0xFF7CC4F0),
    success: ToneColors(Color(0xFF86EFAC), Color(0xFF0F2A1B)),
    info: ToneColors(Color(0xFF93C5FD), Color(0xFF0F2238)),
    warning: ToneColors(Color(0xFFFCD34D), Color(0xFF2B2110)),
    danger: ToneColors(Color(0xFFFCA5A5), Color(0xFF2E1414)),
    neutral: ToneColors(Color(0xFFCBD5E1), Color(0xFF1E293B)),
    accent: ToneColors(Color(0xFFC4B5FD), Color(0xFF241A3D)),
    vitalHeart: Color(0xFFFF6369),
    vitalSteps: Color(0xFF7CC4F0),
    vitalCalories: Color(0xFFFFB224),
    vitalActive: Color(0xFF3DD9C1),
    vitalSleep: Color(0xFF9E8CFC),
    vitalOxygen: Color(0xFF52A9FF),
  );

  ToneColors tone(StatusTone tone) => switch (tone) {
        StatusTone.success => success,
        StatusTone.info => info,
        StatusTone.warning => warning,
        StatusTone.danger => danger,
        StatusTone.neutral => neutral,
        StatusTone.accent => accent,
      };

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    ToneColors tc(ToneColors a, ToneColors b) =>
        ToneColors(c(a.foreground, b.foreground), c(a.background, b.background));
    return AppColors(
      background: c(background, other.background),
      surface: c(surface, other.surface),
      surfaceMuted: c(surfaceMuted, other.surfaceMuted),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textMuted: c(textMuted, other.textMuted),
      primary: c(primary, other.primary),
      onPrimary: c(onPrimary, other.onPrimary),
      primaryContainer: c(primaryContainer, other.primaryContainer),
      onPrimaryContainer: c(onPrimaryContainer, other.onPrimaryContainer),
      brandNavy: c(brandNavy, other.brandNavy),
      onBrandNavy: c(onBrandNavy, other.onBrandNavy),
      accentSky: c(accentSky, other.accentSky),
      success: tc(success, other.success),
      info: tc(info, other.info),
      warning: tc(warning, other.warning),
      danger: tc(danger, other.danger),
      neutral: tc(neutral, other.neutral),
      accent: tc(accent, other.accent),
      vitalHeart: c(vitalHeart, other.vitalHeart),
      vitalSteps: c(vitalSteps, other.vitalSteps),
      vitalCalories: c(vitalCalories, other.vitalCalories),
      vitalActive: c(vitalActive, other.vitalActive),
      vitalSleep: c(vitalSleep, other.vitalSleep),
      vitalOxygen: c(vitalOxygen, other.vitalOxygen),
    );
  }
}
