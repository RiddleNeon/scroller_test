import 'package:flutter/cupertino.dart';

extension ConstraintsContainPos on BoxConstraints {
  bool contains(Offset pos) {
    return pos.dx >= 0 && pos.dx <= maxWidth && pos.dy >= 0 && pos.dy <= maxHeight;
  }
}
