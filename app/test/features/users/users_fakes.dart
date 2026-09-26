import 'dart:async';

import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/users/data/users_repository.dart';

/// Shared fixtures for the user roster tests.
///
/// Failures are `Error`s and not bare `Exception`s: Riverpod 3's
/// `defaultRetry` backs off and retries anything that is not an `Error`, so a
/// fixture that throws `Exception('boom')` leaves a widget test on the loading
/// skeleton for ~12 seconds and never reaches the error branch.
StateError offline() => StateError('SocketException: api.tradeiq.co.za');

const AppUser activeUser = AppUser(
  id: 'u-active',
  email: 'active@example.com',
  role: 'manager',
  active: true,
);

const AppUser inactiveUser = AppUser(
  id: 'u-inactive',
  email: 'inactive@example.com',
  role: 'field_agent',
  active: false,
);

const AppUser namedUser = AppUser(
  id: 'u-named',
  email: 'agent7@example.com',
  role: 'field_agent',
  active: true,
  displayName: 'Sipho Ndlovu',
);

const AppUser adminUser = AppUser(
  id: 'u-admin',
  email: 'boss@example.com',
  role: 'admin',
  active: true,
  displayName: 'Ayanda Khumalo',
);

class FakeUsersRepository implements UsersRepository {
  FakeUsersRepository({
    List<AppUser> users = const <AppUser>[activeUser, inactiveUser],
    this.listFailure,
    this.listPending = false,
    this.updateFailure,
    this.setActiveFailure,
    this.createFailure,
  }) : users = <AppUser>[...users];

  /// Mutable so a successful update shows up on the next list.
  final List<AppUser> users;
  final Object? listFailure;
  final bool listPending;
  final Object? updateFailure;
  final Object? setActiveFailure;
  final Object? createFailure;

  int listCalls = 0;
  String? setActiveId;
  bool? setActiveValue;
  String? createdEmail;
  String? createdPassword;
  String? createdRole;
  String? createdDisplayName;
  int updateCalls = 0;
  String? updatedId;
  String? updatedDisplayName;

  @override
  Future<PaginatedResponse<AppUser>> listUsers({
    int? limit,
    String? cursor,
  }) async {
    listCalls++;
    if (listFailure != null) throw listFailure!;
    if (listPending) return Completer<PaginatedResponse<AppUser>>().future;
    return PaginatedResponse<AppUser>(
      data: List<AppUser>.of(users),
      nextCursor: null,
    );
  }

  @override
  Future<AppUser> updateDisplayName(String id, String? displayName) async {
    updateCalls++;
    updatedId = id;
    updatedDisplayName = displayName;
    if (updateFailure != null) throw updateFailure!;
    final i = users.indexWhere((u) => u.id == id);
    final old = users[i];
    final updated = AppUser(
      id: old.id,
      email: old.email,
      role: old.role,
      active: old.active,
      displayName: displayName,
    );
    users[i] = updated;
    return updated;
  }

  @override
  Future<AppUser> createUser({
    required String email,
    required String password,
    required String role,
    String? displayName,
  }) async {
    createdEmail = email;
    createdPassword = password;
    createdRole = role;
    createdDisplayName = displayName;
    if (createFailure != null) throw createFailure!;
    return AppUser(
      id: 'u-new',
      email: email,
      role: role,
      active: true,
      displayName: displayName,
    );
  }

  @override
  Future<AppUser> setActive(String id, bool active) async {
    setActiveId = id;
    setActiveValue = active;
    if (setActiveFailure != null) throw setActiveFailure!;
    final i = users.indexWhere((u) => u.id == id);
    final old = users[i];
    final updated = AppUser(
      id: old.id,
      email: old.email,
      role: old.role,
      active: active,
      displayName: old.displayName,
    );
    users[i] = updated;
    return updated;
  }
}
