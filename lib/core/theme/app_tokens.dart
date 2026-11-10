import 'package:flutter/widgets.dart';

/// Spacing scale (4-point grid). Use these instead of ad-hoc numbers.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Side padding of every screen.
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: lg);
}

/// Corner radii.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
}

/// Sizes that come from accessibility guidance.
abstract final class AppSizes {
  /// Minimum touch target (Material / Android accessibility guideline).
  static const double minTouchTarget = 48;
  static const double buttonHeight = 52;
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
}

/// Motion: calm and short. Medical apps should feel steady, not flashy.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration entrance = Duration(milliseconds: 450);

  /// Material 3 "emphasized" curves.
  static const Curve emphasized = Cubic(0.2, 0, 0, 1);
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1);
  static const Curve standard = Cubic(0.2, 0, 0, 1);

  /// True when the user turned off animations in Android accessibility
  /// settings. Animations must then be skipped or reduced to a fade.
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}
