import 'dart:convert';

import '../../l10n/l10n.dart';

/// The password rule, as the phone can check it before a request (#400).
///
/// **The server is the rule.** `backend/src/lib/passwordPolicy.ts` decides, and
/// every door that sets a password shares it. This copy exists so an agent on a
/// weak signal learns "too short" from the keyboard rather than from a round
/// trip, and it deliberately checks only what the server checks the same way:
/// the 12-character floor (surrounding spaces do not count), bcrypt's 72-byte
/// ceiling, and "not your own email". The server's short deny-list is not
/// copied — a second list is the first thing to drift — so a refused common
/// password comes back as a 400 and is worded by [PasswordProblem.rejected].
const passwordMinLength = 12;

/// bcrypt hashes the first 72 bytes and ignores the rest, so the server refuses
/// anything longer rather than accept characters it never checks.
const passwordMaxBytes = 72;

/// What is wrong with a candidate new password, in the order it is checked.
enum PasswordProblem {
  tooShort,
  tooLong,
  isEmail,

  /// The confirmation does not match.
  mismatch,

  /// The server refused it for a reason the phone does not check (the
  /// deny-list). Only ever produced from a 400.
  rejected;

  String message(AppLocalizations l10n) => switch (this) {
    PasswordProblem.tooShort => l10n.passwordTooShort,
    PasswordProblem.tooLong => l10n.passwordTooLong,
    PasswordProblem.isEmail => l10n.passwordIsEmail,
    PasswordProblem.mismatch => l10n.passwordMismatch,
    PasswordProblem.rejected => l10n.passwordRejected,
  };
}

/// Checks [password] the way the server will. Null when it would pass these
/// checks — which is necessary, not sufficient: see [PasswordProblem.rejected].
///
/// The password is never trimmed before it is sent. Spaces at either end are
/// allowed; they simply do not count towards the floor.
PasswordProblem? checkNewPassword(String password, {String? email}) {
  if (password.length < passwordMinLength) return PasswordProblem.tooShort;
  if (utf8.encode(password).length > passwordMaxBytes) {
    return PasswordProblem.tooLong;
  }
  if (password.trim().length < passwordMinLength) {
    return PasswordProblem.tooShort;
  }
  final folded = password.trim().toLowerCase();
  if (email != null &&
      email.trim().isNotEmpty &&
      folded == email.trim().toLowerCase()) {
    return PasswordProblem.isEmail;
  }
  return null;
}
