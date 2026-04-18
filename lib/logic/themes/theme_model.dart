import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wurp/base_logic.dart';

const defaultLightThemeId = '0f5309f7-0a82-4842-ae06-79a7251afa6f';
const defaultDarkThemeId = '3c5ec440-64fd-46ad-ac2c-2ea06821a32f';

/// Holds all customizable colors of a theme.
class CustomThemeColors {
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color onSecondary;
  final Color tertiary;
  final Color onTertiary;
  final Color surface;
  final Color onSurface;
  final Color surfaceContainerHighest;
  final Color onSurfaceVariant;
  final Color outlineVariant;
  final Color inverseSurface;
  final Color onInverseSurface;
  final Color error;
  final Color onError;
  final bool isDark;

  Color get background => surface;

  Color get onBackground => onSurface;

  const CustomThemeColors({
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.tertiary,
    required this.onTertiary,
    required this.surface,
    required this.onSurface,
    required this.surfaceContainerHighest,
    required this.onSurfaceVariant,
    required this.outlineVariant,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.error,
    required this.onError,
    this.isDark = false,
  });

  factory CustomThemeColors.fromPrimary(Color primary, {bool dark = false}) =>
      CustomThemeColors.fromSeeds(primary: primary, dark: dark);

  factory CustomThemeColors.fromSeeds({
    required Color primary,
    Color? secondary,
    Color? tertiary,
    bool dark = false,
    double themeVibrance = 0,
    double themeSaturation = 1,
    double themeTone = 0,
    double accentBoost = 0.65,
    double surfaceDepth = 0.5,
    double surfaceTintStrength = 0.35,
    double secondaryHueShift = 30,
    double tertiaryHueShift = 62,
    bool blendTertiaryWithSecondary = true,
  }) {
    final seedPrimary = _applyGlobalAdjustments(
      primary,
      saturation: themeSaturation,
      vibrance: themeVibrance,
      tone: themeTone,
    );
    final seedSecondary = secondary == null
        ? null
        : _applyGlobalAdjustments(
            secondary,
            saturation: themeSaturation,
            vibrance: themeVibrance,
            tone: themeTone,
          );
    final seedTertiary = tertiary == null
        ? null
        : _applyGlobalAdjustments(
            tertiary,
            saturation: themeSaturation,
            vibrance: themeVibrance,
            tone: themeTone,
          );

    final hsl = HSLColor.fromColor(seedPrimary);
    final accentIntensity = accentBoost.clamp(0.0, 1.0).toDouble();
    final baseSaturation = hsl.saturation;
    final rawSurface = _surfaceFromSeed(
      hsl,
      seedPrimary,
      dark: dark,
      depth: surfaceDepth,
      tintStrength: surfaceTintStrength,
    );
    final surface = _applyGlobalAdjustments(
      rawSurface,
      saturation: _lerp(1.0, themeSaturation, 0.24),
      vibrance: themeVibrance * 0.20,
      tone: themeTone * 0.70,
    );
    final surfaceHsl = HSLColor.fromColor(surface);

    final accentSaturation =
        (baseSaturation + _lerp(0.14, 0.36, accentIntensity))
            .clamp(0.38, 0.92)
            .toDouble();
    final accentLightnessBase = dark ? 0.62 : 0.50;

    Color deriveAccentFromHue(double hue, {double lightnessNudge = 0}) {
      final accentLightness =
          (accentLightnessBase + (0.5 - hsl.lightness) * 0.22 + lightnessNudge)
              .clamp(dark ? 0.50 : 0.38, dark ? 0.74 : 0.62)
              .toDouble();

      return hsl
          .withHue(hue)
          .withSaturation(accentSaturation)
          .withLightness(accentLightness)
          .toColor();
    }

    Color deriveAccent(double hueShift, {double lightnessNudge = 0}) =>
        deriveAccentFromHue(
          (hsl.hue + hueShift) % 360,
          lightnessNudge: lightnessNudge,
        );

    final secondaryShift =
        secondaryHueShift + (baseSaturation < 0.35 ? 14.0 : 0.0);
    final tertiaryShift =
        tertiaryHueShift + (baseSaturation < 0.35 ? 24.0 : 0.0);
    final resolvedSecondary =
        seedSecondary ??
        _applyGlobalAdjustments(
          deriveAccent(secondaryShift),
          saturation: themeSaturation,
          vibrance: themeVibrance,
          tone: themeTone * 0.85,
        );
    final resolvedTertiary =
        seedTertiary ??
        _applyGlobalAdjustments(
          _deriveTertiary(
            primaryHsl: hsl,
            secondary: resolvedSecondary,
            dark: dark,
            blendWithSecondary: blendTertiaryWithSecondary,
            tertiaryShift: tertiaryShift,
            deriveAccentFromHue: deriveAccentFromHue,
          ),
          saturation: themeSaturation,
          vibrance: themeVibrance,
          tone: themeTone * 0.85,
        );

    final resolvedSurfaceContainerHighest = dark
        ? surfaceHsl
              .withLightness(
                (surfaceHsl.lightness + 0.06).clamp(0.0, 1.0).toDouble(),
              )
              .toColor()
        : surfaceHsl
              .withLightness(
                (surfaceHsl.lightness - 0.05).clamp(0.0, 1.0).toDouble(),
              )
              .toColor();
    final resolvedInverseSurface = dark
        ? surfaceHsl
              .withLightness(
                (surfaceHsl.lightness + 0.78).clamp(0.84, 0.94).toDouble(),
              )
              .toColor()
        : surfaceHsl
              .withLightness(
                (surfaceHsl.lightness - 0.72).clamp(0.14, 0.26).toDouble(),
              )
              .toColor();

    final resolvedOnSurface = _pickOnColor(surface, minContrast: 4.5);
    final resolvedOnInverseSurface = _pickOnColor(
      resolvedInverseSurface,
      minContrast: 4.5,
    );

    final onSurfaceVariantCandidate = Color.lerp(
      resolvedOnSurface,
      surface,
      dark ? 0.28 : 0.42,
    )!;
    final resolvedOnSurfaceVariant = _ensureMinContrast(
      onSurfaceVariantCandidate,
      surface,
      minContrast: 3.4,
      fallback: resolvedOnSurface,
    );
    final outlineCandidate = Color.lerp(
      resolvedOnSurfaceVariant,
      surface,
      dark ? 0.36 : 0.52,
    )!;
    final resolvedOutlineVariant = _ensureMinContrast(
      outlineCandidate,
      surface,
      minContrast: 1.6,
      fallback: Color.lerp(resolvedOnSurface, surface, dark ? 0.48 : 0.62)!,
    );

    final onPrimary = _pickOnColor(seedPrimary, minContrast: 4.5);
    final onSecondary = _pickOnColor(resolvedSecondary, minContrast: 4.5);
    final onTertiary = _pickOnColor(resolvedTertiary, minContrast: 4.5);

    return CustomThemeColors(
      primary: seedPrimary,
      onPrimary: onPrimary,
      secondary: resolvedSecondary,
      onSecondary: onSecondary,
      tertiary: resolvedTertiary,
      onTertiary: onTertiary,
      surface: surface,
      onSurface: resolvedOnSurface,
      surfaceContainerHighest: resolvedSurfaceContainerHighest,
      onSurfaceVariant: resolvedOnSurfaceVariant,
      outlineVariant: resolvedOutlineVariant,
      inverseSurface: resolvedInverseSurface,
      onInverseSurface: resolvedOnInverseSurface,
      error: dark ? const Color(0xFFCF6679) : const Color(0xFFB00020),
      onError: Colors.white,
      isDark: dark,
    );
  }

