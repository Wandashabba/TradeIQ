import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/section_rule.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/alerts/presentation/alerts_screen.dart';
import 'package:tradeiq_app/features/audit/data/photos_repository.dart';
import 'package:tradeiq_app/features/fraud/data/fraud_repository.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/users/data/users_repository.dart';
import 'package:tradeiq_app/features/visits/data/visit_detail_repository.dart';

import '../../core/design/amber_golden.dart';
import '../worklist_harness.dart';

AlertItem _alert({
  String id = 'a1',
  String severity = 'critical',
  String message = 'Out of stock since Tuesday',
  String metric = 'out_of_stock',
  String? outletId = 'o1',
  String? visitId,
  String? photoId,
  bool acknowledged = false,
  DateTime? createdAt,
}) => AlertItem(
  id: id,
  metric: metric,
  message: message,
  severity: severity,
  acknowledged: acknowledged,
  outletId: outletId,
  visitId: visitId,
  evidencePhotoId: photoId,
  createdAt: createdAt ?? DateTime.utc(2026, 9, 18, 6),
);

final List<Outlet> _outlets = <Outlet>[
  outlet('o1', 'Kasi Corner Spaza'),
  outlet('o2', 'Shoprite Klipspruit Mall'),
];

VisitDetail _visit(String id) => VisitDetail(
  id: id,
  status: 'submitted',
  outlet: const VisitOutletRef(
    id: 'o1',
    name: 'Kasi Corner Spaza',
    code: 'KCS-001',
    channelType: 'spaza',
  ),
  agent: const VisitAgentRef(id: 'agent-1', email: 'thandi@acme.test'),
  checkinTs: DateTime.utc(2026, 9, 18, 7),
  submittedAtClient: DateTime.utc(2026, 9, 18, 7, 14),
  geofencePass: true,
  distanceM: 12,
  score: null,
  sections: const <VisitSectionSummary>[],
  photoTotal: 0,
  photos: const <VisitPhotoRef>[],
  riskScore: 0,
  signals: const <FraudSignal>[],
);

class _Visits implements VisitDetailRepository {
  @override
  Future<VisitDetail> fetch(String visitId) async => _visit(visitId);
}

Future<FakeAlertsRepository> _pump(
  WidgetTester tester, {
  List<AlertItem> alerts = const <AlertItem>[],
  List<Outlet> outlets = const <Outlet>[],
  String? nextCursor,
  int? total,
  List<AppUser> users = const <AppUser>[],
  Object? listFailure,
  Object? ackFailure,
  bool listPending = false,
  TiqSkin? skin,
  double textScale = 1.0,
  Size size = const Size(360, 720),
}) async {
  final repository = FakeAlertsRepository(
    alerts: alerts,
    nextCursor: nextCursor,
    total: total,
    listFailure: listFailure,
    ackFailure: ackFailure,
    listPending: listPending,
  );
  await pumpWorklist(
    tester,
    const AlertsScreen(),
    skin: skin,
    size: size,
    settle: !listPending,
    textScale: textScale,
    users: users,
    overrides: <Override>[
      visitDetailRepositoryProvider.overrideWithValue(_Visits()),
      alertsRepositoryProvider.overrideWithValue(repository),
      outletsRepositoryProvider.overrideWithValue(
        FakeOutletsRepository(outlets),
      ),
      photosRepositoryProvider.overrideWithValue(
        FakePhotosRepository(bytes: pngBytes),
      ),
    ],
  );
  return repository;
}

