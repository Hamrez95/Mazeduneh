import 'package:flutter/material.dart';

import 'formatters.dart';

const _jalaliMonths = <String>[
  'فروردین',
  'اردیبهشت',
  'خرداد',
  'تیر',
  'مرداد',
  'شهریور',
  'مهر',
  'آبان',
  'آذر',
  'دی',
  'بهمن',
  'اسفند',
];

const _jalaliWeekdays = <String>[
  'یکشنبه',
  'دوشنبه',
  'سه‌شنبه',
  'چهارشنبه',
  'پنجشنبه',
  'جمعه',
  'شنبه',
];

const _englishMonths = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _englishWeekdays = <String>[
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

bool usesJalaliCalendar(Locale locale) =>
    locale.languageCode.toLowerCase() == 'fa';

DateTime calendarDateFor(DateTime gregorian, Locale locale) =>
    usesJalaliCalendar(locale)
    ? _toJalaliDate(gregorian)
    : DateUtils.dateOnly(gregorian);

DateTime gregorianDateFor(DateTime calendarDate, Locale locale) =>
    usesJalaliCalendar(locale)
    ? _toGregorianDate(calendarDate)
    : DateUtils.dateOnly(calendarDate);

String formatCalendarDate(DateTime gregorian, Locale locale) {
  final date = DateUtils.dateOnly(gregorian);
  if (usesJalaliCalendar(locale)) {
    final jalali = _gregorianToJalali(date);
    return toPersianDigits(
      '${jalali.$1.toString().padLeft(4, '0')}/${jalali.$2.toString().padLeft(2, '0')}/${jalali.$3.toString().padLeft(2, '0')}',
    );
  }
  return '${_englishMonths[date.month - 1]} ${date.day}, ${date.year}';
}

String formatCalendarDateTime(DateTime value, Locale locale) {
  final date = value.toLocal();
  final clock =
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  if (usesJalaliCalendar(locale)) {
    final jalali = _gregorianToJalali(date);
    final weekday = _jalaliWeekdays[date.weekday % 7];
    final dateText =
        '${toPersianDigits(jalali.$3)} ${_jalaliMonths[jalali.$2 - 1]} ${toPersianDigits(jalali.$1)}';
    return '$weekday، $dateText · ${toPersianDigits(clock)}';
  }
  return '${_englishWeekdays[date.weekday % 7]}, ${_englishMonths[date.month - 1]} ${date.day}, ${date.year} · $clock';
}

String formatLocalizedDate(BuildContext context, DateTime value) =>
    formatCalendarDate(value, Localizations.localeOf(context));

String formatLocalizedDateTime(BuildContext context, DateTime value) =>
    formatCalendarDateTime(value, Localizations.localeOf(context));

DateTime? parseCalendarDate(String? value, Locale locale) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final normalized = normalizeNumberDigits(text);
  if (usesJalaliCalendar(locale)) {
    // Keep pasted ISO dates usable for existing records; the field itself is
    // always displayed in the Solar Hijri calendar.
    if (text.contains('-'))
      return _parseGregorian(normalized.replaceAll('/', '-'));
    final match = RegExp(
      r'^(\d{1,4})[/.](\d{1,2})[/.](\d{1,2})$',
    ).firstMatch(normalized);
    if (match == null) return null;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    if (month < 1 ||
        month > 12 ||
        day < 1 ||
        day > _daysInJalaliMonth(year, month))
      return null;
    return _jalaliToGregorian(year, month, day);
  }

  if (text.contains('/')) {
    final match = RegExp(
      r'^(\d{1,2})/(\d{1,2})/(\d{4})$',
    ).firstMatch(normalized);
    if (match != null) {
      return _validGregorianDate(
        int.parse(match[3]!),
        int.parse(match[1]!),
        int.parse(match[2]!),
      );
    }
  }
  final namedMonth = RegExp(
    r'^([A-Za-z]+)\s+(\d{1,2}),?\s+(\d{4})$',
  ).firstMatch(text);
  if (namedMonth != null) {
    final month =
        _englishMonths.indexWhere(
          (name) => name.toLowerCase() == namedMonth[1]!.toLowerCase(),
        ) +
        1;
    if (month < 1) return null;
    return _validGregorianDate(
      int.parse(namedMonth[3]!),
      month,
      int.parse(namedMonth[2]!),
    );
  }
  return _parseGregorian(normalized.replaceAll('/', '-'));
}

