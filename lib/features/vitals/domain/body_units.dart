import 'package:phia_flutter/core/theme/app_colors.dart';

/// Unit conversion and formatting for body and activity values.
///
/// Values are always stored in kg and cm; these helpers convert only for
/// display and input, following the user's unit setting.
class BodyUnits {
  BodyUnits._();

  static const double _lbsPerKg = 2.2046226218;
  static const double _cmPerInch = 2.54;

  static bool isPounds(String weightUnit) => weightUnit == 'lbs';
  static bool isInches(String heightUnit) => heightUnit != 'cm';

  static String weightLabel(String weightUnit) => isPounds(weightUnit) ? 'lbs' : 'kg';
  static String heightLabel(String heightUnit) => isInches(heightUnit) ? 'in' : 'cm';

  /// kg -> the user's unit.
  static double weightToDisplay(double kg, String weightUnit) => isPounds(weightUnit) ? kg * _lbsPerKg : kg;

  /// The user's unit -> kg.
  static double weightFromDisplay(double value, String weightUnit) =>
      isPounds(weightUnit) ? value / _lbsPerKg : value;

  /// cm -> the user's unit.
  static double heightToDisplay(double cm, String heightUnit) => isInches(heightUnit) ? cm / _cmPerInch : cm;

  /// The user's unit -> cm.
  static double heightFromDisplay(double value, String heightUnit) =>
      isInches(heightUnit) ? value * _cmPerInch : value;

  /// "72.5 kg", "160 lbs" or "--" when unknown.
  static String formatWeight(double kg, String weightUnit) {
    if (kg <= 0) return '--';
    final v = weightToDisplay(kg, weightUnit);
    return '${isPounds(weightUnit) ? v.toStringAsFixed(0) : v.toStringAsFixed(1)} ${weightLabel(weightUnit)}';
  }

  /// "175 cm", "69 in" or "--" when unknown.
  static String formatHeight(double cm, String heightUnit) {
    if (cm <= 0) return '--';
    return '${heightToDisplay(cm, heightUnit).toStringAsFixed(0)} ${heightLabel(heightUnit)}';
  }

  /// Allowed input ranges, in the user's unit.
  static (double, double) weightRange(String weightUnit) => isPounds(weightUnit) ? (4.0, 1100.0) : (2.0, 500.0);
  static (double, double) heightRange(String heightUnit) => isInches(heightUnit) ? (16.0, 100.0) : (40.0, 250.0);
  static const (int, int) ageRange = (1, 120);

  /// Text for a number field: no trailing ".0", empty when unknown.
  static String inputText(double value, {int decimals = 1}) {
    if (value <= 0) return '';
    final fixed = value.toStringAsFixed(decimals);
    return fixed.contains('.') ? fixed.replaceFirst(RegExp(r'\.?0+$'), '') : fixed;
  }
}

/// Body-mass index from stored kg and cm.
class Bmi {
  final double value;
  final String label;
  final StatusTone tone;

  const Bmi._(this.value, this.label, this.tone);

  /// Null when height or weight is not set (never a made-up "Normal").
  static Bmi? from({required double weightKg, required double heightCm}) {
    if (weightKg <= 0 || heightCm <= 0) return null;
    final m = heightCm / 100.0;
    final v = weightKg / (m * m);
    if (v < 18.5) return Bmi._(v, 'Underweight', StatusTone.info);
    if (v < 25) return Bmi._(v, 'Normal', StatusTone.success);
    if (v < 30) return Bmi._(v, 'Overweight', StatusTone.warning);
    return Bmi._(v, 'Obese', StatusTone.danger);
  }
}

/// Formatting for activity values; "--" whenever nothing has synced.
class VitalsFormat {
  VitalsFormat._();

  /// 12345 -> "12,345".
  static String thousands(int n) =>
      n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  static String count(int n) => n > 0 ? thousands(n) : '--';

  static String number(double v, {int decimals = 0}) => v > 0 ? v.toStringAsFixed(decimals) : '--';

  /// 95 -> "1h 35m", 40 -> "40m".
  static String minutes(int m) {
    if (m <= 0) return '--';
    final h = m ~/ 60;
    final r = m % 60;
    if (h == 0) return '${r}m';
    return r == 0 ? '${h}h' : '${h}h ${r}m';
  }

  /// "just now", "6 min ago", "2 h ago", "3 days ago".
  static String ago(DateTime t, {DateTime? now}) {
    final d = (now ?? DateTime.now()).difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    final days = d.inDays;
    return days == 1 ? '1 day ago' : '$days days ago';
  }
}
