import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  const AppTypography._();

  static TextTheme textTheme(TextTheme base) {
    final poppins = GoogleFonts.poppinsTextTheme(base);

    return poppins.copyWith(
      displayLarge: poppins.displayLarge?.copyWith(fontWeight: FontWeight.w700),
      headlineMedium:
          poppins.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: poppins.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: poppins.bodyLarge?.copyWith(fontWeight: FontWeight.w400),
      bodyMedium: poppins.bodyMedium?.copyWith(fontWeight: FontWeight.w400),
      labelLarge: poppins.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
