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
    final defaults = brightness == Brightness.dark ? darkScheme : lightScheme;
    final seeded = ColorScheme.fromSeed(seedColor: primary, brightness: brightness);
    final cappuccinoBase = _lerpScheme(defaults, seeded, 0.44);

    final anchoredSecondary = secondary ?? _colorLerp(cappuccinoBase.secondary, primary, 0.22);
    final anchoredTertiary = tertiary ?? _colorLerp(cappuccinoBase.tertiary, primary, 0.18);
    final anchoredSurface = surface ?? _colorLerp(cappuccinoBase.surface, primary, 0.08);
    final anchoredContainer =
        surfaceContainerHighest ?? _colorLerp(cappuccinoBase.surfaceContainerHighest, anchoredSurface, 0.62);
    final surfaceContainerHigh = _colorLerp(anchoredSurface, anchoredContainer, 0.72);
    final surfaceContainer = _colorLerp(anchoredSurface, anchoredContainer, 0.52);
    final surfaceContainerLow = _colorLerp(anchoredSurface, anchoredContainer, 0.34);
    final surfaceContainerLowest = _colorLerp(anchoredSurface, anchoredContainer, 0.18);
    final surfaceBright = _colorLerp(anchoredSurface, Colors.white, brightness == Brightness.dark ? 0.06 : 0.18);
    final surfaceDim = _colorLerp(anchoredSurface, Colors.black, brightness == Brightness.dark ? 0.16 : 0.06);

    final template = cappuccinoBase.copyWith(
      primary: primary,
      onPrimary: _bestOnColor(primary),
      secondary: anchoredSecondary,
      onSecondary: _bestOnColor(anchoredSecondary),
      tertiary: anchoredTertiary,
      onTertiary: _bestOnColor(anchoredTertiary),
      surface: anchoredSurface,
      onSurface: _bestOnColor(anchoredSurface),
      surfaceBright: surfaceBright,
      surfaceDim: surfaceDim,
      surfaceContainerLowest: surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: anchoredContainer,
      onSurfaceVariant: _bestOnColor(anchoredContainer).withValues(alpha: 0.84),
      surfaceTint: primary,
    );

    return _lerpScheme(cappuccinoBase, template, 0.86);
  }

  static Color _bestOnColor(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : const Color(0xFF1D1712);
  }

  static ColorScheme _lerpScheme(ColorScheme a, ColorScheme b, double t) {
    return a.copyWith(
      primary: _colorLerp(a.primary, b.primary, t),
      onPrimary: _colorLerp(a.onPrimary, b.onPrimary, t),
      secondary: _colorLerp(a.secondary, b.secondary, t),
      onSecondary: _colorLerp(a.onSecondary, b.onSecondary, t),
      tertiary: _colorLerp(a.tertiary, b.tertiary, t),
      onTertiary: _colorLerp(a.onTertiary, b.onTertiary, t),
      error: _colorLerp(a.error, b.error, t),
      onError: _colorLerp(a.onError, b.onError, t),
      surface: _colorLerp(a.surface, b.surface, t),
      onSurface: _colorLerp(a.onSurface, b.onSurface, t),
      surfaceBright: _colorLerp(a.surfaceBright, b.surfaceBright, t),
      surfaceDim: _colorLerp(a.surfaceDim, b.surfaceDim, t),
      surfaceContainerLowest: _colorLerp(a.surfaceContainerLowest, b.surfaceContainerLowest, t),
      surfaceContainerLow: _colorLerp(a.surfaceContainerLow, b.surfaceContainerLow, t),
      surfaceContainer: _colorLerp(a.surfaceContainer, b.surfaceContainer, t),
      surfaceContainerHigh: _colorLerp(a.surfaceContainerHigh, b.surfaceContainerHigh, t),
      surfaceContainerHighest: _colorLerp(a.surfaceContainerHighest, b.surfaceContainerHighest, t),
      onSurfaceVariant: _colorLerp(a.onSurfaceVariant, b.onSurfaceVariant, t),
      outline: _colorLerp(a.outline, b.outline, t),
      outlineVariant: _colorLerp(a.outlineVariant, b.outlineVariant, t),
      shadow: _colorLerp(a.shadow, b.shadow, t),
      scrim: _colorLerp(a.scrim, b.scrim, t),
      inverseSurface: _colorLerp(a.inverseSurface, b.inverseSurface, t),
      onInverseSurface: _colorLerp(a.onInverseSurface, b.onInverseSurface, t),
      inversePrimary: _colorLerp(a.inversePrimary, b.inversePrimary, t),
      surfaceTint: _colorLerp(a.surfaceTint, b.surfaceTint, t),
    );
  }

  static Color _colorLerp(Color a, Color b, double t) {
    return Color.lerp(a, b, t)!;
  }
}
