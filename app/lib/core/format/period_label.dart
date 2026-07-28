const _monthAbbrev = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Turns a raw period key into an axis-friendly tick.
///
/// `2026-07-06T00:00:00.000Z` and `2026-07-06` → `6 Jul`; `2026-W26` → `W26`.
/// Anything that isn't a recognisable period — a bucket name like `All`, an
/// empty string, a malformed value — is returned untouched. Never throws:
/// axis ticks must render whatever they are handed.
String formatPeriodLabel(String period) {
  // Full ISO timestamps carry a `T` separator; the date portion is all we show.
  final datePart = period.contains('T') ? period.split('T').first : period;

  final date = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(datePart);
  if (date != null) {
    final year = int.parse(date.group(1)!);
    final month = int.parse(date.group(2)!);
    final day = int.parse(date.group(3)!);
    try {
      final d = DateTime(year, month, day);
      // DateTime silently rolls overflow forward (month 13 → next January,
      // day 45 → the following month), so a regex-valid but impossible date
      // would otherwise render as some *other* day. Only format when the value
      // round-trips exactly; anything else falls through to passthrough.
      if (d.year == year && d.month == month && d.day == day) {
        return '${d.day} ${_monthAbbrev[d.month - 1]}';
      }
    } catch (_) {
      // Defensive only: the constructor is lenient, but never let a throw escape.
    }
    return period;
  }

  final week = RegExp(r'^\d{4}-(W\d{1,2})$').firstMatch(period);
  if (week != null) return week.group(1)!;

  return period;
}
