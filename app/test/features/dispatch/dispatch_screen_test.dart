import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/dispatch/data/dispatch_repository.dart';
import 'package:tradeiq_app/features/dispatch/presentation/dispatch_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import '../../core/design/amber_golden.dart';
import '../../core/widgets/torchlight/torch_harness.dart' show torchSkins;
import '../territory_harness.dart';

final List<Outlet> _outlets = <Outlet>[
  outlet('o1', 'Kasi Corner Spaza'),
  outlet('o2', 'Shoprite Klipspruit Mall'),
];

const DispatchResult _ranked = DispatchResult(
  recommended: DispatchCandidate(
    agentId: 'a1',
    email: 'near@example.com',
    distanceM: 120,
    inTerritory: true,
    displayName: 'Sipho Ndlovu',
  ),
  candidates: <DispatchCandidate>[
    DispatchCandidate(
      agentId: 'a1',
      email: 'near@example.com',
      distanceM: 120,
      inTerritory: true,
      displayName: 'Sipho Ndlovu',
    ),
    // No `distanceM`: an agent the server cannot place.
    DispatchCandidate(
      agentId: 'a2',
      email: 'far@example.com',
      inTerritory: false,
    ),
  ],
);

/// Nobody the server was willing to recommend. The list is still ranked and
/// the order is the whole statement — no row invents a crown.
const DispatchResult _unrecommended = DispatchResult(
  candidates: <DispatchCandidate>[
    DispatchCandidate(
      agentId: 'a1',
      email: 'near@example.com',
      distanceM: 120,
      inTerritory: true,
      displayName: 'Sipho Ndlovu',
    ),
  ],
);

Future<FakeDispatchRepository> _pump(
  WidgetTester tester, {
  DispatchResult? result,
  List<Outlet> outlets = const <Outlet>[],
  Object? outletsFailure,
  Object? dispatchFailure,
  bool dispatchPending = false,
  TiqSkin? skin,
  double textScale = 1.0,
  Locale? locale,
  Size size = const Size(360, 900),
}) async {
  final repository = FakeDispatchRepository(
    result: result,
    failure: dispatchFailure,
    pending: dispatchPending,
  );
  await pumpConsole(
    tester,
    const DispatchScreen(),
    skin: skin,
    size: size,
    textScale: textScale,
    locale: locale,
    settle: !dispatchPending,
    overrides: <Override>[
      dispatchRepositoryProvider.overrideWithValue(repository),
      outletsRepositoryProvider.overrideWithValue(
        FakeOutletsRepository(outlets: outlets, failure: outletsFailure),
      ),
    ],
  );
  return repository;
}

Future<void> _pickCornerShop(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('outlet-select')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey<String>('dispatch-outlet-o1')));
  await tester.pumpAndSettle();
}

