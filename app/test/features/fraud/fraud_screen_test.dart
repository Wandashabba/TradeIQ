import 'dart:async';

import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/fraud/data/fraud_repository.dart';
import 'package:tradeiq_app/features/fraud/data/fraud_view.dart';
import 'package:tradeiq_app/features/fraud/presentation/fraud_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/users/data/users_repository.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

import '../../core/design/amber_golden.dart';
import '../worklist_harness.dart';

FraudSignal _signal([
  String code = 'GPS_JUMP',
  String detail = 'Checked in 4,2 km from the pin',
]) => FraudSignal(code: code, detail: detail);

FlaggedVisit _visit({
  String visitId = 'v-1',
  String agentId = 'agent-1',
  String outletId = 'o1',
  double riskScore = 82,
  List<FraudSignal>? signals,
  FraudVerdict? verdict,
}) => FlaggedVisit(
  visitId: visitId,
  outletId: outletId,
  agentId: agentId,
  riskScore: riskScore,
  signals: signals ?? <FraudSignal>[_signal()],
  scoredAt: DateTime.utc(2026, 9, 18, 7),
  verdict: verdict,
);

FraudVerdict _verdict({
  FraudVerdictKind kind = FraudVerdictKind.cleared,
  String reviewer = 'Nomsa Dlamini-Mkhize',
  String? note,
  int? at = 82,
}) => FraudVerdict(
  visitId: 'v-1',
  kind: kind,
  reviewerLabel: reviewer,
  note: note,
  riskScoreAtReview: at,
  decidedAt: DateTime.utc(2026, 9, 19, 9),
);

final List<Outlet> _outlets = <Outlet>[
  outlet('o1', 'Kasi Corner Spaza'),
  outlet('o2', 'Shoprite Klipspruit Mall'),
];

final List<AppUser> _roster = <AppUser>[
  person('agent-1', 'thandi@acme.test', name: 'Thandi Mokoena'),
  person('agent-2', 'busi@acme.test', name: 'Busi Dlamini'),
];

class _FakeFraud implements FraudRepository {
  _FakeFraud({
    this.open = const <FlaggedVisit>[],
    this.decided = const <FlaggedVisit>[],
    this.unscored = 0,
    this.nextCursor,
    this.failure,
    this.pending = false,
    this.verdictFailure,
  });

  final List<FlaggedVisit> open;
  final List<FlaggedVisit> decided;
  final int unscored;
  final String? nextCursor;
  final Object? failure;
  final bool pending;

  /// Thrown by [recordVerdict] — a conflict, or a network failure.
  final Object? verdictFailure;

  final List<({String visitId, FraudVerdictKind kind, String? note})> recorded =
      <({String visitId, FraudVerdictKind kind, String? note})>[];

  @override
  Future<FlaggedPage> flagged({
    int? minScore,
    FlaggedReviewFilter reviewed = FlaggedReviewFilter.open,
  }) async {
    if (failure != null) throw failure!;
    if (pending) return Completer<FlaggedPage>().future;
    final data = switch (reviewed) {
      FlaggedReviewFilter.open => open,
      FlaggedReviewFilter.decided => decided,
      FlaggedReviewFilter.all => <FlaggedVisit>[...open, ...decided],
    };
    return FlaggedPage(data: data, nextCursor: nextCursor, unscored: unscored);
  }

  @override
  Future<FraudVerdict> recordVerdict({
    required String visitId,
    required FraudVerdictKind kind,
    String? note,
  }) async {
    recorded.add((visitId: visitId, kind: kind, note: note));
    if (verdictFailure != null) throw verdictFailure!;
    return FraudVerdict(
      visitId: visitId,
      kind: kind,
      reviewerLabel: 'You',
      note: note,
      riskScoreAtReview: 82,
      decidedAt: DateTime.utc(2026, 9, 20, 10),
    );
  }
}

