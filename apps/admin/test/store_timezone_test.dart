import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mazeduneh_admin/localized_calendar.dart';
import 'package:mazeduneh_admin/store_timezone.dart';

void main() {
  test('converts the Tehran midnight boundary to the correct UTC day', () {
    final utc = storeWallTimeToUtc(DateTime(2026, 10, 21));

    expect(utc, DateTime.utc(2026, 10, 20, 20, 30));
    final wall = storeUtcToWallTime(utc);
    expect(
      (wall.year, wall.month, wall.day, wall.hour, wall.minute),
      (2026, 10, 21, 0, 0),
    );
  });

  test(
    'formats an instant in Tehran time for Persian and English calendars',
    () {
      final instant = DateTime.utc(2026, 10, 20, 20, 30);

      expect(
        formatCalendarDateTime(instant, const Locale('fa')),
        contains('۰۰:۰۰'),
      );
      expect(
        formatCalendarDateTime(instant, const Locale('en')),
        contains('00:00'),
      );
    },
  );
}
