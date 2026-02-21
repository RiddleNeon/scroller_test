List<T> removeDuplicates<T>(List<T> list, {Object Function(T)? getCheckedParameter}) {
  final seenKeys = <Object?>{};
  final result = <T>[];
  for (var item in list) {
    final key = getCheckedParameter?.call(item) ?? item;
    if (seenKeys.add(key)) {
      result.add(item);
    }
  }
  return result;
}
