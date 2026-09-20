import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

class AuthResult {
  const AuthResult({required this.token, required this.role});
  final String token;
  final String role;
}

abstract class AuthRepository {
  Future<AuthResult> login(String email, String password);
}

class DioAuthRepository implements AuthRepository {
  @override
  Future<AuthResult> login(String email, String password) async {
    final response = await dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return AuthResult(
      token: response.data['token'] as String,
      role: response.data['role'] as String,
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => DioAuthRepository(),
);