Future<_FakeFraud> _pump(
  WidgetTester tester, {
  List<FlaggedVisit> open = const <FlaggedVisit>[],
  List<FlaggedVisit> decided = const <FlaggedVisit>[],
  int unscored = 0,
  String? nextCursor,
  Object? failure,
  Object? verdictFailure,
  bool pending = false,
  List<Outlet> outlets = const <Outlet>[],
  List<AppUser> users = const <AppUser>[],
  TiqSkin? skin,
  double textScale = 1.0,
  Size size = const Size(360, 720),
  Locale? locale,
}) async {
  final repo = _FakeFraud(
    open: open,
    decided: decided,
    unscored: unscored,
    nextCursor: nextCursor,
    failure: failure,
    pending: pending,
    verdictFailure: verdictFailure,
  );
  await pumpWorklist(
    tester,
    const FraudScreen(),
    skin: skin,
    size: size,
    textScale: textScale,
    locale: locale,
    users: users,
    path: '/fraud',
    settle: !pending,
    overrides: <Override>[
      fraudRepositoryProvider.overrideWithValue(repo),
      outletsRepositoryProvider.overrideWithValue(
        FakeOutletsRepository(outlets),
      ),
    ],
  );
  return repo;
}

/// Painted text, ignoring case.
///
/// The kit uppercases eyebrows and field labels for display while the ARB
/// holds sentence case, so a case-sensitive `textContaining` would pass on an
/// English eyebrow simply by failing to see it. Ignoring case makes the
/// absence assertions below stricter, not looser.
Finder paintedIgnoringCase(String text) {
  final needle = text.toUpperCase();
  return find.byWidgetPredicate(
    (Widget w) => w is Text && (w.data ?? '').toUpperCase().contains(needle),
    description: 'text containing "$text", ignoring case',
  );
}

