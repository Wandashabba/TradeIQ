import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/core/theme/torchlight/agent_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/features/audit/data/visit_progress.dart';
import 'package:tradeiq_app/features/audit/data/visit_review.dart';
import 'package:tradeiq_app/features/audit/presentation/submit_gate_screen.dart';

import '../../core/design/amber_golden.dart';
import '../agent_harness.dart';

/// THE SUBMIT GATE, on Torchlight.
///
/// The gate is the one moment the agent accuses a store of something, so what
/// is asserted here is what it *says* — the count, the findings, every
/// can't-confirm section by name, and the fact that submitting still works
/// with no signal — plus the amber census per phase × skin.

/// Four scored sections done — so the gate reads "4 of 7 sections complete".
const _progress = VisitProgress(
  states: <AuditSection, CaptureState>{
    AuditSection.stock: CaptureState.done,
    AuditSection.visibility: CaptureState.done,
    AuditSection.pricing: CaptureState.done,
    AuditSection.capability: CaptureState.done,
  },
  details: <AuditSection, String>{},
);

/// The same visit with the product list gone: a required section the app
/// could not establish (#389). The gate must name it.
const _progressCantConfirm = VisitProgress(
  states: <AuditSection, CaptureState>{
    AuditSection.stock: CaptureState.cantConfirm,
    AuditSection.visibility: CaptureState.done,
    AuditSection.pricing: CaptureState.done,
    AuditSection.capability: CaptureState.done,
  },
  details: <AuditSection, String>{},
  cantConfirm: <AuditSection, CantConfirmReason>{
    AuditSection.stock: CantConfirmReason.productListUnavailable,
  },
);

/// A visit that will raise two tasks: one urgent, one routine.
const _reviewWithTasks = VisitReview(
  skusCounted: 12,
  outOfStock: 1,
  skusPriced: 12,
  competitors: 2,
  photos: 1,
  willRaise: <RaisedTask>[
    RaisedTask(
      title: 'Fanta Orange 2L is out of stock',
      reason: 'You counted zero on shelf',
      priority: 'high',
    ),
    RaisedTask(
      title: 'Aisle blocked by delivery',
      reason: 'Risk you raised',
      priority: 'normal',
    ),
  ],
);

/// A clean store — nothing to raise.
const _reviewClean = VisitReview(
  skusCounted: 12,
  outOfStock: 0,
  skusPriced: 12,
  competitors: 0,
  photos: 0,
  willRaise: <RaisedTask>[],
);

/// A single pending capture, so the gate reads as offline.
final _offlineStatus = SyncStatus(
  pending: <SyncItem>[
    SyncItem(
      id: 1,
      entityType: 'stock',
      queuedAt: DateTime(2026),
      synced: false,
      attempts: 0,
    ),
  ],
  sent: const <SyncItem>[],
  needsAttention: const <SyncItem>[],
);

Future<void> _pump(
  WidgetTester tester, {
  VisitReview review = _reviewWithTasks,
  VisitProgress progress = _progress,
  bool offline = false,
  bool reviewThrows = false,
  bool reviewPends = false,
  bool progressThrows = false,
  bool progressPends = false,
  SkinMode skin = SkinMode.night,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
  VoidCallback? onConfirm,
}) async {
  final db = agentTestDb();
  await pumpAgentScreen(
    tester,
    SubmitGateScreen(
      visitDraftId: 'visit-1',
      outletId: 'o1',
      outletName: 'Kasi Corner Spaza',
      checkinTs: null,
      onConfirm: onConfirm ?? () {},
    ),
    path: '/audit/o1/submit',
    overrides: <Override>[
      ...agentBaseOverrides(
        db: db,
        skin: skin,
        sync: offline ? _offlineStatus : SyncStatus.empty,
      ),
      // Drift's `watch()` reschedules a zero-duration timer on every tick, so
      // every derived stream on this route is stubbed with `Stream.value`.
      // `sync_status_test` and `visit_review_test` cover the real queries.
      if (reviewThrows)
        visitReviewProvider.overrideWith(
          (ref, arg) => Stream<VisitReview>.error(StateError('no read')),
        )
      else if (reviewPends)
        visitReviewProvider.overrideWith(
          (ref, arg) => const Stream<VisitReview>.empty(),
        )
      else
        visitReviewProvider.overrideWith(
          (ref, arg) => Stream<VisitReview>.value(review),
        ),
      if (progressThrows)
        visitProgressProvider.overrideWith(
          (ref, arg) => Stream<VisitProgress>.error(StateError('no read')),
        )
      else if (progressPends)
        visitProgressProvider.overrideWith(
          (ref, arg) => const Stream<VisitProgress>.empty(),
        )
      else
        visitProgressProvider.overrideWith(
          (ref, arg) => Stream<VisitProgress>.value(progress),
        ),
    ],
    textScale: textScale,
    locale: locale,
    // The skeleton's own appear/slow timers are `Timer`s, not animations, so
    // a pending phase settles; the loading test pumps by hand instead.
    settle: !reviewPends && !progressPends,
  );
}