  static Color _surfaceFromSeed(
    HSLColor seedHsl,
    Color primary, {
    required bool dark,
    double depth = 0.5,
    double tintStrength = 0.35,
  }) {
    final normalizedDepth = depth.clamp(0.0, 1.0).toDouble();
    final normalizedTint = tintStrength.clamp(0.0, 1.0).toDouble();
    final tintWeight = dark
        ? _lerp(0.30, 0.55, normalizedTint)
        : _lerp(0.42, 0.92, normalizedTint);
    final baseSurfaceSaturation = dark
        ? (seedHsl.saturation * 0.18 + 0.02)
        : (seedHsl.saturation * 0.24 + 0.03);
    final targetSurfaceSaturation = _lerp(
      baseSurfaceSaturation,
      seedHsl.saturation,
      tintWeight,
    ).clamp(dark ? 0.03 : 0.05, dark ? 0.24 : 0.38).toDouble();
    final tintedNeutral = seedHsl.withSaturation(targetSurfaceSaturation);
    final primaryLum = primary.computeLuminance();
    final targetLightness = dark
        ? (0.17 + (1 - primaryLum) * 0.04 + _lerp(-0.05, 0.05, normalizedDepth))
              .clamp(0.12, 0.26)
              .toDouble()
        : (0.91 - primaryLum * 0.03 + _lerp(0.06, -0.05, normalizedDepth))
              .clamp(0.84, 0.96)
              .toDouble();

    return tintedNeutral.withLightness(targetLightness).toColor();
  }

