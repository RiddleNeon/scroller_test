import 'package:flutter/material.dart';

class AppTheme {
  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF6C5443),
    onPrimary: Color(0xFFFFF8F1),
    secondary: Color(0xFF8A7260),
    onSecondary: Color(0xFFFFF8F2),
    tertiary: Color(0xFF4F6A66),
    onTertiary: Color(0xFFF3FFFC),
    error: Color(0xFF8E3D34),
    onError: Color(0xFFFFF6F5),
    surface: Color(0xFFF5EEE6),
    onSurface: Color(0xFF2B221B),
    surfaceContainerHighest: Color(0xFFD9CCC0),
    onSurfaceVariant: Color(0xFF5D5044),
    outline: Color(0xFF8F7F72),
    outlineVariant: Color(0xFFC3B4A6),
    shadow: Color(0x22000000),
    scrim: Color(0x66000000),
    inverseSurface: Color(0xFF2A231E),
    onInverseSurface: Color(0xFFF3EAE1),
    inversePrimary: Color(0xFFDBC0A8),
    surfaceTint: Color(0xFF6C5443),
  );

  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFD2B89F),
    onPrimary: Color(0xFF3A2A1F),
    secondary: Color(0xFFC2AA95),
    onSecondary: Color(0xFF3A2D24),
    tertiary: Color(0xFF9EC5BE),
    onTertiary: Color(0xFF113A34),
    error: Color(0xFFFFB4A9),
    onError: Color(0xFF561E17),
    surface: Color(0xFF181411),
    onSurface: Color(0xFFECE1D7),
    surfaceContainerHighest: Color(0xFF3A312A),
    onSurfaceVariant: Color(0xFFC6B7A9),
    outline: Color(0xFF918274),
    outlineVariant: Color(0xFF4A4037),
    shadow: Color(0x66000000),
    scrim: Color(0x99000000),
    inverseSurface: Color(0xFFECE1D7),
    onInverseSurface: Color(0xFF2A231E),
    inversePrimary: Color(0xFF695240),
    surfaceTint: Color(0xFFD2B89F),
  );

  static ThemeData light() => _build(lightScheme);
  static ThemeData dark() => _build(darkScheme);

  static ThemeData _build(ColorScheme cs) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surfaceContainerHigh,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant.withValues(alpha: 0.6),
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainer,
        hintStyle: TextStyle(color: cs.onSurfaceVariant),
        prefixIconColor: cs.onSurfaceVariant,
        suffixIconColor: cs.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.primary, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.inverseSurface,
        contentTextStyle: TextStyle(color: cs.onInverseSurface),
      ),
    );
  }
}
