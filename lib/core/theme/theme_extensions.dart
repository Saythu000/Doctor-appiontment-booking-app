import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_colors.dart';

/// Short access to the design system from any widget:
/// `context.colors.primary`, `context.text.titleMedium`.
extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