Future<DateTime?> showLocalizedDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
}) async {
  final locale = Localizations.localeOf(context);
  final jalali = usesJalaliCalendar(locale);
  final selected = await showDatePicker(
    context: context,
    initialDate: calendarDateFor(initialDate, locale),
    firstDate: calendarDateFor(firstDate, locale),
    lastDate: calendarDateFor(lastDate, locale),
    locale: locale,
    textDirection: jalali ? TextDirection.rtl : TextDirection.ltr,
    helpText: helpText,
    initialEntryMode: DatePickerEntryMode.calendar,
    calendarDelegate: jalali
        ? const JalaliCalendarDelegate()
        : const GregorianCalendarDelegate(),
    builder: (context, child) => Directionality(
      textDirection: jalali ? TextDirection.rtl : TextDirection.ltr,
      child: child!,
    ),
  );
  if (selected == null) return null;
  return gregorianDateFor(selected, locale);
}

/// Flutter's date picker keeps its `DateTime` API. For Persian dates this
/// delegate treats the date components as Jalali calendar components and the
/// call site converts the result back to a Gregorian `DateTime` for storage.
class JalaliCalendarDelegate extends CalendarDelegate<DateTime> {
  const JalaliCalendarDelegate();

  @override
  DateTime now() => _toJalaliDate(DateTime.now());

  @override
  DateTime dateOnly(DateTime date) => DateUtils.dateOnly(date);

  @override
  int monthDelta(DateTime startDate, DateTime endDate) =>
      DateUtils.monthDelta(startDate, endDate);

  @override
  DateTime addMonthsToMonthDate(DateTime monthDate, int monthsToAdd) =>
      DateUtils.addMonthsToMonthDate(monthDate, monthsToAdd);

  @override
  DateTime addDaysToDate(DateTime date, int days) =>
      DateUtils.addDaysToDate(date, days);

  @override
  int firstDayOffset(int year, int month, MaterialLocalizations localizations) {
    final gregorian = _jalaliToGregorian(year, month, 1);
    final weekdayFromSunday = gregorian.weekday % 7;
    return (weekdayFromSunday - localizations.firstDayOfWeekIndex) % 7;
  }

  @override
  int getDaysInMonth(int year, int month) => _daysInJalaliMonth(year, month);

  @override
  DateTime getMonth(int year, int month) => DateTime(year, month);

  @override
  DateTime getDay(int year, int month, int day) => DateTime(year, month, day);

  @override
  String formatMonthYear(DateTime date, MaterialLocalizations localizations) =>
      '${_jalaliMonths[date.month - 1]} ${toPersianDigits(date.year)}';

  @override
  String formatYear(int year, MaterialLocalizations localizations) =>
      toPersianDigits(year);

  @override
  String formatMediumDate(DateTime date, MaterialLocalizations localizations) {
    final gregorian = _toGregorianDate(date);
    return '${_jalaliWeekdays[gregorian.weekday % 7]}، ${toPersianDigits(date.day)} ${_jalaliMonths[date.month - 1]}';
  }

  @override
  String formatShortMonthDay(
    DateTime date,
    MaterialLocalizations localizations,
  ) => '${toPersianDigits(date.day)} ${_jalaliMonths[date.month - 1]}';

  @override
  String formatShortDate(DateTime date, MaterialLocalizations localizations) =>
      '${toPersianDigits(date.day.toString().padLeft(2, '0'))}/${toPersianDigits(date.month.toString().padLeft(2, '0'))}/${toPersianDigits(date.year)}';

  @override
  String formatFullDate(DateTime date, MaterialLocalizations localizations) {
    final gregorian = _toGregorianDate(date);
    return '${_jalaliWeekdays[gregorian.weekday % 7]}، ${toPersianDigits(date.day)} ${_jalaliMonths[date.month - 1]} ${toPersianDigits(date.year)}';
  }

  @override
  String formatCompactDate(
    DateTime date,
    MaterialLocalizations localizations,
  ) => formatShortDate(date, localizations);

  @override
  DateTime? parseCompactDate(
    String? inputString,
    MaterialLocalizations localizations,
  ) {
    final normalized = normalizeNumberDigits(inputString ?? '');
    final match = RegExp(
      r'^(\d{1,4})[/.](\d{1,2})[/.](\d{1,2})$',
    ).firstMatch(normalized);
    if (match == null) return null;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    if (month < 1 ||
        month > 12 ||
        day < 1 ||
        day > _daysInJalaliMonth(year, month))
      return null;
    return DateTime(year, month, day);
  }

  @override
  String dateHelpText(MaterialLocalizations localizations) => 'سال/ماه/روز';
}

DateTime _toJalaliDate(DateTime gregorian) {
  final jalali = _gregorianToJalali(gregorian);
  return DateTime(jalali.$1, jalali.$2, jalali.$3);
}

DateTime _toGregorianDate(DateTime jalali) =>
    _jalaliToGregorian(jalali.year, jalali.month, jalali.day);

DateTime? _parseGregorian(String value) {
  final match = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(value);
  if (match == null) return null;
  return _validGregorianDate(
    int.parse(match[1]!),
    int.parse(match[2]!),
    int.parse(match[3]!),
  );
}

