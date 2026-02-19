import 'package:flutter/material.dart';

import 'app_elevation.dart';
import 'app_radius.dart';
import 'app_typography.dart';

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.authGradientStart,
    required this.authGradientEnd,
    required this.destructive,
    required this.success,
    required this.warning,
  });

  final Color authGradientStart;
  final Color authGradientEnd;
  final Color destructive;
  final Color success;
  final Color warning;

  @override
  AppSemanticColors copyWith({
    Color? authGradientStart,
    Color? authGradientEnd,
    Color? destructive,
    Color? success,
    Color? warning,
  }) {
    return AppSemanticColors(
      authGradientStart: authGradientStart ?? this.authGradientStart,
      authGradientEnd: authGradientEnd ?? this.authGradientEnd,
      destructive: destructive ?? this.destructive,
      success: success ?? this.success,
      warning: warning ?? this.warning,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) {
      return this;
    }

    return AppSemanticColors(
      authGradientStart:
          Color.lerp(authGradientStart, other.authGradientStart, t) ??
              authGradientStart,
      authGradientEnd: Color.lerp(authGradientEnd, other.authGradientEnd, t) ??
          authGradientEnd,
      destructive: Color.lerp(destructive, other.destructive, t) ?? destructive,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
    );
  }
}

class AppTheme {
  const AppTheme._();
  static const AppSemanticColors fallbackSemanticColors = AppSemanticColors(
    authGradientStart: Color(0xFF0F172A),
    authGradientEnd: Color(0xFF1E1B4B),
    destructive: Color(0xFFDC2626),
    success: Color(0xFF16A34A),
    warning: Color(0xFFF59E0B),
  );

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: Color(0xFF0284C7),
      secondary: Color(0xFF6366F1),
      surface: Colors.white,
      onSurface: Color(0xFF1E293B),
    );

    return _buildTheme(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF1F5F9),
      colorScheme: scheme,
      semanticColors: const AppSemanticColors(
        authGradientStart: Color(0xFF0F172A),
        authGradientEnd: Color(0xFF1E1B4B),
        destructive: Color(0xFFDC2626),
        success: Color(0xFF16A34A),
        warning: Color(0xFFF59E0B),
      ),
      appBarTitleColor: const Color(0xFF0F172A),
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: Color(0xFF38BDF8),
      secondary: Color(0xFF818CF8),
      surface: Color(0xFF1E293B),
      onSurface: Colors.white,
    );

    return _buildTheme(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      colorScheme: scheme,
      semanticColors: const AppSemanticColors(
        authGradientStart: Color(0xFF0F172A),
        authGradientEnd: Color(0xFF1E1B4B),
        destructive: Color(0xFFEF4444),
        success: Color(0xFF22C55E),
        warning: Color(0xFFFBBF24),
      ),
      appBarTitleColor: Colors.white,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color scaffoldBackgroundColor,
    required ColorScheme colorScheme,
    required AppSemanticColors semanticColors,
    required Color appBarTitleColor,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      colorScheme: colorScheme,
    );

    return base.copyWith(
      textTheme: AppTypography.textTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: AppElevation.none,
        centerTitle: true,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: appBarTitleColor,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: appBarTitleColor),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        semanticColors,
      ],
    );
  }
}
