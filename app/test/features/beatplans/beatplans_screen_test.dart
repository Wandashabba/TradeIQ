import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/section_rule.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/beatplans/data/beatplans_repository.dart';
import 'package:tradeiq_app/features/beatplans/presentation/beatplans_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import '../../core/design/amber_golden.dart';
import '../operations_harness.dart';

const List<BeatPlan> _plans = <BeatPlan>[
  BeatPlan(
    id: 'bp1',
    name: 'North Route',
    status: 'in_progress',
    scheduledDate: '2026-07-10',
  ),
  BeatPlan(
    id: 'bp2',
    name: 'South Route',
    // The one status on this list that costs somebody a day of stores.
    status: 'missed',
    scheduledDate: '2026-07-11',
  ),
  BeatPlan(
    id: 'bp3',
    name: 'West Route',
    status: 'cancelled',
    scheduledDate: '2026-07-12',
  ),
];

BeatPlanDetail _detail({
  List<BeatPlanStop> stops = const <BeatPlanStop>[
    BeatPlanStop(id: 's1', outletId: 'o1', sequence: 1, visited: true),
    BeatPlanStop(id: 's2', outletId: 'o2', sequence: 2, visited: false),
  ],
}) => BeatPlanDetail(
  plan: const BeatPlan(
    id: 'bp1',
    name: 'North Route',
    status: 'in_progress',
    scheduledDate: '2026-07-10',
  ),
  stops: stops,
  stopsTotal: stops.length,
  stopsVisited: stops.where((s) => s.visited).length,
  adherenceRate: stops.isEmpty
      ? 0
      : stops.where((s) => s.visited).length / stops.length,
);

final List<Outlet> _outlets = <Outlet>[
  opsOutlet('o1', 'Kasi Corner Spaza'),
  opsOutlet('o2', 'Shoprite Klipspruit Mall'),
];

Future<FakeBeatPlansRepository> _pumpList(
  WidgetTester tester, {
  List<BeatPlan> plans = _plans,
  Object? listFailure,
  bool listPending = false,
  String role = 'manager',
  TiqSkin? skin,
  double textScale = 1.0,
  Locale? locale,
}) async {
  final repo = FakeBeatPlansRepository(
    plans: plans,
    listFailure: listFailure,
    listPending: listPending,
  );
  await pumpOperations(
    tester,
    const BeatPlansScreen(),
    skin: skin,
    textScale: textScale,
    locale: locale,
    settle: !listPending,
    overrides: <Override>[
      beatPlansRepositoryProvider.overrideWithValue(repo),
      outletsRepositoryProvider.overrideWithValue(
        FakeOpsOutletsRepository(outlets: _outlets),
      ),
      sessionControllerProvider.overrideWith(() => _Session(role)),
    ],
  );
  return repo;
}

Future<FakeBeatPlansRepository> _pumpDetail(
  WidgetTester tester, {
  BeatPlanDetail? detail,
  Object? detailFailure,
  Object? markFailure,

  /// The STORE list's own unhappy phases — a stop is titled with its store's
  /// name, and that list has a loading state and a failure state of its own.
  Object? outletsFailure,
  bool outletsPending = false,
  TiqSkin? skin,
  double textScale = 1.0,
  Locale? locale,
}) async {
  final repo = FakeBeatPlansRepository(
    detail: detail ?? _detail(),
    detailFailure: detailFailure,
    markFailure: markFailure,
  );
  await pumpOperations(
    tester,
    const BeatPlanDetailScreen(planId: 'bp1'),
    skin: skin,
    textScale: textScale,
    locale: locale,
    settle: !outletsPending,
    overrides: <Override>[
      beatPlansRepositoryProvider.overrideWithValue(repo),
      outletsRepositoryProvider.overrideWithValue(
        FakeOpsOutletsRepository(
          outlets: _outlets,
          listFailure: outletsFailure,
          listPending: outletsPending,
        ),
      ),
    ],
  );
  return repo;
}

class _Session extends SessionController {
  _Session(this.role);