bool _primaryArmed(WidgetTester tester) =>
    tester
        .widget<TorchPrimaryButton>(
          find.byKey(const ValueKey<String>('confirm-submit')),
        )
        .onPressed !=
    null;

void main() {
  group('what the gate says', () {
    testWidgets('the captured block carries the count and the captured line', (
      tester,
    ) async {
      await _pump(tester);

      final block = find.byKey(const ValueKey<String>('submit-captured'));
      expect(block, findsOneWidget);
      expect(
        find.descendant(
          of: block,
          matching: find.text('4 of 7 sections complete'),
        ),
        findsOneWidget,
      );
      // Verbatim from the review — nothing on this screen is added by the app.
      expect(
        find.descendant(
          of: block,
          matching: find.text('12 SKUs counted · 2 competitors · 1 photo'),
        ),
        findsOneWidget,
      );
      // A done block is the tick disc, never a bare block of text.
      expect(
        find.descendant(of: block, matching: find.byType(SectionStateGlyph)),
        findsOneWidget,
      );
    });

    testWidgets('the intro says nothing was added by the app', (tester) async {
      await _pump(tester);
      expect(
        find.text(
          'Check this before it goes to your manager — you cannot change it '
          'after.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('each raised task pairs its severity with the priority WORD', (
      tester,
    ) async {
      await _pump(tester);
      await scrollAgentTo(tester, find.text('Aisle blocked by delivery'));

      // Urgency is never colour-alone. The severity is the bar AND the
      // silhouette AND the word — three channels, all of which survive
      // greyscale, deuteranopia and a sun-washed panel.
      expect(find.text('Task for the manager · high'), findsOneWidget);
      expect(find.text('Task for the manager · normal'), findsOneWidget);

      final urgent = tester.widget<SoftRow>(
        find.ancestor(
          of: find.text('Fanta Orange 2L is out of stock'),
          matching: find.byType(SoftRow),
        ),
      );
      expect(urgent.severity, SoftRowSeverity.critical);
      final routine = tester.widget<SoftRow>(
        find.ancestor(
          of: find.text('Aisle blocked by delivery'),
          matching: find.byType(SoftRow),
        ),
      );
      expect(routine.severity, SoftRowSeverity.watch);
    });

    testWidgets('a reader hears the severity before the finding', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      await scrollAgentTo(tester, find.text('Fanta Orange 2L is out of stock'));

      expect(
        find.bySemanticsLabel(
          'Urgent. Fanta Orange 2L is out of stock. Task for the manager · '
          'high',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('the section rule counts what will be raised', (tester) async {
      await _pump(tester);
      expect(find.textContaining('This will raise'.toUpperCase()), findsOneWidget);
            // MOVED 25 September 2026 — the owner made The Floor's grammar global.
      // The section marker is words on the ground, uppercase and
      // letter-spaced, with no line across the screen. The string itself is
      // still sentence case; the shout is presentation, so a screen reader
      // is handed the sentence. See `section_rule.dart` and unify §1.17.
      // The count is in the marker's words now — `THIS WILL RAISE · 2` —
      // rather than a mono figure beside them. It is the same information
      // and this still fails if the gate miscounts.
      expect(
        find.textContaining('THIS WILL RAISE · 2'),
        findsOneWidget,
      );
    });
  });

  group(
    'a section the app could not establish is something to raise (#389)',
    () {
      testWidgets('it gets its own row, named, with the reason in words', (
        tester,
      ) async {
        await _pump(tester, progress: _progressCantConfirm);
        await scrollAgentTo(
          tester,
          find.byKey(
            const ValueKey<String>('cant-confirm-Stock & availability'),
            skipOffstage: false,
          ),
        );

        // The old gate listed nothing here, so a store that refused four counts
        // produced a gate printing "this store is in good shape" — the cleanest
        // fraud path in the app.
        expect(
          find.text('Stock & availability could not be confirmed'),
          findsOneWidget,
        );
        expect(
          find.textContaining('The product list did not load'),
          findsOneWidget,
        );
        expect(
          find.text('The manager is told · not confirmed'),
          findsOneWidget,
        );
      });

      testWidgets('the captured block names how many were not confirmed', (
        tester,
      ) async {
        await _pump(tester, progress: _progressCantConfirm);
        expect(
          find.text('1 section could not be confirmed — the manager is told'),
          findsOneWidget,
        );
      });

      testWidgets('a store that refused everything is never "clean"', (
        tester,
      ) async {
        await _pump(
          tester,
          review: _reviewClean,
          progress: _progressCantConfirm,
        );
        expect(
          find.byKey(
            const ValueKey<String>('submit-clean'),
            skipOffstage: false,
          ),
          findsNothing,
        );
        await scrollAgentTo(
          tester,
          find.text(
            'Stock & availability could not be confirmed',
            skipOffstage: false,
          ),
        );
        expect(
          find.text('Stock & availability could not be confirmed'),
          findsOneWidget,
        );
      });
    },
  );

  // Unknown is not zero. The gate used to read an unloaded or unreadable
  // progress as "0 of 0 sections complete" and a visit with nothing
  // can't-confirm in it — so a clean review printed "this store is in good
  // shape" over a section nobody could confirm, and the manager was never told.
  group('sections that have not been read are unknown, not zero', () {
    testWidgets('an unreadable progress never prints "0 of 0" or a clean '
        'verdict', (tester) async {
      await _pump(tester, review: _reviewClean, progressThrows: true);

      expect(find.text('0 of 0 sections complete'), findsNothing);
      expect(find.textContaining('0 of '), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('submit-clean')),
        findsNothing,
        reason:
            'a store is not in good shape because the app could not read '
            'its sections',
      );
      expect(find.textContaining('this store is in good shape'), findsNothing);

      // The count is a sentence in words, not a figure.
      final block = find.byKey(const ValueKey<String>('submit-captured'));
      expect(
        find.descendant(
          of: block,
          matching: find.text('Could not read which sections are done'),
        ),
        findsOneWidget,
      );
      // A tick would claim the sections are done.
      expect(
        find.descendant(of: block, matching: find.byType(SectionStateGlyph)),
        findsNothing,
      );
    });

    testWidgets('an unreadable progress is a row in the list, in words, and '
        'the primary stays armed', (tester) async {
      await _pump(tester, review: _reviewClean, progressThrows: true);

      await scrollAgentTo(
        tester,
        find.byKey(const ValueKey<String>('submit-sections-unread')),
      );
      expect(find.text('Your sections could not be read'), findsOneWidget);
      await scrollAgentTo(
        tester,
        find.byKey(const ValueKey<String>('submit-sections-unread-note')),
      );
      expect(
        find.textContaining('may be missing from this list'),
        findsWidgets,
      );
      // Failing to read the sections is not failing to submit.
      expect(_primaryArmed(tester), isTrue);
    });

    testWidgets('an unreadable progress keeps the tasks the review did raise', (
      tester,
    ) async {
      await _pump(tester, progressThrows: true);

      await scrollAgentTo(tester, find.text('Fanta Orange 2L is out of stock'));
      expect(find.text('Fanta Orange 2L is out of stock'), findsOneWidget);
      await scrollAgentTo(
        tester,
        find.byKey(const ValueKey<String>('submit-sections-unread')),
      );
      expect(
        find.byKey(const ValueKey<String>('submit-sections-unread')),
        findsOneWidget,
      );
    });

    testWidgets('a progress still loading is the skeleton, never "0 of 0" '
        'and never clean', (tester) async {
      await _pump(tester, review: _reviewClean, progressPends: true);
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.textContaining('0 of '), findsNothing);
      expect(find.byKey(const ValueKey<String>('submit-clean')), findsNothing);
      expect(find.byType(SkeletonRows), findsOneWidget);
      expect(_primaryArmed(tester), isTrue);
    });

    testWidgets('a reader hears that the sections could not be read', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, review: _reviewClean, progressThrows: true);
      expect(
        find.bySemanticsLabel(
          RegExp(r'^Could not read which sections are done\. '),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp(r'0 of 0')), findsNothing);
      handle.dispose();
    });
  });

  group('the states', () {
    testWidgets('a clean store is a result, not an empty screen', (
      tester,
    ) async {
      await _pump(tester, review: _reviewClean);
      final block = find.byKey(const ValueKey<String>('submit-clean'));
      expect(block, findsOneWidget);
      expect(
        find.descendant(of: block, matching: find.text('Nothing to raise')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: block,
          matching: find.textContaining('this store is in good shape'),
        ),
        findsOneWidget,
      );
      // The mark, not the hue alone.
      expect(
        find.descendant(of: block, matching: find.byType(SeverityMark)),
        findsOneWidget,
      );
    });

    testWidgets('offline keeps the "submitting still works" promise, and the '
        'primary', (tester) async {
      await _pump(tester, offline: true);

      expect(
        find.text(
          'No signal? Submitting still works — it saves on the phone and '
          'sends itself.',
        ),
        findsOneWidget,
      );
      // Held work is never an error: an Oatmeal square, never a crimson
      // triangle, and never a disabled primary.
      final note = find.byKey(const ValueKey<String>('submit-offline-note'));
      expect(
        find.descendant(of: note, matching: find.byType(RowMarkTile)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: note, matching: find.byType(SeverityMark)),
        findsNothing,
      );
      expect(
        tester
            .widget<TorchPrimaryButton>(
              find.byKey(const ValueKey<String>('confirm-submit')),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('a review that cannot be read still submits, and says so', (
      tester,
    ) async {
      await _pump(tester, reviewThrows: true);

      // Failing to READ what the visit will raise is not failing to submit:
      // the captures are already on the phone, and a gate that took the
      // primary away here would strand an agent with a finished visit.
      expect(
        find.byKey(const ValueKey<String>('gate-review-error')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TorchPrimaryButton>(
              find.byKey(const ValueKey<String>('confirm-submit')),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('loading is the real geometry, not a spinner', (tester) async {
      await _pump(tester, reviewPends: true);
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(SkeletonRows), findsOneWidget);
    });
  });

  group('the gate only confirms', () {
    testWidgets('tapping the primary fires the hub\'s callback', (
      tester,
    ) async {
      var confirmed = 0;
      await _pump(tester, onConfirm: () => confirmed++);

      await tester.tap(find.byKey(const ValueKey<String>('confirm-submit')));
      await tester.pump();

      // The gate does not submit — it confirms. The hub's callback is what
      // runs `submitVisit`, and it is the second deliberate step, so there is
      // no third dialog.
      expect(confirmed, 1);
    });

    testWidgets('the primary announces the whole sentence', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      // Nobody is ever asked to confirm the word "Submit".
      expect(
        find.bySemanticsLabel('Submit this visit to your manager'),
        findsWidgets,
      );
      handle.dispose();
    });
  });

  group('the amber census', () {
    for (final (mode, expected) in <(SkinMode, int)>[
      (SkinMode.night, 1),
      (SkinMode.day, 1),
      (SkinMode.veld, 1),
    ]) {
      testWidgets('${mode.name}: one object — the primary', (tester) async {
        await _pump(tester, skin: mode);
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          agentSkinFor(mode),
          route: 'submit-gate',
          phase: 'will-raise',
        );
        expect(
          census.objectCount,
          expected,
          reason:
              'An untabbed route has two content grants in Night and this '
              'screen spends one. The severity bars, the task glyphs, the '
              'section rule and the offline note are labels.\n\n'
              '${census.describe()}',
        );
      });
    }

    testWidgets('a clean store still lights exactly the primary', (
      tester,
    ) async {
      await _pump(tester, review: _reviewClean);
      final census = await amberCensus(tester);
      expectWithinAmberBudget(
        census,
        agentSkinFor(SkinMode.night),
        route: 'submit-gate',
        phase: 'clean',
      );
      expect(census.objectCount, 1, reason: census.describe());
    });

    testWidgets('an unreadable review does not change the count', (
      tester,
    ) async {
      await _pump(tester, reviewThrows: true);
      final census = await amberCensus(tester);
      expectWithinAmberBudget(
        census,
        agentSkinFor(SkinMode.night),
        route: 'submit-gate',
        phase: 'review-failed',
      );
      expect(census.objectCount, 1, reason: census.describe());
    });

    testWidgets('at 2.0× the count does not change', (tester) async {
      await _pump(tester, textScale: 2.0);
      final census = await amberCensus(tester);
      expect(census.objectCount, 1, reason: census.describe());
    });

    for (final mode in agentSkinModes) {
      testWidgets('${mode.name}: unreadable sections light exactly the '
          'primary', (tester) async {
        await _pump(
          tester,
          review: _reviewClean,
          progressThrows: true,
          skin: mode,
        );
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          agentSkinFor(mode),
          route: 'submit-gate',
          phase: 'sections-unread',
        );
        expect(
          census.objectCount,
          1,
          reason:
              'The unread row and its square are labels.\n\n'
              '${census.describe()}',
        );
      });
    }
  });

  group('2.0× and Afrikaans', () {
    testWidgets('Afrikaans at 2.0× still lays out', (tester) async {
      await _pump(tester, textScale: 2.0, locale: const Locale('af'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Afrikaans at 2.0× lays out with the sections unread', (
      tester,
    ) async {
      await _pump(
        tester,
        textScale: 2.0,
        locale: const Locale('af'),
        progressThrows: true,
      );
      expect(tester.takeException(), isNull);
      final unread = find.text('Kon nie lees watter afdelings klaar is nie');
      await scrollAgentTo(tester, unread);
      expect(unread, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the findings are translated, not the agent\'s own words', (
      tester,
    ) async {
      await _pump(
        tester,
        locale: const Locale('af'),
        review: VisitReview(
          skusCounted: 12,
          outOfStock: 1,
          skusPriced: 12,
          competitors: 2,
          photos: 1,
          willRaise: <RaisedTask>[
            RaisedTask.stockout(skuName: 'Fanta Orange 2L'),
            RaisedTask.actionPlan(priority: 'normal'),
          ],
        ),
      );
      // The captured line is above the fold, so it is read before the list is
      // scrolled out from under it.
      expect(
        find.text('12 SKU’s getel · 2 mededingers · 1 foto'),
        findsOneWidget,
      );
      await scrollAgentTo(tester, find.text('Fanta Orange 2L is uit voorraad'));

      // The SKU's name is never translated; the sentence around it is.
      expect(find.text('Fanta Orange 2L is uit voorraad'), findsOneWidget);
      expect(find.text('Fanta Orange 2L is out of stock'), findsNothing);
    });
  });
}
