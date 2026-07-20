import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/jwt.dart';

/// Builds a token with the given claims. Only the payload segment is real —
/// nothing here verifies signatures, and neither does the code under test.
String _token(Map<String, dynamic> claims) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  return '${seg({'alg': 'HS256', 'typ': 'JWT'})}.${seg(claims)}.signature';
}

void main() {
  final now = DateTime.utc(2026, 7, 20, 12, 0, 0);

  group('jwtExpiry', () {
    test('reads the exp claim', () {
      final token = _token({
        'sub': 'u1',
        'exp': DateTime.utc(2026, 7, 20, 18).millisecondsSinceEpoch ~/ 1000,
      });

      expect(jwtExpiry(token), DateTime.utc(2026, 7, 20, 18));
    });

    test('returns null for a token with no exp', () {
      expect(jwtExpiry(_token({'sub': 'u1'})), isNull);
    });

    test('returns null for a malformed token rather than throwing', () {
      expect(jwtExpiry('not-a-jwt'), isNull);
      expect(jwtExpiry('only.two'), isNull);
      expect(jwtExpiry('a.!!!not-base64!!!.c'), isNull);
    });

    test('handles payloads whose length needs base64 padding', () {
      // JWTs strip '=' padding; a decoder that does not re-add it throws on
      // payload lengths that are not a multiple of four.
      final token = _token({'exp': 1784548800, 'role': 'field_agent'});
      expect(jwtExpiry(token), isNotNull);
    });
  });

  group('isExpired', () {
    test('a token whose exp has passed is expired', () {
      final token = _token({
        'exp': DateTime.utc(2026, 7, 20, 11).millisecondsSinceEpoch ~/ 1000,
      });

      expect(isExpired(token, now: now), isTrue);
    });

    test('a token still in date is not expired', () {
      final token = _token({
        'exp': DateTime.utc(2026, 7, 20, 13).millisecondsSinceEpoch ~/ 1000,
      });

      expect(isExpired(token, now: now), isFalse);
    });

    test('exp exactly now counts as expired', () {
      final token = _token({'exp': now.millisecondsSinceEpoch ~/ 1000});

      expect(isExpired(token, now: now), isTrue);
    });

    test('an unreadable token is left to the server, not locally expired', () {
      // Logging someone out over a parsing quirk is worse than sending a token
      // the server will reject with a 401 the interceptor already handles.
      expect(isExpired('not-a-jwt', now: now), isFalse);
      expect(isExpired(_token({'sub': 'u1'}), now: now), isFalse);
    });
  });
}
