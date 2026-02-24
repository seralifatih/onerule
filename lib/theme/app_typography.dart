import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  const AppTypography._();

  static TextTheme textTheme(TextTheme base) {
    final poppins = GoogleFonts.poppinsTextTheme(base);

    return poppins.copyWith(
      displayLarge: poppins.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.35,
      ),
      headlineMedium: poppins.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
      ),
      titleLarge: poppins.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: poppins.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 16,
        letterSpacing: -0.1,
      ),
      titleSmall: poppins.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        letterSpacing: -0.05,
      ),
      bodyLarge: poppins.bodyLarge?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      bodyMedium: poppins.bodyMedium?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      bodySmall: poppins.bodySmall?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 12,
        letterSpacing: 0.08,
      ),
      labelLarge: poppins.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.12,
      ),
      labelMedium: poppins.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      ),
      labelSmall: poppins.labelSmall?.copyWith(
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
