String formatNumber(int value) {
  final negative = value < 0;
  final source = value.abs().toString();
  final chunks = <String>[];
  for (var end = source.length; end > 0; end -= 3) {
    final start = (end - 3).clamp(0, end).toInt();
    chunks.add(source.substring(start, end));
  }
  final formatted = chunks.reversed.join(',');
  return negative ? '-$formatted' : formatted;
}

String formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
