import 'package:flutter_test/flutter_test.dart';
import 'package:mazeduneh_admin/formatters.dart';

void main() {
  test('formats visible digits without changing numeric values', () {
    expect(toPersianDigits('SKU 120'), 'SKU ۱۲۰');
    expect(formatPersianInteger(1234567), '۱٬۲۳۴٬۵۶۷');
    expect(formatPersianNumber(1234.5, fractionDigits: 1), '۱٬۲۳۴٫۵');
    expect(formatToman(1200000), '۱۲۰٬۰۰۰');
  });
}