void main() {
  group('the risk band', () {
    test('is declared once and banded where the backend bands', () {
      expect(FraudRiskBand.of(82), FraudRiskBand.high);
      expect(FraudRiskBand.of(70), FraudRiskBand.high);
      expect(FraudRiskBand.of(69.9), FraudRiskBand.elevated);
      expect(FraudRiskBand.of(50), FraudRiskBand.elevated);
      expect(FraudRiskBand.of(49), FraudRiskBand.low);
    });

    test('carries a word, and it is never only a colour', () {
      // In every locale the app ships, not only the template one: the word is
      // the channel that survives greyscale and a reader, and a band that
      // falls back to English has lost it for an Afrikaans manager.
      for (final locale in appSupportedLocales) {
        final l10n = lookupAppLocalizations(locale);
        final words = <String>{
          for (final band in FraudRiskBand.values) band.word(l10n),
        };
        for (final band in FraudRiskBand.values) {
          expect(band.word(l10n), isNotEmpty, reason: '\$band in \$locale');
        }
        // Three bands, three different words: two bands sharing one word is
        // colour becoming the only thing that tells them apart.
        expect(words, hasLength(FraudRiskBand.values.length));
      }
      // And the words differ BETWEEN locales, or the ARB is being ignored.
      expect(
        FraudRiskBand.high.word(lookupAppLocalizations(const Locale('af'))),
        isNot(FraudRiskBand.high.word(lookupAppLocalizations(
          const Locale('en'),
        ))),
      );
    });

    test('a score under the review threshold takes no severity bar', () {
      expect(FraudRiskBand.low.severity, isNull);
      expect(FraudRiskBand.elevated.severity, SoftRowSeverity.watch);
      expect(FraudRiskBand.high.severity, SoftRowSeverity.critical);
    });
  });

  group('a row names a person, not a database id (#399/#400)', () {
    testWidgets('the agent is the title and no UUID is on the row', (
      tester,
    ) async {
      await _pump(
        tester,
        open: <FlaggedVisit>[_visit()],
        outlets: _outlets,
        users: _roster,
      );

      // THE AGENT, NOT A UUID. Since the card override of 25 September 2026
      // a list row spends its own padding before the title starts, and in
      // `flutter_test`'s font — about twice Onest's advance — a
      // 14-character name middle-truncates on a 360dp row. That is the
      // ruling's own behaviour, and the FULL name is what a screen reader is
      // handed whatever the row painted; what may never happen is a database
      // id in a person's place.
      expect(find.bySemanticsLabel(RegExp('Thandi Mokoena')), findsOneWidget);
      expect(find.textContaining('Thandi'), findsOneWidget);
      expect(find.textContaining('v-1'), findsNothing);
      expect(find.byType(PersonRow), findsOneWidget);
    });

    testWidgets(
      'an unresolved agent says so in words and keeps the reference',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(
          tester,
          open: <FlaggedVisit>[_visit(agentId: 'nobody')],
          outlets: _outlets,
          users: _roster,
        );

        // The title says the absence in words and keeps the shop beside it —
        // never the shop's name alone, because the subject of the row is a
        // person. It is a long title on a 360dp row so it middle-truncates,
        // which is exactly why the whole of it goes to a screen reader.
        expect(
          find.bySemanticsLabel(RegExp('Unknown agent, Kasi Corner Spaza')),
          findsOneWidget,
        );
        // And the visit reference drops to the mono identifier line, the one
        // place a raw id is legitimate because it is then the only fact.
        expect(find.text('v-1'), findsOneWidget);
        handle.dispose();
      },
    );

    testWidgets('an unresolved outlet says so in words, never the id', (
      tester,
    ) async {
      await _pump(
        tester,
        open: <FlaggedVisit>[_visit(outletId: 'o-gone')],
        users: _roster,
      );

      expect(
        find.textContaining(englishLocalizations.fraudUnnamedOutlet),
        findsOneWidget,
      );
      expect(find.textContaining('o-gone'), findsNothing);
    });

    testWidgets(
      'the whole accusation reaches a screen reader as one sentence',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(
          tester,
          open: <FlaggedVisit>[_visit()],
          outlets: _outlets,
          users: _roster,
        );

        // Severity first, then who, then where, then the figure, then the
        // evidence. A row is one utterance and everything under it is excluded,
        // so anything not spelled here is silent.
        expect(
          find.bySemanticsLabel(
            RegExp(
              r'High risk.*Thandi Mokoena.*Kasi Corner Spaza.*Risk 82 of 100.*'
              r'GPS_JUMP',
            ),
          ),
          findsOneWidget,
        );
        handle.dispose();
      },
    );

    testWidgets('both verbs keep their own nodes and can be activated', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        open: <FlaggedVisit>[_visit()],
        outlets: _outlets,
        users: _roster,
      );

      // The defect this guards: a tertiary button inside a row's `meta`
      // paints, hit-tests and is announced nowhere.
      for (final label in <String>['Rule on this visit', 'See the visit']) {
        final node = tester.getSemantics(find.bySemanticsLabel(label));
        expect(
          node.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
          reason: '"$label" is announced and cannot be activated',
        );
      }
      handle.dispose();
    });
  });

  group('the evidence is printed, never implied by a colour', () {
    testWidgets('the rules that fired and what they found are both on screen', (
      tester,
    ) async {
      await _pump(
        tester,
        open: <FlaggedVisit>[
          _visit(
            signals: <FraudSignal>[
              _signal(),
              _signal('DWELL_SHORT', '40 s on site'),
            ],
          ),
        ],
        outlets: _outlets,
        users: _roster,
      );

      expect(find.text('GPS_JUMP, DWELL_SHORT'), findsOneWidget);
      expect(
        find.textContaining('Checked in 4,2 km from the pin · 40 s on site'),
        findsOneWidget,
      );
    });

    testWidgets('the flag is a fact plus a word and is never amber', (
      tester,
    ) async {
      await _pump(
        tester,
        open: <FlaggedVisit>[_visit()],
        outlets: _outlets,
        users: _roster,
      );

      final chip = tester.widget<FlagChip>(
        find.byKey(const ValueKey<String>('fraud-flag-v-1')),
      );
      expect(chip.label, 'High risk');
      expect(chip.detail, 'Not yet reviewed');
      // A visit nobody has looked at has not been cleared.
      expect(chip.cleared, isFalse);
    });
  });

  group('a ruled visit leaves the open queue (#392)', () {
    testWidgets('the queue asks for the OPEN list by default', (tester) async {
      await _pump(
        tester,
        open: <FlaggedVisit>[_visit()],
        decided: <FlaggedVisit>[
          _visit(visitId: 'v-2', agentId: 'agent-2', verdict: _verdict()),
        ],
        outlets: _outlets,
        users: _roster,
      );

      expect(find.textContaining('Thandi'), findsOneWidget);
      expect(find.textContaining('Busi'), findsNothing);
    });

    testWidgets('the decided list is one chip away, and nothing is hidden', (
      tester,
    ) async {
      await _pump(
        tester,
        open: <FlaggedVisit>[_visit()],
        decided: <FlaggedVisit>[
          _visit(visitId: 'v-2', agentId: 'agent-2', verdict: _verdict()),
        ],
        outlets: _outlets,
        users: _roster,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('fraud-filter-decided')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Busi'), findsOneWidget);
      expect(find.textContaining('Thandi'), findsNothing);
    });

    testWidgets('a decided row names who ruled and the score they saw', (
      tester,
    ) async {
      await _pump(
        tester,
        decided: <FlaggedVisit>[_visit(verdict: _verdict(at: 82))],
        outlets: _outlets,
        users: _roster,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('fraud-filter-decided')),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Nomsa Dlamini-Mkhize ruled it cleared.'),
        findsOneWidget,
      );
      // A rescore can move the stored score afterwards, so the number behind
      // the decision is recorded with it.
      expect(
        find.textContaining('They were looking at risk 82.'),
        findsOneWidget,
      );
    });

    testWidgets('a ruling made against no score says so rather than an 0', (
      tester,
    ) async {
      await _pump(
        tester,
        decided: <FlaggedVisit>[_visit(verdict: _verdict(at: null))],
        outlets: _outlets,
        users: _roster,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('fraud-filter-decided')),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('The visit was unscored at the time.'),
        findsOneWidget,
      );
    });
  });

  group('the verdict control', () {
    Future<_FakeFraud> openSheet(
      WidgetTester tester, {
      Object? verdictFailure,
    }) async {
      final repo = await _pump(
        tester,
        open: <FlaggedVisit>[_visit()],
        outlets: _outlets,
        users: _roster,
        verdictFailure: verdictFailure,
      );
      await tester.tap(find.byKey(const ValueKey<String>('fraud-rule-v-1')));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('opens with nothing chosen, which is a state and says so', (
      tester,
    ) async {
      await openSheet(tester);

      expect(find.byType(TorchSheet), findsOneWidget);
      expect(find.byType(VerdictControl<FraudVerdictKind>), findsOneWidget);
      expect(find.text('No ruling chosen yet'), findsOneWidget);
      // A control that pre-selected "cleared" would record a decision nobody
      // made every time somebody opened and closed the sheet.
      expect(find.textContaining('Choose a ruling first.'), findsOneWidget);
    });

    testWidgets('every ruling carries its consequence', (tester) async {
      await openSheet(tester);

      expect(
        find.textContaining('The visit stands and leaves the queue'),
        findsOneWidget,
      );
      expect(
        find.textContaining('This is the one ruling that accuses a person'),
        findsWidgets,
      );
    });

    testWidgets('needs-evidence cannot be recorded without a note', (
      tester,
    ) async {
      final repo = await openSheet(tester);

      await scrollSheetTo(tester, find.text('Needs evidence'));
      await tester.tap(find.text('Needs evidence'));
      await tester.pumpAndSettle();

      await scrollSheetTo(
        tester,
        find.byKey(const ValueKey<String>('verdict-commit')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('verdict-commit')));
      await tester.pumpAndSettle();

      // Nothing was sent, and the block says what is missing rather than
      // leaving a dead button.
      expect(repo.recorded, isEmpty);
      expect(find.textContaining('Say what evidence is missing'), findsWidgets);
    });

    testWidgets('a cleared ruling records without a note', (tester) async {
      final repo = await openSheet(tester);

      await scrollSheetTo(tester, find.text('Cleared'));
      await tester.tap(find.text('Cleared'));
      await tester.pumpAndSettle();

      await scrollSheetTo(
        tester,
        find.byKey(const ValueKey<String>('verdict-commit')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('verdict-commit')));
      await tester.pumpAndSettle();

      expect(repo.recorded, hasLength(1));
      expect(repo.recorded.single.kind, FraudVerdictKind.cleared);
      expect(repo.recorded.single.note, isNull);
      // The sheet becomes the ruling that stands rather than offering the
      // control again.
      expect(
        find.byKey(const ValueKey<String>('verdict-standing')),
        findsOneWidget,
      );
    });

    testWidgets('a needs-evidence ruling sends the note it demanded', (
      tester,
    ) async {
      final repo = await openSheet(tester);

      await scrollSheetTo(tester, find.text('Needs evidence'));
      await tester.tap(find.text('Needs evidence'));
      await tester.pumpAndSettle();

      await scrollSheetTo(
        tester,
        find.byKey(const ValueKey<String>('verdict-note')),
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('verdict-note')),
        '  Ask the store for the till roll.  ',
      );
      await tester.pumpAndSettle();

      await scrollSheetTo(
        tester,
        find.byKey(const ValueKey<String>('verdict-commit')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('verdict-commit')));
      await tester.pumpAndSettle();

      expect(repo.recorded.single.kind, FraudVerdictKind.needsEvidence);
      expect(repo.recorded.single.note, 'Ask the store for the till roll.');
    });

    testWidgets('a second reviewer is told whose decision applies', (
      tester,
    ) async {
      await openSheet(
        tester,
        verdictFailure: FraudVerdictConflict(
          _verdict(
            kind: FraudVerdictKind.confirmed,
            reviewer: 'Nomsa Dlamini-Mkhize',
            note: 'Two shops, one GPS fix.',
          ),
        ),
      );

      await scrollSheetTo(tester, find.text('Cleared'));
      await tester.tap(find.text('Cleared'));
      await tester.pumpAndSettle();
      await scrollSheetTo(
        tester,
        find.byKey(const ValueKey<String>('verdict-commit')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('verdict-commit')));
      await tester.pumpAndSettle();

      // Their ruling replaces the control rather than sitting above a button
      // that would lose again.
      expect(
        find.textContaining('Nomsa Dlamini-Mkhize ruled it confirmed.'),
        findsOneWidget,
      );
      expect(find.text('Two shops, one GPS fix.'), findsOneWidget);
      expect(find.byType(VerdictControl<FraudVerdictKind>), findsNothing);
    });

    testWidgets('a failure is sanitised and the control stays usable', (
      tester,
    ) async {
      final repo = await openSheet(
        tester,
        verdictFailure: StateError('SocketException: api.tradeiq.co.za'),
      );

      await scrollSheetTo(tester, find.text('Cleared'));
      await tester.tap(find.text('Cleared'));
      await tester.pumpAndSettle();
      await scrollSheetTo(
        tester,
        find.byKey(const ValueKey<String>('verdict-commit')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('verdict-commit')));
      await tester.pumpAndSettle();

      expect(repo.recorded, hasLength(1));
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      expect(find.byType(VerdictControl<FraudVerdictKind>), findsOneWidget);
    });
  });

  group('unscored visits are counted, never hidden (#236)', () {
    testWidgets('the note renders beside a loaded queue', (tester) async {
      await _pump(
        tester,
        open: <FlaggedVisit>[_visit()],
        unscored: 3,
        outlets: _outlets,
        users: _roster,
      );

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('fraud-footer')),
      );
      expect(
        find.textContaining('3 submitted visits have not been scored yet'),
        findsOneWidget,
      );
    });

    testWidgets('and beside an EMPTY one, where it matters most', (
      tester,
    ) async {
      await _pump(tester, unscored: 2, outlets: _outlets);

      // A queue with nothing in it and two visits nobody scored is not an
      // all-clear.
      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('fraud-footer')),
      );
      expect(
        find.textContaining('2 submitted visits have not been scored yet'),
        findsOneWidget,
      );
    });

    testWidgets('one unscored visit is said in the singular', (tester) async {
      await _pump(tester, unscored: 1, outlets: _outlets);

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('fraud-footer')),
      );
      expect(
        find.textContaining('1 submitted visit has not been scored yet'),
        findsOneWidget,
      );
    });

    testWidgets('no footer at all when nothing was cut and nothing unscored', (
      tester,
    ) async {
      await _pump(
        tester,
        open: <FlaggedVisit>[_visit()],
        outlets: _outlets,
        users: _roster,
      );
      expect(find.byType(PaginationFooter), findsNothing);
    });
  });

  group('the states', () {
    testWidgets('loading is a skeleton, not a spinner', (tester) async {
      await _pump(tester, pending: true);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(Skeleton), findsOneWidget);
    });

    testWidgets('an empty open queue says where ruled visits went', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets);

      expect(find.byKey(const ValueKey<String>('fraud-empty')), findsOneWidget);
      expect(
        find.textContaining('Ruled visits move to Decided'),
        findsOneWidget,
      );
    });

    testWidgets('an error is sanitised and carries one retry', (tester) async {
      await _pump(
        tester,
        failure: StateError('SocketException: api.tradeiq.co.za'),
      );

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      expect(find.byKey(const ValueKey<String>('fraud-retry')), findsOneWidget);
    });

    testWidgets('a queue that will not name an outlet still loads', (
      tester,
    ) async {
      // The outlet list is a base layer, never a blocker: a review queue that
      // will not load because a name will not resolve is a queue nobody
      // reviews.
      await _pump(tester, open: <FlaggedVisit>[_visit()], users: _roster);

      expect(find.textContaining('Thandi'), findsOneWidget);
    });
  });

  // ── Every button a reader announces, a reader can press ───────────────
  //
  // The kit once shipped a whole button family that announced itself and did
  // nothing when a screen reader activated it, and `SectionRuleAction` and
  // `PaginationFooter.action` were still shipping it when this group started.
  // This is that law on this screen, in every phase, so no local
  // `Semantics(button: true, ..., excludeSemantics: true)` around a bare
  // gesture detector can bring it back here.
  group('every button a screen reader announces can be activated', () {
    final phases = <String, Future<void> Function(WidgetTester)>{
      'loaded': (t) => _pump(
        t,
        open: <FlaggedVisit>[_visit()],
        unscored: 3,
        nextCursor: 'c2',
        outlets: _outlets,
        users: _roster,
      ),
      'empty': (t) => _pump(t, outlets: _outlets),
      'error': (t) =>
          _pump(t, failure: StateError('SocketException: api.tradeiq.co.za')),
      // Where the verdict control lives. Three rows and a commit, and the
      // commit is disabled until a ruling is chosen — which the guard allows
      // and an inert ENABLED button it does not.
      'the ruling sheet': (t) async {
        await _pump(
          t,
          open: <FlaggedVisit>[_visit()],
          outlets: _outlets,
          users: _roster,
        );
        await t.tap(find.byKey(const ValueKey<String>('fraud-rule-v-1')));
        await t.pumpAndSettle();
      },
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
    // A queue nominates nothing: no commit action is armed on a list, the
    // filter chips are lifted, the severity bars are severity and the flag
    // chips are neutral. Night paints the nav's active tab; Day and Veld
    // paint nothing.
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
          open: <FlaggedVisit>[
            _visit(),
            _visit(visitId: 'v-3', agentId: 'agent-2', riskScore: 58),
          ],
          unscored: 3,
          nextCursor: 'c2',
          outlets: _outlets,
          users: _roster,
        ),
        'empty': (t) => _pump(t, skin: skin, outlets: _outlets),
        'loading': (t) async {
          await _pump(t, skin: skin, pending: true);
          await t.pump(const Duration(milliseconds: 700));
        },
        'error': (t) => _pump(
          t,
          skin: skin,
          failure: StateError('SocketException: api.tradeiq.co.za'),
        ),
      };
      for (final phase in phases.entries) {
        testWidgets('${skin.mode.name}, ${phase.key}: $lit', (tester) async {
          await phase.value(tester);
          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'fraud',
            phase: phase.key,
          );
          expect(census.objectCount, lit, reason: census.describe());
        });
      }
    }

    testWidgets('Night, with the ruling sheet up, the queue goes dark', (
      tester,
    ) async {
      await _pump(
        tester,
        open: <FlaggedVisit>[_visit()],
        outlets: _outlets,
        users: _roster,
      );
      await tester.tap(find.byKey(const ValueKey<String>('fraud-rule-v-1')));
      await tester.pumpAndSettle();

      // Nothing is armed yet: the commit is blocked until a ruling is chosen,
      // so it paints its disabled form and the whole frame is dark. The nav
      // tab beneath is out too, which is what lets the scrim stay at 72% and
      // keep the row the sheet is about visible.
      final dark = await amberCensus(tester);
      expect(dark.objectCount, 0, reason: dark.describe());

      await scrollSheetTo(tester, find.text('Cleared'));
      await tester.tap(find.text('Cleared'));
      await tester.pumpAndSettle();

      // Now the commit is armed. The sheet is an untabbed route and it owns
      // exactly one lit object; the queue beneath is still out.
      final armed = await amberCensus(tester);
      expect(armed.objectCount, 1, reason: armed.describe());
    });
  });

  group('2.0x text and Afrikaans', () {
    testWidgets('nothing overflows at 2.0x', (tester) async {
      await _pump(
        tester,
        textScale: 2.0,
        open: <FlaggedVisit>[_visit()],
        outlets: _outlets,
        users: _roster,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('nothing overflows at 320dp in Afrikaans', (tester) async {
      await _pump(
        tester,
        size: const Size(320, 640),
        locale: const Locale('af'),
        open: <FlaggedVisit>[_visit()],
        outlets: _outlets,
        users: _roster,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the verdict rows stack, never side by side', (tester) async {
      await _pump(
        tester,
        open: <FlaggedVisit>[_visit()],
        outlets: _outlets,
        users: _roster,
      );
      await tester.tap(find.byKey(const ValueKey<String>('fraud-rule-v-1')));
      await tester.pumpAndSettle();

      // One of these options accuses a person of faking their work, a verdict
      // is INSERT-ONLY, and three 44dp targets side by side is a mis-tap
      // waiting to happen.
      final cleared = tester.getRect(find.text('Cleared'));
      final confirmed = tester.getRect(find.text('Confirmed'));
      expect(confirmed.top, greaterThan(cleared.bottom - 1));
    });

    testWidgets('Veld is built and the queue still names the person', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        skin: TiqSkin.veld(),
        open: <FlaggedVisit>[_visit()],
        outlets: _outlets,
        users: _roster,
      );

      expect(find.byType(PersonRow), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Thandi Mokoena')), findsOneWidget);
      expect(tester.takeException(), isNull);
      handle.dispose();
    });
  });

  // THE QUEUE AN AFRIKAANS MANAGER OPENS.
  //
  // The check's PROBE E pumped this route under Locale('af') and asserted
  // each of these English literals was on the screen — and passed. They are
  // the defect, so they are what the test names. The accusation this screen
  // records is the most consequential thing in the console; asking for it
  // entirely in a language the reader did not choose is the least defensible
  // place in the product to do it.
  group('an Afrikaans manager opens the fraud queue', () {
    const englishThatWasOnScreen = <String>[
      'Fraud review',
      'Open',
      'Decided',
      'All',
      'High risk',
      'Not yet reviewed',
      'Rule on this visit',
      'See the visit',
      'Field agent',
      'Risk is scored',
    ];

    testWidgets('not one of those English words is painted', (tester) async {
      await _pump(
        tester,
        open: <FlaggedVisit>[_visit()],
        outlets: _outlets,
        users: _roster,
        locale: const Locale('af'),
        size: const Size(360, 1200),
      );

      for (final word in englishThatWasOnScreen) {
        expect(paintedIgnoringCase(word), findsNothing, reason: word);
      }
    });

    testWidgets('and the Afrikaans is', (tester) async {
      final af = lookupAppLocalizations(const Locale('af'));
      await _pump(
        tester,
        open: <FlaggedVisit>[_visit()],
        outlets: _outlets,
        users: _roster,
        locale: const Locale('af'),
        size: const Size(360, 1200),
      );

      for (final word in <String>[
        af.fraudTitle,
        af.fraudFilterOpen,
        af.fraudFilterDecided,
        af.fraudFilterAll,
        af.fraudBandHigh,
        af.fraudNotYetReviewed,
        af.fraudRuleOnThisVisit,
        af.fraudSeeTheVisit,
        af.roleFieldAgent,
      ]) {
        expect(paintedIgnoringCase(word), findsWidgets, reason: word);
      }
    });

    testWidgets('the ruling sheet accuses in Afrikaans too', (tester) async {
      final af = lookupAppLocalizations(const Locale('af'));
      await _pump(
        tester,
        open: <FlaggedVisit>[_visit()],
        outlets: _outlets,
        users: _roster,
        locale: const Locale('af'),
        size: const Size(360, 1200),
      );
      await tester.tap(find.byKey(const ValueKey<String>('fraud-rule-v-1')));
      await tester.pumpAndSettle();

      // The consequence of the one ruling that accuses a person is the line
      // that must never be in a language the reader did not choose.
      expect(
        paintedIgnoringCase(af.fraudConsequenceConfirmed),
        findsOneWidget,
      );
      for (final word in <String>[
        af.fraudVerdictCleared,
        af.fraudVerdictConfirmed,
        af.fraudVerdictNeedsEvidence,
        af.fraudRecordThisRuling,
      ]) {
        expect(paintedIgnoringCase(word), findsWidgets, reason: word);
      }
      expect(
        paintedIgnoringCase('The work is recorded as faked'),
        findsNothing,
      );
      expect(paintedIgnoringCase('Record this ruling'), findsNothing);

      // The control's own group label is announced, never painted, so a
      // reader is the only person who ever hears it — which is exactly why
      // it cannot be the one thing left in English.
      final spoken = semanticsDump(tester);
      expect(spoken, contains(af.fraudYourRuling));
      expect(spoken, isNot(contains('Your ruling')));
    });
  });
}
