import 'package:flutter/material.dart';

/// === App Theme: single source of truth for color, spacing & typography ===
/// UI-only phase. Never hardcode hex in widgets — reference [AppTheme] tokens
/// or `Theme.of(context)`.
class AppTheme {
  AppTheme._();

  // === Section: Brand & Semantic Colors ===
  static const Color primary = Color(0xFF4FC3F7);
  static const Color primaryDark = Color(0xFF0288D1);
  static const Color secondary = Color(0xFF1E3A5F);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF4F7FB);
  static const Color navy = secondary;
  static const Color success = Color(0xFF22C55E);
  static const Color successDark = Color(0xFF15803D);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color errorDark = Color(0xFFB91C1C);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color inactiveRail = Color(0xFFB0C4DE);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color green = Color(0xFF22C55E);
  static const Color red = Color(0xFFEF4444);
  static const Color orange = Color(0xFFF59E0B);
  static const Color lightBlue = Color(0xFF3B82F6);
  static const Color darkBlue = Color(0xFF1D4ED8);

  static const Color cyan = Color(0xFF00B2FF);
  static const Color navyDark = Color(0xFF0F172A);
  static const Color subtitleGrey = Color(0xFF64748B);
  static const Color borderLight = Color(0xFFE2E8F0);

  // === Section: Spacing Scale (4/8 rhythm) ===
  static const double sp4 = 4;
  static const double sp8 = 8;
  static const double sp12 = 12;
  static const double sp16 = 16;
  static const double sp24 = 24;
  static const double sp32 = 32;
  static const double sp48 = 48;

  // === Section: Radii & Layout ===
  static const double cardRadius = 16;
  static const double loginCardRadius = 24;
  static const double inputRadius = 12;
  static const double railWidth = 84;
  static const double maxContentWidth = 1600;
  static const double tabletBreakpoint = 1024;

  // === Section: Motion ===
  static const Duration motionFast = Duration(milliseconds: 150);
  static const Duration motionBase = Duration(milliseconds: 220);
  static const Duration motionSlow = Duration(milliseconds: 320);
  static const Curve motionCurve = Curves.easeOutCubic;

  // === Section: Elevation / Shadow scale ===
  static List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: navy.withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get shadowMd => [
        BoxShadow(
          color: navy.withValues(alpha: 0.06),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get shadowLg => [
        BoxShadow(
          color: navy.withValues(alpha: 0.10),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ];

  /// Soft brand glow used for active/primary surfaces.
  static List<BoxShadow> primaryGlow({double alpha = 0.28}) => [
        BoxShadow(
          color: primary.withValues(alpha: alpha),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ];

  // === Section: Typography ===
  static TextTheme _buildTextTheme(TextTheme base) {
    return base
        .copyWith(
          displaySmall: base.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: navy,
            letterSpacing: -0.5,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: navy,
            fontSize: 28,
            letterSpacing: -0.4,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: navy,
            letterSpacing: -0.2,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: navy,
          ),
          titleMedium: base.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: navy,
          ),
          titleSmall: base.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: navy,
          ),
          bodyLarge: base.bodyLarge?.copyWith(
            color: textPrimary,
            height: 1.5,
          ),
          bodyMedium: base.bodyMedium?.copyWith(
            color: textPrimary,
            height: 1.5,
          ),
          bodySmall: base.bodySmall?.copyWith(
            color: textSecondary,
            height: 1.45,
          ),
          labelLarge: base.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        )
        .apply(
          bodyColor: textPrimary,
          displayColor: navy,
        );
  }

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        secondary: secondary,
        surface: surface,
        onSurface: textPrimary,
        error: error,
      ).copyWith(
        outline: borderLight,
        outlineVariant: borderLight,
        surfaceContainerHighest: background,
      ),
      scaffoldBackgroundColor: background,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: _buildTextTheme(base.textTheme),
      dividerTheme: const DividerThemeData(
        color: borderLight,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: borderLight),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
        labelStyle: const TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: borderLight, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: borderLight, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: error, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // Finite minWidth (0) so buttons stay valid inside unbounded contexts
          // (Stack/Positioned, Row without Expanded). Opt into full width via
          // SizedBox(width: infinity)/Expanded at the call site.
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(inputRadius),
          ),
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return Colors.white.withValues(alpha: 0.18);
            }
            if (states.contains(WidgetState.hovered)) {
              return Colors.white.withValues(alpha: 0.10);
            }
            return null;
          }),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(inputRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          side: const BorderSide(color: borderLight, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(inputRadius),
          ),
          foregroundColor: navy,
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return primary.withValues(alpha: 0.06);
            }
            return null;
          }),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryDark,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        side: BorderSide.none,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: navy,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(inputRadius),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: navy,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
