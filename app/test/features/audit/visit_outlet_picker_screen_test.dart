import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/network/human_error.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/core/theme/torchlight/agent_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sync_status.dart';
import 'package:tradeiq_app/features/audit/presentation/visit_outlet_picker_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import '../../core/design/amber_golden.dart';
import '../agent_harness.dart';

const _mine = Outlet(
  id: 'o1',
  name: 'Kasi Corner Spaza',
  code: 'KC-0412',
  lat: -26.20413,
  lng: 28.04732,
);
const _other = Outlet(
  id: 'o2',
  name: 'Sunrise Spaza',
  code: 'SS-221',
  lat: -26.3,
  lng: 28.1,
);

/// Returns a shorter list when narrowed, so a test can tell the two apart —
/// a fake that ignored `mine` would make the scope switch untestable.
class _Outlets implements OutletsRepository {
  _Outlets({this.error, this.empty = false});

  final Object? error;
  final bool empty;
  final List<bool> calls = <bool>[];

  @override
  Future<PaginatedResponse<Outlet>> listOutlets({
    bool mine = false,
    int? limit,
    String? cursor,
  }) async {
    calls.add(mine);
    if (error != null) throw error!;
    return PaginatedResponse<Outlet>(
      data: empty
          ? const <Outlet>[]
          : mine
          ? const <Outlet>[_mine]
          : const <Outlet>[_mine, _other],
      nextCursor: null,
    );
  }

  @override
  Future<Outlet> createOutlet({
    required String name,
    required String code,
    required String channelType,
    required double lat,
    required double lng,
    required String territoryId,
  }) => throw UnimplementedError();
}

final _serverError = DioException(
  requestOptions: RequestOptions(path: '/outlets'),
  type: DioExceptionType.badResponse,
  response: Response<void>(
    requestOptions: RequestOptions(path: '/outlets'),
    statusCode: 500,
  ),
);

