import 'package:flutter/material.dart';

import 'app_elevation.dart';
import 'app_radius.dart';
import 'app_typography.dart';

@immutable
class AppColorTokens extends ThemeExtension<AppColorTokens> {
  const AppColorTokens({
    required this.scaffoldNavy,
    required this.cardSlate,
    required this.accentCyan,
    required this.subtleBorder,
    required this.metadataText,
  });

  final Color scaffoldNavy;
  final Color cardSlate;
  final Color accentCyan;
  final Color subtleBorder;
  final Color metadataText;

  @override
  AppColorTokens copyWith({
    Color? scaffoldNavy,
    Color? cardSlate,
    Color? accentCyan,
    Color? subtleBorder,
    Color? metadataText,
  }) {
    return AppColorTokens(
      scaffoldNavy: scaffoldNavy ?? this.scaffoldNavy,
      cardSlate: cardSlate ?? this.cardSlate,
      accentCyan: accentCyan ?? this.accentCyan,
      subtleBorder: subtleBorder ?? this.subtleBorder,
      metadataText: metadataText ?? this.metadataText,
    );
  }

  @override
  AppColorTokens lerp(ThemeExtension<AppColorTokens>? other, double t) {
    if (other is! AppColorTokens) {
      return this;
    }

    return AppColorTokens(
      scaffoldNavy:
          Color.lerp(scaffoldNavy, other.scaffoldNavy, t) ?? scaffoldNavy,
      cardSlate: Color.lerp(cardSlate, other.cardSlate, t) ?? cardSlate,
      accentCyan: Color.lerp(accentCyan, other.accentCyan, t) ?? accentCyan,
      subtleBorder:
          Color.lerp(subtleBorder, other.subtleBorder, t) ?? subtleBorder,
      metadataText:
          Color.lerp(metadataText, other.metadataText, t) ?? metadataText,
    );
  }
}

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

  static const AppColorTokens fallbackColorTokens = AppColorTokens(
    scaffoldNavy: Color(0xFF0C1A2B),
    cardSlate: Color(0xFF16273A),
    accentCyan: Color(0xFF22D3EE),
    subtleBorder: Color(0x333B82F6),
    metadataText: Color(0xFF93A4B8),
  );

  static const AppSemanticColors fallbackSemanticColors = AppSemanticColors(
    authGradientStart: Color(0xFF0F172A),
    authGradientEnd: Color(0xFF123547),
    destructive: Color(0xFFDC2626),
    success: Color(0xFF16A34A),
    warning: Color(0xFFF59E0B),
  );

  static ThemeData light() {
    const tokens = AppColorTokens(
      scaffoldNavy: Color(0xFFE7EFF7),
      cardSlate: Color(0xFFF5FAFE),
      accentCyan: Color(0xFF0891B2),
      subtleBorder: Color(0x220F172A),
      metadataText: Color(0xFF526173),
    );

    final scheme = ColorScheme.light(
      primary: tokens.accentCyan,
      secondary: const Color(0xFF0EA5E9),
      surface: tokens.cardSlate,
      onSurface: const Color(0xFF0F172A),
      onPrimary: Colors.white,
      outlineVariant: const Color(0x260F172A),
      primaryContainer: const Color(0xFFCCF0F8),
      secondaryContainer: const Color(0xFFD9F3FA),
    );

    return _buildTheme(
      brightness: Brightness.light,
      scaffoldBackgroundColor: tokens.scaffoldNavy,
      colorScheme: scheme,
      colorTokens: tokens,
      semanticColors: const AppSemanticColors(
        authGradientStart: Color(0xFF0F172A),
        authGradientEnd: Color(0xFF123547),
        destructive: Color(0xFFDC2626),
        success: Color(0xFF16A34A),
        warning: Color(0xFFF59E0B),
      ),
      appBarTitleColor: const Color(0xFF0F172A),
    );
  }

  static ThemeData dark() {
    const tokens = AppColorTokens(
      scaffoldNavy: Color(0xFF081220),
      cardSlate: Color(0xFF14273A),
      accentCyan: Color(0xFF22D3EE),
      subtleBorder: Color(0x337DD3FC),
      metadataText: Color(0xFF91A9C3),
    );

    final scheme = ColorScheme.dark(
      primary: tokens.accentCyan,
      secondary: const Color(0xFF67E8F9),
      surface: tokens.cardSlate,
      onSurface: const Color(0xFFE6EDF6),
      onPrimary: const Color(0xFF03222D),
      outlineVariant: const Color(0x337DD3FC),
      primaryContainer: const Color(0xFF12435B),
      secondaryContainer: const Color(0xFF0F364A),
    );

    return _buildTheme(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: tokens.scaffoldNavy,
      colorScheme: scheme,
      colorTokens: tokens,
      semanticColors: const AppSemanticColors(
        authGradientStart: Color(0xFF081220),
        authGradientEnd: Color(0xFF123547),
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
    required AppColorTokens colorTokens,
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
      dividerColor: colorTokens.subtleBorder,
      dividerTheme: DividerThemeData(
        color: colorTokens.subtleBorder,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorTokens.cardSlate,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide(color: colorTokens.subtleBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide(color: colorTokens.accentCyan, width: 1.7),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.primary,
        textColor: colorScheme.onSurface,
      ),
      cardTheme: CardThemeData(
        color: colorTokens.cardSlate,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
          side: BorderSide(color: colorTokens.subtleBorder),
        ),
        margin: EdgeInsets.zero,
        elevation: AppElevation.low,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorTokens.accentCyan,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorTokens.cardSlate,
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
        actionTextColor: colorTokens.accentCyan,
        behavior: SnackBarBehavior.floating,
      ),
      extensions: <ThemeExtension<dynamic>>[
        colorTokens,
        semanticColors,
      ],
    );
  }
}

extension AppThemeBuildContextX on BuildContext {
  AppColorTokens get appColors =>
      Theme.of(this).extension<AppColorTokens>() ??
      AppTheme.fallbackColorTokens;

  AppSemanticColors get appSemanticColors =>
      Theme.of(this).extension<AppSemanticColors>() ??
      AppTheme.fallbackSemanticColors;
}
