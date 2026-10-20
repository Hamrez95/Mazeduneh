import 'package:flutter/services.dart';
import 'store_timezone.dart';

String toPersianDigits(Object? value) {
  final text = value?.toString() ?? '';
  const digits = '۰۱۲۳۴۵۶۷۸۹';
  return text.replaceAllMapped(RegExp(r'[0-9]'), (match) => digits[int.parse(match.group(0)!)]);
}

class PersianDigitsInputFormatter extends TextInputFormatter {
  const PersianDigitsInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    final text = newValue.text.replaceAllMapped(RegExp(r'[0-9٠-٩]'), (match) {
      final digit = match.group(0)!;
      return persian[int.tryParse(digit) ?? arabic.indexOf(digit)];
    });
    return newValue.copyWith(text: text, composing: TextRange.empty);
  }
}

class PersianGroupedIntegerInputFormatter extends TextInputFormatter {
  const PersianGroupedIntegerInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // Keep decimal input visible so integer validators can reject it instead of
    // silently turning e.g. ۱٫۵ into ۱۵.
    if (RegExp(r'[.٫]').hasMatch(newValue.text)) {
      return const PersianDigitsInputFormatter().formatEditUpdate(oldValue, newValue);
    }
    final digits = normalizeNumberDigits(newValue.text).replaceAll(RegExp(r'[^0-9]'), '');
    final formatted = toPersianDigits(_groupDigits(digits));
    final cursorPosition = newValue.selection.extentOffset.clamp(0, newValue.text.length).toInt();
    final digitsBeforeCursor = normalizeNumberDigits(newValue.text.substring(0, cursorPosition))
        .replaceAll(RegExp(r'[^0-9]'), '').length;
    var offset = 0;
    var digitCount = 0;
    while (offset < formatted.length && digitCount < digitsBeforeCursor) {
      if (RegExp(r'[۰-۹]').hasMatch(formatted[offset])) digitCount++;
      offset++;
    }
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: offset));
  }
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

/// Convert a toman entry with at most one decimal digit to the API's integer rials.
int? parseTomanToRial(String? value) {
  final normalized = _normalizeDigitsAndSeparators(value?.trim() ?? '');
  if (!RegExp(r'^[+-]?(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d)?$')
      .hasMatch(normalized)) {
    return null;
  }
  final toman = num.tryParse(normalized.replaceAll(',', ''));
  if (toman == null || !toman.isFinite || toman.abs() > maxSafeTomanAmount) {
    return null;
  }
  return (toman * 10).round();
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

/// API amounts remain integer rials. Display the exact amount in tomans,
/// including one decimal place when the rial amount is not divisible by ten.
String formatToman(num rial) {
  if (rial % 10 == 0) return formatPersianInteger(rial / 10);
  var formatted = formatPersianNumber(rial / 10, fractionDigits: 6);
  while (formatted.endsWith('۰')) {
    formatted = formatted.substring(0, formatted.length - 1);
  }
  if (formatted.endsWith('٫')) {
    formatted = formatted.substring(0, formatted.length - 1);
  }
  return formatted;
}

String formatAdminMoney(num amount, {String currency = 'IRR'}) =>
    currency.toUpperCase() == 'IRR'
        ? '${formatToman(amount)} تومان'
        : '${formatPersianNumber(amount)} $currency';

String formatPersianDate(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return toPersianDigits('${value.year}/${two(value.month)}/${two(value.day)}');
}

String formatPersianDateTime(DateTime value) {
  final local = storeUtcToWallTime(value);
  String two(int number) => number.toString().padLeft(2, '0');
  return toPersianDigits(
    '${local.year}/${two(local.month)}/${two(local.day)} ${two(local.hour)}:${two(local.minute)}',
  );
}

