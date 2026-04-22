import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lightweight accessors that derive reusable UI sizes from active ThemeData.
extension ThemeUiValues on BuildContext {
  ThemeData get _theme => Theme.of(this);

  double get uiBorderWidth {
    final inputBorder = _theme.inputDecorationTheme.border;
    if (inputBorder is OutlineInputBorder) {
      return inputBorder.borderSide.width;
    }
    final divider = _theme.dividerTheme.thickness;
    return divider ?? 1;
  }

  double get uiFocusedBorderWidth {
    final focused = _theme.inputDecorationTheme.focusedBorder;
    if (focused is OutlineInputBorder) {
      return focused.borderSide.width;
    }
    return math.max(uiBorderWidth, 1.4);
  }

  double get uiRadiusMd {
    final inputBorder = _theme.inputDecorationTheme.border;
    if (inputBorder is OutlineInputBorder) {
      final resolved = inputBorder.borderRadius.resolve(Directionality.of(this));
      return resolved.topLeft.x;
    }
    return 14;
  }

  double get uiRadiusLg {
    final shape = _theme.cardTheme.shape;
    if (shape is RoundedRectangleBorder) {
      final resolved = shape.borderRadius.resolve(Directionality.of(this));
      return resolved.topLeft.x;
    }
    return uiRadiusMd + 4;
  }

  double get uiRadiusSm {
    final md = uiRadiusMd.clamp(0.0, 48.0).toDouble();
    final lower = math.min(6.0, md);
    final upper = math.max(6.0, md);
    return (md * 0.72).clamp(lower, upper).toDouble();
  }

  double get uiRadiusXl {
    final lg = uiRadiusLg.clamp(0.0, 64.0).toDouble();
    final upper = math.max(32.0, lg);
    return (lg + 6).clamp(lg, upper).toDouble();
  }

  double uiSpace(double base) {
    final density = _theme.visualDensity.vertical.clamp(-1.0, 1.0).toDouble();
    return (base + density * 2).clamp(2.0, base * 1.3).toDouble();
  }
}

