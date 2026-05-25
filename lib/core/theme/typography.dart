import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PhiaTypography {
  static TextTheme get textTheme => TextTheme(
        // Bebas Neue
        displayLarge: GoogleFonts.bebasNeue(
          fontSize: 72,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.05 * 72,
        ),
        headlineLarge: GoogleFonts.bebasNeue(
          fontSize: 40,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.02 * 40,
        ),
        headlineMedium: GoogleFonts.bebasNeue(
          fontSize: 24,
          fontWeight: FontWeight.w400,
        ),
        // Geist (Using Inter as temporary placeholder)
        bodyLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.05,
        ),
      );
}
