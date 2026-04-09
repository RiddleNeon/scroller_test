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

  /// Builds cappuccino-styled light and dark themes from a primary color.
  /// Optional colors can override the auto-derived palette.
  static ({ThemeData light, ThemeData dark}) cappuccinoFromPrimary({
    required Color primary,
    Color? secondary,
    Color? tertiary,
    Color? lightSurface,
    Color? darkSurface,
    Color? lightSurfaceContainerHighest,
    Color? darkSurfaceContainerHighest,
  }) {
    final schemes = cappuccinoSchemesFromPrimary(
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      lightSurface: lightSurface,
      darkSurface: darkSurface,
      lightSurfaceContainerHighest: lightSurfaceContainerHighest,
      darkSurfaceContainerHighest: darkSurfaceContainerHighest,
    );

    return (light: _build(schemes.light), dark: _build(schemes.dark));
  }

  /// Builds cappuccino-like color schemes for both brightness modes.
  static ({ColorScheme light, ColorScheme dark}) cappuccinoSchemesFromPrimary({
    required Color primary,
    Color? secondary,
    Color? tertiary,
    Color? lightSurface,
    Color? darkSurface,
    Color? lightSurfaceContainerHighest,
    Color? darkSurfaceContainerHighest,
  }) {
    final light = _buildCappuccinoScheme(
      brightness: Brightness.light,
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      surface: lightSurface,
      surfaceContainerHighest: lightSurfaceContainerHighest,
    );
    final dark = _buildCappuccinoScheme(
      brightness: Brightness.dark,
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      surface: darkSurface,
      surfaceContainerHighest: darkSurfaceContainerHighest,
    );
    return (light: light, dark: dark);
  }

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
        color: cs.surfaceContainerHighest,
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
        fillColor: cs.surfaceContainerHighest,
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

  static ColorScheme _buildCappuccinoScheme({
    required Brightness brightness,
    required Color primary,
    Color? secondary,
    Color? tertiary,
    Color? surface,
    Color? surfaceContainerHighest,
  }) {
    final bool isDark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(seedColor: primary, brightness: brightness);

    final derivedSecondary =
        secondary ?? _transformHsl(primary, hueShift: 18, saturationFactor: 0.6, lightnessDelta: isDark ? 0.06 : -0.05);
    final derivedTertiary =
        tertiary ?? _transformHsl(primary, hueShift: -28, saturationFactor: 0.5, lightnessDelta: isDark ? 0.08 : -0.03);

    final derivedSurface =
        surface ??
        _transformHsl(
          primary,
          hueShift: 14,
          saturationFactor: 0.18,
          lightnessTarget: isDark ? 0.10 : 0.93,
        );
    final derivedContainer =
        surfaceContainerHighest ??
        _transformHsl(
          derivedSurface,
          hueShift: 0,
          saturationFactor: 0.9,
          lightnessDelta: isDark ? 0.10 : -0.10,
        );

    return base.copyWith(
      primary: primary,
      onPrimary: _bestOnColor(primary),
      secondary: derivedSecondary,
      onSecondary: _bestOnColor(derivedSecondary),
      tertiary: derivedTertiary,
      onTertiary: _bestOnColor(derivedTertiary),
      surface: derivedSurface,
      onSurface: _bestOnColor(derivedSurface),
      surfaceContainerHighest: derivedContainer,
      onSurfaceVariant: _bestOnColor(derivedContainer).withValues(alpha: 0.84),
      inversePrimary: _transformHsl(primary, hueShift: 0, saturationFactor: 0.85, lightnessTarget: isDark ? 0.42 : 0.76),
      surfaceTint: primary,
    );
  }

  static Color _bestOnColor(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : const Color(0xFF1D1712);
  }

  static Color _transformHsl(
    Color color, {
    double hueShift = 0,
    double saturationFactor = 1,
    double lightnessDelta = 0,
    double? lightnessTarget,
  }) {
    final hsl = HSLColor.fromColor(color);
    final hue = (hsl.hue + hueShift) % 360;
    final saturation = (hsl.saturation * saturationFactor).clamp(0.0, 1.0);
    final lightness = (lightnessTarget ?? (hsl.lightness + lightnessDelta)).clamp(0.0, 1.0);
    return hsl.withHue(hue).withSaturation(saturation).withLightness(lightness).toColor();
  }
}
