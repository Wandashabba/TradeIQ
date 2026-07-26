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

  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(datePart)) {
    try {
      final d = DateTime.parse(datePart);
      return '${d.day} ${_monthAbbrev[d.month - 1]}';
    } catch (_) {
      return period;
    }
  }

  final week = RegExp(r'^\d{4}-(W\d{1,2})$').firstMatch(period);
  if (week != null) return week.group(1)!;

  return period;
}
