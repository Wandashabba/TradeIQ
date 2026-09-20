import 'dart:convert';

/// Reads the `exp` claim out of a JWT without verifying its signature.
///
/// Verification is the server's job and the client cannot do it anyway — it has
/// no signing secret. The only question here is whether a stored token is worth
/// sending at all, and a token whose own `exp` has passed is not: the server
/// will reject it, so restoring a session from it just produces a screen full
/// of errors instead of a login prompt.
///
/// Returns null when the token is malformed, unreadable, or carries no numeric
/// `exp`. Callers should treat null as "cannot tell" rather than "expired" —
/// see [isExpired], which deliberately trusts an undecodable token to the
/// server rather than logging someone out over a parsing quirk.
DateTime? jwtExpiry(String token) {
  final exp = _payload(token)?['exp'];
  if (exp is! num) return null;

  return DateTime.fromMillisecondsSinceEpoch((exp * 1000).toInt(), isUtc: true);
}

/// Decodes a JWT's payload segment, or null if it cannot be read.
///
/// No signature verification: the client holds no signing secret, so it could
/// not verify one if it wanted to. Everything read here is a hint for local
/// decisions — never an authorisation check, which stays entirely server-side.
Map<String, dynamic>? _payload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;

  try {
    // base64Url.decode requires canonical padding; JWTs omit it.
    final decoded = json.decode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

/// Reads the `userId` claim out of a JWT, or null if it is absent or the token
/// is unreadable.
///
/// The server puts `userId` in every token it issues (`AuthTokenPayload`), so
/// the client can tell whose device-local rows are whose without an extra
/// round trip — which matters offline, where there is no round trip to make.
String? jwtUserId(String token) {
  final claims = _payload(token);
  final id = claims?['userId'];
  return id is String ? id : null;
}

/// Whether [token] has already expired, judged against [now].
///
/// A token we cannot read returns false: the server is the authority on
/// validity, and a parsing failure here should surface as a 401 from a real
/// request — which the interceptor handles — rather than as a silent local
/// logout that the user cannot explain or act on.
bool isExpired(String token, {DateTime? now}) {
  final expiry = jwtExpiry(token);
  if (expiry == null) return false;
  return !expiry.isAfter(now ?? DateTime.now().toUtc());
}
