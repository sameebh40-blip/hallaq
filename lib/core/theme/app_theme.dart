import 'package:flutter/material.dart';

class AppTheme {
  static const onyx = Color(0xFF000000);
  static const onyx2 = Color(0xFF111111);
  static const onyx3 = Color(0xFF1A1A1A);
  static const onyx4 = Color(0xFF1C1C1C);
  static const gold = Color(0xFFD4AF37);
  static const goldSoft = Color(0xFFF3E3A3);
  static const goldDeep = Color(0xFFB08A22);

  static const background = onyx;
  static const surface = onyx2;
  static const card = onyx3;
  static const text = Color(0xFFF5F5F5);
  static const textMuted = Color(0xFFB3B3B3);
  static const border = Color(0xFF2A2A2A);
  static const success = Color(0xFF34C759);
  static const error = Color(0xFFFF453A);

  static const radiusSm = 16.0;
  static const radiusMd = 20.0;
  static const radiusLg = 24.0;
  static const radiusXl = 28.0;
  static const spaceXs = 6.0;
  static const spaceSm = 10.0;
  static const spaceMd = 14.0;
  static const spaceLg = 18.0;
  static const spaceXl = 24.0;
  static const pageGutter = 16.0;

  static const goldGradient = LinearGradient(
    colors: [goldSoft, gold, goldDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> softShadow({double opacity = 0.10}) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: opacity),
        blurRadius: 22,
        offset: const Offset(0, 12),
      ),
    ];
  }

  static List<BoxShadow> goldGlow({double opacity = 0.18, double blur = 26, double y = 14}) {
    return [
      BoxShadow(
        color: gold.withValues(alpha: opacity),
        blurRadius: blur,
        offset: Offset(0, y),
      ),
    ];
  }

  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(letterSpacing: -0.8, fontWeight: FontWeight.w700),
      displayMedium: base.displayMedium?.copyWith(letterSpacing: -0.6, fontWeight: FontWeight.w700),
      displaySmall: base.displaySmall?.copyWith(letterSpacing: -0.4, fontWeight: FontWeight.w700),
      headlineLarge: base.headlineLarge?.copyWith(letterSpacing: -0.4, fontWeight: FontWeight.w700),
      headlineMedium: base.headlineMedium?.copyWith(letterSpacing: -0.3, fontWeight: FontWeight.w700),
      headlineSmall: base.headlineSmall?.copyWith(letterSpacing: -0.2, fontWeight: FontWeight.w700),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(fontWeight: FontWeight.w400),
      bodyMedium: base.bodyMedium?.copyWith(fontWeight: FontWeight.w400),
      bodySmall: base.bodySmall?.copyWith(fontWeight: FontWeight.w400),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      labelSmall: base.labelSmall?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  static ThemeData dark() => _luxuryTheme(brightness: Brightness.dark);

  static ThemeData light() => _luxuryTheme(brightness: Brightness.light);

  static ThemeData _luxuryTheme({required Brightness brightness}) {
    final textTheme = _textTheme(brightness).apply(
      bodyColor: text,
      displayColor: text,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      colorScheme: brightness == Brightness.dark
          ? const ColorScheme.dark(
              primary: gold,
              secondary: gold,
              surface: onyx2,
              error: error,
              onPrimary: Colors.black,
              onSecondary: Colors.black,
              onSurface: Colors.white,
              onError: Colors.white,
            )
          : const ColorScheme.light(
              primary: gold,
              secondary: gold,
              surface: surface,
              error: error,
              onPrimary: Color(0xFF111111),
              onSecondary: Color(0xFF111111),
              onSurface: text,
              onError: Colors.white,
            ),
      textTheme: textTheme,
      dividerColor: border,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: gold,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ).copyWith(
          overlayColor: WidgetStatePropertyAll(gold.withValues(alpha: 0.10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.dark ? onyx3 : surface,
        hintStyle: textTheme.bodyMedium?.copyWith(color: textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: gold.withValues(alpha: 0.55), width: 1),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.dark ? onyx3 : const Color(0xFF111111),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      ),
    );
  }
}
