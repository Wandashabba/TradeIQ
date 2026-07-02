import 'package:dio/dio.dart';

String? currentAuthToken;

final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))
  ..interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final token = currentAuthToken;
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
  ));
