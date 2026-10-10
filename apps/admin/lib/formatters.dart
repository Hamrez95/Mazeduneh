String toPersianDigits(Object? value) {
  final text = value?.toString() ?? '';
  const digits = '۰۱۲۳۴۵۶۷۸۹';
  return text.replaceAllMapped(RegExp(r'[0-9]'), (match) => digits[int.parse(match.group(0)!)]);
}

String _normalizeDigitsAndSeparators(String value) {
  const persianDigits = '۰۱۲۳۴۵۶۷۸۹';
  const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
  var normalized = value;
  for (var index = 0; index < 10; index++) {
    normalized = normalized
        .replaceAll(persianDigits[index], '$index')
        .replaceAll(arabicDigits[index], '$index');
  }
  return normalized
      .replaceAll('٫', '.')
      .replaceAll('٬', ',')
      .replaceAll('،', ',')
      .replaceAll('−', '-');
}

String normalizeNumberDigits(String value) =>
    _normalizeDigitsAndSeparators(value).replaceAll(',', '');

num? parsePersianNumber(String? value) => num.tryParse(normalizeNumberDigits(value?.trim() ?? ''));

const int maxApiInteger = 2147483647;
const int maxInventoryAdjustment = 1000000;
const int maxSafeTomanAmount = 900719925474099;
final BigInt _maxSafeInteger = BigInt.from(9007199254740991);

int? parsePersianInteger(String? value, {int? min, int? max}) {
  if (min != null && max != null && min > max) return null;
  final normalized = _normalizeDigitsAndSeparators(value?.trim() ?? '');
  if (normalized.isEmpty ||
      !RegExp(r'^[+-]?(?:\d+|\d{1,3}(?:,\d{3})+)$').hasMatch(normalized)) {
    return null;
  }

  final integer = BigInt.tryParse(normalized.replaceAll(',', ''));
  if (integer == null || integer.abs() > _maxSafeInteger) return null;
  if (min != null && integer < BigInt.from(min)) return null;
  if (max != null && integer > BigInt.from(max)) return null;
  return integer.toInt();
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

String formatPersianDate(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return toPersianDigits('${value.year}/${two(value.month)}/${two(value.day)}');
}

String formatPersianDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return toPersianDigits(
    '${local.year}/${two(local.month)}/${two(local.day)} ${two(local.hour)}:${two(local.minute)}',
  );
}
