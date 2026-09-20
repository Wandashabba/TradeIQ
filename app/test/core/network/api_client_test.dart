import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/api_client.dart';

void main() {
  test('defaults the API base URL to the local dev server', () {
    // With no --dart-define=API_BASE_URL override (as in CI/unit tests),
    // the client should fall back to the local backend. A real deployment
    // passes --dart-define=API_BASE_URL=... to point elsewhere.
    expect(apiBaseUrl, 'http://localhost:4000');
    expect(dio.options.baseUrl, 'http://localhost:4000');
  });

  test('every request is bounded by a timeout', () {
    // Dio defaults these to null, which means wait forever. On the connectivity
    // this app is built for that is a request that never returns and a spinner
    // that never stops — and the agent force-quits, losing the queued work they
    // were trying to send.
    expect(dio.options.connectTimeout, isNotNull);
    expect(dio.options.receiveTimeout, isNotNull);
    expect(dio.options.sendTimeout, isNotNull);
  });

  test('upload and download timeouts leave room for a large photo', () {
    // These apply between chunks rather than to the whole transfer, so a slow
    // 8 MB shelf photo is not cut off for being large — only a connection that
    // has actually stopped moving is. A value tight enough to kill a genuine
    // slow upload would make the offline-first capture flow lose work.
    expect(
      dio.options.receiveTimeout,
      greaterThanOrEqualTo(const Duration(seconds: 30)),
    );
    expect(
      dio.options.sendTimeout,
      greaterThanOrEqualTo(const Duration(seconds: 30)),
    );
  });
}
