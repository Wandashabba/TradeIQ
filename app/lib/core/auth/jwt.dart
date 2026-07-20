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
  final parts = token.split('.');
  if (parts.length != 3) return null;

  try {
    // base64Url.decode requires canonical padding; JWTs omit it.
    final payload = parts[1];
    final normalised = base64Url.normalize(payload);
    final decoded = json.decode(utf8.decode(base64Url.decode(normalised)));
    if (decoded is! Map<String, dynamic>) return null;

    final exp = decoded['exp'];
    if (exp is! num) return null;

    return DateTime.fromMillisecondsSinceEpoch(
      (exp * 1000).toInt(),
      isUtc: true,
    );
  } catch (_) {
    // A token we cannot parse is not a token we can call expired.
    return null;
  }
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
