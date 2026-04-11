import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:wurp/base_logic.dart';

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

  factory CustomThemeColors.fromPrimary(Color primary, {bool dark = false}) => CustomThemeColors.fromSeeds(primary: primary, dark: dark);

  factory CustomThemeColors.fromSeeds({required Color primary, Color? secondary, Color? tertiary, bool dark = false}) {
    final hsl = HSLColor.fromColor(primary);

    Color deriveAccent(double hueShift) =>
        hsl.withHue((hsl.hue + hueShift) % 360).withLightness(hsl.lightness.clamp(0.35, 0.65)).withSaturation(hsl.saturation.clamp(0.3, 0.8)).toColor();

    final resolvedSecondary = secondary ?? deriveAccent(30);
    final resolvedTertiary = tertiary ?? deriveAccent(60);

    final bgHsl = hsl.withSaturation(0.08);

    final Color resolvedSurface;
    final Color resolvedSurfaceContainerHighest;
    final Color resolvedInverseSurface;
    final Color resolvedOnInverseSurface;
    final Color resolvedOnSurface;
    final Color resolvedOnSurfaceVariant;
    final Color resolvedOutlineVariant;

    if (dark) {
      resolvedSurface = bgHsl.withLightness(0.08).toColor();
      resolvedSurfaceContainerHighest = bgHsl.withLightness(0.22).toColor();
      resolvedInverseSurface = bgHsl.withLightness(0.92).toColor();
      resolvedOnInverseSurface = const Color(0xFF1A1612);
      resolvedOnSurface = const Color(0xFFECECEC);
      resolvedOnSurfaceVariant = const Color(0xFFC6C6C6);
      resolvedOutlineVariant = hsl.withSaturation((hsl.saturation * 0.25).clamp(0.05, 0.30)).withLightness(0.28).toColor();
    } else {
      resolvedSurface = bgHsl.withLightness(0.97).toColor();
      resolvedSurfaceContainerHighest = bgHsl.withLightness(0.87).toColor();
      resolvedInverseSurface = bgHsl.withLightness(0.14).toColor();
      resolvedOnInverseSurface = const Color(0xFFF2EDE8);
      resolvedOnSurface = const Color(0xFF1A1A1A);
      resolvedOnSurfaceVariant = hsl.withSaturation((hsl.saturation * 0.40).clamp(0.08, 0.45)).withLightness(0.38).toColor();
      resolvedOutlineVariant = hsl.withSaturation((hsl.saturation * 0.22).clamp(0.05, 0.28)).withLightness(0.78).toColor();
    }

    Color contrast(Color c) => c.computeLuminance() > 0.45 ? const Color(0xFF1A1A1A) : Colors.white;

    return CustomThemeColors(
      primary: primary,
      onPrimary: contrast(primary),
      secondary: resolvedSecondary,
      onSecondary: contrast(resolvedSecondary),
      tertiary: resolvedTertiary,
      onTertiary: contrast(resolvedTertiary),
      surface: resolvedSurface,
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

  factory CustomThemeColors.fromJson(Map<String, dynamic> json) {
    int c(String key, int fallback) => (json[key] as int? ?? fallback).toUnsigned(32);

    final isDark = json['is_dark'] as bool? ?? false;
    final storedSurface = Color(c('surface', 0xFFF2EDE8));
    final storedHsl = HSLColor.fromColor(storedSurface);

    final defaultContainer = isDark
        ? storedHsl.withLightness((storedHsl.lightness + 0.14).clamp(0.0, 1.0)).toColor().toARGB32()
        : storedHsl.withLightness((storedHsl.lightness - 0.10).clamp(0.0, 1.0)).toColor().toARGB32();

    return CustomThemeColors(
      primary: Color(c('primary', 0xFF6C5443)),
      onPrimary: Color(c('on_primary', 0xFFFFFFFF)),
      secondary: Color(c('secondary', 0xFF8C7460)),
      onSecondary: Color(c('on_secondary', 0xFFFFFFFF)),
      tertiary: Color(c('tertiary', 0xFF6C8C54)),
      onTertiary: Color(c('on_tertiary', 0xFFFFFFFF)),
      surface: storedSurface,
      onSurface: Color(c('on_surface', 0xFF1A1A1A)),
      surfaceContainerHighest: Color(c('surface_container_highest', defaultContainer)),
      onSurfaceVariant: Color(c('on_surface_variant', isDark ? 0xFFC6C6C6 : 0xFF5D5044)),
      outlineVariant: Color(c('outline_variant', isDark ? 0xFF3A312A : 0xFFC3B4A6)),
      inverseSurface: Color(c('inverse_surface', isDark ? 0xFFF2EDE8 : 0xFF2A231E)),
      onInverseSurface: Color(c('on_inverse_surface', isDark ? 0xFF1A1612 : 0xFFF2EDE8)),
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
    surfaceContainerHighest: surfaceContainerHighest ?? this.surfaceContainerHighest,
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
      surfaceContainerLowest: Color.lerp(surface, surfaceContainerHighest, 0.18)!,
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
      appBarTheme: AppBarTheme(backgroundColor: primary, foregroundColor: onPrimary, elevation: 0),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceContainerHighest,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      dividerTheme: DividerThemeData(color: outlineVariant.withValues(alpha: 0.6), thickness: 1),
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
      floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: primary, foregroundColor: onPrimary),
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
  });

  factory CustomThemeModel.fromJson(Map<String, dynamic> json) {
    final rawPrimary = (json['primary_color'] as int? ?? 0xFF6C5443).toUnsigned(32);

    CustomThemeColors colors;
    final rawThemeData = json['theme_data'];
    if (rawThemeData != null) {
      try {
        final decoded = rawThemeData is String ? jsonDecode(rawThemeData) as Map<String, dynamic> : rawThemeData as Map<String, dynamic>;
        colors = CustomThemeColors.fromJson(decoded);
      } catch (_) {
        colors = CustomThemeColors.fromPrimary(Color(rawPrimary));
      }
    } else {
      colors = CustomThemeColors.fromPrimary(Color(rawPrimary));
    }

    return CustomThemeModel(
      id: json['id'] as String? ?? UniqueKey().toString(),
      name: json['name'] as String? ?? 'Untitled Theme',
      colors: colors,
      createdBy: json['created_by'] as String?,
      likesCount: json['likes_count'] as int? ?? 0,
      isPublic: json['is_public'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id.length > 20) 'id': id,
    'name': name,
    'primary_color': colors.primary.toARGB32(),
    'theme_data': jsonEncode(colors.toJson()),
    'is_public': isPublic,
    'created_by': createdBy ?? currentUser.id,
    'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
  };

  CustomThemeModel copyWith({String? id, String? name, CustomThemeColors? colors, Color? primaryColor, bool? isPublic, int? likesCount}) => CustomThemeModel(
    id: id ?? this.id,
    name: name ?? this.name,
    colors: colors ?? (primaryColor != null ? CustomThemeColors.fromPrimary(primaryColor) : this.colors),
    createdBy: createdBy,
    likesCount: likesCount ?? this.likesCount,
    isPublic: isPublic ?? this.isPublic,
    createdAt: createdAt,
  );
}
