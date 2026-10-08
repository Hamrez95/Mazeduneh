import 'package:flutter_test/flutter_test.dart';
import 'package:mazeduneh_admin/formatters.dart';

void main() {
  test('formats visible digits without changing numeric values', () {
    expect(toPersianDigits('SKU 120'), 'SKU ۱۲۰');
    expect(formatPersianInteger(1234567), '۱٬۲۳۴٬۵۶۷');
    expect(formatPersianNumber(1234.5, fractionDigits: 1), '۱٬۲۳۴٫۵');
    expect(formatToman(1200000), '۱۲۰٬۰۰۰');
    expect(parsePersianNumber('۱٬۲۳۴٫۵'), 1234.5);
    expect(parsePersianNumber('١٬٢٣٤٫٥'), 1234.5);
    expect(parsePersianInteger('۱۲ بسته'), isNull);
  });

  test('accepts bounded whole numbers across Persian, Arabic, and Latin digits', () {
    expect(parsePersianInteger('1,234'), 1234);
    expect(parsePersianInteger('۱٬۲۳۴'), 1234);
    expect(parsePersianInteger('١٬٢٣٤'), 1234);
    expect(parsePersianInteger('-۱۲'), -12);
    expect(parsePersianInteger('+12'), 12);
    expect(parsePersianInteger('۲۱۴۷۴۸۳۶۴۷', min: 0, max: maxApiInteger), maxApiInteger);
    expect(parsePersianInteger('۹۰۰۷۱۹۹۲۵۴۷۴۰۹۹', min: 0, max: maxSafeTomanAmount), maxSafeTomanAmount);
    expect(parsePersianInteger('۹۰۰۷۱۹۹۲۵۴۷۴۰۹۹۱'), 9007199254740991);
    expect(parsePersianInteger('۹۰۰۷۱۹۹۲۵۴۷۴۰۹۹۲'), isNull);
    expect(parsePersianInteger('12', min: 13, max: 10), isNull);
  });

  test('rejects decimal, non-finite, empty, malformed, and out-of-range integers', () {
    for (final value in <String?>[
      null,
      '',
      '   ',
      '1.5',
      '۱٫۵',
      '۱،۵',
      'NaN',
      'Infinity',
      '-Infinity',
      '12,34',
      '1,,000',
      '2147483648',
    ]) {
      expect(parsePersianInteger(value, min: 0, max: maxApiInteger), isNull, reason: 'value=$value');
    }
  });
}
