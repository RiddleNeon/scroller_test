import 'dart:math';
import 'dart:ui';

extension OffsetDistance on Offset {
  double distanceTo(Offset other) {
    final dx = other.dx - this.dx;
    final dy = other.dy - this.dy;
    return sqrt(dx * dx + dy * dy);
  }
}