  static Color _deriveTertiary({
    required HSLColor primaryHsl,
    required Color secondary,
    required bool dark,
    required bool blendWithSecondary,
    required double tertiaryShift,
    required Color Function(double hue, {double lightnessNudge})
    deriveAccentFromHue,
  }) {
    if (!blendWithSecondary) {
      return deriveAccentFromHue(
        (primaryHsl.hue + tertiaryShift) % 360,
        lightnessNudge: dark ? -0.04 : 0.03,
      );
    }

    final secondaryHsl = HSLColor.fromColor(secondary);
    final midpointHue = _circularHueMidpoint(primaryHsl.hue, secondaryHsl.hue);
    final distance = _circularHueDistance(primaryHsl.hue, secondaryHsl.hue);
    final separationBoost = distance < 40
        ? 84.0
        : distance < 75
        ? 68.0
        : 54.0;
    final blendedHue = (midpointHue + separationBoost) % 360;

    return deriveAccentFromHue(blendedHue, lightnessNudge: dark ? -0.05 : 0.04);
  }

  static double _circularHueMidpoint(double a, double b) {
    final aRad = a * math.pi / 180.0;
    final bRad = b * math.pi / 180.0;
    final x = (math.cos(aRad) + math.cos(bRad)) * 0.5;
    final y = (math.sin(aRad) + math.sin(bRad)) * 0.5;
    final angle = (math.atan2(y, x) * 180.0 / math.pi + 360.0) % 360.0;
    return angle;
  }

