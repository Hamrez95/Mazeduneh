import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mazeduneh_admin/localized_calendar.dart';

void main() {
  const persian = Locale('fa');
  const english = Locale('en', 'US');

  group('localized calendar formatting', () {
    test('formats Persian dates as Jalali with Persian digits', () {
      expect(formatCalendarDate(DateTime(2025, 3, 20), persian), '۱۴۰۳/۱۲/۳۰');
      expect(formatCalendarDate(DateTime(2025, 3, 21), persian), '۱۴۰۴/۰۱/۰۱');
    });

    test('formats English dates as Gregorian with Latin digits', () {
      expect(
        formatCalendarDate(DateTime(2025, 3, 21), english),
        'March 21, 2025',
      );
    });

    test('parses Persian, Arabic, and Latin digits as Jalali dates', () {
      final expected = DateTime(2025, 3, 21);
      expect(parseCalendarDate('۱۴۰۴/۰۱/۰۱', persian), expected);
      expect(parseCalendarDate('١٤٠٤/٠١/٠١', persian), expected);
      expect(parseCalendarDate('1404/01/01', persian), expected);
    });

    test('parses dashed Jalali dates without confusing them with ISO dates', () {
      final expected = DateTime(2025, 3, 21);
      expect(parseCalendarDate('۱۴۰۴-۰۱-۰۱', persian), expected);
      expect(parseCalendarDate('١٤٠٤-٠١-٠١', persian), expected);
      expect(parseCalendarDate('1404-01-01', persian), expected);
      expect(parseCalendarDate('۱۴۰۴-۰۱-۳۲', persian), isNull);
      expect(parseCalendarDate('2025-03-21', persian), expected);
    });

    test('accepts ISO dates in Persian fields for existing records', () {
      expect(parseCalendarDate('2025-03-21', persian), DateTime(2025, 3, 21));
    });

    test(
      'parses Gregorian dates in English fields and rejects invalid dates',
      () {
        expect(
          parseCalendarDate('March 21, 2025', english),
          DateTime(2025, 3, 21),
        );
        expect(parseCalendarDate('03/21/2025', english), DateTime(2025, 3, 21));
        expect(parseCalendarDate('۱۴۰۴/۱۳/۰۱', persian), isNull);
        expect(parseCalendarDate('۱۴۰۴/۰۱/۳۲', persian), isNull);
        expect(parseCalendarDate('February 30, 2025', english), isNull);
      },
    );

    test('converts date picker values to and from Gregorian storage dates', () {
      final stored = DateTime(2025, 3, 21);
      final pickerValue = calendarDateFor(stored, persian);
      expect(pickerValue, DateTime(1404, 1, 1));
      expect(gregorianDateFor(pickerValue, persian), stored);
      expect(calendarDateFor(stored, english), stored);
      expect(gregorianDateFor(stored, english), stored);
    });
  });
}