  final String role;

  @override
  Future<SessionState> build() async => SessionState(role: role);
}

void main() {
  group('the list', () {
    testWidgets('names every plan, with its status and day', (tester) async {
      await _pumpList(tester);
      expect(find.text('North Route'), findsOneWidget);
      expect(find.text('In progress · Fri 10 Jul'), findsOneWidget);
    });

    testWidgets('missed is the only severity on the list', (tester) async {
      await _pumpList(tester);

      final missed = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('beatplan-bp2')),
      );
      expect(missed.severity, SoftRowSeverity.critical);
      expect(missed.severityLabel, 'Missed');

      // A cancelled plan is a decision somebody made, not a failure. The old
      // list painted it crimson-critical beside missed.
      final cancelled = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('beatplan-bp3')),
      );
      expect(cancelled.severity, SoftRowSeverity.none);

      final running = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('beatplan-bp1')),
      );
      expect(running.severity, SoftRowSeverity.none);
    });

    testWidgets('an unparseable date is shown as the wire sent it', (
      tester,
    ) async {
      await _pumpList(
        tester,
        plans: const <BeatPlan>[
          BeatPlan(
            id: 'bp9',
            name: 'Odd Route',
            status: 'scheduled',
            scheduledDate: 'next Tuesday',
          ),
        ],
      );
      // Still something a person can read back to support, rather than a
      // crash or an em dash.
      expect(find.text('Scheduled · next Tuesday'), findsOneWidget);
    });

    testWidgets('a cut list says so', (tester) async {
      await pumpOperations(
        tester,
        const BeatPlansScreen(),
        overrides: <Override>[
          beatPlansRepositoryProvider.overrideWithValue(_CutBeatPlans()),
          outletsRepositoryProvider.overrideWithValue(
            FakeOpsOutletsRepository(outlets: _outlets),
          ),
        ],
      );
      await scrollOpsTo(tester, find.byType(PaginationFooter));
      expect(find.text('Showing 3 of 41 plans.'), findsOneWidget);
    });

    testWidgets('a field agent is not offered the builder', (tester) async {
      await _pumpList(tester, role: 'field_agent');
      // An agent executes plans; POST /beatplans refuses them, so a dishonest
      // affordance is worse than none.
      expect(find.byType(SectionRuleAction), findsNothing);
    });

    testWidgets('an admin is', (tester) async {
      await _pumpList(tester, role: 'admin');
      expect(find.byType(SectionRuleAction), findsOneWidget);
    });
  });

  group('the list states', () {
    testWidgets('loading is a skeleton', (tester) async {
      await _pumpList(tester, listPending: true);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(Skeleton), findsOneWidget);
    });

    testWidgets('empty says what a plan is for', (tester) async {
      await _pumpList(tester, plans: const <BeatPlan>[]);
      expect(find.text('No beat plans.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('beatplan-create')),
        findsOneWidget,
      );
    });

    testWidgets('error sanitises and retries', (tester) async {
      await _pumpList(
        tester,
        listFailure: StateError('SocketException: api.tradeiq.co.za'),
      );
      expect(find.text('The beat plans did not load.'), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
    });
  });

  group('the detail', () {
    testWidgets('adherence is a figure, a meter and the fraction in words', (
      tester,
    ) async {
      await _pumpDetail(tester);

      final tile = find.byKey(const ValueKey<String>('adherence'));
      expect(tile, findsOneWidget);
      expect(
        find.descendant(of: tile, matching: find.text('50%')),
        findsOneWidget,
      );
      expect(find.text('1 of 2 stops'), findsOneWidget);
    });

    testWidgets('a plan with no stops has NO adherence, not nought', (
      tester,
    ) async {
      await _pumpDetail(tester, detail: _detail(stops: const <BeatPlanStop>[]));

      final tile = tester.widget<StatTile>(
        find.byKey(const ValueKey<String>('adherence')),
      );
      expect(
        tile.value,
        isNull,
        reason:
            'visited/total on an empty plan is 0/0. The old screen ran that '
            'through toStringAsFixed(0) and accused an agent of not working '
            'stops that were never there.',
      );
      expect(tile.noDataReason, isNotNull);
      expect(find.text('0%'), findsNothing);
      expect(
        find.text('This plan has no stops, so there is nothing to work.'),
        findsOneWidget,
      );
    });

    testWidgets('a stop names the shop, not its id', (tester) async {
      await _pumpDetail(tester);
      expect(find.text('Kasi Corner Spaza'), findsOneWidget);
      expect(find.text('Shoprite Klipspruit Mall'), findsOneWidget);
    });

    testWidgets('a stop with no name does not repeat its own subtitle', (
      tester,
    ) async {
      // THE FAILURE, WRITTEN DOWN: the fallback title was the stop's own
      // sequence, and the subtitle is that same sequence — a row reading
      // "Stop 1" over "Stop 1", which is the duplicated row title unify §1.15
      // lists as a defect this system removed. And it was reached by reading
      // `.value` off the outlets `AsyncValue`, which is null while the list is
      // still being walked as well as when the walk failed.
      await _pumpDetail(tester, outletsPending: true);
      await tester.pump(const Duration(milliseconds: 700));

      final row = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('stop-s1')),
      );
      expect(row.title, 'Store list still loading');
      expect(row.subtitle, 'Stop 1');
      expect(row.title, isNot(row.subtitle));
    });

    testWidgets('a store list that failed says that on every stop', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        outletsFailure: StateError('SocketException: api.tradeiq.co.za'),
      );

      final row = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('stop-s1')),
      );
      expect(row.title, 'Store list did not load');
      expect(row.subtitle, 'Stop 1');
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
    });

    testWidgets('a stop whose store is genuinely absent says so', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        detail: _detail(
          stops: const <BeatPlanStop>[
            BeatPlanStop(
              id: 's1',
              outletId: 'gone',
              sequence: 1,
              visited: false,
            ),
          ],
        ),
      );

      final row = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('stop-s1')),
      );
      expect(row.title, 'Store not on this list');
      expect(row.subtitle, 'Stop 1');
    });

    testWidgets('ticking a stop records markStopVisited', (tester) async {
      final repo = await _pumpDetail(tester);

      await tester.tap(find.byKey(const ValueKey<String>('stop-tick-s2')));
      await tester.pumpAndSettle();

      expect(repo.visitedPlanId, 'bp1');
      expect(repo.visitedStopId, 's2');
      expect(repo.visitedValue, isTrue);
    });

    testWidgets('the tick is a control the row does not swallow', (
      tester,
    ) async {
      await _pumpDetail(tester);
      final row = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('stop-s2')),
      );
      expect(
        row.trailingIsControl,
        isTrue,
        reason:
            'Without this the row\'s own label excludes the checkbox and a '
            'screen-reader user cannot work a stop at all.',
      );
      expect(
        tester
            .widget<TorchCheckbox>(
              find.byKey(const ValueKey<String>('stop-tick-s2')),
            )
            .label,
        'Not yet',
      );
    });

    testWidgets('a failed tick says the stop is as it was', (tester) async {
      await _pumpDetail(
        tester,
        markFailure: StateError('SocketException: api.tradeiq.co.za'),
      );

      await tester.tap(find.byKey(const ValueKey<String>('stop-tick-s2')));
      await tester.pumpAndSettle();

      expect(
        find.text('That stop was not changed. It is as it was.'),
        findsOneWidget,
      );
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      await settleOpsToasts(tester);
    });

    testWidgets('a plan with no stops says so rather than showing a blank', (
      tester,
    ) async {
      await _pumpDetail(tester, detail: _detail(stops: const <BeatPlanStop>[]));
      expect(find.text('No stops on this plan.'), findsOneWidget);
    });

    testWidgets('error sanitises', (tester) async {
      await _pumpDetail(
        tester,
        detailFailure: StateError('SocketException: api.tradeiq.co.za'),
      );
      expect(find.text('This beat plan did not load.'), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
    });
  });

  group('Afrikaans and 2.0x', () {
    testWidgets('the list is Afrikaans throughout', (tester) async {
      await _pumpList(tester, locale: const Locale('af'));
      expect(find.text('Besoekplanne'), findsWidgets);
      expect(find.text('Planne'), findsOneWidget);
      expect(find.textContaining('Gemis'), findsWidgets);
      expect(find.text('Beat plans'), findsNothing);
    });

    testWidgets('the detail is Afrikaans throughout', (tester) async {
      await _pumpDetail(tester, locale: const Locale('af'));
      expect(find.text('Stoppe'), findsOneWidget);
      expect(find.text('1 van 2 stoppe'), findsOneWidget);
      expect(find.text('Stops'), findsNothing);
    });

    testWidgets('the list at 2.0x does not overflow', (tester) async {
      await _pumpList(tester, textScale: 2.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the detail at 2.0x does not overflow', (tester) async {
      await _pumpDetail(tester, textScale: 2.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Afrikaans at 1.4x does not overflow either', (tester) async {
      await _pumpList(tester, textScale: 1.4, locale: const Locale('af'));
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
      'the list, loaded': (t) => _pumpList(t),
      'the list, empty': (t) => _pumpList(t, plans: const <BeatPlan>[]),
      'the list, error': (t) =>
          _pumpList(t, listFailure: StateError('no route to host')),
      'the day, loaded': (t) => _pumpDetail(t),
      'the day, error': (t) =>
          _pumpDetail(t, detailFailure: StateError('no route to host')),
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
    for (final skin in <TiqSkin>[
      TiqSkin.night(),
      TiqSkin.day(),
      TiqSkin.veld(),
    ]) {
      final onList = skin.mode == SkinMode.night ? 1 : 0;
      final listPhases = <String, Future<void> Function(WidgetTester)>{
        'loaded': (t) => _pumpList(t, skin: skin),
        'empty': (t) => _pumpList(t, skin: skin, plans: const <BeatPlan>[]),
        'loading': (t) async {
          await _pumpList(t, skin: skin, listPending: true);
          await t.pump(const Duration(milliseconds: 700));
        },
        'error': (t) => _pumpList(
          t,
          skin: skin,
          listFailure: StateError('SocketException: api.tradeiq.co.za'),
        ),
      };
      for (final phase in listPhases.entries) {
        testWidgets('list, ${skin.mode.name}, ${phase.key}: $onList', (
          tester,
        ) async {
          await phase.value(tester);
          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'beat-plans',
            phase: phase.key,
          );
          expect(census.objectCount, onList, reason: census.describe());
        });
      }

      // The detail route has no commit at all: ticking a stop is the row's
      // own control, and the nav is not on the route. Zero, everywhere.
      final detailPhases = <String, Future<void> Function(WidgetTester)>{
        'loaded': (t) => _pumpDetail(t, skin: skin),
        'empty': (t) => _pumpDetail(
          t,
          skin: skin,
          detail: _detail(stops: const []),
        ),
        'error': (t) => _pumpDetail(
          t,
          skin: skin,
          detailFailure: StateError('SocketException: api.tradeiq.co.za'),
        ),
      };
      for (final phase in detailPhases.entries) {
        testWidgets('detail, ${skin.mode.name}, ${phase.key}: 0', (
          tester,
        ) async {
          await phase.value(tester);
          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'beat-plan-detail',
            phase: phase.key,
          );
          expect(census.objectCount, 0, reason: census.describe());
        });
      }
    }
  });
}

/// A page with more behind it, and a server that counted.
class _CutBeatPlans extends FakeBeatPlansRepository {
  _CutBeatPlans() : super(plans: _plans);

  @override
  Future<PaginatedResponse<BeatPlan>> listBeatPlans() async =>
      const PaginatedResponse<BeatPlan>(
        data: _plans,
        nextCursor: 'cursor-2',
        total: 41,
      );
}