void main() {
  group('the worklist', () {
    testWidgets('opens on the open alerts, worst first', (tester) async {
      await _pump(
        tester,
        outlets: _outlets,
        alerts: <AlertItem>[
          _alert(
            id: 'watch',
            severity: 'warning',
            message: 'Price above the published band',
            outletId: 'o2',
            createdAt: DateTime.utc(2026, 9, 18, 12),
          ),
          _alert(id: 'crit'),
          _alert(id: 'done', acknowledged: true, message: 'Old one'),
        ],
      );

      await scrollWorklistTo(tester, find.byType(SoftRow).first);
      final rows = tester.widgetList<SoftRow>(find.byType(SoftRow)).toList();
      // Acknowledged rows are filtered out of Open entirely.
      expect(rows.length, 2);
      expect(rows.first.title, 'Out of stock since Tuesday');
      expect(rows.first.severity, SoftRowSeverity.critical);
      expect(rows.last.severity, SoftRowSeverity.watch);
    });

    testWidgets('a row names the outlet, never its database id', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets, alerts: <AlertItem>[_alert()]);

      await scrollWorklistTo(tester, find.text('Kasi Corner Spaza'));
      expect(find.text('Kasi Corner Spaza'), findsOneWidget);
      // #399/#400: the row before this one printed `Outlet o1`.
      expect(find.textContaining('Outlet o1'), findsNothing);
    });

    testWidgets('an outlet the list cannot name reads as words, not its id', (
      tester,
    ) async {
      const uuid = '5f3c9a1e-2b7d-4c1f-9e0a-7d2b1c3e4f50';
      await _pump(tester, alerts: <AlertItem>[_alert(outletId: uuid)]);

      await scrollWorklistTo(tester, find.byType(SoftRow).first);
      expect(find.text('Outlet name unavailable'), findsOneWidget);
      expect(find.textContaining(uuid), findsNothing);
      final row = tester.widget<SoftRow>(find.byType(SoftRow).first);
      expect(row.semanticsLabel, isNot(contains(uuid)));
    });

    testWidgets('severity is a bar AND a word, never the hue alone', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets, alerts: <AlertItem>[_alert()]);

      await scrollWorklistTo(tester, find.byType(SoftRow).first);
      final row = tester.widget<SoftRow>(find.byType(SoftRow).first);
      expect(row.severity, SoftRowSeverity.critical);
      expect(row.severityLabel, 'Critical');
      expect(row.semanticsLabel, startsWith('Critical.'));
    });

    testWidgets('the rule that fired is on the row, in the identifier face', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        alerts: <AlertItem>[_alert(metric: 'OSA_BELOW_50')],
      );

      await scrollWorklistTo(tester, find.text('OSA_BELOW_50'));
      final skin = TiqSkin.night();
      final text = tester.widget<Text>(find.text('OSA_BELOW_50'));
      expect(text.style!.fontFamily, skin.text.monoIdent.family);
    });

    testWidgets('the section rule carries the count it is showing', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        alerts: <AlertItem>[_alert(id: 'a'), _alert(id: 'b', outletId: 'o2')],
      );

      await scrollWorklistTo(tester, find.byType(SectionRule));
      final rule = tester.widget<SectionRule>(find.byType(SectionRule));
      expect(rule.name, 'Open');
      expect(rule.count, 2);
    });
  });

  group('the lead indicator', () {
    testWidgets('leads with open criticals and subordinates the rest', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        alerts: <AlertItem>[
          _alert(id: 'c1'),
          _alert(id: 'c2', outletId: 'o2'),
          _alert(id: 'w1', severity: 'warning'),
          _alert(id: 'ack', acknowledged: true),
        ],
      );

      expect(find.text('OPEN CRITICAL'), findsOneWidget);
      expect(find.text('1 warnings · 1 acknowledged'), findsOneWidget);
    });

    testWidgets('a measured zero renders 0 and keeps its place', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        alerts: <AlertItem>[_alert(id: 'w1', severity: 'warning')],
      );

      // Never suppressed, never an em dash: nought open criticals is a fact.
      expect(find.text('OPEN CRITICAL'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(StatTile),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(StatTile),
          matching: find.text(emDash),
        ),
        findsNothing,
      );
    });
  });

  group('the filter rail', () {
    testWidgets('is never amber and carries the selection in three channels', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets, alerts: <AlertItem>[_alert()]);

      final chips = tester
          .widgetList<TorchFilterChip>(find.byType(TorchFilterChip))
          .toList();
      final open = chips.firstWhere((c) => c.label == 'Open');
      expect(open.selected, isTrue);
      expect(open.count, 1);
    });

    testWidgets('Acknowledged reveals the rows Open hides', (tester) async {
      await _pump(
        tester,
        outlets: _outlets,
        alerts: <AlertItem>[
          _alert(id: 'ack', acknowledged: true, message: 'Already seen'),
        ],
      );

      expect(find.byType(SoftRow), findsNothing);
      await tester.tap(find.byKey(const ValueKey<String>('tab-acknowledged')));
      await tester.pumpAndSettle();

      await scrollWorklistTo(tester, find.text('Already seen'));
      expect(find.text('Already seen'), findsOneWidget);
      // Still listed, and it says so in words rather than vanishing.
      expect(find.textContaining('acknowledged'), findsWidgets);
    });

    testWidgets('a severity chip narrows the list without refetching', (
      tester,
    ) async {
      final repository = await _pump(
        tester,
        outlets: _outlets,
        alerts: <AlertItem>[
          _alert(id: 'c'),
          _alert(id: 'w', severity: 'warning', message: 'Price drift'),
        ],
      );

      await scrollRailTo(
        tester,
        find.byKey(const ValueKey<String>('filter-warning')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('filter-warning')));
      await tester.pumpAndSettle();

      await scrollWorklistTo(tester, find.byType(SoftRow).first);
      expect(find.byType(SoftRow), findsOneWidget);
      expect(find.text('Price drift'), findsOneWidget);
      // Filtering is client-side over the loaded page, so the list does not
      // flash and the server is not asked again.
      expect(repository.acknowledged, isEmpty);
    });

    testWidgets('a filter that hides everything names the way back', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        alerts: <AlertItem>[_alert(id: 'c')],
      );

      await scrollRailTo(
        tester,
        find.byKey(const ValueKey<String>('filter-warning')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('filter-warning')));
      await tester.pumpAndSettle();

      await scrollWorklistTo(tester, find.byType(EmptyState));
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Clear the filter to see the rest.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('clear-filters')));
      await tester.pumpAndSettle();
      await scrollWorklistTo(tester, find.byType(SoftRow).first);
      expect(find.byType(SoftRow), findsOneWidget);
    });
  });

  group('acknowledging', () {
    testWidgets('patches the alert by id', (tester) async {
      final repository = await _pump(
        tester,
        outlets: _outlets,
        alerts: <AlertItem>[_alert(id: 'a7')],
      );

      await scrollWorklistTo(tester, find.byKey(const ValueKey('ack-a7')));
      await tester.tap(find.byKey(const ValueKey('ack-a7')));
      await tester.pumpAndSettle();

      expect(repository.acknowledged, <String>['a7']);
    });

    testWidgets('a second tap mid-collapse fires no duplicate PATCH', (
      tester,
    ) async {
      final repository = await _pump(
        tester,
        outlets: _outlets,
        alerts: <AlertItem>[_alert(id: 'a7')],
      );

      await scrollWorklistTo(tester, find.byKey(const ValueKey('ack-a7')));
      await tester.tap(find.byKey(const ValueKey('ack-a7')));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(
        find.byKey(const ValueKey('ack-a7')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(repository.acknowledged, <String>['a7']);
    });

    testWidgets('a failure brings the row back and says so', (tester) async {
      await _pump(
        tester,
        outlets: _outlets,
        alerts: <AlertItem>[_alert(id: 'a7')],
        ackFailure: StateError('no'),
      );

      await scrollWorklistTo(tester, find.byKey(const ValueKey('ack-a7')));
      await tester.tap(find.byKey(const ValueKey('ack-a7')));
      await tester.pumpAndSettle();

      // An unacknowledged alert never silently vanishes.
      expect(find.byType(SoftRow), findsOneWidget);
      expect(
        find.text('That alert was not acknowledged. It is still open.'),
        findsOneWidget,
      );
      await settleToasts(tester);
    });
  });

  group('evidence and the visit link', () {
    testWidgets('a photo on a visit shows the thumbnail', (tester) async {
      await _pump(
        tester,
        outlets: _outlets,
        alerts: <AlertItem>[_alert(photoId: 'p1', visitId: 'v1')],
      );

      await scrollWorklistTo(tester, find.byType(SoftRow).first);
      expect(find.byType(Image), findsWidgets);
    });

    testWidgets('no photo means no thumbnail and nothing reserved', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        alerts: <AlertItem>[_alert(visitId: 'v1')],
      );

      await scrollWorklistTo(tester, find.byType(SoftRow).first);
      final row = tester.widget<SoftRow>(find.byType(SoftRow).first);
      expect(row.trailing, isNull);
    });

    testWidgets('an alert with no visit offers no View visit at all', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        alerts: <AlertItem>[_alert(id: 'a7')],
      );

      await scrollWorklistTo(tester, find.byKey(const ValueKey('ack-a7')));
      expect(find.byKey(const ValueKey('view-visit-a7')), findsNothing);
    });

    testWidgets('a row with a visit opens it', (tester) async {
      await _pump(
        tester,
        outlets: _outlets,
        alerts: <AlertItem>[_alert(id: 'a7', visitId: 'v9')],
      );

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey('view-visit-a7')),
      );
      await tester.tap(find.byKey(const ValueKey('view-visit-a7')));
      await tester.pumpAndSettle();

      expect(find.text('stub:/visits/v9'), findsOneWidget);
    });
  });

  group('the detail sheet', () {
    testWidgets('the row opens it, and it leads with the severity', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        alerts: <AlertItem>[_alert(id: 'a7', metric: 'OSA_BELOW_50')],
      );

      await scrollWorklistTo(tester, find.byType(SoftRow).first);
      await tester.tap(find.byType(SoftRow).first);
      await tester.pumpAndSettle();

      expect(find.byType(TorchSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TorchSheet),
          matching: find.text('Critical'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('OSA_BELOW_50 · Kasi Corner Spaza'),
        findsOneWidget,
      );
    });

    testWidgets('the submitting agent is named from the roster', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        users: <AppUser>[
          person('agent-1', 'thandi@acme.test', name: 'Thandi Mokoena'),
        ],
        alerts: <AlertItem>[_alert(id: 'a7', visitId: 'v7')],
      );

      // The title, not the row's centre: with a visit linked, the centre is
      // the row's own "View visit" action.
      await scrollWorklistTo(tester, find.text('Out of stock since Tuesday'));
      await tester.tap(find.text('Out of stock since Tuesday'));
      await tester.pumpAndSettle();
      await scrollSheetTo(
        tester,
        find.byKey(const ValueKey<String>('sheet-agent')),
      );

      final agent = tester.widget<PersonRow>(
        find.byKey(const ValueKey<String>('sheet-agent')),
      );
      expect(agent.name, 'Thandi Mokoena');
      expect(find.text('Thandi Mokoena'), findsOneWidget);
      // Named, the sign-in address is not shown beside the name.
      expect(find.text('thandi@acme.test'), findsNothing);
      expect(find.textContaining('agent-1'), findsNothing);
    });

    testWidgets('an agent the roster cannot name is their sign-in address', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        alerts: <AlertItem>[_alert(id: 'a7', visitId: 'v7')],
      );

      // The title, not the row's centre: with a visit linked, the centre is
      // the row's own "View visit" action.
      await scrollWorklistTo(tester, find.text('Out of stock since Tuesday'));
      await tester.tap(find.text('Out of stock since Tuesday'));
      await tester.pumpAndSettle();
      await scrollSheetTo(
        tester,
        find.byKey(const ValueKey<String>('sheet-agent')),
      );

      final agent = tester.widget<PersonRow>(
        find.byKey(const ValueKey<String>('sheet-agent')),
      );
      expect(agent.name, isNull);
      expect(find.textContaining('thandi@acme.test'), findsOneWidget);
      expect(find.textContaining('agent-1'), findsNothing);
    });

    testWidgets('a sheet with no visit offers no Open the visit', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        alerts: <AlertItem>[_alert(id: 'a7')],
      );

      await scrollWorklistTo(tester, find.byType(SoftRow).first);
      await tester.tap(find.byType(SoftRow).first);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('sheet-open-visit')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('sheet-acknowledge')),
        findsOneWidget,
      );
    });
  });

  group('the settled states', () {
    testWidgets('empty is a designed state, not a centred "No data"', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets);

      expect(find.text('Nothing to triage.'), findsOneWidget);
      expect(
        find.text('Alerts appear here when a rule fires on a submitted visit.'),
        findsOneWidget,
      );
      // The section still renders: a section that vanishes when empty makes a
      // manager think the feature is gone.
      expect(find.byType(SectionRule), findsOneWidget);
    });

    testWidgets('a failure is sanitised and offers one retry', (tester) async {
      await _pump(
        tester,
        listFailure: StateError(
          'SocketException: Failed host lookup: api.tradeiq.co.za',
        ),
      );

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('alerts-retry')),
        findsOneWidget,
      );
    });

    testWidgets('a cut list says so, and never invents a total', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        alerts: <AlertItem>[_alert(id: 'a1'), _alert(id: 'a2')],
        nextCursor: 'cursor-2',
      );

      await scrollWorklistTo(tester, find.byType(PaginationFooter));
      expect(
        find.text('Showing the first 2. There are more.'),
        findsOneWidget,
      );
      // Never a fabricated total: this server did not say how many exist.
      expect(
        find.descendant(
          of: find.byType(PaginationFooter),
          matching: find.textContaining('newest of'),
        ),
        findsNothing,
      );
      // And no offer to narrow: the filters are client-side over this page
      // and could never bring the rest into view.
      expect(find.textContaining('Narrow'), findsNothing);
      expect(find.text('The counts above are of these 2.'), findsOneWidget);
    });

    testWidgets('a cut list with a server total names it, in the order used', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        alerts: <AlertItem>[_alert(id: 'a1'), _alert(id: 'a2')],
        nextCursor: 'cursor-2',
        total: 1284,
      );

      await scrollWorklistTo(tester, find.byType(PaginationFooter));
      // Newest, because that is the order the server cut in — not
      // "riskiest", which is a ranking it did not do. The total is grouped
      // by the locale formatter.
      expect(
        find.text('Showing the 2 newest of 1,284 alerts.'),
        findsOneWidget,
      );
      expect(find.text('The counts above are of these 2.'), findsOneWidget);
    });

    testWidgets('one page renders no footer at all', (tester) async {
      await _pump(
        tester,
        outlets: _outlets,
        alerts: <AlertItem>[_alert(id: 'a1')],
      );

      expect(find.byType(PaginationFooter), findsNothing);
    });
  });

  group('the amber census', () {
    testWidgets('Night paints exactly one lit object: the nav tab', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        alerts: <AlertItem>[_alert(id: 'a1'), _alert(id: 'a2', outletId: 'o2')],
      );

      final census = await amberCensus(tester);
      expectWithinAmberBudget(
        census,
        TiqSkin.night(),
        route: 'alerts',
        phase: 'loaded',
      );
      expect(
        census.objectCount,
        1,
        reason:
            'Alerts nominates no content amber: the lead figure is crimson, '
            'the filter chip is lifted, the section rule has no colour, and '
            'the severity bars are severity.\n${census.describe()}',
      );
    });

    testWidgets('Night, empty, still paints exactly the nav tab', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets);

      final census = await amberCensus(tester);
      expect(census.objectCount, 1, reason: census.describe());
    });

    testWidgets('Night, loading, still paints exactly the nav tab', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets, listPending: true);
      // Past the 600ms threshold, so the skeleton and its travelling rule are
      // both on screen. The rule is Oatmeal: a skeleton is loading, not live,
      // and an amber pulse on a placeholder tells a manager that a blank is
      // real-time data.
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(Skeleton), findsOneWidget);

      final census = await amberCensus(tester);
      expect(census.objectCount, 1, reason: census.describe());
    });

    for (final skin in <TiqSkin>[TiqSkin.day(), TiqSkin.veld()]) {
      testWidgets('${skin.mode.name} paints no amber at all', (tester) async {
        await _pump(
          tester,
          skin: skin,
          outlets: _outlets,
          alerts: <AlertItem>[_alert()],
        );

        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'alerts',
          phase: 'loaded',
        );
        expect(
          census.objectCount,
          0,
          reason:
              'On a light ground the ladder has one rung — the primary commit '
              'block — and a worklist has no primary. The nav tab is an '
              'Abyssal block.\n${census.describe()}',
        );
      });
    }

    testWidgets('Day, empty, paints no amber', (tester) async {
      await _pump(tester, skin: TiqSkin.day(), outlets: _outlets);
      final census = await amberCensus(tester);
      expect(census.objectCount, 0, reason: census.describe());
    });
  });

  group('2.0x text', () {
    testWidgets('the structure survives and nothing overflows', (tester) async {
      await _pump(
        tester,
        textScale: 2.0,
        outlets: _outlets,
        alerts: <AlertItem>[
          _alert(id: 'a1'),
          _alert(id: 'a2', severity: 'warning', outletId: 'o2'),
        ],
      );

      expect(tester.takeException(), isNull);
      await scrollWorklistTo(tester, find.byType(SectionRule));
      await scrollWorklistTo(tester, find.byType(SoftRow).first);
      expect(find.byType(SoftRow), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
