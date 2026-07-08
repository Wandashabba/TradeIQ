import 'package:dio/dio.dart';

String? currentAuthToken;

/// The backend base URL. Overridable at build/run time with
/// `--dart-define=API_BASE_URL=...` so the same binary can target a local
/// server, an Android emulator (`http://10.0.2.2:4000`), or a deployed
/// environment without a code change. Defaults to the local dev server.
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:4000',
);

final dio = Dio(BaseOptions(baseUrl: apiBaseUrl))
  ..interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final token = currentAuthToken;
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
  ));
