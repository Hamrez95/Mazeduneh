/// Mazeduneh currently operates in Iran. Keep calendar input and reporting
/// anchored to the store's IANA time zone instead of the operator's device.
/// Iran uses UTC+03:30 year-round since daylight saving time was abolished.
const storeTimeZoneId = 'Asia/Tehran';
const _storeUtcOffset = Duration(hours: 3, minutes: 30);

/// Current wall-clock time at the store, represented as a local DateTime whose
/// components are store time. Do not serialize this value directly; convert it
/// with [storeWallTimeToUtc] first.
DateTime storeWallTimeNow() => storeUtcToWallTime(DateTime.now().toUtc());

/// Converts an absolute instant to the store's wall-clock components.
DateTime storeUtcToWallTime(DateTime instant) {
  final wall = instant.toUtc().add(_storeUtcOffset);
  return DateTime(
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
    wall.millisecond,
    wall.microsecond,
  );
}

/// Converts a date/time selected in the store's calendar to the UTC instant
/// expected by APIs and persistence.
DateTime storeWallTimeToUtc(DateTime wallTime) => DateTime.utc(
  wallTime.year,
  wallTime.month,
  wallTime.day,
  wallTime.hour,
  wallTime.minute,
  wallTime.second,
  wallTime.millisecond,
  wallTime.microsecond,
).subtract(_storeUtcOffset);
