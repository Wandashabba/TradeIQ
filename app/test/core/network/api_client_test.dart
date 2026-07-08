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
}
