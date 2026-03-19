import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  const AppTypography._();

  static TextTheme textTheme(TextTheme base) {
    final inter = GoogleFonts.interTextTheme(base);

    return inter.copyWith(
      displayLarge: GoogleFonts.manrope(
        textStyle: inter.displayLarge,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      headlineLarge: GoogleFonts.manrope(
        textStyle: inter.headlineLarge,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      headlineMedium: GoogleFonts.manrope(
        textStyle: inter.headlineMedium,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
      ),
      headlineSmall: GoogleFonts.manrope(
        textStyle: inter.headlineSmall,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleLarge: GoogleFonts.manrope(
        textStyle: inter.titleLarge,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: GoogleFonts.manrope(
        textStyle: inter.titleMedium,
        fontWeight: FontWeight.w700,
        fontSize: 16,
        letterSpacing: -0.1,
      ),
      titleSmall: GoogleFonts.manrope(
        textStyle: inter.titleSmall,
        fontWeight: FontWeight.w600,
        fontSize: 14,
        letterSpacing: -0.05,
      ),
      bodyLarge: inter.bodyLarge?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      bodyMedium: inter.bodyMedium?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      bodySmall: inter.bodySmall?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 12,
        letterSpacing: 0.08,
      ),
      labelLarge: inter.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.12,
      ),
      labelMedium: inter.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      ),
      labelSmall: inter.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 11,
        letterSpacing: 0.2,
      ),
    );
  }
}

extension AppTextThemeTokens on TextTheme {
  TextStyle? get serviceName => titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      );

  TextStyle? get usernameMasked => bodySmall?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      );

  TextStyle? get metadata => labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.18,
      );
}
