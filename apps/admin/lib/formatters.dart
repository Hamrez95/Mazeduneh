String toPersianDigits(Object? value) {
  final text = value?.toString() ?? '';
  const digits = '۰۱۲۳۴۵۶۷۸۹';
  return text.replaceAllMapped(RegExp(r'[0-9]'), (match) => digits[int.parse(match.group(0)!)]);
}

String _groupDigits(String digits) {
  final groups = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    final start = end > 3 ? end - 3 : 0;
    groups.insert(0, digits.substring(start, end));
  }
  return groups.join('٬');
}

String formatPersianInteger(num value) {
  if (!value.isFinite) return toPersianDigits(value);
  final sign = value < 0 ? '-' : '';
  return toPersianDigits('$sign${_groupDigits(value.abs().round().toString())}');
}

String formatPersianNumber(num value, {int fractionDigits = 0}) {
  if (!value.isFinite) return toPersianDigits(value);
  final fixed = value.toStringAsFixed(fractionDigits);
  final parts = fixed.split('.');
  final integer = parts.first;
  final sign = integer.startsWith('-') ? '-' : '';
  final absolute = integer.replaceFirst('-', '');
  final fraction = parts.length == 1 ? '' : '٫${parts[1]}';
  return toPersianDigits('$sign${_groupDigits(absolute)}$fraction');
}

String formatToman(num rial) => formatPersianInteger((rial / 10).round());

String formatPersianDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return toPersianDigits(
    '${local.year}/${two(local.month)}/${two(local.day)} ${two(local.hour)}:${two(local.minute)}',
  );
}