DateTime? _validGregorianDate(int year, int month, int day) {
  if (month < 1 ||
      month > 12 ||
      day < 1 ||
      day > DateUtils.getDaysInMonth(year, month)) {
    return null;
  }
  return DateTime(year, month, day);
}

int _daysInJalaliMonth(int year, int month) {
  if (month < 1 || month > 12) return 0;
  if (month <= 6) return 31;
  if (month <= 11) return 30;
  return _jalaliCalendarYear(year).leap == 0 ? 30 : 29;
}

(int, int, int) _gregorianToJalali(DateTime date) {
  final jdn = _gregorianToJulianDay(date.year, date.month, date.day);
  final g = _julianDayToGregorian(jdn);
  var jy = g.year - 621;
  final calendarYear = _jalaliCalendarYear(jy);
  final firstDay = _gregorianToJulianDay(
    calendarYear.gregorianYear,
    3,
    calendarYear.marchDay,
  );
  var dayOfYear = jdn - firstDay;
  if (dayOfYear >= 0) {
    if (dayOfYear <= 185) {
      return (jy, 1 + dayOfYear ~/ 31, dayOfYear % 31 + 1);
    }
    dayOfYear -= 186;
  } else {
    jy -= 1;
    dayOfYear += 179;
    if (calendarYear.leap == 1) dayOfYear += 1;
  }
  return (jy, 7 + dayOfYear ~/ 30, dayOfYear % 30 + 1);
}

DateTime _jalaliToGregorian(int year, int month, int day) {
  if (month < 1 ||
      month > 12 ||
      day < 1 ||
      day > _daysInJalaliMonth(year, month)) {
    throw RangeError('Invalid Jalali date: $year/$month/$day');
  }
  final calendarYear = _jalaliCalendarYear(year);
  final firstDay = _gregorianToJulianDay(
    calendarYear.gregorianYear,
    3,
    calendarYear.marchDay,
  );
  final daysBeforeMonth = month <= 7
      ? (month - 1) * 31
      : 6 * 31 + (month - 7) * 30;
  return _julianDayToGregorian(firstDay + daysBeforeMonth + day - 1);
}

({int leap, int gregorianYear, int marchDay}) _jalaliCalendarYear(int year) {
  const breaks = <int>[
    -61,
    9,
    38,
    199,
    426,
    686,
    756,
    818,
    1111,
    1181,
    1210,
    1635,
    2060,
    2097,
    2192,
    2262,
    2324,
    2394,
    2456,
    3178,
  ];
  if (year < breaks.first || year >= breaks.last) {
    throw RangeError('Jalali year is outside the supported range: $year');
  }
  final gregorianYear = year + 621;
  var leapJ = -14;
  var previous = breaks.first;
  var jump = 0;
  for (var index = 1; index < breaks.length; index++) {
    final next = breaks[index];
    jump = next - previous;
    if (year < next) break;
    leapJ += (jump ~/ 33) * 8 + ((jump % 33) ~/ 4);
    previous = next;
  }
  var n = year - previous;
  leapJ += (n ~/ 33) * 8 + ((n % 33 + 3) ~/ 4);
  if (jump % 33 == 4 && jump - n == 4) leapJ += 1;
  final leapG =
      gregorianYear ~/ 4 - ((gregorianYear ~/ 100 + 1) * 3 ~/ 4) - 150;
  final marchDay = 20 + leapJ - leapG;
  if (jump - n < 6) n = n - jump + (jump + 4) ~/ 33 * 33;
  final leapCycle = (n + 1) % 33;
  final leap = leapCycle == 0 ? 4 : (leapCycle - 1) % 4;
  return (leap: leap, gregorianYear: gregorianYear, marchDay: marchDay);
}

int _gregorianToJulianDay(int year, int month, int day) {
  final a = (14 - month) ~/ 12;
  final y = year + 4800 - a;
  final m = month + 12 * a - 3;
  return day +
      (153 * m + 2) ~/ 5 +
      365 * y +
      y ~/ 4 -
      y ~/ 100 +
      y ~/ 400 -
      32045;
}

DateTime _julianDayToGregorian(int julianDay) {
  final a = julianDay + 32044;
  final b = (4 * a + 3) ~/ 146097;
  final c = a - 146097 * b ~/ 4;
  final d = (4 * c + 3) ~/ 1461;
  final e = c - 1461 * d ~/ 4;
  final m = (5 * e + 2) ~/ 153;
  final day = e - (153 * m + 2) ~/ 5 + 1;
  final month = m + 3 - 12 * (m ~/ 10);
  final year = 100 * b + d - 4800 + m ~/ 10;
  return DateTime(year, month, day);
}
