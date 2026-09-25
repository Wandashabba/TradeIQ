import '../../l10n/l10n.dart';

/// How long ago something happened, in words.
///
/// The one bucketing in the app: "just now", minutes, hours, days. Every
/// "time since" line reads it — the agent shell, My work, the audit console
/// and the dashboard's agent panel — because a second implementation would
/// silently drift from that wording, and two screens disagreeing about how old
/// the same reading is, is exactly the kind of small lie this codebase has
/// been busy removing.
///
/// [l10n] is optional so a pure Dart caller (a repository, a test fixture) can
/// still read it; it falls back to English rather than throwing.
String formatAgo(DateTime when, [AppLocalizations? l10n]) {
  final l = l10n ?? englishLocalizations;
  final d = DateTime.now().difference(when);
  if (d.inSeconds < 60) return l.agoJustNow;
  if (d.inMinutes < 60) return l.agoMinutes(d.inMinutes);
  if (d.inHours < 24) return l.agoHours(d.inHours);
  return l.agoDays(d.inDays);
}
