extension NumDistance on num {
  /// Returns the distance between this number and another number.
  num distanceTo(num other) => (this - other).abs();
}