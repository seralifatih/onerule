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

  // ── Obsidian dark palette ──────────────────────────────────────────────────
  static const Color _darkBackground = Color(0xFF060E20);
  static const Color _darkSurface = Color(0xFF060E20);
  static const Color _darkSurfaceContainer = Color(0xFF0F1930);
  static const Color _darkSurfaceContainerLow = Color(0xFF091328);
  static const Color _darkSurfaceContainerHigh = Color(0xFF141F38);
  static const Color _darkSurfaceContainerHighest = Color(0xFF192540);
  static const Color _darkPrimary = Color(0xFF5EB4FF);
  static const Color _darkOnPrimary = Color(0xFF003151);
  static const Color _darkPrimaryContainer = Color(0xFF2AA7FF);
  static const Color _darkOnPrimaryContainer = Color(0xFF00253F);
  static const Color _darkSecondary = Color(0xFFC8D8F3);
  static const Color _darkOnSecondary = Color(0xFF3C4C61);
  static const Color _darkSecondaryContainer = Color(0xFF38485D);
  static const Color _darkOnSecondaryContainer = Color(0xFFC1D1EB);
  static const Color _darkTertiary = Color(0xFFAF88FF);
  static const Color _darkOnTertiary = Color(0xFF2B0065);
  static const Color _darkTertiaryContainer = Color(0xFF8342F4);
  static const Color _darkOnTertiaryContainer = Color(0xFFFFFFFF);
  static const Color _darkError = Color(0xFFFF716C);
  static const Color _darkOnError = Color(0xFF490006);
  static const Color _darkErrorContainer = Color(0xFF9F0519);
  static const Color _darkOnErrorContainer = Color(0xFFFFA8A3);
  static const Color _darkOnSurface = Color(0xFFDEE5FF);
  static const Color _darkOnSurfaceVariant = Color(0xFFA3AAC4);
  static const Color _darkOutline = Color(0xFF6D758C);
  static const Color _darkOutlineVariant = Color(0xFF40485D);

  static const AppColorTokens fallbackColorTokens = AppColorTokens(
    scaffoldNavy: _darkBackground,
    cardSlate: _darkSurfaceContainer,
    accentCyan: _darkPrimary,
    subtleBorder: Color(0x4040485D),
    metadataText: _darkOnSurfaceVariant,
  );

  static const AppSemanticColors fallbackSemanticColors = AppSemanticColors(
    authGradientStart: Color(0xFF060E20),
    authGradientEnd: Color(0xFF0F1930),
    destructive: Color(0xFFFF716C),
    success: Color(0xFF22C55E),
    warning: Color(0xFFFBBF24),
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
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFCCF0F8),
      onPrimaryContainer: const Color(0xFF003151),
      secondary: const Color(0xFF0EA5E9),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFD9F3FA),
      onSecondaryContainer: const Color(0xFF003151),
      tertiary: const Color(0xFF7C3AED),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFEDE9FE),
      onTertiaryContainer: const Color(0xFF2B0065),
      surface: tokens.cardSlate,
      onSurface: const Color(0xFF0F172A),
      onSurfaceVariant: const Color(0xFF526173),
      outline: const Color(0xFF94A3B8),
      outlineVariant: const Color(0x260F172A),
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
      scaffoldNavy: _darkBackground,
      cardSlate: _darkSurfaceContainer,
      accentCyan: _darkPrimary,
      subtleBorder: Color(0x4040485D),
      metadataText: _darkOnSurfaceVariant,
    );

    const scheme = ColorScheme.dark(
      primary: _darkPrimary,
      onPrimary: _darkOnPrimary,
      primaryContainer: _darkPrimaryContainer,
      onPrimaryContainer: _darkOnPrimaryContainer,
      secondary: _darkSecondary,
      onSecondary: _darkOnSecondary,
      secondaryContainer: _darkSecondaryContainer,
      onSecondaryContainer: _darkOnSecondaryContainer,
      tertiary: _darkTertiary,
      onTertiary: _darkOnTertiary,
      tertiaryContainer: _darkTertiaryContainer,
      onTertiaryContainer: _darkOnTertiaryContainer,
      error: _darkError,
      onError: _darkOnError,
      errorContainer: _darkErrorContainer,
      onErrorContainer: _darkOnErrorContainer,
      surface: _darkSurface,
      onSurface: _darkOnSurface,
      onSurfaceVariant: _darkOnSurfaceVariant,
      outline: _darkOutline,
      outlineVariant: _darkOutlineVariant,
      surfaceContainerHighest: _darkSurfaceContainerHighest,
      surfaceContainerHigh: _darkSurfaceContainerHigh,
      surfaceContainer: _darkSurfaceContainer,
      surfaceContainerLow: _darkSurfaceContainerLow,
      surfaceTint: _darkPrimary,
      inverseSurface: Color(0xFFFAF8FF),
      onInverseSurface: Color(0xFF4D556B),
      inversePrimary: Color(0xFF00639E),
    );

    return _buildTheme(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _darkBackground,
      colorScheme: scheme,
      colorTokens: tokens,
      semanticColors: const AppSemanticColors(
        authGradientStart: _darkBackground,
        authGradientEnd: _darkSurfaceContainerLow,
        destructive: _darkError,
        success: Color(0xFF22C55E),
        warning: Color(0xFFFBBF24),
      ),
      appBarTitleColor: _darkPrimary,
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
        backgroundColor: scaffoldBackgroundColor,
        elevation: AppElevation.none,
        centerTitle: false,
        titleTextStyle: AppTypography.textTheme(base.textTheme).titleLarge?.copyWith(
          color: appBarTitleColor,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
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
        fillColor: colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
          borderSide: BorderSide(color: colorTokens.accentCyan, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.primary,
        textColor: colorScheme.onSurface,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xlarge),
        ),
        margin: EdgeInsets.zero,
        elevation: AppElevation.none,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorTokens.accentCyan,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.large),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
        actionTextColor: colorTokens.accentCyan,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
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
