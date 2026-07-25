/// `2026-W26` → `W26`; an ISO date or datetime keeps its `MM-DD`. Axis ticks
/// have no room for the year (or a time), and it is the same for every bucket
/// anyway. Anything unrecognised passes through unchanged.
String shortPeriodLabel(String period) {
  final week = RegExp(r'^\d{4}-(W\d{1,2})$').firstMatch(period);
  if (week != null) return week.group(1)!;
  final date = period.split('T').first;
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
    return date.substring(5);
  }
  return period;
}
