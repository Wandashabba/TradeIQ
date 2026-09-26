import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';
import 'package:tradeiq_app/features/users/data/users_repository.dart';

/// REFERENCE DATA IS READ WHOLE, OR IT IS NOT REFERENCE DATA.
///
/// `usersListProvider` and `territoriesListProvider` each read one page and
/// dropped `nextCursor`, on the reading that their screens "want the current
/// set, not the whole history". Both feed something other than their own
/// screen, and that is where it bit:
///
/// * `userDirectoryProvider` is built from the roster and is what the messages
///   screen resolves every sender and recipient against — so a colleague on
///   page two rendered as "not on the roster" beside a raw user id, which is
///   exactly the failure #399/#400 repaired;
/// * the territory list backs the pickers in the beat-plan form, the
///   sales-target form, the contest form and The Floor's scope sheet — so a
///   territory on page two was simply unassignable, with nothing saying so.
///
/// `fetchAllOutlets` has walked its pages since it was written, for the reason
/// stated in its own doc: reference data is found by identity, not scrolled.
/// These two now do the same, bounded the same three ways.
void main() {
  AppUser user(String id) => AppUser(
    id: id,
    email: '$id@tradeiq.com',
    role: 'field_agent',
    active: true,
  );

  Territory territory(String id) =>
      Territory(id: id, name: 'Territory $id', code: id.toUpperCase());

  test('the roster walks every page', () async {
    final repo = _PagedUsers(<List<AppUser>>[
      <AppUser>[user('a'), user('b')],
      <AppUser>[user('c')],
    ]);
    final container = ProviderContainer(
      overrides: [usersRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final users = await container.read(usersListProvider.future);
    expect(users.map((u) => u.id), <String>['a', 'b', 'c']);
    expect(repo.cursorsAsked, <String?>[null, 'page-1']);
    expect(repo.limitsAsked, <int?>[200, 200], reason: 'fewer round trips');
  });

  test('a server that repeats a cursor fails loudly rather than spinning', () {
    final container = ProviderContainer(
      overrides: [
        usersRepositoryProvider.overrideWithValue(_StuckUsers(user('a'))),
      ],
    );
    addTearDown(container.dispose);

    // An unbounded client loop accumulating rows until the app dies is the
    // bug this codebase has already been bitten by.
    expect(
      container.read(usersListProvider.future),
      throwsA(isA<StateError>()),
    );
  });

  test('the territory list walks every page', () async {
    final repo = _PagedTerritories(<List<Territory>>[
      <Territory>[territory('gn')],
      <Territory>[territory('ws')],
    ]);
    final container = ProviderContainer(
      overrides: [territoriesRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final list = await container.read(territoriesListProvider.future);
    expect(
      list.map((t) => t.id),
      <String>['gn', 'ws'],
      reason: 'a territory on page two was unassignable in every picker',
    );
    expect(repo.cursorsAsked, <String?>[null, 'page-1']);
  });
}

class _PagedUsers implements UsersRepository {
  _PagedUsers(this.pages);

  final List<List<AppUser>> pages;
  final List<String?> cursorsAsked = <String?>[];
  final List<int?> limitsAsked = <int?>[];

  @override
  Future<PaginatedResponse<AppUser>> listUsers({
    int? limit,
    String? cursor,
  }) async {
    cursorsAsked.add(cursor);
    limitsAsked.add(limit);
    final index = cursor == null ? 0 : int.parse(cursor.split('-').last);
    return PaginatedResponse<AppUser>(
      data: pages[index],
      nextCursor: index + 1 < pages.length ? 'page-${index + 1}' : null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A server whose cursor never advances — a stale id whose `skip: 1` re-yields
/// the same page.
class _StuckUsers implements UsersRepository {
  _StuckUsers(this.only);

  final AppUser only;

  @override
  Future<PaginatedResponse<AppUser>> listUsers({
    int? limit,
    String? cursor,
  }) async => PaginatedResponse<AppUser>(
    data: <AppUser>[only],
    nextCursor: 'always-the-same',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _PagedTerritories implements TerritoriesRepository {
  _PagedTerritories(this.pages);

  final List<List<Territory>> pages;
  final List<String?> cursorsAsked = <String?>[];

  @override
  Future<PaginatedResponse<Territory>> listTerritories({
    int? limit,
    String? cursor,
  }) async {
    cursorsAsked.add(cursor);
    final index = cursor == null ? 0 : int.parse(cursor.split('-').last);
    return PaginatedResponse<Territory>(
      data: pages[index],
      nextCursor: index + 1 < pages.length ? 'page-${index + 1}' : null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
