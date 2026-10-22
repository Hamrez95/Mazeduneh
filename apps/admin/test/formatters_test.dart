import 'dart:ui' show Locale;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mazeduneh_admin/formatters.dart';

void main() {
  test('formats visible digits without changing numeric values', () {
    expect(toPersianDigits('SKU 120'), 'SKU ۱۲۰');
    expect(formatPersianInteger(1234567), '۱٬۲۳۴٬۵۶۷');
    expect(formatPersianNumber(1234.5, fractionDigits: 1), '۱٬۲۳۴٫۵');
    expect(formatToman(1200000), '۱۲۰٬۰۰۰');
    expect(formatToman(1234565), '۱۲۳٬۴۵۷');
    expect(formatToman(1234564), '۱۲۳٬۴۵۶');
    expect(formatToman(-1234565), '-۱۲۳٬۴۵۷');
    expect(formatTomanInput(1234565), '۱۲۳٬۴۵۶٫۵');
    expect(parseTomanToRial('۱۲۳٬۴۵۶٫۵'), 1234565);
    expect(parsePersianNumber('۱٬۲۳۴٫۵'), 1234.5);
    expect(parsePersianNumber('١٬٢٣٤٫٥'), 1234.5);
    expect(parsePersianInteger('۱۲ بسته'), isNull);
    expect(toLatinDigits('۰۹۱۲-۳۴۵ ۶۷۸۹'), '0912-345 6789');
    expect(toLatinDigits('+٩٨ (۹۱۲) ۳۴۵'), '+98 (912) 345');
    expect(toPersianDigits('SKU KOO-250 · 09123456789'), 'SKU KOO-250 · ۰۹۱۲۳۴۵۶۷۸۹');
    expect(toPersianDigits('شناسه 550e8400-e29b-41d4-a716-446655440000'), 'شناسه 550e8400-e29b-41d4-a716-446655440000');
  });

  test('displays whole-toman order money in both locales', () {
    expect(formatAdminMoney(1234560), '۱۲۳٬۴۵۶ تومان');
    expect(formatAdminMoney(1234565), '۱۲۳٬۴۵۷ تومان');
    expect(formatAdminMoney(1234565, locale: const Locale('en', 'US')), '123,457 Toman');
    expect(formatAdminMoney(123456, currency: 'USD', locale: const Locale('en', 'US')), '123,456 USD');
  });

  test('localized integer output follows Persian or English UI locale', () {
    expect(formatLocalizedInteger(1234567, const Locale('fa')), '۱٬۲۳۴٬۵۶۷');
    expect(formatLocalizedInteger(1234567, const Locale('en', 'US')), '1,234,567');
    expect(toLocalizedDigits('تلفن ۱۲۳', const Locale('en', 'US')), 'تلفن 123');
  });

  test(
    'postal code formatter accepts Persian, Arabic, Latin and filters text',
    () {
      const formatter = PersianDigitsOnlyInputFormatter();
      final value = formatter.formatEditUpdate(
        const TextEditingValue(),
        const TextEditingValue(
          text: '۱۲A٣4-۵',
          selection: TextSelection.collapsed(offset: 7),
        ),
      );
      expect(value.text, '۱۲۳۴۵');
      expect(value.selection.extentOffset, value.text.length);
    },
  );

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

  test('toman amounts accept only precision supported by integer rials', () {
    expect(parseTomanToRial('۱٬۲۳۴٫۵'), 12345);
    expect(parseTomanToRial('١٢٣٫٤'), 1234);
    expect(parseTomanToRial('۱٫۲۵'), isNull);
    expect(parseTomanToRial('۱۲۳٫۴ تومان'), isNull);
  });
}