  static double _circularHueDistance(double a, double b) {
    final diff = (a - b).abs() % 360.0;
    return diff > 180.0 ? 360.0 - diff : diff;
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static Color _applyGlobalAdjustments(
    Color color, {
    required double saturation,
    required double vibrance,
    required double tone,
  }) {
    final hsl = HSLColor.fromColor(color);
    final saturationFactor = saturation.clamp(0.4, 1.8).toDouble();
    final vibranceAmount = vibrance.clamp(-1.0, 1.0).toDouble();
    final toneShift = tone.clamp(-0.16, 0.16).toDouble();

    var sat = hsl.saturation;
    if (vibranceAmount >= 0) {
      sat += (1 - sat) * vibranceAmount * 0.55;
    } else {
      sat += sat * vibranceAmount * 0.55;
    }
    sat = _clamp01(sat * saturationFactor);

    final lightness = _clamp01(
      hsl.lightness + toneShift * (hsl.lightness < 0.5 ? 0.80 : 1.0),
    );

    return hsl.withSaturation(sat).withLightness(lightness).toColor();
  }

  static double _clamp01(double v) => v.clamp(0.0, 1.0).toDouble();

  static double _contrastRatio(Color a, Color b) {
    final l1 = a.computeLuminance();
    final l2 = b.computeLuminance();
    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  static Color _pickOnColor(Color background, {double minContrast = 4.5}) {
    const light = Color(0xFFFFFFFF);
    const dark = Color(0xFF111111);
    final contrastWithLight = _contrastRatio(background, light);
    final contrastWithDark = _contrastRatio(background, dark);

    if (contrastWithLight >= minContrast &&
        contrastWithLight >= contrastWithDark) {
      return light;
    }
    if (contrastWithDark >= minContrast) {
      return dark;
    }
    return contrastWithLight >= contrastWithDark ? light : dark;
  }

  static Color _ensureMinContrast(
    Color foreground,
    Color background, {
    required double minContrast,
    required Color fallback,
  }) {
    if (_contrastRatio(foreground, background) >= minContrast) {
      return foreground;
    }

    var adjusted = foreground;
    for (var i = 0; i < 6; i++) {
      adjusted = Color.lerp(adjusted, fallback, 0.35)!;
      if (_contrastRatio(adjusted, background) >= minContrast) {
        return adjusted;
      }
    }

    return fallback;
  }

  factory CustomThemeColors.fromJson(Map<String, dynamic> json) {
    int c(String key, int fallback) =>
        (json[key] as int? ?? fallback).toUnsigned(32);

    final isDark = json['is_dark'] as bool? ?? false;
    final storedSurface = Color(c('surface', 0xFFF2EDE8));
    final storedHsl = HSLColor.fromColor(storedSurface);

    final defaultContainer = isDark
        ? storedHsl
              .withLightness((storedHsl.lightness + 0.14).clamp(0.0, 1.0))
              .toColor()
              .toARGB32()
        : storedHsl
              .withLightness((storedHsl.lightness - 0.10).clamp(0.0, 1.0))
              .toColor()
              .toARGB32();

    return CustomThemeColors(
      primary: Color(c('primary', 0xFF6C5443)),
      onPrimary: Color(c('on_primary', 0xFFFFFFFF)),
      secondary: Color(c('secondary', 0xFF8C7460)),
      onSecondary: Color(c('on_secondary', 0xFFFFFFFF)),
      tertiary: Color(c('tertiary', 0xFF6C8C54)),
      onTertiary: Color(c('on_tertiary', 0xFFFFFFFF)),
      surface: storedSurface,
      onSurface: Color(c('on_surface', 0xFF1A1A1A)),
      surfaceContainerHighest: Color(
        c('surface_container_highest', defaultContainer),
      ),
      onSurfaceVariant: Color(
        c('on_surface_variant', isDark ? 0xFFC6C6C6 : 0xFF5D5044),
      ),
      outlineVariant: Color(
        c('outline_variant', isDark ? 0xFF3A312A : 0xFFC3B4A6),
      ),
      inverseSurface: Color(
        c('inverse_surface', isDark ? 0xFFF2EDE8 : 0xFF2A231E),
      ),
      onInverseSurface: Color(
        c('on_inverse_surface', isDark ? 0xFF1A1612 : 0xFFF2EDE8),
      ),
      error: Color(c('error', isDark ? 0xFFCF6679 : 0xFFB00020)),
      onError: Color(c('on_error', 0xFFFFFFFF)),
      isDark: isDark,
    );
  }

  Map<String, dynamic> toJson() => {
    'primary': primary.toARGB32(),
    'on_primary': onPrimary.toARGB32(),
    'secondary': secondary.toARGB32(),
    'on_secondary': onSecondary.toARGB32(),
    'tertiary': tertiary.toARGB32(),
    'on_tertiary': onTertiary.toARGB32(),
    'surface': surface.toARGB32(),
    'on_surface': onSurface.toARGB32(),
    'surface_container_highest': surfaceContainerHighest.toARGB32(),
    'on_surface_variant': onSurfaceVariant.toARGB32(),
    'outline_variant': outlineVariant.toARGB32(),
    'inverse_surface': inverseSurface.toARGB32(),
    'on_inverse_surface': onInverseSurface.toARGB32(),
    'error': error.toARGB32(),
    'on_error': onError.toARGB32(),
    'is_dark': isDark,
  };

  CustomThemeColors copyWith({
    Color? primary,
    Color? onPrimary,
    Color? secondary,
    Color? onSecondary,
    Color? tertiary,
    Color? onTertiary,
    Color? surface,
    Color? onSurface,
    Color? surfaceContainerHighest,
    Color? onSurfaceVariant,
    Color? outlineVariant,
    Color? inverseSurface,
    Color? onInverseSurface,
    Color? error,
    Color? onError,
    bool? isDark,
  }) => CustomThemeColors(
    primary: primary ?? this.primary,
    onPrimary: onPrimary ?? this.onPrimary,
    secondary: secondary ?? this.secondary,
    onSecondary: onSecondary ?? this.onSecondary,
    tertiary: tertiary ?? this.tertiary,
    onTertiary: onTertiary ?? this.onTertiary,
    surface: surface ?? this.surface,
    onSurface: onSurface ?? this.onSurface,
    surfaceContainerHighest:
        surfaceContainerHighest ?? this.surfaceContainerHighest,
    onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
    outlineVariant: outlineVariant ?? this.outlineVariant,
    inverseSurface: inverseSurface ?? this.inverseSurface,
    onInverseSurface: onInverseSurface ?? this.onInverseSurface,
    error: error ?? this.error,
    onError: onError ?? this.onError,
    isDark: isDark ?? this.isDark,
  );

  ThemeData toThemeData() {
    final scheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: onSecondary,
      tertiary: tertiary,
      onTertiary: onTertiary,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceContainerHighest,
      onSurfaceVariant: onSurfaceVariant,
      surfaceContainerHigh: Color.lerp(surface, surfaceContainerHighest, 0.72)!,
      surfaceContainer: Color.lerp(surface, surfaceContainerHighest, 0.52)!,
      surfaceContainerLow: Color.lerp(surface, surfaceContainerHighest, 0.34)!,
      surfaceContainerLowest: Color.lerp(
        surface,
        surfaceContainerHighest,
        0.18,
      )!,
      outline: Color.lerp(onSurfaceVariant, outlineVariant, 0.5)!,
      outlineVariant: outlineVariant,
      inverseSurface: inverseSurface,
      onInverseSurface: onInverseSurface,
      inversePrimary: Color.lerp(primary, surface, isDark ? 0.55 : 0.35)!,
      surfaceTint: primary,
      error: error,
      onError: onError,
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: surface,
      cardColor: surfaceContainerHighest,
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceContainerHighest,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: outlineVariant.withValues(alpha: 0.6),
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerHighest,
        hintStyle: TextStyle(color: onSurfaceVariant),
        prefixIconColor: onSurfaceVariant,
        suffixIconColor: onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: inverseSurface,
        contentTextStyle: TextStyle(color: onInverseSurface),
      ),
    );
  }
}