Future<_Outlets> _pump(
  WidgetTester tester, {
  _Outlets? repo,
  SkinMode skin = SkinMode.night,
  SyncStatus sync = SyncStatus.empty,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) async {
  final outlets = repo ?? _Outlets();
  await pumpAgentScreen(
    tester,
    const VisitOutletPickerScreen(),
    path: '/audit',
    overrides: <Override>[
      ...agentBaseOverrides(db: agentTestDb(), skin: skin, sync: sync),
      outletsRepositoryProvider.overrideWithValue(outlets),
    ],
    textScale: textScale,
    locale: locale,
    extraRoutes: <GoRoute>[
      GoRoute(
        path: '/audit/:outletId',
        builder: (c, s) => Text('Visit ${s.pathParameters['outletId']}'),
      ),
      GoRoute(path: '/today', builder: (c, s) => const Text('Today view')),
      GoRoute(path: '/my-work', builder: (c, s) => const Text('My work view')),
      GoRoute(
        path: '/outlets/create',
        builder: (c, s) => const Text('Create store'),
      ),
    ],
  );
  return outlets;
}

/// The body is a lazy list under a 214dp header on a 360×640 phone, so the
/// stores — and on a narrow screen the scope control — are genuinely past the
/// fold until scrolled to. That is the screen an agent has.
Future<void> _see(WidgetTester tester, Finder finder) =>
    scrollAgentTo(tester, finder);

Finder _key(String k) => find.byKey(ValueKey<String>(k));

/// Riverpod 3 retries a provider that threw an `Exception`, with backoff, and
/// the screen stays on its skeleton meanwhile — the real app shows the same.
/// Elapse the fake clock, a second at a time, until the retries give up.
Future<void> _untilError(WidgetTester tester) async {
  for (var i = 0; i < 90 && find.byType(ErrorState).evaluate().isEmpty; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  expect(find.byType(ErrorState), findsOneWidget);
}

SyncStatus _needsYou() {
  final stuck = SyncItem(
    id: 1,
    entityType: 'photo',
    queuedAt: DateTime(2026, 9, 18),
    synced: false,
    attempts: 2,
    lastError: 'sync:rejected:422',
  );
  return SyncStatus(
    pending: <SyncItem>[stuck],
    sent: const <SyncItem>[],
    needsAttention: <SyncItem>[stuck],
  );
}

SyncStatus _held() {
  final held = SyncItem(
    id: 2,
    entityType: 'stock',
    queuedAt: DateTime(2026, 9, 18),
    synced: false,
    attempts: 0,
  );
  return SyncStatus(
    pending: <SyncItem>[held],
    sent: const <SyncItem>[],
    needsAttention: const <SyncItem>[],
  );
}

void main() {
  group('the list', () {
    testWidgets('a whole row is the way into a visit', (tester) async {
      await _pump(tester);
      final row = find.byKey(const ValueKey<String>('outlet-o1'));
      await _see(tester, row);
      expect(tester.widget(row), isA<SoftRow>());
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text('Visit o1'), findsOneWidget);
    });

    testWidgets('the store code is the identifier, and no coordinates', (
      tester,
    ) async {
      await _pump(tester);
      await _see(tester, _key('outlet-o1'));
      final row = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('outlet-o1')),
      );
      expect(row.title, 'Kasi Corner Spaza');
      expect(row.subtitle, 'KC-0412');
      expect(find.textContaining('-26.20413'), findsNothing);
      expect(find.textContaining('28.04732'), findsNothing);
      expect(
        row.semanticsLabel,
        'Kasi Corner Spaza, KC-0412. Double-tap to start a visit here.',
      );
    });
  });

  group('the scope control keeps its honesty line', () {
    testWidgets('it defaults to the agent\'s own territories, and says so', (
      tester,
    ) async {
      final repo = await _pump(tester);
      expect(repo.calls.first, isTrue);
      await _see(tester, _key('outlet-o1'));
      expect(find.text('Kasi Corner Spaza'), findsOneWidget);
      expect(find.text('Sunrise Spaza'), findsNothing);
      expect(
        find.text('1 in your territories · tap All stores to see every shop'),
        findsOneWidget,
      );
      final mine = tester.widget<TorchFilterChip>(
        find.byKey(const ValueKey<String>('scope-mine')),
      );
      final all = tester.widget<TorchFilterChip>(
        find.byKey(const ValueKey<String>('scope-all')),
      );
      expect(mine.selected, isTrue);
      expect(all.selected, isFalse);
    });

    testWidgets('every store is always reachable', (tester) async {
      // A filter, not a permission: an agent covering a colleague's patch
      // must be able to check in without finding an administrator first.
      final repo = await _pump(tester);
      await _see(tester, _key('scope-all'));
      await tester.tap(find.byKey(const ValueKey<String>('scope-all')));
      await tester.pumpAndSettle();
      expect(repo.calls.last, isFalse);
      await _see(tester, _key('outlet-o2'));
      expect(find.text('Sunrise Spaza'), findsOneWidget);
      await _see(tester, find.text('All 2 stores across this client'));
      expect(
        tester
            .widget<TorchFilterChip>(
              find.byKey(const ValueKey<String>('scope-all')),
            )
            .selected,
        isTrue,
      );
    });

    testWidgets('the selection reaches a screen reader, not colour alone', (
      tester,
    ) async {
      await _pump(tester);
      await _see(tester, _key('scope-mine'));
      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byKey(const ValueKey<String>('scope-mine'))),
        isSemantics(
          isSelected: true,
          isButton: true,
          label: 'My territories',
        ),
      );
      handle.dispose();
    });
  });

  group('the states that are not a list', () {
    testWidgets('a server failure speaks the one voice and offers a retry', (
      tester,
    ) async {
      final repo = await _pump(tester, repo: _Outlets(error: _serverError));
      await _untilError(tester);
      await _see(tester, find.text('Could not load your stores'));
      expect(find.text(humanErrorMessage(_serverError)), findsOneWidget);
      expect(find.textContaining('Check your connection'), findsNothing);
      await _see(
        tester,
        find.textContaining('Your stores are fetched from the server'),
      );
      expect(
        find.text(
          'Your stores are fetched from the server. Nothing you have '
          'captured is affected.',
        ),
        findsOneWidget,
      );

      final calls = repo.calls.length;
      await _see(tester, _key('retry-outlets'));
      await tester.tap(find.byKey(const ValueKey<String>('retry-outlets')));
      await tester.pumpAndSettle();
      expect(repo.calls.length, greaterThan(calls));
    });

    testWidgets('an empty territory says where the rest are', (tester) async {
      await _pump(tester, repo: _Outlets(empty: true));
      await _see(tester, find.byType(EmptyState));
      expect(find.textContaining('Switch to all stores'), findsOneWidget);
      // The honesty line is still there, with its zero.
      expect(
        find.text('0 in your territories · tap All stores to see every shop'),
        findsOneWidget,
      );
    });

    testWidgets('an empty client says so, differently', (tester) async {
      await _pump(tester, repo: _Outlets(empty: true));
      await _see(tester, _key('scope-all'));
      await tester.tap(find.byKey(const ValueKey<String>('scope-all')));
      await tester.pumpAndSettle();
      await _see(tester, find.byType(EmptyState));
      expect(
        find.text(
          'This client has no stores on the server yet. Add the one you are '
          'standing in.',
        ),
        findsOneWidget,
      );
    });
  });

  group('the chrome', () {
    testWidgets('not a tab root: a thumb zone, no nav, and a back to Today', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.byType(TorchNavPill), findsNothing);
      expect(find.byType(TorchThumbZone), findsOneWidget);
      final header = tester.widget<TorchAppHeader>(find.byType(TorchAppHeader));
      expect(header.back, isNotNull);
      expect(header.back!.semanticLabel, 'Today');

      // Every way in is a `go`, so there is nothing to pop — the back has to
      // GO somewhere, and where it goes is what it is called.
      await tester.tap(find.byWidget(header.back!));
      await tester.pumpAndSettle();
      expect(find.text('Today view'), findsOneWidget);
    });

    testWidgets('"Add a store" is a secondary and still opens the form', (
      tester,
    ) async {
      final repo = await _pump(tester);
      final add = find.byKey(const ValueKey<String>('add-store'));
      expect(tester.widget(add), isA<TorchSecondaryButton>());
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.text('Create store'), findsOneWidget);
      expect(repo.calls, isNotEmpty);
    });

    testWidgets('held work is a chip, and no band', (tester) async {
      await _pump(tester, sync: _held());
      expect(find.byType(TorchSyncChip), findsOneWidget);
      expect(find.text('1 held on this phone'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('offline-held-banner')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(TorchSyncBanner),
          matching: find.byType(OfflineHeldBanner),
        ),
        findsNothing,
      );
    });

    testWidgets('needs-you promotes to the band, which opens My work', (
      tester,
    ) async {
      await _pump(tester, sync: _needsYou());
      final band = find.descendant(
        of: find.byType(TorchSyncBanner),
        matching: find.byType(OfflineHeldBanner),
      );
      expect(band, findsOneWidget);
      await tester.tap(band);
      await tester.pumpAndSettle();
      expect(find.text('My work view'), findsOneWidget);
    });
  });

  group('2.0× text', () {
    for (final locale in <Locale>[const Locale('en'), const Locale('af')]) {
      testWidgets('${locale.languageCode}: nothing overflows', (tester) async {
        await _pump(tester, textScale: 2.0, locale: locale);
        expect(tester.takeException(), isNull);
        await scrollAgentTo(
          tester,
          find.byKey(const ValueKey<String>('outlet-o1')),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Veld is built, not declared', () {
    testWidgets('rows 64, targets 56', (tester) async {
      await _pump(tester, skin: SkinMode.veld);
      await scrollAgentTo(
        tester,
        find.byKey(const ValueKey<String>('outlet-o1')),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey<String>('outlet-o1'))).height,
        greaterThanOrEqualTo(64),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey<String>('add-store'))).height,
        greaterThanOrEqualTo(56),
      );
    });
  });

  group('the amber census', () {
    // A list of stores has no commit. The rows are the affordance and a row
    // never emits light; "Add a store" is a secondary. Zero on every skin,
    // in every state — including the needs-you band, which is never amber.
    final cases = <(String, _Outlets Function(), SyncStatus)>[
      ('loaded', _Outlets.new, SyncStatus.empty),
      ('empty', () => _Outlets(empty: true), SyncStatus.empty),
      ('error', () => _Outlets(error: _serverError), SyncStatus.empty),
      ('needs-you', _Outlets.new, _needsYou()),
    ];
    for (final (phase, repo, sync) in cases) {
      for (final skin in agentSkinModes) {
        testWidgets('$phase · ${skin.name}: 0', (tester) async {
          await _pump(tester, repo: repo(), skin: skin, sync: sync);
          if (phase == 'error') await _untilError(tester);
          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            agentSkinFor(skin),
            route: 'visit-outlet-picker',
            phase: phase,
          );
          expect(census.objectCount, 0, reason: census.describe());
        });
      }
    }
  });
}
