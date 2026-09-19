import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/theme/torchlight/agent_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/check_in_radar.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/features/audit/data/visits_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/audit_shell_screen.dart';

import '../../core/design/amber_golden.dart';
import '../agent_harness.dart';
import 'visit_harness.dart';

void main() {
  group('the visit hub', () {
    testWidgets('the audit is a named ladder after a successful check-in', (
      tester,
    ) async {
      await pumpVisit(tester, visits: ScriptedVisits.succeeds());

      expect(find.text('Kasi Corner Spaza'), findsWidgets);

      // The hint is ABOVE the ladder, not meta at the bottom: the agent needs
      // it before they start choosing, not after they have finished — so it
      // is on the first screen and the ladder is the thing you scroll to.
      final hint = find.textContaining('Any order.');
      expect(hint, findsOneWidget);
      expect(
        tester
            .getRect(
              find.byKey(
                const ValueKey<String>('section-stock'),
                skipOffstage: false,
              ),
            )
            .top,
        greaterThan(tester.getRect(hint).bottom),
        reason: 'the hint must sit above the first rung, not under the last',
      );

      // The ladder itself: named rungs, each exactly once. On a 360×640 phone
      // the header, the readiness block and the hint fill the first screen, so
      // the rungs are one flick down — which is the geometry a real agent has,
      // and the reason this scrolls rather than pumping a 2000dp viewport.
      await scrollAgentTo(tester, find.text('Stock & availability'));
      expect(find.text('Stock & availability'), findsOneWidget);
      expect(find.text('Pricing & promotions'), findsOneWidget);
    });

    testWidgets('no tabs — one primary in the thumb zone', (tester) async {
      await pumpVisit(tester, visits: ScriptedVisits.succeeds());
      // The owner's decision: mid-visit navigation loses captured work.
      expect(find.byType(TorchNavPill), findsNothing);
      expect(find.byType(TorchNavCircle), findsNothing);
      expect(find.byType(TorchThumbZone), findsOneWidget);
      // And the skin cycle is at the leading end of it — never a screen
      // without the skin cycle.
      expect(find.byType(TorchSkinCycle), findsOneWidget);
    });

    testWidgets('the readiness block says the fraction and the words', (
      tester,
    ) async {
      await pumpVisit(
        tester,
        visits: ScriptedVisits.succeeds(),
        progress: readyToSubmit,
      );
      final block = find.byKey(const ValueKey<String>('visit-progress'));
      expect(block, findsOneWidget);
      expect(
        find.descendant(of: block, matching: find.text('/7')),
        findsOneWidget,
      );
      expect(find.text('Ready to submit'), findsOneWidget);
    });

    testWidgets('the score row is a result, not a form', (tester) async {
      await pumpVisit(tester, visits: ScriptedVisits.succeeds());
      final row = find.byKey(const ValueKey<String>('section-score'));
      await scrollAgentTo(tester, row);

      final soft = tester.widget<SoftRow>(row);
      // Not tappable, no chevron — and NOT at reduced opacity, because
      // opacity is banned as a state channel and a dimmed row reads as a
      // disabled one.
      expect(soft.onTap, isNull);
      expect(soft.trailing, isNot(isA<SoftRowChevron>()));
      expect(find.byType(Opacity), findsNothing);
      expect(
        find.descendant(of: row, matching: find.byType(RowMarkTile)),
        findsOneWidget,
      );
    });
  });

  group('a blocked submit names what blocks it', () {
    testWidgets('by name, and the button is disabled', (tester) async {
      await pumpVisit(tester, visits: ScriptedVisits.succeeds());

      final button = tester.widget<TorchPrimaryButton>(
        find.byKey(const ValueKey<String>('submit-visit')),
      );
      expect(button.onPressed, isNull);
      expect(button.blockedReason, isNotNull);
      // Every blocker, by name. A dead end in a shop is a phone call to the
      // office.
      for (final name in <String>[
        'Stock & availability',
        'Visibility & display',
        'Pricing & promotions',
        'Team capability',
      ]) {
        expect(
          button.blockedReason!.contains(name),
          isTrue,
          reason:
              'the BarNote must name $name — it got:\n'
              '${button.blockedReason}',
        );
      }
    });

    testWidgets('the blocking reason is rendered, wrapping, above the button', (
      tester,
    ) async {
      await pumpVisit(tester, visits: ScriptedVisits.succeeds());
      expect(find.byType(TorchBarNote), findsOneWidget);
    });

    testWidgets('a ready visit arms the submit', (tester) async {
      await pumpVisit(
        tester,
        visits: ScriptedVisits.succeeds(),
        progress: readyToSubmit,
      );
      final button = tester.widget<TorchPrimaryButton>(
        find.byKey(const ValueKey<String>('submit-visit')),
      );
      expect(button.onPressed, isNotNull);
      expect(button.blockedReason, isNull);
    });

    testWidgets('submit opens the gate first — it does not submit on one tap', (
      tester,
    ) async {
      final visits = ScriptedVisits.succeeds();
      await pumpVisit(tester, visits: visits, progress: readyToSubmit);

      await tester.tap(find.byKey(const ValueKey<String>('submit-visit')));
      await tester.pumpAndSettle();

      expect(visits.submittedId, isNull);
      expect(find.text('Outcome'), findsNothing);
    });

    testWidgets('a read failure keeps the chrome and refuses to send', (
      tester,
    ) async {
      await pumpVisit(
        tester,
        visits: ScriptedVisits.succeeds(),
        progress: null,
        progressThrows: true,
      );
      expect(find.text('This visit could not be read.'), findsOneWidget);
      final button = tester.widget<TorchPrimaryButton>(
        find.byType(TorchPrimaryButton),
      );
      expect(button.onPressed, isNull);
      expect(button.blockedReason, isNotNull);
    });
  });

  group("can't confirm is reachable (#389)", () {
    testWidgets('a product list that will not load makes the per-SKU sections '
        "can't-confirm, not done", (tester) async {
      // The real derivation, from a real failing repository.
      await pumpVisitLive(
        tester,
        visits: ScriptedVisits.succeeds(),
        skus: FakeSkus(fail: true),
      );

      final row = find.byKey(const ValueKey<String>('section-stock'));
      await dragAgentUp(tester);
      final glyph = tester.widget<SectionStateGlyph>(
        find.descendant(of: row, matching: find.byType(SectionStateGlyph)),
      );
      expect(glyph.state, SectionState.cantConfirm);
      expect(
        find.textContaining('The product list did not load'),
        findsWidgets,
      );
      await disposeAgentScreen(tester);
    });

    testWidgets('and the submit is blocked, with the reason named', (
      tester,
    ) async {
      await pumpVisitLive(
        tester,
        visits: ScriptedVisits.succeeds(),
        skus: FakeSkus(fail: true),
      );
      final button = tester.widget<TorchPrimaryButton>(
        find.byKey(const ValueKey<String>('submit-visit')),
      );
      expect(
        button.onPressed,
        isNull,
        reason:
            'Before #389 a stock section with no product list reported DONE '
            'on zero captures, and a visit with nothing in it went through '
            'the gate printing "This store is clean".',
      );
      expect(button.blockedReason!.contains('Stock & availability'), isTrue);
      await disposeAgentScreen(tester);
    });

    testWidgets('a template pin that fails leaves a row, not a silence', (
      tester,
    ) async {
      await pumpVisitLive(
        tester,
        visits: ScriptedVisits.succeeds(),
        templates: NoTemplate(throwsOnPin: true),
      );

      final row = find.byKey(const ValueKey<String>('section-clientQuestions'));
      await dragAgentUp(tester, by: 400);
      expect(row, findsOneWidget);
      expect(
        find.textContaining('The client’s questions did not load'),
        findsWidgets,
      );
      await disposeAgentScreen(tester);
    });

    testWidgets('the readiness line counts it separately', (tester) async {
      await pumpVisit(
        tester,
        visits: ScriptedVisits.succeeds(),
        progress: cantConfirmStock,
      );
      // Two facts, not one figure: a section nobody could measure is not a
      // section somebody skipped.
      expect(find.text('1 section can’t be confirmed'), findsOneWidget);
    });
  });

  group('check-in — locating', () {
    testWidgets('a radar and a real escape, and no primary at all', (
      tester,
    ) async {
      // The check-in never answers, so the screen stays on the radar — the
      // real thing being a GPS fix in a fridge aisle under a tin roof.
      await pumpVisit(tester, visits: ScriptedVisits.pending(), settle: false);
      await tester.pump();
      expect(find.byType(CheckInRadar), findsOneWidget);
      expect(find.text('Finding you…'), findsOneWidget);
      expect(find.byType(TorchPrimaryButton), findsNothing);
      expect(find.text('Back to route'), findsOneWidget);
    });
  });

  group('check-in — too far', () {
    testWidgets('shows the measured distance as the hero', (tester) async {
      await pumpVisit(tester, visits: ScriptedVisits.tooFar(180));

      expect(
        find.byKey(const ValueKey<String>('checkin-distance')),
        findsOneWidget,
      );
      expect(find.textContaining('180'), findsWidgets);
      expect(find.text('You’re too far away'), findsOneWidget);
    });

    testWidgets('the distance is a FigureSlot, not a formatted string', (
      tester,
    ) async {
      await pumpVisit(tester, visits: ScriptedVisits.tooFar(180));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('checkin-distance')),
          matching: find.byType(FigureSlot),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the first attempt is a fact, not a threat', (tester) async {
      await pumpVisit(tester, visits: ScriptedVisits.tooFar(180));
      // The hero is the measured distance; the note about what retrying costs
      // sits under it and is past the fold on a 360×640 phone. The claim here
      // is WHICH sentence the screen renders, so both finders read the whole
      // built frame — and the negative one has to, or it passes on any screen
      // that simply scrolled the sentence out of sight.
      expect(
        find.text(
          'Every attempt is recorded with where you were.',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      // The penalty sentence does NOT appear here: the penalty has not
      // started, and the app must not threaten before it charges.
      expect(
        find.textContaining('fraud signal', skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets('the third attempt is where the honest warning arrives', (
      tester,
    ) async {
      final visits = ScriptedVisits.tooFar(180);
      await pumpVisit(tester, visits: visits);

      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const ValueKey<String>('checkin-retry')));
        await tester.pumpAndSettle();
      }
      expect(
        find.textContaining('fraud signal', skipOffstage: false),
        findsOneWidget,
      );
      // Retry must reset the started flag or the post-frame call never fires
      // again — which is how a retry button that did nothing shipped once.
      expect(visits.calls, 3);
    });

    testWidgets('under 80 m it says walk to the door', (tester) async {
      await pumpVisit(tester, visits: ScriptedVisits.tooFar(60));
      expect(
        find.text('You’re close. Try walking to the front door.'),
        findsOneWidget,
      );
    });

    testWidgets('over 2 km it says the pin may be wrong', (tester) async {
      await pumpVisit(tester, visits: ScriptedVisits.tooFar(4200));
      expect(
        find.text(
          'This looks like the wrong store, or the store’s pin is wrong.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('"The pin is wrong" records locally and says exactly that', (
      tester,
    ) async {
      await pumpVisit(tester, visits: ScriptedVisits.tooFar(180));

      final action = find.byKey(const ValueKey<String>('pin-is-wrong'));
      await scrollAgentTo(tester, action);
      await tester.tap(action);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('pin-reported')),
        findsOneWidget,
      );
      // Never "thanks, we'll look into it": there is no endpoint, and the
      // copy must not pretend a server heard it.
      expect(
        find.textContaining('It has not been sent anywhere yet'),
        findsOneWidget,
      );
      expect(action, findsNothing);
    });
  });

  group('check-in — no GPS', () {
    testWidgets('names the cause and the fix as separate paragraphs', (
      tester,
    ) async {
      await pumpVisit(
        tester,
        visits: ScriptedVisits.noGps(CheckInLocationProblem.servicesDisabled),
      );
      expect(find.text('Can’t find your location'), findsOneWidget);
      expect(
        find.text('Turn location on in your phone’s settings, then try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('Nothing is lost'), findsOneWidget);
    });

    testWidgets('permission denied gets its own fix', (tester) async {
      await pumpVisit(
        tester,
        visits: ScriptedVisits.noGps(CheckInLocationProblem.permissionDenied),
      );
      expect(
        find.textContaining('You can allow it just while using the app.'),
        findsOneWidget,
      );
    });

    testWidgets('a timeout names airplane mode explicitly', (tester) async {
      await pumpVisit(
        tester,
        visits: ScriptedVisits.noGps(CheckInLocationProblem.timedOut),
      );
      expect(find.textContaining('airplane mode'), findsOneWidget);
    });

    testWidgets('retry actually runs the check-in again', (tester) async {
      final visits = ScriptedVisits.noGps();
      await pumpVisit(tester, visits: visits);
      await tester.tap(find.byKey(const ValueKey<String>('checkin-retry')));
      await tester.pumpAndSettle();
      expect(visits.calls, 2);
    });
  });

  group('check-in — something else', () {
    testWidgets('a thrown check-in ends on a failure screen, not the radar', (
      tester,
    ) async {
      await pumpVisit(tester, visits: ScriptedVisits.throwing());

      expect(find.byType(CheckInRadar), findsNothing);
      expect(find.text('Could not start the visit'), findsOneWidget);
      expect(find.textContaining('Nothing is lost'), findsOneWidget);
    });

    testWidgets('the error code is there to be read down a phone', (
      tester,
    ) async {
      await pumpVisit(tester, visits: ScriptedVisits.throwing());
      final block = find.byKey(const ValueKey<String>('checkin-error-code'));
      expect(block, findsOneWidget);
      expect(
        find.descendant(of: block, matching: find.text('Copy')),
        findsOneWidget,
      );
      expect(find.textContaining('checkin/'), findsOneWidget);
    });
  });

  group('the amber census', () {
    testWidgets('a BLOCKED hub emits nothing at all', (tester) async {
      await pumpVisit(tester, visits: ScriptedVisits.succeeds());
      final census = await amberCensus(tester);
      expect(
        census.objectCount,
        0,
        reason:
            'A disabled submit does not declare a claim, so it cannot be '
            'lit. The hub is a reading screen and is deliberately under '
            'budget.\n\n${census.describe()}',
      );
    });

    for (final skin in agentSkinModes) {
      testWidgets('an ARMED hub is exactly one — ${skin.name}', (tester) async {
        await pumpVisit(
          tester,
          visits: ScriptedVisits.succeeds(),
          progress: readyToSubmit,
          skin: skin,
        );
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          agentSkinFor(skin),
          route: 'visit hub',
          phase: 'ready',
        );
        expect(census.objectCount, 1, reason: census.describe());
      });

      testWidgets('too far is exactly one — ${skin.name}', (tester) async {
        await pumpVisit(tester, visits: ScriptedVisits.tooFar(180), skin: skin);
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          agentSkinFor(skin),
          route: 'check-in / too far',
          phase: 'too-far',
        );
        expect(census.objectCount, 1, reason: census.describe());
      });

      // The other three check-in phases each declare exactly one claim — the
      // radar's live pulse, then the retry — and a phase that declares one and
      // is never counted is a phase the law is not enforced on.
      testWidgets('locating at rest emits nothing — ${skin.name}', (
        tester,
      ) async {
        // The check-in never answers, so the screen stays on the radar. Its
        // pulse is presence, never progress, and it is the agent surface's
        // only `livePulse` claimant.
        await pumpVisit(
          tester,
          visits: ScriptedVisits.pending(),
          skin: skin,
          settle: false,
        );
        await tester.pump();
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          agentSkinFor(skin),
          route: 'check-in / locating',
          phase: 'locating',
        );
        // ZERO, in all three — and that is the design, not a gap. This
        // harness pins `disableAnimations`, which is also the frame a
        // reduce-motion reader meets, and reduce-motion removes the rings
        // entirely: a static pin and the headline carry the whole message.
        // The rings ARE the object, so with them gone there is nothing lit.
        //
        // Night's moving leading ring is therefore the one amber on the agent
        // surface a pixel census cannot see. Its claim is asserted instead,
        // below — and a census that pumped mid-animation would be asserting a
        // frame that depends on which millisecond it sampled.
        expect(census.objectCount, 0, reason: census.describe());
      });

      testWidgets('no GPS is exactly one — ${skin.name}', (tester) async {
        await pumpVisit(tester, visits: ScriptedVisits.noGps(), skin: skin);
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          agentSkinFor(skin),
          route: 'check-in / no GPS',
          phase: 'no-gps',
        );
        expect(census.objectCount, 1, reason: census.describe());
      });

      testWidgets('a failed check-in is exactly one — ${skin.name}', (
        tester,
      ) async {
        await pumpVisit(tester, visits: ScriptedVisits.throwing(), skin: skin);
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          agentSkinFor(skin),
          route: 'check-in / something else',
          phase: 'check-in-failed',
        );
        expect(census.objectCount, 1, reason: census.describe());
      });
    }

    testWidgets('an untabbed route still spends at most its two', (
      tester,
    ) async {
      await pumpVisit(
        tester,
        visits: ScriptedVisits.succeeds(),
        progress: readyToSubmit,
        textScale: 2.0,
      );
      final census = await amberCensus(tester);
      expectWithinAmberBudget(
        census,
        agentSkinFor(SkinMode.night),
        route: 'visit hub',
        phase: 'ready @2.0x',
      );
    });
  });

  group('2.0× text', () {
    testWidgets('the ladder survives and nothing overflows', (tester) async {
      await pumpVisit(
        tester,
        visits: ScriptedVisits.succeeds(),
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);
      await scrollAgentTo(
        tester,
        find.byKey(const ValueKey<String>('section-score')),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Afrikaans at 2.0× lays out on the too-far screen', (
      tester,
    ) async {
      await pumpVisit(
        tester,
        visits: ScriptedVisits.tooFar(180),
        textScale: 2.0,
        locale: const Locale('af'),
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('te ver', findRichText: true), findsWidgets);
    });
  });

  group('the claims are declared, not painted', () {
    testWidgets('a blocked hub declares nothing', (tester) async {
      await pumpVisit(tester, visits: ScriptedVisits.succeeds());
      final scope = TorchScope.maybeOf(tester.element(find.byType(TorchShell)));
      expect(scope!.allocation.isLit(AuditShellScreen.submitClaimId), isFalse);
    });

    testWidgets('an armed hub declares exactly the submit', (tester) async {
      await pumpVisit(
        tester,
        visits: ScriptedVisits.succeeds(),
        progress: readyToSubmit,
      );
      final scope = TorchScope.maybeOf(tester.element(find.byType(TorchShell)));
      expect(scope!.allocation.isLit(AuditShellScreen.submitClaimId), isTrue);
    });

    testWidgets('locating declares the live pulse, and gets it', (
      tester,
    ) async {
      // The one amber on this surface a pixel census cannot see: the ring is
      // painted only while it moves, and this harness renders resting frames.
      // The allocator is where it can still be held to account.
      await pumpVisit(tester, visits: ScriptedVisits.pending(), settle: false);
      await tester.pump();
      final scope = TorchScope.maybeOf(tester.element(find.byType(TorchShell)));
      expect(scope!.allocation.isLit(AuditShellScreen.locatingClaimId), isTrue);
      // And nothing else asks: there is no primary while waiting, and the
      // zone does not pretend there is.
      expect(scope.allocation.isLit(AuditShellScreen.retryClaimId), isFalse);
    });
  });
}
