import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// An admin-facing view of one platform user returned by GET /users.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.active,
  });
  final String id;
  final String email;
  final String role;
  final bool active;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        active: json['active'] as bool? ?? true,
      );
}

abstract class UsersRepository {
  Future<List<AppUser>> listUsers();
  Future<AppUser> createUser({
    required String email,
    required String password,
    required String role,
  });
  Future<AppUser> setActive(String id, bool active);
}

class DioUsersRepository implements UsersRepository {
  @override
  Future<List<AppUser>> listUsers() async {
    final response = await dio.get('/users');
    return (response.data as List)
        .map((json) => AppUser.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<AppUser> createUser({
    required String email,
    required String password,
    required String role,
  }) async {
    final response = await dio.post('/users', data: {
      'email': email,
      'password': password,
      'role': role,
    });
    return AppUser.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<AppUser> setActive(String id, bool active) async {
    final response = await dio.patch('/users/$id', data: {
      'active': active,
    });
    return AppUser.fromJson(response.data as Map<String, dynamic>);
  }
}

final usersRepositoryProvider =
    Provider<UsersRepository>((ref) => DioUsersRepository());

final usersListProvider = FutureProvider<List<AppUser>>((ref) {
  return ref.read(usersRepositoryProvider).listUsers();
});
