import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/agent_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/audit/data/scorecards_repository.dart';
import 'package:tradeiq_app/features/audit/data/seen_score.dart';
import 'package:tradeiq_app/features/audit/presentation/visit_outcome_screen.dart';

import '../../core/design/amber_golden.dart';
import '../agent_harness.dart';

/// HOW THE VISIT WENT, on Torchlight.
///
/// The three things this screen is answerable for: the number the manager
/// will see, the refusal to guess one when it has not been scored yet, and
/// the promise that an unmeasured dimension is never printed as a zero.

const _visit = ServerScorecard(
  visitId: 'remote-1',
  weightedTotal: 72,
  ratingBand: 'amber',
  dimensionScores: <String, double>{
    'availability': 83,
    'visibility': 80,
    'display': 80,
    'pricing': 61,
    'competitive': 29,
    // salesCapability is ABSENT — no staff on shift to assess. It must never
    // render as a zero.
  },
);

const _previous = ServerScorecard(
  visitId: 'remote-0',
  weightedTotal: 66,
  ratingBand: 'amber',
  dimensionScores: <String, double>{},
);

ServerScorecard _onBand(String band, {double total = 72}) => ServerScorecard(
  visitId: 'remote-b',
  weightedTotal: total,
  ratingBand: band,
  dimensionScores: const <String, double>{'availability': 83},
);

/// A seen-score store with a scripted memory, so the reconciliation line can
/// be driven without a keychain.
class _FakeSeenScores implements SeenScoreStore {
  _FakeSeenScores([this.stored = const <String, int>{}]);

  Map<String, int> stored;
  int writes = 0;

  @override
  Future<Map<String, int>> read() async => stored;

  @override
  Future<void> write(Map<String, int> scores) async {
    stored = scores;
    writes++;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  VisitOutcome? outcome = const VisitOutcome(score: _visit, previous: null),
  bool throws = false,
  bool pends = false,
  SkinMode skin = SkinMode.night,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
  SeenScoreStore? seen,
}) async {
  final db = agentTestDb();
  await pumpAgentScreen(
    tester,
    const VisitOutcomeScreen(
      visitDraftId: 'v1',
      outletId: 'o1',
      outletName: 'Sunrise Spaza',
    ),
    path: '/audit/o1/done',
    overrides: <Override>[
      ...agentBaseOverrides(db: db, skin: skin),
      if (throws)
        visitOutcomeProvider.overrideWith(
          (ref, arg) async => throw StateError('no read'),
        )
      else if (pends)
        visitOutcomeProvider.overrideWith(
          (ref, arg) => Completer<VisitOutcome>().future,
        )
      else
        visitOutcomeProvider.overrideWith((ref, arg) async => outcome!),
      if (seen != null) seenScoreStoreProvider.overrideWithValue(seen),
    ],
    textScale: textScale,
    locale: locale,
    extraRoutes: <GoRoute>[
      GoRoute(path: '/today', builder: (c, s) => const Text('Today')),
      GoRoute(path: '/my-work', builder: (c, s) => const Text('My work')),
    ],
  );
}