void main() {
  group('the outlet picker', () {
    testWidgets('asks for a destination before it ranks anybody', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets);

      expect(find.text('Choose an outlet'), findsWidgets);
      expect(find.text('Pick an outlet to rank agents'), findsOneWidget);
      expect(find.byType(PersonRow), findsNothing);
    });

    testWidgets('picking one names it and asks the server for that id', (
      tester,
    ) async {
      final repository = await _pump(
        tester,
        outlets: _outlets,
        result: _ranked,
      );
      await _pickCornerShop(tester);

      expect(find.text('Kasi Corner Spaza'), findsOneWidget);
      expect(repository.asked, <String>['o1']);
    });

    testWidgets('an empty outlet list is a designed state', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(const ValueKey<String>('outlet-select')));
      await tester.pumpAndSettle();

      expect(find.text('No outlets yet'), findsOneWidget);
    });

    testWidgets('a failed outlet list offers a retry inside the sheet', (
      tester,
    ) async {
      await _pump(tester, outletsFailure: Exception('boom'));
      await tester.tap(find.byKey(const ValueKey<String>('outlet-select')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('outlets-retry')),
        findsOneWidget,
      );
    });
  });

  group('a row names a person', () {
    testWidgets('by name, keyed by email, with the role and the territory', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets, result: _ranked);
      await _pickCornerShop(tester);

      expect(find.byType(PersonRow), findsNWidgets(2));
      expect(find.text('Sipho Ndlovu'), findsOneWidget);
      // The name replaces the address, and the key does not move with it.
      expect(find.text('near@example.com'), findsNothing);
      final named = find.byKey(
        const ValueKey<String>('candidate-near@example.com'),
      );
      expect(named, findsOneWidget);
      expect(
        find.descendant(of: named, matching: find.text('Sipho Ndlovu')),
        findsOneWidget,
      );
      // An unnamed candidate falls back to the address people mail — still
      // not a database id. It is asserted on the widget rather than by text,
      // because a long title middle-truncates and the painted string is not
      // the whole one; the row's own label keeps the full value.
      final rows = tester.widgetList<PersonRow>(find.byType(PersonRow));
      expect(rows.map((r) => r.name), <String>[
        'Sipho Ndlovu',
        'far@example.com',
      ]);
      expect(find.text('a1'), findsNothing);
      expect(
        find.text('Field agent · In territory · 120 m away'),
        findsOneWidget,
      );
      expect(
        find.text('Field agent · Outside territory · No last-known location'),
        findsOneWidget,
      );
    });
  });

  group('unknown is not zero', () {
    testWidgets('an agent the server cannot place gets an em dash', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets, result: _ranked);
      await _pickCornerShop(tester);

      final unplaced = find.byKey(
        const ValueKey<String>('candidate-far@example.com'),
      );
      expect(
        find.descendant(
          of: unplaced,
          matching: find.text(
            'Field agent · Outside territory · No last-known location',
          ),
        ),
        findsOneWidget,
      );
      // Never a zero, which would read as standing on the doorstep.
      expect(
        find.descendant(of: unplaced, matching: find.text('0')),
        findsNothing,
      );
      expect(
        find.descendant(of: unplaced, matching: find.text('0 m away')),
        findsNothing,
      );
      // A screen reader gets the sentence, because the row's own label
      // carries it — a plain `trailing` is inside the excluded node, so a
      // figure dropped there would be painted and announced to nobody.
      expect(
        find.bySemanticsLabel(
          'far@example.com, Field agent, Outside territory · '
          'No last-known location',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a placed agent gets a distance, in the spoken line', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets, result: _ranked);
      await _pickCornerShop(tester);

      expect(
        find.text('Field agent · In territory · 120 m away'),
        findsOneWidget,
      );
    });
  });

  group('a rank is never invented', () {
    testWidgets("the server's own pick carries the word, and it is spoken", (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets, result: _ranked);
      await _pickCornerShop(tester);

      expect(find.text('Recommended'), findsOneWidget);
      // `trailingWord` is the one trailing a row announces. A Text dropped in
      // the trailing WIDGET slot would be painted and spoken to nobody.
      expect(
        find.bySemanticsLabel(
          'Sipho Ndlovu, Field agent, In territory · 120 m away, Recommended',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a result with no recommendation marks nobody', (tester) async {
      await _pump(tester, outlets: _outlets, result: _unrecommended);
      await _pickCornerShop(tester);

      expect(find.byType(PersonRow), findsOneWidget);
      expect(find.text('Recommended'), findsNothing);
    });
  });

  group('the phases', () {
    testWidgets('no candidates is a designed state with the reason', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets);
      await _pickCornerShop(tester);

      expect(find.text('No agent can be ranked'), findsOneWidget);
      expect(
        find.textContaining('agents assigned to a territory'),
        findsOneWidget,
      );
    });

    testWidgets('a failed ranking offers one retry', (tester) async {
      await _pump(
        tester,
        outlets: _outlets,
        dispatchFailure: Exception('boom'),
      );
      await _pickCornerShop(tester);

      expect(find.byType(ErrorState), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('candidates-retry')),
        findsOneWidget,
      );
    });

    testWidgets('a ranking in flight is a skeleton, not an empty list', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets, dispatchPending: true);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('outlet-select')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(
        find.byKey(const ValueKey<String>('dispatch-outlet-o1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('No agent can be ranked'), findsNothing);
      expect(find.byType(SkeletonRows), findsWidgets);
    });
  });

  group('the amber census, per phase × skin', () {
    for (final skin in torchSkins) {
      for (final phase in const <String>['no-outlet', 'ranking', 'error']) {
        testWidgets('${skin.mode.name} · $phase', (tester) async {
          await _pump(
            tester,
            skin: skin,
            outlets: _outlets,
            result: _ranked,
            dispatchFailure: phase == 'error' ? Exception('boom') : null,
          );
          if (phase != 'no-outlet') await _pickCornerShop(tester);

          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'dispatch',
            phase: phase,
          );
          // Dispatch READS a ranking. Assigning the visit is another screen's
          // commit, so the content declines its grant on every phase.
          expect(
            census.objectCount,
            skin.mode == SkinMode.night ? 1 : 0,
            reason: census.describe(),
          );
        });
      }
    }
  });

  group('2.0× text and Afrikaans', () {
    testWidgets('nothing overflows at 2.0× on a 320dp phone', (tester) async {
      await _pump(
        tester,
        outlets: _outlets,
        result: _ranked,
        textScale: 2.0,
        size: const Size(320, 1200),
      );
      await _pickCornerShop(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Afrikaans, including the absence', (tester) async {
      await _pump(
        tester,
        outlets: _outlets,
        result: _ranked,
        locale: const Locale('af'),
      );
      await _pickCornerShop(tester);

      expect(find.text('Versending'), findsWidgets);
      expect(find.text('Aanbeveel'), findsOneWidget);
      expect(find.text('Veldagent · Binne gebied · 120 m weg'), findsOneWidget);
      expect(find.text('Recommended'), findsNothing);
      expect(find.text('Dispatch'), findsNothing);
    });
  });
}
