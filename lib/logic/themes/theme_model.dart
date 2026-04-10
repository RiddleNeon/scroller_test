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
  final Color background;
  final Color onBackground;
  final Color surface;
  final Color onSurface;
  final Color error;
  final Color onError;
  final bool isDark;

  const CustomThemeColors({
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.tertiary,
    required this.onTertiary,
    required this.background,
    required this.onBackground,
    required this.surface,
    required this.onSurface,
    required this.error,
    required this.onError,
    this.isDark = false,
  });

  // ── Generators ────────────────────────────────────────────────────────────

  /// Generates a full harmonious palette from a single primary seed color.
  factory CustomThemeColors.fromPrimary(Color primary, {bool dark = false}) =>
      CustomThemeColors.fromSeeds(primary: primary, dark: dark);

  /// Generates a palette from 1–3 seed colors.
  ///
  /// - [primary] is required.
  /// - [secondary] and [tertiary] are optional; missing ones are derived via
  ///   hue rotation from [primary].
  /// - [dark] switches between light and dark surface/background generation.
  factory CustomThemeColors.fromSeeds({
    required Color primary,
    Color? secondary,
    Color? tertiary,
    bool dark = false,
  }) {
    final hsl = HSLColor.fromColor(primary);

    Color _deriveAccent(double hueShift) => hsl
        .withHue((hsl.hue + hueShift) % 360)
        .withLightness(hsl.lightness.clamp(0.35, 0.65))
        .withSaturation(hsl.saturation.clamp(0.3, 0.8))
        .toColor();

    final resolvedSecondary = secondary ?? _deriveAccent(30);
    final resolvedTertiary = tertiary ?? _deriveAccent(60);

    final bgHsl = hsl.withSaturation(0.08);
    final Color background;
    final Color surface;
    final Color onBackground;
    final Color onSurface;

    if (dark) {
      background = bgHsl.withLightness(0.08).toColor();
      surface    = bgHsl.withLightness(0.13).toColor();
      onBackground = const Color(0xFFECECEC);
      onSurface    = const Color(0xFFECECEC);
    } else {
      background = bgHsl.withLightness(0.97).toColor();
      surface    = bgHsl.withLightness(0.94).toColor();
      onBackground = const Color(0xFF1A1A1A);
      onSurface    = const Color(0xFF1A1A1A);
    }

    Color _contrast(Color c) =>
        c.computeLuminance() > 0.45 ? const Color(0xFF1A1A1A) : Colors.white;

    return CustomThemeColors(
      primary:      primary,
      onPrimary:    _contrast(primary),
      secondary:    resolvedSecondary,
      onSecondary:  _contrast(resolvedSecondary),
      tertiary:     resolvedTertiary,
      onTertiary:   _contrast(resolvedTertiary),
      background:   background,
      onBackground: onBackground,
      surface:      surface,
      onSurface:    onSurface,
      error:        dark ? const Color(0xFFCF6679) : const Color(0xFFB00020),
      onError:      Colors.white,
      isDark:       dark,
    );
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  factory CustomThemeColors.fromJson(Map<String, dynamic> json) {
    // toUnsigned(32) safely handles values stored as signed ints (legacy bug)
    int _c(String key, int fallback) =>
        (json[key] as int? ?? fallback).toUnsigned(32);

    return CustomThemeColors(
      primary:      Color(_c('primary',       0xFF6C5443)),
      onPrimary:    Color(_c('on_primary',    0xFFFFFFFF)),
      secondary:    Color(_c('secondary',     0xFF8C7460)),
      onSecondary:  Color(_c('on_secondary',  0xFFFFFFFF)),
      tertiary:     Color(_c('tertiary',      0xFF6C8C54)),
      onTertiary:   Color(_c('on_tertiary',   0xFFFFFFFF)),
      background:   Color(_c('background',    0xFFF8F4F0)),
      onBackground: Color(_c('on_background', 0xFF1A1A1A)),
      surface:      Color(_c('surface',       0xFFF2EDE8)),
      onSurface:    Color(_c('on_surface',    0xFF1A1A1A)),
      error:        Color(_c('error',         0xFFB00020)),
      onError:      Color(_c('on_error',      0xFFFFFFFF)),
      isDark:       json['is_dark'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'primary':       primary.value,
    'on_primary':    onPrimary.value,
    'secondary':     secondary.value,
    'on_secondary':  onSecondary.value,
    'tertiary':      tertiary.value,
    'on_tertiary':   onTertiary.value,
    'background':    background.value,
    'on_background': onBackground.value,
    'surface':       surface.value,
    'on_surface':    onSurface.value,
    'error':         error.value,
    'on_error':      onError.value,
    'is_dark':       isDark,
  };

  // ── Helpers ───────────────────────────────────────────────────────────────

  CustomThemeColors copyWith({
    Color? primary,
    Color? onPrimary,
    Color? secondary,
    Color? onSecondary,
    Color? tertiary,
    Color? onTertiary,
    Color? background,
    Color? onBackground,
    Color? surface,
    Color? onSurface,
    Color? error,
    Color? onError,
    bool? isDark,
  }) =>
      CustomThemeColors(
        primary:      primary      ?? this.primary,
        onPrimary:    onPrimary    ?? this.onPrimary,
        secondary:    secondary    ?? this.secondary,
        onSecondary:  onSecondary  ?? this.onSecondary,
        tertiary:     tertiary     ?? this.tertiary,
        onTertiary:   onTertiary   ?? this.onTertiary,
        background:   background   ?? this.background,
        onBackground: onBackground ?? this.onBackground,
        surface:      surface      ?? this.surface,
        onSurface:    onSurface    ?? this.onSurface,
        error:        error        ?? this.error,
        onError:      onError      ?? this.onError,
        isDark:       isDark       ?? this.isDark,
      );

  ThemeData toThemeData() {
    final scheme = ColorScheme(
      brightness:   isDark ? Brightness.dark : Brightness.light,
      primary:      primary,
      onPrimary:    onPrimary,
      secondary:    secondary,
      onSecondary:  onSecondary,
      tertiary:     tertiary,
      onTertiary:   onTertiary,
      background:   background,
      onBackground: onBackground,
      surface:      surface,
      onSurface:    onSurface,
      error:        error,
      onError:      onError,
    );
    return ThemeData(
      colorScheme:            scheme,
      useMaterial3:           true,
      brightness:             isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: background,
      cardColor:              surface,
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation:       0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────

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
    // primary_color is BIGINT after migration; toUnsigned(32) handles legacy data
    final rawPrimary = (json['primary_color'] as int? ?? 0xFF6C5443).toUnsigned(32);

    CustomThemeColors colors;
    final rawThemeData = json['theme_data'];
    if (rawThemeData != null) {
      try {
        final decoded = rawThemeData is String
            ? jsonDecode(rawThemeData) as Map<String, dynamic>
            : rawThemeData as Map<String, dynamic>;
        colors = CustomThemeColors.fromJson(decoded);
      } catch (_) {
        colors = CustomThemeColors.fromPrimary(Color(rawPrimary));
      }
    } else {
      colors = CustomThemeColors.fromPrimary(Color(rawPrimary));
    }

    return CustomThemeModel(
      id:        json['id']         as String? ?? UniqueKey().toString(),
      name:      json['name']       as String? ?? 'Untitled Theme',
      colors:    colors,
      createdBy: json['created_by'] as String?,
      likesCount: json['likes_count'] as int? ?? 0,
      isPublic:  json['is_public']  as bool?   ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id.length > 20) 'id': id,
    'name':          name,
    'primary_color': colors.primary.value, // BIGINT in DB — no overflow
    'theme_data':    jsonEncode(colors.toJson()),
    'is_public':     isPublic,
    'created_by':    createdBy ?? currentUser.id,
    'created_at':    createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
  };

  CustomThemeModel copyWith({
    String? id,
    String? name,
    CustomThemeColors? colors,
    Color? primaryColor,
    bool? isPublic,
    int? likesCount,
  }) =>
      CustomThemeModel(
        id:        id        ?? this.id,
        name:      name      ?? this.name,
        colors:    colors    ?? (primaryColor != null
            ? CustomThemeColors.fromPrimary(primaryColor)
            : this.colors),
        createdBy: createdBy,
        likesCount: likesCount ?? this.likesCount,
        isPublic:  isPublic  ?? this.isPublic,
        createdAt: createdAt,
      );
}