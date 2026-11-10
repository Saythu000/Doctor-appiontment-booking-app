import 'package:flutter/material.dart';

/// Legacy colour constants, used by screens not yet moved to the design
/// system. New code must use `context.colors` (AppColors) instead, which also
/// supports dark mode. Screens are migrated in the Phase 9 redesign, after
/// which this class is deleted.
///
/// Values that failed WCAG contrast were corrected to match AppColors.light:
/// [primary] (white text on it was 2.75:1, now 5.3:1) and [textMuted]
/// (3.3:1 on white, now 4.9:1).
abstract final class PhiaColors {
  // Brand Anchors from Reference Image
  static const Color primary = Color(0xFF1A6FB0);       // Brand blue (accessible with white text)
  static const Color primaryDark = Color(0xFF155A8F);   // Pressed state
  static const Color primaryLight = Color(0xFFE1F2FC);  // Soft sky tint for selected chips
  static const Color primaryCard = Color(0xFF50B1E6);   // Clinical unit card background from image

  static const Color navyAnchor = Color(0xFF102554);    // Deep Oxford Navy (Card Headers, Nav Icon, Headings)
  static const Color navyLight = Color(0xFF1B3673);     // Slightly lighter navy

  // Canvas & Surfaces
  static const Color background = Color(0xFFF4F8FB);    // Glacier Slate background canvas (not blinding white)
  static const Color surface = Color(0xFFFFFFFF);       // Pure white card body
  static const Color surfaceSubtle = Color(0xFFEDF4F9); // Light cool container

  // Typography & Text
  static const Color textPrimary = Color(0xFF1B2A3E);   // Dark Charcoal / Navy for high-contrast readability
  static const Color textSecondary = Color(0xFF4A5E78); // Slate 600 body text
  static const Color textMuted = Color(0xFF5F7389);     // Muted labels / hints (AA on white)
  static const Color textInverse = Color(0xFFFFFFFF);   // White on Navy / Blue headers

  // Clinical Status & Badges
  static const Color activeGreen = Color(0xFF22C55E);   // Green "Active" badge from image
  static const Color activeGreenBg = Color(0xFFDCFCE7); // Mint background for active badge
  static const Color pulseRed = Color(0xFFEF4444);      // Warning / high HR
  static const Color pulseRedLight = Color(0xFFFEE2E2);
  static const Color amberWarning = Color(0xFFF59E0B);

  // Borders & Dividers
  static const Color borderSubtle = Color(0xFFDDE6ED); // Crisp defined card border
  static const Color borderStrong = Color(0xFFBAC9D8);
  static const Color outline = Color(0xFFBAC9D8);
  static const Color outlineVariant = Color(0xFFDDE6ED);

  // Legacy & Utility Aliases
  static const Color vitalEmerald = Color(0xFF22C55E);
  static const Color vitalEmeraldDark = Color(0xFF16A34A);
  static const Color vitalEmeraldLight = Color(0xFFDCFCE7);
  static const Color clinicalBlue = Color(0xFF38A5E1);
  static const Color clinicalBlueLight = Color(0xFFE1F2FC);
  static const Color clinicalCyan = Color(0xFF50B1E6);
  static const Color clinicalCyanLight = Color(0xFFE1F2FC);
  static const Color skyBlue = Color(0xFF38A5E1);
  static const Color skyBlueLight = Color(0xFFE1F2FC);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF1B2A3E);
  static const Color gray = Color(0xFF7B8FA6);
  static const Color stepGreen = Color(0xFF22C55E);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color warningOrangeLight = Color(0xFFFEF3C7);
}


