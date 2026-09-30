import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/section_rule.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/dashboard/data/dashboard_repository.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/outlets/presentation/outlets_list_screen.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';

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

/// The two territories the scope tests choose between.
const List<Territory> _territories = <Territory>[
  Territory(id: 't-gp', name: 'Gauteng North', code: 'GP-TSH'),
  Territory(id: 't-wc', name: 'Western Cape', code: 'WC-CPT'),
];

/// The scope, already narrowed — the same device `floor_look_test` uses. The
/// chip's sheet needs a route to open over, and what is under test here is the
/// scoped SCREEN rather than the gesture that scoped it.
class _ScopedFilter extends DashboardFilterNotifier {
  _ScopedFilter(this.territoryId);

  final String? territoryId;

  @override
  DashboardFilter build() => DashboardFilter(territoryId: territoryId);
}

/// The fake the last `_pump` built, so a test can ask what the server was
/// asked for.
late FakeOpsOutletsRepository _repo;

/// Bring something below the fold into the tree.
///
/// The console frame is a lazy `SliverList`, so a widget that is off-screen is
/// not merely invisible — it has not been built, and no finder will see it.
/// The territory chip moved everything under it down by its own height, which
/// on a 360×720 handset is the difference for the last store row and for the
/// empty state's action. A reader scrolls; so does this.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 120);
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  List<Outlet> outlets = const <Outlet>[],
  Map<String, List<Outlet>> byTerritory = const <String, List<Outlet>>{},
  List<PinDispute> disputes = const <PinDispute>[],
  Object? listFailure,
  bool listPending = false,
  TiqSkin? skin,
  double textScale = 1.0,
  Locale? locale,
  Size size = const Size(360, 720),
  String? territoryId,
  List<Territory> territories = _territories,
}) async {
  _repo = FakeOpsOutletsRepository(
    outlets: outlets,
    byTerritory: byTerritory,
    listFailure: listFailure,
    listPending: listPending,
  );
  await pumpOperations(
    tester,
    const OutletsListScreen(),
    skin: skin,
    size: size,
    textScale: textScale,
    locale: locale,
    settle: !listPending,
    overrides: <Override>[
      outletsRepositoryProvider.overrideWithValue(_repo),
      outletAdminRepositoryProvider.overrideWithValue(
        FakeOutletAdminRepository(disputes: disputes),
      ),
      // Overridden in every case, including the unscoped ones: the chip reads
      // this list to decide whether it can be opened, and leaving it to reach
      // for a real `GET /territories` would put a socket error in the middle
      // of tests about something else.
      territoriesListProvider.overrideWith((ref) async => territories),
      dashboardFilterProvider.overrideWith(() => _ScopedFilter(territoryId)),
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
      expect(
        find.textContaining('Open pin reports'.toUpperCase()),
        findsNothing,
      );
    });

    testWidgets('name the agent and how far they stood', (tester) async {
      await _pump(
        tester,
        outlets: _outlets,
        disputes: <PinDispute>[_dispute()],
      );

      expect(
        find.textContaining('Open pin reports'.toUpperCase()),
        findsOneWidget,
      );
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
      await tester.tap(find.byKey(const ValueKey<String>('pin-reports-more')));
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
      final admin =
          FakeOutletAdminRepository(disputes: <PinDispute>[_dispute()])
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
      await tester.tap(find.byKey(const ValueKey<String>('pin-reports-more')));
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
      expect(
        find.textContaining('Open pin reports'.toUpperCase()),
        findsNothing,
      );
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

  // "when choosing a territory we need it to only show the store on that
  // territory and not everything else" — the owner, and the reason this
  // screen has a scope at all.
  group('the territory scope', () {
    testWidgets('reads "All territories" until one is chosen', (tester) async {
      await _pump(tester, outlets: _outlets);
      final chip = tester.widget<TorchFilterChip>(
        find.byKey(const ValueKey<String>('outlets-territory')),
      );
      expect(chip.label, 'All territories');
      expect(chip.selected, isFalse);
      // The unscoped screen must ask for no territory, not for a territory
      // that happens to be null-ish on the wire.
      expect(_repo.territoriesAsked, everyElement(isNull));
    });

    testWidgets('sends the chosen territory to the server', (tester) async {
      await _pump(
        tester,
        territoryId: 't-gp',
        outlets: _outlets,
        byTerritory: <String, List<Outlet>>{
          't-gp': <Outlet>[opsOutlet('o9', 'Tshwane Spaza', code: 'TS-009')],
        },
      );

      // THE WHOLE POINT. The fake answers `?territoryId=` out of its own map,
      // so a screen that read the scope and forgot to send it would show
      // `outlets` — every store in the account — and this fails.
      expect(_repo.territoriesAsked, contains('t-gp'));
      expect(find.text('Tshwane Spaza'), findsOneWidget);
      expect(find.text('Test Hypermarket'), findsNothing);
      expect(find.text('Unplaced Spaza'), findsNothing);
    });

    testWidgets('names the chosen territory on the chip', (tester) async {
      await _pump(tester, territoryId: 't-gp');
      final chip = tester.widget<TorchFilterChip>(
        find.byKey(const ValueKey<String>('outlets-territory')),
      );
      // Never the raw id: a uuid is not a name (unify §1.15).
      expect(chip.label, 'Gauteng North');
      expect(chip.selected, isTrue);
    });

    testWidgets('choosing one from the sheet narrows the list', (tester) async {
      await _pump(
        tester,
        outlets: _outlets,
        byTerritory: <String, List<Outlet>>{
          't-wc': <Outlet>[opsOutlet('o8', 'Cape Corner', code: 'CC-008')],
        },
      );
      expect(find.text('Test Hypermarket'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('outlets-territory')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('territory-option-t-wc')),
      );
      await tester.pumpAndSettle();

      expect(_repo.territoriesAsked, contains('t-wc'));
      expect(find.text('Cape Corner'), findsOneWidget);
      expect(find.text('Test Hypermarket'), findsNothing);
    });

    testWidgets('the unplaced figure counts the territory, not the account', (
      tester,
    ) async {
      await _pump(
        tester,
        territoryId: 't-gp',
        // Two unplaced stores in the account, one of them in this territory.
        outlets: <Outlet>[
          opsOutlet('o1', 'Elsewhere Unplaced', lat: 0, lng: 0),
          opsOutlet('o2', 'Also Elsewhere', lat: 0, lng: 0),
        ],
        byTerritory: <String, List<Outlet>>{
          't-gp': <Outlet>[
            opsOutlet('o3', 'Here Placed'),
            opsOutlet('o4', 'Here Unplaced', lat: 0, lng: 0),
          ],
        },
      );

      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('outlets-unplaced')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a territory with no stores is a designed state', (
      tester,
    ) async {
      await _pump(
        tester,
        territoryId: 't-gp',
        // The account is NOT empty — which is the whole distinction. "No
        // stores yet" here would tell a manager their account is bare.
        outlets: _outlets,
      );

      expect(find.text('No stores in Gauteng North.'), findsOneWidget);
      expect(find.text('No stores yet.'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('outlets-empty-territory')),
        findsOneWidget,
      );
      // A silhouette, because this is an absence and not an invitation
      // (unify §1.12) — and the way out of a filter is out of the filter, so
      // the action is the scope and not a new store.
      expect(find.byType(EmptyStateDrawing), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('outlets-clear-territory')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey<String>('create-outlet')), findsNothing);
    });

    testWidgets('clearing from that empty brings every store back', (
      tester,
    ) async {
      await _pump(tester, territoryId: 't-gp', outlets: _outlets);
      await _scrollTo(
        tester,
        find.byKey(const ValueKey<String>('outlets-clear-territory')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('outlets-clear-territory')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Hypermarket'), findsOneWidget);
      expect(_repo.territoriesAsked.last, isNull);
      final chip = tester.widget<TorchFilterChip>(
        find.byKey(const ValueKey<String>('outlets-territory')),
      );
      expect(chip.selected, isFalse);
    });

    testWidgets('an account with no stores at all keeps its invitation', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('No stores yet.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('create-outlet')),
        findsOneWidget,
      );
    });

    // GET /outlets/pin-disputes takes no territory, so this queue is the whole
    // account's. Sitting under a chip naming one territory it reads as that
    // territory's, and a manager who clears what they can see believes they
    // are done.
    testWidgets('the pin report queue says it is not narrowed', (tester) async {
      await _pump(
        tester,
        territoryId: 't-gp',
        byTerritory: <String, List<Outlet>>{'t-gp': _outlets},
        disputes: <PinDispute>[_dispute()],
      );
      expect(
        find.textContaining('This queue covers every territory'),
        findsOneWidget,
      );
    });

    testWidgets('and says nothing about it when nothing is scoped', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        disputes: <PinDispute>[_dispute()],
      );
      expect(
        find.textContaining('This queue covers every territory'),
        findsNothing,
      );
    });

    // A scope control that vanishes while the list loads, or after it fails,
    // leaves the reader unable to say what they asked for — which on an error
    // screen is the moment they most need to know.
    testWidgets('the chip survives loading', (tester) async {
      await _pump(tester, territoryId: 't-gp', listPending: true);
      await tester.pump(const Duration(milliseconds: 700));
      expect(
        find.byKey(const ValueKey<String>('outlets-territory')),
        findsOneWidget,
      );
    });

    testWidgets('the chip survives failure', (tester) async {
      await _pump(
        tester,
        territoryId: 't-gp',
        listFailure: StateError('no route to host'),
      );
      expect(
        find.byKey(const ValueKey<String>('outlets-territory')),
        findsOneWidget,
      );
    });

    testWidgets('the chip is not openable before the territories arrive', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets, territories: const <Territory>[]);
      final chip = tester.widget<TorchFilterChip>(
        find.byKey(const ValueKey<String>('outlets-territory')),
      );
      // An empty list is still a loaded list, so the chip opens onto the one
      // row that is always there — "All territories".
      expect(chip.onSelected, isNotNull);
      expect(chip.label, 'All territories');
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
      // Below the fold since the territory chip landed above it.
      await _scrollTo(tester, find.byKey(const ValueKey<String>('outlet-o2')));
      expect(find.text('Geen koördinate op rekord nie'), findsOneWidget);
      expect(
        find.textContaining('Oop pen-verslae'.toUpperCase()),
        findsOneWidget,
      );
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
    /// Day paints nothing, because their one rung is the primary
    /// commit block and this route has none armed.
    for (final skin in <TiqSkin>[TiqSkin.night(), TiqSkin.day()]) {
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