class CustomThemeModel {
  final String id;
  final String name;
  final CustomThemeColors colors;
  final String? createdBy;
  final String? originalThemeId;
  final int likesCount;
  final bool isPublic;
  final DateTime? createdAt;

  Color get primaryColor => colors.primary;

  const CustomThemeModel({
    required this.id,
    required this.name,
    required this.colors,
    this.createdBy,
    this.likesCount = 0,
    this.isPublic = false,
    this.createdAt,
    this.originalThemeId,
  });

  factory CustomThemeModel.fromJson(Map<String, dynamic> json) {
    return CustomThemeModel(
      id: json['id'] as String? ?? UniqueKey().toString(),
      name: json['name'] as String? ?? 'Untitled Theme',
      colors: getColorsFromJson(json),
      createdBy: json['created_by'] as String?,
      likesCount: json['likes_count'] as int? ?? 0,
      isPublic: json['is_public'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      originalThemeId: json['original_theme_id'] as String?,
    );
  }

  static CustomThemeColors getColorsFromJson(Map<String, dynamic> json) {
    final rawPrimary = (json['primary_color'] as int? ?? 0xFF6C5443).toUnsigned(
      32,
    );

    if (json['id'] == defaultLightThemeId) {
      return CustomThemeColors.fromSeeds(
        primary: Color(rawPrimary),
        dark: false,
      );
    }
    if (json['id'] == defaultDarkThemeId) {
      return CustomThemeColors.fromSeeds(
        primary: Color(rawPrimary),
        dark: true,
      );
    }

    final rawThemeData = json['theme_data'];
    if (rawThemeData == null) {
      return CustomThemeColors.fromPrimary(Color(rawPrimary));
    }

    try {
      final decoded = rawThemeData is String
          ? jsonDecode(rawThemeData) as Map<String, dynamic>
          : rawThemeData as Map<String, dynamic>;
      return CustomThemeColors.fromJson(decoded);
    } catch (_) {
      return CustomThemeColors.fromPrimary(Color(rawPrimary));
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'primary_color': colors.primary.toARGB32(),
    'theme_data': jsonEncode(colors.toJson()),
    'is_public': isPublic,
    'created_by': createdBy ?? currentUser.id,
    'created_at':
        createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    'original_theme_id': originalThemeId,
  };

  CustomThemeModel copyWith({
    String? id,
    String? originalThemeId,
    String? name,
    CustomThemeColors? colors,
    Color? primaryColor,
    bool? isPublic,
    int? likesCount,
    String? createdBy,
  }) => CustomThemeModel(
    id: id ?? this.id,
    name: name ?? this.name,
    colors:
        colors ??
        (primaryColor != null
            ? CustomThemeColors.fromPrimary(primaryColor)
            : this.colors),
    createdBy: createdBy ?? this.createdBy,
    likesCount: likesCount ?? this.likesCount,
    isPublic: isPublic ?? this.isPublic,
    createdAt: createdAt,
    originalThemeId: originalThemeId ?? this.originalThemeId,
  );
}