void main() {
  group('the score', () {
    testWidgets('shows the number the manager will see, with the band in '
        'words', (tester) async {
      await _pump(tester);

      expect(find.text('72'), findsOneWidget);
      expect(find.text('/100'), findsOneWidget);
      // Watch and Gap share a hue on purpose — severity abandons amber's hue
      // entirely — so the mark and the WORD are what tell them apart.
      expect(find.text('Watch'), findsOneWidget);
      expect(find.byType(SeverityMark), findsWidgets);
    });

    for (final (wire, word, kind) in <(String, String, SeverityMarkKind)>[
      ('green', 'Healthy', SeverityMarkKind.onTarget),
      ('amber', 'Watch', SeverityMarkKind.watch),
      ('red', 'Gap', SeverityMarkKind.critical),
    ]) {
      testWidgets('band $word is a word beside its own silhouette', (
        tester,
      ) async {
        await _pump(
          tester,
          outcome: VisitOutcome(score: _onBand(wire), previous: null),
        );

        // The bands are Healthy · Watch · Gap (#408). The wire still says
        // green/amber/red and is never shown: a system whose brand colour is
        // Burning Flame cannot have a severity called Amber.
        expect(find.text(word), findsOneWidget);
        expect(find.text(wire), findsNothing);
        final mark = tester.widget<SeverityMark>(
          find.byType(SeverityMark).first,
        );
        expect(mark.kind, kind);
      });
    }

    testWidgets('the figure is ink-1 even on a Gap — a severity-coded number '
        'is a hue doing a number\'s job', (tester) async {
      await _pump(
        tester,
        outcome: VisitOutcome(score: _onBand('red', total: 31), previous: null),
      );
      final skin = agentSkinFor(SkinMode.night);
      final hero = tester.widget<FigureSlot>(
        find.byKey(const ValueKey<String>('score-hero')),
      );
      expect(hero.color, skin.palette.ink1);
    });
  });

  group('unknown is never zero (#93)', () {
    testWidgets('an unmeasured dimension is an em dash, a hatch and a reason', (
      tester,
    ) async {
      await _pump(tester);
      await scrollAgentTo(
        tester,
        find.byKey(
          const ValueKey<String>('unmeasured-Team capability'),
          skipOffstage: false,
        ),
      );

      // A zero would read as "you scored nothing on this" for something the
      // agent was never given a chance to do.
      expect(find.text('Team capability'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('0'), findsNothing);
      expect(
        find.textContaining('No staff on shift'),
        findsOneWidget,
        reason: 'a hatch with no sentence is a puzzle',
      );
      final hatched = tester.widget<Meter>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('unmeasured-Team capability')),
          matching: find.byType(Meter),
        ),
      );
      expect(hatched.state, MeterState.notMeasured);
    });

    testWidgets('a reader hears "not measured" and the reason', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      await scrollAgentTo(
        tester,
        find.byKey(
          const ValueKey<String>('unmeasured-Team capability'),
          skipOffstage: false,
        ),
      );
      expect(
        find.bySemanticsLabel(
          RegExp(r'Team capability, not measured\. No staff on shift'),
        ),
        findsWidgets,
      );
      handle.dispose();
    });

    testWidgets('a measured dimension carries the published 80-point target', (
      tester,
    ) async {
      await _pump(tester);
      final meter = tester.widget<Meter>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('dimension-Availability')),
          matching: find.byType(Meter),
        ),
      );
      expect(meter.value, 83);
      // Never an invented target: `target: null` would render no tick, and a
      // tick at 100 or at the midpoint is a number somebody gets measured on.
      expect(meter.target, 80);
    });
  });

  group('the delta', () {
    testWidgets('compares against their own last visit here', (tester) async {
      await _pump(
        tester,
        outcome: const VisitOutcome(score: _visit, previous: _previous),
      );
      expect(
        find.byKey(const ValueKey<String>('outcome-delta')),
        findsOneWidget,
      );
      expect(
        find.textContaining('from your last visit here (66)'),
        findsOneWidget,
      );
      expect(find.text('+6'), findsOneWidget);
    });

    testWidgets('no previous visit is a sentence, never a delta beside '
        'nothing', (tester) async {
      await _pump(tester);
      expect(find.text('First scored visit here.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('outcome-delta')),
        findsNothing,
        reason: 'a delta never stands beside nothing',
      );
    });

    // A delta never stands beside nothing, and a sentence never stands beside
    // something false. A history request that dropped leaves the previous
    // visit UNKNOWN; the screen used to print "First scored visit here." over
    // it, at a store the agent had scored before.
    testWidgets('a history that could not be read is never "first scored '
        'visit here"', (tester) async {
      await _pump(
        tester,
        outcome: const VisitOutcome(
          score: _visit,
          previous: null,
          previousUnknown: true,
        ),
      );

      expect(
        find.text('First scored visit here.'),
        findsNothing,
        reason: 'unknown is not absent — that sentence is a false claim about '
            'their own record',
      );
      expect(
        find.byKey(const ValueKey<String>('outcome-delta')),
        findsNothing,
        reason: 'a delta never stands beside nothing',
      );
      expect(
        find.text(
          'Your last visit here could not be loaded, so there is nothing to '
          'compare this score with.',
        ),
        findsOneWidget,
      );
      // The score itself still stands.
      expect(find.text('72'), findsOneWidget);
    });

    testWidgets('a history that loaded and held nothing is still the first '
        'visit sentence', (tester) async {
      await _pump(tester);
      expect(find.text('First scored visit here.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('outcome-previous-unknown')),
        findsNothing,
      );
    });

    testWidgets('a flat move says so in words', (tester) async {
      await _pump(
        tester,
        outcome: const VisitOutcome(score: _previous, previous: _previous),
      );
      expect(
        find.textContaining('Same as your last visit here (66)'),
        findsOneWidget,
      );
    });

    // The hero and the baseline are each rounded on their own, so the delta
    // beside them must be their difference and not the rounded difference of
    // the raw totals — or the three numbers on the one screen that has to be
    // believed do not add up.
    ServerScorecard total(double t) => ServerScorecard(
      visitId: 'remote-$t',
      weightedTotal: t,
      ratingBand: 'amber',
      dimensionScores: const <String, double>{},
    );

    testWidgets('71.4 after 64.6 reads 71, +6 and 65 — the raw 6.8 does not '
        'round the delta to +7', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        outcome: VisitOutcome(score: total(71.4), previous: total(64.6)),
      );
      expect(find.text('71'), findsOneWidget, reason: 'the hero');
      expect(find.textContaining('from your last visit here (65)'),
          findsOneWidget);
      expect(find.text('+6'), findsOneWidget, reason: '71 − 65 = 6');
      expect(find.text('+7'), findsNothing,
          reason: 'a delta that does not add up to the figures beside it');
      expect(
        find.bySemanticsLabel(
          RegExp(r'Up 6 points from your last visit here \(65\)\.'),
        ),
        findsWidgets,
      );
      handle.dispose();
    });

    testWidgets('71.4 after 71.6 reads 71 and down 1 from 72 — never "same '
        'as" beside two different numbers', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        outcome: VisitOutcome(score: total(71.4), previous: total(71.6)),
      );
      expect(find.text('71'), findsOneWidget, reason: 'the hero');
      expect(find.textContaining('Same as your last visit here'), findsNothing,
          reason: '71 is not the same as 72');
      expect(find.textContaining('from your last visit here (72)'),
          findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp(r'Down 1 point from your last visit here \(72\)\.'),
        ),
        findsWidgets,
      );
      handle.dispose();
    });

    testWidgets('71.4 after 70.6 reads 71 and "same as (71)" — a raw 0.8 that '
        'rounds to +1 is not a move the screen can show', (tester) async {
      await _pump(
        tester,
        outcome: VisitOutcome(score: total(71.4), previous: total(70.6)),
      );
      expect(find.text('71'), findsOneWidget, reason: 'the hero');
      expect(find.textContaining('Same as your last visit here (71)'),
          findsOneWidget);
      expect(find.text('+1'), findsNothing,
          reason: '71 beside 71 is not up a point');
    });
  });

  group('held on the phone', () {
    testWidgets('no score at all, rather than a guess', (tester) async {
      await _pump(
        tester,
        outcome: const VisitOutcome(score: null, previous: null),
      );

      // The app CAN compute a scorecard offline; showing it would mean showing
      // a number that quietly changes once the visit reaches the server.
      expect(find.text('/100'), findsNothing);
      expect(find.byKey(const ValueKey<String>('score-hero')), findsNothing);
      expect(find.text('Your visit is safe on this phone'), findsOneWidget);
      // The refusal is STATED, not left as an absence.
      expect(
        find.text(
          'Your real score — the one your manager sees — appears once this '
          'reaches the server.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('held is Oatmeal plus a square plus a word — never crimson', (
      tester,
    ) async {
      await _pump(
        tester,
        outcome: const VisitOutcome(score: null, previous: null),
      );
      final held = find.byKey(const ValueKey<String>('outcome-held'));
      expect(
        find.descendant(of: held, matching: find.byType(RowMarkTile)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: held, matching: find.byType(SeverityMark)),
        findsNothing,
        reason:
            'working offline is the normal state of South African field work',
      );
      final banner = tester.widget<OfflineHeldBanner>(
        find.byKey(const ValueKey<String>('outcome-held-banner')),
      );
      expect(banner.state, SyncState.held);
    });

    testWidgets('a server that cannot be READ is still the held receipt', (
      tester,
    ) async {
      await _pump(tester, throws: true);
      // Failing to read a score is not failing to submit.
      expect(
        find.byKey(const ValueKey<String>('outcome-held')),
        findsOneWidget,
      );
      expect(find.textContaining('Could not reach the server'), findsOneWidget);
      expect(find.text('/100'), findsNothing);
    });
  });

  group('the reconciliation line (#377/#390/#398)', () {
    testWidgets('a score that changed after the agent saw it says so', (
      tester,
    ) async {
      await _pump(tester, seen: _FakeSeenScores(<String, int>{'v1': 84}));

      final line = find.byKey(const ValueKey<String>('outcome-reconciled'));
      expect(line, findsOneWidget);
      expect(
        find.descendant(of: line, matching: find.text('Now scored')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: line, matching: find.text('84')),
        findsOneWidget,
      );
    });

    testWidgets('a score that did not change renders no line at all', (
      tester,
    ) async {
      await _pump(tester, seen: _FakeSeenScores(<String, int>{'v1': 72}));
      // Not "matches what you saw", which is noise.
      expect(
        find.byKey(const ValueKey<String>('outcome-reconciled')),
        findsNothing,
      );
    });

    testWidgets('a first open has nothing to reconcile, and records what it '
        'showed', (tester) async {
      final store = _FakeSeenScores();
      await _pump(tester, seen: store);

      expect(
        find.byKey(const ValueKey<String>('outcome-reconciled')),
        findsNothing,
      );
      // What is on the screen now is what a later change is measured against.
      expect(store.stored['v1'], 72);
    });

    testWidgets('the first number seen is the referent, not the latest', (
      tester,
    ) async {
      final store = _FakeSeenScores(<String, int>{'v1': 84});
      await _pump(tester, seen: store);
      // Overwriting it would make the line say "now 72 — it was 72" on the
      // next open, and then never appear again.
      expect(store.stored['v1'], 84);
    });

    testWidgets('a reader hears what it was', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, seen: _FakeSeenScores(<String, int>{'v1': 84}));
      expect(
        // The line's own node is merged into the scroll view's, so the
        // assertion is that the sentence is IN what a reader hears, not that
        // it is the whole of it.
        find.bySemanticsLabel(
          RegExp(r'Now scored 72\. It was 84 when you saw it\.'),
        ),
        findsWidgets,
      );
      handle.dispose();
    });
  });

  group('the way off the screen', () {
    testWidgets('both ways go forward — a submitted visit cannot be walked '
        'back into', (tester) async {
      await _pump(tester);
      expect(find.byKey(const ValueKey<String>('next-store')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('next-store')));
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('loading is the real geometry, not a spinner', (tester) async {
      await _pump(tester, pends: true);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(Skeleton), findsOneWidget);
      // The primary is still there: an agent can always walk to the next store.
      expect(find.byKey(const ValueKey<String>('next-store')), findsOneWidget);
    });
  });

  group('the amber census', () {
    for (final mode in agentSkinModes) {
      testWidgets('${mode.name}: one object — "Next store"', (tester) async {
        await _pump(tester, skin: mode);
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          agentSkinFor(mode),
          route: 'visit-outcome',
          phase: 'scored',
        );
        expect(
          census.objectCount,
          1,
          reason:
              'The meter\'s target tick is ink-1 everywhere — unify §1.1 '
              'deleted TorchClaim.meterTick, because six amber ticks is a '
              'repeated fill wearing a different hat.\n\n${census.describe()}',
        );
      });

      testWidgets('${mode.name}: held on the phone lights the same one', (
        tester,
      ) async {
        await _pump(
          tester,
          outcome: const VisitOutcome(score: null, previous: null),
          skin: mode,
        );
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          agentSkinFor(mode),
          route: 'visit-outcome',
          phase: 'held',
        );
        expect(census.objectCount, 1, reason: census.describe());
      });
    }

    testWidgets('the reconciliation line is never amber', (tester) async {
      await _pump(tester, seen: _FakeSeenScores(<String, int>{'v1': 84}));
      final census = await amberCensus(tester);
      expect(
        census.objectCount,
        1,
        reason:
            'A reconciliation is information, and information is never '
            'amber.\n\n${census.describe()}',
      );
    });

    testWidgets('at 2.0× the count does not change', (tester) async {
      await _pump(tester, textScale: 2.0);
      final census = await amberCensus(tester);
      expect(census.objectCount, 1, reason: census.describe());
    });

    testWidgets('an unknown history does not change the count', (tester) async {
      await _pump(
        tester,
        outcome: const VisitOutcome(
          score: _visit,
          previous: null,
          previousUnknown: true,
        ),
      );
      final census = await amberCensus(tester);
      expect(census.objectCount, 1, reason: census.describe());
    });
  });

  group('2.0× and Afrikaans', () {
    testWidgets('Afrikaans at 2.0× still lays out', (tester) async {
      await _pump(tester, textScale: 2.0, locale: const Locale('af'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the band is translated', (tester) async {
      await _pump(tester, locale: const Locale('af'));
      expect(find.text('Watch'), findsNothing);
      expect(find.text('Dophou'), findsOneWidget);
    });
  });
}
