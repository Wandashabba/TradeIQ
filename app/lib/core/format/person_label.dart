/// What to call a person on screen: their display name when they have one,
/// otherwise their email.
///
/// `displayName` is nullable on the server (#280) — accounts that predate it
/// were never given one, and it is deliberately not guessed from the address —
/// so every place that shows a person needs this same fallback. A name that is
/// only whitespace counts as no name.
String personLabel(String? displayName, String email) {
  final trimmed = displayName?.trim();
  return (trimmed == null || trimmed.isEmpty) ? email : trimmed;
}

/// The trimmed name, or null when [displayName] is absent or blank.
String? nonBlankName(String? displayName) {
  final trimmed = displayName?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}
