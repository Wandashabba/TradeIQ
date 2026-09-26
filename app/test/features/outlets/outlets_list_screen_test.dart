import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/section_rule.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/outlets/presentation/outlets_list_screen.dart';

import '../../core/design/amber_golden.dart';
import '../operations_harness.dart';

final List<Outlet> _outlets = <Outlet>[
  opsOutlet('o1', 'Test Hypermarket', code: 'TH-001'),
  // An outlet at 0,0 has no usable coordinates — it cannot be geofenced, so a
  // visit to it cannot be verified. The list has to say so.
  opsOutlet('o2', 'Unplaced Spaza', code: 'US-002', lat: 0, lng: 0),
];

PinDispute _dispute({
  String id = 'd1',
  String outletId = 'o2',
  String outletName = 'Unplaced Spaza',
  double distanceM = 8400,
}) => PinDispute(
  id: id,
  outletId: outletId,
  outletName: outletName,
  outletCode: 'US-002',
  visitId: 'v1',
  agentLabel: 'Thandi Mokoena',
  lat: -26.2114,
  lng: 28.0493,
  distanceM: distanceM,
  outletLat: 0,
  outletLng: 0,
  note: null,
  status: 'open',
  resolvedByLabel: null,
  resolvedAt: null,
  accuracyM: 12,
  isMocked: false,
  createdAt: DateTime.utc(2026, 9, 18, 7),
  agentIsOnlyVisitor: false,
  photos: const <PinDisputePhoto>[],
);

Future<void> _pump(
  WidgetTester tester, {
  List<Outlet> outlets = const <Outlet>[],
  List<PinDispute> disputes = const <PinDispute>[],
  Object? listFailure,
  bool listPending = false,
  TiqSkin? skin,
  double textScale = 1.0,
  Locale? locale,
  Size size = const Size(360, 720),
}) async {
  await pumpOperations(
    tester,
    const OutletsListScreen(),
    skin: skin,
    size: size,
    textScale: textScale,
    locale: locale,
    settle: !listPending,
    overrides: <Override>[
      outletsRepositoryProvider.overrideWithValue(
        FakeOpsOutletsRepository(
          outlets: outlets,
          listFailure: listFailure,
          listPending: listPending,
        ),
      ),
      outletAdminRepositoryProvider.overrideWithValue(
        FakeOutletAdminRepository(disputes: disputes),
      ),
    ],
  );
}

