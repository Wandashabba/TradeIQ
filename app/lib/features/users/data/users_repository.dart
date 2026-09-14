import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/person_label.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated_response.dart';

/// An admin-facing view of one platform user returned by GET /users.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.active,
    this.displayName,
  });
  final String id;
  final String email;
  final String role;
  final bool active;

  /// What people call this user. Null for accounts that were never given one.
  final String? displayName;

  /// The name when there is one, otherwise the email.
  String get label => personLabel(displayName, email);

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        active: json['active'] as bool? ?? true,
        displayName: json['displayName'] as String?,
      );
}

abstract class UsersRepository {
  Future<PaginatedResponse<AppUser>> listUsers();
  Future<AppUser> createUser({
    required String email,
    required String password,
    required String role,
    String? displayName,
  });
  Future<AppUser> setActive(String id, bool active);
}

class DioUsersRepository implements UsersRepository {
  @override
  Future<PaginatedResponse<AppUser>> listUsers() async {
    final response = await dio.get('/users');
    return PaginatedResponse<AppUser>.fromJson(
      response.data as Map<String, dynamic>,
      (e) => AppUser.fromJson(e as Map<String, dynamic>),
    );
  }

  @override
  Future<AppUser> createUser({
    required String email,
    required String password,
    required String role,
    String? displayName,
  }) async {
    final name = nonBlankName(displayName);
    final response = await dio.post('/users', data: {
      'email': email,
      'password': password,
      'role': role,
      // Omitted rather than sent blank: the server stores no name either way,
      // and an absent key keeps the request identical for unnamed users.
      'displayName': ?name,
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

// The provider exposes the FIRST PAGE as a plain list: the admin roster
// screen wants the current set, not the whole history, and "load more" UI is
// deliberately out of scope for the pagination sweep (see the spec).
// `nextCursor` is available on the repository for any screen that later needs
// to page; this provider intentionally drops it.
final usersListProvider = FutureProvider<List<AppUser>>((ref) async {
  final page = await ref.read(usersRepositoryProvider).listUsers();
  return page.data;
});
