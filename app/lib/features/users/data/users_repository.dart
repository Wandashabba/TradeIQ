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
  /// One page of `GET /users`. [cursor] is the previous page's `nextCursor`
  /// and [limit] is a request, not a guarantee — the backend caps it.
  Future<PaginatedResponse<AppUser>> listUsers({int? limit, String? cursor});
  Future<AppUser> createUser({
    required String email,
    required String password,
    required String role,
    String? displayName,
  });
  Future<AppUser> setActive(String id, bool active);

  /// Sets, changes or clears a user's display name via PATCH /users/:id.
  ///
  /// The name is trimmed; null or blank clears it. The server caps a name at
  /// [displayNameMaxLength] characters after trimming.
  Future<AppUser> updateDisplayName(String id, String? displayName);
}

/// Longest display name the server accepts (after trimming). Mirrors
/// `DISPLAY_NAME_MAX_LENGTH` in `backend/src/lib/personName.ts`.
const displayNameMaxLength = 120;

class DioUsersRepository implements UsersRepository {
  @override
  Future<PaginatedResponse<AppUser>> listUsers({
    int? limit,
    String? cursor,
  }) async {
    final response = await dio.get(
      '/users',
      queryParameters: <String, dynamic>{
        'limit': ?limit?.toString(),
        'cursor': ?cursor,
      },
    );
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

  @override
  Future<AppUser> updateDisplayName(String id, String? displayName) async {
    final response = await dio.patch('/users/$id', data: {
      // Always present, unlike on create: an absent key means "leave it
      // unchanged", so clearing must send an explicit null.
      'displayName': nonBlankName(displayName),
    });
    return AppUser.fromJson(response.data as Map<String, dynamic>);
  }
}

final usersRepositoryProvider =
    Provider<UsersRepository>((ref) => DioUsersRepository());

/// THE WHOLE ROSTER, NOT PAGE ONE OF IT — 26 September 2026.
///
/// This read one page and dropped `nextCursor`, on the reading that the admin
/// screen "wants the current set, not the whole history". Two things were
/// wrong with that. The roster screen printed the length of page one as the
/// count beside its section marker, so an admin read the size of a page as
/// the size of the team. And [userDirectoryProvider] is built from this list
/// and is what the messages screen resolves every sender and recipient
/// against — so a colleague on page two rendered as "not on the roster" beside
/// a raw user id, which is precisely the failure #399/#400 repaired.
///
/// It walks, like `fetchAllOutlets` does and for the same stated reason: a
/// roster is **reference data somebody finds by identity**, not an activity
/// feed, so a "there are more" footer on the admin screen would not have
/// helped the message list at all. The loop is bounded three ways — a page
/// cap, a null cursor, and a cursor that fails to advance — because an
/// unbounded client loop is a bug this codebase has already been bitten by.
const _maxRosterPageSize = 200;
const _maxRosterPages = 50;

final usersListProvider = FutureProvider<List<AppUser>>((ref) async {
  final repo = ref.read(usersRepositoryProvider);
  final users = <AppUser>[];
  String? cursor;
  for (var page = 0; page < _maxRosterPages; page += 1) {
    final result = await repo.listUsers(
      limit: _maxRosterPageSize,
      cursor: cursor,
    );
    users.addAll(result.data);
    final next = result.nextCursor;
    if (next == null) return users;
    if (next == cursor) {
      throw StateError('Roster paging stalled: the server repeated "$next".');
    }
    cursor = next;
  }
  throw StateError(
    'Roster paging exceeded $_maxRosterPages pages of $_maxRosterPageSize.',
  );
});

/// Who a user id is, for a screen whose payload carries only the id.
///
/// A base layer and never a blocker: while the roster is loading, or if it
/// fails, the map is empty and the caller says so in words — it never prints
/// the id in a name's place (#399/#400). Read in the widget layer rather than
/// inside a list's own provider, so the roster arriving re-renders the rows
/// without refetching them.
final userDirectoryProvider = Provider<Map<String, AppUser>>((ref) {
  return ref
      .watch(usersListProvider)
      .maybeWhen(
        data: (users) => <String, AppUser>{for (final u in users) u.id: u},
        orElse: () => const <String, AppUser>{},
      );
});