void main() {
  group('the list', () {
    testWidgets('names every store', (tester) async {
      await _pump(tester, outlets: _outlets);
      expect(find.text('Test Hypermarket'), findsOneWidget);
      expect(find.text('Unplaced Spaza'), findsOneWidget);
    });

    testWidgets('flags a store that cannot be geofenced, in words', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets);

      final row = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('outlet-o2')),
      );
      expect(row.severity, SoftRowSeverity.watch);
      // The bar is crimson and the WORD is what survives greyscale.
      expect(row.severityLabel, 'No location');
      expect(find.text('No coordinates on file'), findsOneWidget);
    });

    testWidgets('a located store carries no severity at all', (tester) async {
      await _pump(tester, outlets: _outlets);

      final row = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('outlet-o1')),
      );
      expect(row.severity, SoftRowSeverity.none);
      expect(row.severityLabel, isNull);
    });

    testWidgets('the code wears the identifier face, never the title', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets);

      final code = tester.widget<Text>(find.text('TH-001'));
      expect(code.style?.fontFamily, 'JetBrains Mono');
    });

    testWidgets('a row goes to the repair screen', (tester) async {
      await _pump(tester, outlets: _outlets);

      await tester.tap(find.byKey(const ValueKey<String>('outlet-o2')));
      await tester.pumpAndSettle();
      expect(find.text('stub:/outlets/o2'), findsOneWidget);
    });
  });

  group('unplaced stores, as a figure', () {
    testWidgets('a measured zero renders 0 and keeps its place', (
      tester,
    ) async {
      await _pump(tester, outlets: <Outlet>[_outlets.first]);

      final tile = find.byKey(const ValueKey<String>('outlets-unplaced'));
      expect(tile, findsOneWidget);
      expect(
        find.descendant(of: tile, matching: find.text('0')),
        findsOneWidget,
        reason:
            'The provider walks every page, so nought unplaced stores is a '
            'measured fact. An em dash here would claim we did not count.',
      );
      final mark = tester.widget<SeverityMark>(
        find.descendant(of: tile, matching: find.byType(SeverityMark)),
      );
      expect(mark.kind, SeverityMarkKind.onTarget);
    });

    testWidgets('one unplaced store raises the watch mark', (tester) async {
      await _pump(tester, outlets: _outlets);

      final tile = find.byKey(const ValueKey<String>('outlets-unplaced'));
      expect(
        find.descendant(of: tile, matching: find.text('1')),
        findsOneWidget,
      );
      final mark = tester.widget<SeverityMark>(
        find.descendant(of: tile, matching: find.byType(SeverityMark)),
      );
      expect(mark.kind, SeverityMarkKind.watch);
    });
  });

  group('open pin reports', () {
    testWidgets('are silent when there are none', (tester) async {
      await _pump(tester, outlets: _outlets);
      expect(find.textContaining('Open pin reports'.toUpperCase()), findsNothing);
    });

    testWidgets('name the agent and how far they stood', (tester) async {
      await _pump(
        tester,
        outlets: _outlets,
        disputes: <PinDispute>[_dispute()],
      );

      expect(find.textContaining('Open pin reports'.toUpperCase()), findsOneWidget);
      expect(
        find.text('Thandi Mokoena stood 8.4 km away'),
        findsOneWidget,
        reason:
            'The distance goes through the one formatter — the locale owns '
            'the decimal mark — and the km/m choice is RouteDistance’s.',
      );
    });

    testWidgets('a cut queue says so, and offers the rest', (tester) async {
      // The count beside the marker was `open.length` — the size of ONE PAGE,
      // read as the size of the queue. A manager cleared what they could see
      // and believed they were done, and an unworked pin report is a store an
      // agent cannot check into.
      final admin = FakeOutletAdminRepository(
        disputes: <PinDispute>[_dispute()],
      )..disputeCursor = 'page-2';
      admin.disputePages['page-2'] = <PinDispute>[
        _dispute(id: 'd2', outletId: 'o3', outletName: 'Far Corner Spaza'),
      ];

      await pumpOperations(
        tester,
        const OutletsListScreen(),
        overrides: <Override>[
          outletsRepositoryProvider.overrideWithValue(
            FakeOpsOutletsRepository(outlets: _outlets),
          ),
          outletAdminRepositoryProvider.overrideWithValue(admin),
        ],
      );

      // Never a fabricated total: the server returns a cursor, not a count.
      expect(find.textContaining('Showing 1.'), findsOneWidget);
      expect(find.textContaining('Showing 1 of'), findsNothing);

      await scrollOpsTo(
        tester,
        find.byKey(const ValueKey<String>('pin-reports-more')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('pin-reports-more')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Far Corner Spaza'), findsOneWidget);
      expect(
        find.text('Unplaced Spaza'),
        findsWidgets,
        reason: 'page one stays',
      );
      expect(admin.disputeCursorsAsked, <String?>[null, 'page-2']);
      // The server stopped sending a cursor, so the queue is whole.
      expect(
        find.byKey(const ValueKey<String>('pin-reports-more')),
        findsNothing,
      );
    });

    testWidgets('an uncut queue owns up to nothing', (tester) async {
      await _pump(
        tester,
        outlets: _outlets,
        disputes: <PinDispute>[_dispute()],
      );
      expect(find.textContaining('Showing'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('pin-reports-more')),
        findsNothing,
      );
    });

    testWidgets('a page that will not load keeps the reports on screen', (
      tester,
    ) async {
      final admin = FakeOutletAdminRepository(
        disputes: <PinDispute>[_dispute()],
      )
        ..disputeCursor = 'page-2'
        ..disputeMoreThrows = true;

      await pumpOperations(
        tester,
        const OutletsListScreen(),
        overrides: <Override>[
          outletsRepositoryProvider.overrideWithValue(
            FakeOpsOutletsRepository(outlets: _outlets),
          ),
          outletAdminRepositoryProvider.overrideWithValue(admin),
        ],
      );

      await scrollOpsTo(
        tester,
        find.byKey(const ValueKey<String>('pin-reports-more')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('pin-reports-more')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unplaced Spaza'), findsWidgets);
      expect(find.text('The rest of the queue did not load'), findsOneWidget);
    });

    testWidgets('stay silent when the queue itself fails to load', (
      tester,
    ) async {
      await pumpOperations(
        tester,
        const OutletsListScreen(),
        overrides: <Override>[
          outletsRepositoryProvider.overrideWithValue(
            FakeOpsOutletsRepository(outlets: _outlets),
          ),
          outletAdminRepositoryProvider.overrideWithValue(
            _FailingAdminRepository(),
          ),
        ],
      );

      // A manager who cannot reach the disputes endpoint still needs the
      // store list underneath it.
      expect(find.textContaining('Open pin reports'.toUpperCase()), findsNothing);
      expect(find.text('Test Hypermarket'), findsOneWidget);
    });
  });

  group('the states', () {
    testWidgets('loading is a skeleton, not a spinner', (tester) async {
      await _pump(tester, listPending: true);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(Skeleton), findsOneWidget);
    });

    testWidgets('empty offers the one next step', (tester) async {
      await _pump(tester);
      expect(find.text('No stores yet.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('create-outlet')),
        findsOneWidget,
      );
    });

    testWidgets('error sanitises and retries', (tester) async {
      await _pump(
        tester,
        listFailure: StateError('SocketException: api.tradeiq.co.za'),
      );
      expect(find.text('The store list did not load.'), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('outlets-retry')),
        findsOneWidget,
      );
    });
  });

  group('every interactive element is operable by a screen reader', () {
    testWidgets('"Add a store" on the section rule can be activated', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets);

      final handle = tester.ensureSemantics();
      final action = find.byType(SectionRuleAction);
      expect(action, findsOneWidget);

      // Not `tester.tap`: the question is whether a screen-reader user can
      // perform the action, and an excluding Semantics node with no `onTap`
      // announces a button that does nothing.
      expect(
        tester
            .getSemantics(action)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
        reason:
            'A section rule action that announces itself and carries no tap '
            'action is a button a reader can focus and cannot press.',
      );
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('stub:/outlets/create'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the refresh button announces its destination', (tester) async {
      await _pump(tester, outlets: _outlets);
      final handle = tester.ensureSemantics();
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey<String>('outlets-refresh')))
            .label,
        contains('Reload the store list'),
      );
      handle.dispose();
    });
  });

  group('Afrikaans', () {
    testWidgets('has no English left on it', (tester) async {
      await _pump(
        tester,
        outlets: _outlets,
        disputes: <PinDispute>[_dispute()],
        locale: const Locale('af'),
      );
      expect(find.text('Winkels'), findsWidgets);
      expect(find.text('Geen koördinate op rekord nie'), findsOneWidget);
      expect(find.textContaining('Oop pen-verslae'.toUpperCase()), findsOneWidget);
      // The severity word lives in the row's spoken label, which is where it
      // has to be legible too.
      final row = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('outlet-o2')),
      );
      expect(row.severityLabel, 'Geen ligging');
      expect(find.text('Stores'), findsNothing);
    });
  });

  group('2.0x text', () {
    testWidgets('the structure survives and nothing overflows', (tester) async {
      await _pump(
        tester,
        outlets: _outlets,
        disputes: <PinDispute>[_dispute()],
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(SoftRow), findsWidgets);
    });

    testWidgets('Afrikaans at 1.4x does not overflow either', (tester) async {
      await _pump(
        tester,
        outlets: _outlets,
        disputes: <PinDispute>[_dispute()],
        textScale: 1.4,
        locale: const Locale('af'),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('every button is operable by a screen reader', () {
    // The kit shipped a component family that announced itself and did
    // nothing when a screen reader activated it, and `SectionRuleAction` and
    // `PaginationFooter.action` were still shipping that way when this group
    // was migrated. This is the guard, on this screen, per phase — so no
    // local `Semantics(button: true, excludeSemantics: true)` around a bare
    // GestureDetector can bring it back.
    final phases = <String, Future<void> Function(WidgetTester)>{
      'loaded': (t) =>
          _pump(t, outlets: _outlets, disputes: <PinDispute>[_dispute()]),
      'empty': (t) => _pump(t),
      'error': (t) => _pump(t, listFailure: StateError('no route to host')),
    };
    for (final phase in phases.entries) {
      testWidgets(phase.key, (tester) async {
        final handle = tester.ensureSemantics();
        await phase.value(tester);
        expectEveryButtonActivatable(tester);
        handle.dispose();
      });
    }
  });

  group('the amber census, every phase in every skin', () {
    /// The stores list nominates no content amber, so the arithmetic is the
    /// same everywhere: Night paints the nav's active tab and nothing else;
    /// Day and Veld paint nothing, because their one rung is the primary
    /// commit block and this route has none armed.
    for (final skin in <TiqSkin>[
      TiqSkin.night(),
      TiqSkin.day(),
      TiqSkin.veld(),
    ]) {
      final lit = skin.mode == SkinMode.night ? 1 : 0;
      final phases = <String, Future<void> Function(WidgetTester)>{
        'loaded': (t) => _pump(
          t,
          skin: skin,
          outlets: _outlets,
          disputes: <PinDispute>[_dispute()],
        ),
        'empty': (t) => _pump(t, skin: skin),
        'loading': (t) async {
          await _pump(t, skin: skin, listPending: true);
          await t.pump(const Duration(milliseconds: 700));
        },
        'error': (t) => _pump(
          t,
          skin: skin,
          listFailure: StateError('SocketException: api.tradeiq.co.za'),
        ),
      };
      for (final phase in phases.entries) {
        testWidgets('${skin.mode.name}, ${phase.key}: $lit', (tester) async {
          await phase.value(tester);
          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'outlets',
            phase: phase.key,
          );
          expect(census.objectCount, lit, reason: census.describe());
        });
      }
    }
  });
}

class _FailingAdminRepository extends FakeOutletAdminRepository {
  @override
  Future<PaginatedResponse<PinDispute>> listPinDisputes({
    String? status,
    String? outletId,
    int? limit,
    String? cursor,
  }) async => throw StateError('no route to host');
}
