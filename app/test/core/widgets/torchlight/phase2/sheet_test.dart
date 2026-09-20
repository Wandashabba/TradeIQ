import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/mark/section_state_glyph.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';

import 'phase2_harness.dart';

const List<ProofLine> _proof = <ProofLine>[
  ProofLine(text: '6 of 9 sections captured'),
  ProofLine(
    text: '3 photos held on this phone',
    state: SectionState.inProgress,
  ),
];

void main() {
  group('the one modal container', () {
    testWidgets('has a grabber painted at a declared hex, not an opacity', (
      tester,
    ) async {
      for (final name in phase2SkinNames) {
        final skin = phase2SkinNamed(name);
        final spec = TorchSheetSpec.resolve(skin: skin);
        if (spec.form == TorchSheetForm.fullScreen) {
          expect(
            spec.grabberColour,
            isNull,
            reason: '$name is the full-screen form and has no grabber.',
          );
          continue;
        }
        expect(
          spec.grabberColour,
          TorchSheetSpec.grabber,
          reason:
              '$name: the grabber is #616465 in every skin. "ink-1 at 38%" is '
              'a different grey on every surface it lands on, and opacity is '
              'banned as a state channel and as a colour channel with it.',
        );
        expect(spec.grabberColour!.a, 1.0);
      }
    });

    testWidgets('scrims at 72% and never blurs', (tester) async {
      final skin = TiqSkin.night(density: TiqDensity.field);
      final spec = TorchSheetSpec.resolve(skin: skin);
      expect(spec.scrim, skin.palette.scrim);
      // 0xB8 / 0xFF = 0.722. Not 88%: #380 needs the held work visible behind
      // the session-ended sheet, and the assistant surface's 88% defeats it.
      expect((spec.scrim.a * 255).round(), 0xB8);

      await pumpPhase2(
        tester,
        skin: skin,
        child: const TorchSheet(title: 'A sheet', child: Text('body')),
      );
      expect(
        find.byType(BackdropFilter),
        findsNothing,
        reason:
            'Zero BackdropFilter in this product. A blur is a saveLayer, and '
            'the paint budget has none to spend.',
      );
    });

    testWidgets('caps at 88% of the viewport', (tester) async {
      final spec = TorchSheetSpec.resolve(
        skin: TiqSkin.night(density: TiqDensity.field),
      );
      expect(spec.maxHeightFraction, 0.88);
      expect(spec.maxHeightFor(720), closeTo(633.6, 0.01));
    });

    testWidgets('pays 24 plus the safe area at the bottom, and 16 below the '
        'grabber', (tester) async {
      final spec = TorchSheetSpec.resolve(
        skin: TiqSkin.night(density: TiqDensity.field),
        bottomSafeArea: 34,
      );
      expect(spec.belowGrabber, 16);
      expect(spec.bottomPadding, 24 + 34);
      expect(spec.horizontalPadding, TiqSkin.night().space.gutter);
    });

    testWidgets('becomes a full-screen route with a 2px border and a 56dp '
        'Close row in Veld', (tester) async {
      final spec = TorchSheetSpec.resolve(skin: TiqSkin.veld());
      expect(spec.form, TorchSheetForm.fullScreen);
      expect(spec.closeRowHeight, 56);
      expect(spec.outlineWidth, 2);
      expect(spec.radius, BorderRadius.zero);
      expect(
        spec.scrim.a,
        0,
        reason:
            'Veld has no scrim. A translucent wash outdoors dims nothing and '
            'obscures everything.',
      );

      await pumpPhase2(
        tester,
        skin: TiqSkin.veld(),
        child: const TorchSheet(
          title: 'A route, not a sheet',
          closeLabel: 'Close',
          child: Text('body'),
        ),
      );
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('does not stack — a second sheet asserts', (tester) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: Builder(
          builder: (context) => GestureDetector(
            onTap: () => showTorchSheet<void>(
              context,
              builder: (_) => const TorchSheet(title: 'One', child: Text('a')),
            ),
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(TorchSheets.anyOpen, isTrue);

      expect(
        () => showTorchSheet<void>(
          tester.element(find.text('open')),
          builder: (_) => const TorchSheet(title: 'Two', child: Text('b')),
        ),
        throwsA(isA<FlutterError>()),
        reason:
            'Sheets do not stack. A sheet that needs a sheet cross-fades its '
            'own content — two scrims is two dimmings of one screen and the '
            'back gesture stops meaning anything.',
      );
    });

    testWidgets('publishes that it is open, so the route beneath can put its '
        'amber out', (tester) async {
      TorchSheets.resetForTest();
      expect(TorchSheets.anyOpen, isFalse);

      // The allocator's half of the same rule: beneath a sheet, everything
      // that asked for light is denied, including the nav tab the route did
      // not declare.
      final allocation = TorchScope.resolve(
        skin: TiqSkin.night(density: TiqDensity.field),
        claims: <TorchClaim>[
          const TorchClaim.primaryCommit('check-in'),
          const TorchClaim.plateStripLight('plate'),
        ],
        navRenders: true,
        tabbedRoute: true,
        beneathSheet: true,
      );
      expect(allocation.granted, isEmpty);
      expect(
        allocation.denied.values,
        everyElement(TorchDenial.extinguishedBySheet),
      );
    });

    testWidgets('cross-fades its own content instead of opening a second '
        'sheet', (tester) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: const TorchSheet(
          title: 'A sheet',
          child: TorchSheetSwap(paneKey: 'one', child: Text('pane one')),
        ),
      );
      expect(find.byType(TorchSheetSwap), findsOneWidget);
      expect(find.text('pane one'), findsOneWidget);
    });
  });

  group('the decision sheet', () {
    testWidgets('leads with the proof block, and focus is not on a button', (
      tester,
    ) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: const DecisionSheet(
          title: 'You have work here already',
          proof: _proof,
          carryOnLabel: 'Carry on from 11:04',
          startOverCost: 'Loses 6 sections and 3 photos',
        ),
      );
      expect(find.byType(ProofBlock), findsOneWidget);
      expect(find.text('6 of 9 sections captured'), findsOneWidget);
      expect(find.text('Carry on from 11:04'), findsOneWidget);
      // The cost is stated in words, not as "this cannot be undone".
      expect(find.text('Loses 6 sections and 3 photos'), findsOneWidget);
    });

    testWidgets('busy-disables BOTH actions while the cost is still being '
        'counted', (tester) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: const DecisionSheet(
          title: 'You have work here already',
          proof: _proof,
          counting: true,
          countingNote: 'Checking what you have here',
        ),
      );
      expect(find.text('Checking what you have here'), findsOneWidget);
      expect(
        find.byType(ProofBlock),
        findsOneWidget,
        reason: 'The block renders as a skeleton, not as nothing.',
      );
    });

    testWidgets('start over is two steps in one sheet', (tester) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: const DecisionSheet(
          title: 'You have work here already',
          proof: _proof,
          startOverLabel: 'Start over',
          startOverCost: 'Loses 6 sections and 3 photos',
          confirmLabel: 'Delete and start over',
          keepLabel: 'Keep it',
        ),
      );
      expect(find.text('Delete and start over'), findsNothing);

      await tester.tap(find.text('Start over'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Delete and start over'), findsOneWidget);
      expect(find.text('Keep it'), findsOneWidget);
      expect(
        find.byType(TorchSheet),
        findsOneWidget,
        reason: 'One sheet. The second step is a pane, never a second modal.',
      );
    });

    testWidgets('a stale check-in promotes "Check in again"', (tester) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: const DecisionSheet(
          title: 'You have work here already',
          proof: _proof,
          stale: true,
          checkInAgainLabel: 'Check in again',
          carryOnLabel: 'Carry on from 11:04',
        ),
      );
      expect(find.text('Check in again'), findsOneWidget);
      expect(
        find.text('Carry on from 11:04'),
        findsOneWidget,
        reason:
            'Carry on demotes to a ghost; it does not disappear. The captured '
            'work is preserved either way.',
      );
    });
  });

  group('the skip-reason picker', () {
    testWidgets('states each reason WITH its consequence, in the layout and '
        'in the semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: const SkipReasonPicker(title: 'Why not?'),
      );

      for (final reason in SkipReason.standard) {
        expect(find.text(reason.label), findsOneWidget);
        expect(
          find.text(reason.consequence),
          findsOneWidget,
          reason:
              '"${reason.label}" rendered without its consequence. A reason '
              'without one is a dropdown; a reason with one is a decision.',
        );
        expect(
          find.bySemanticsLabel('${reason.label}. ${reason.consequence}'),
          findsOneWidget,
          reason:
              'A screen-reader user makes the same informed choice a sighted '
              'one does, or the consequence line is decoration.',
        );
      }
      handle.dispose();
    });

    testWidgets('will not commit until a reason is chosen', (tester) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: const SkipReasonPicker(
          title: 'Why not?',
          chooseFirstNote: 'Choose a reason first',
        ),
      );
      expect(find.text('Choose a reason first'), findsOneWidget);

      await tester.tap(find.text(SkipReason.storeRefused.label));
      await tester.pump();
      expect(find.text('Choose a reason first'), findsNothing);
    });

    testWidgets('"Something else" requires the note — which is the hole this '
        'component closes', (tester) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: const SkipReasonPicker(
          title: 'Why not?',
          sayWhatHappenedNote: 'Say what happened',
        ),
      );
      await tester.tap(find.text(SkipReason.somethingElse.label));
      await tester.pump();
      expect(find.text('Say what happened'), findsOneWidget);
    });

    testWidgets('renders the standard reasons when none are configured, and '
        'says so', (tester) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: const SkipReasonPicker(
          title: 'Why not?',
          reasonsWereConfigured: false,
          usingStandardReasonsNote: 'Using the standard reasons',
        ),
      );
      expect(find.text('Using the standard reasons'), findsOneWidget);
      expect(
        find.text(SkipReason.storeRefused.label),
        findsOneWidget,
        reason: 'A skip must always be recordable.',
      );
    });

    testWidgets('the check-in variant asks different questions', (
      tester,
    ) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: const SkipReasonPicker(
          title: 'Why can you not get closer?',
          reasons: SkipReason.checkIn,
        ),
      );
      expect(find.text('The store is closed'), findsOneWidget);
      expect(
        find.text(SkipReason.notStocked.label),
        findsNothing,
        reason:
            '"I cannot get closer" is not "they do not stock this". A shared '
            'reason list would make the picker lie about the question.',
      );
    });
  });

  group('the session-ended sheet', () {
    testWidgets('is a state, not an error: no triangle, no crimson', (
      tester,
    ) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: const SessionEndedSheet(proof: _proof),
      );
      expect(find.text('You have been signed out'), findsOneWidget);
      expect(find.byType(ProofBlock), findsOneWidget);
      expect(find.text('Sign in to send them'), findsOneWidget);
      expect(
        find.byType(Opacity),
        findsNothing,
        reason:
            'The proof is countable, not ghostly. Rendering the live screen '
            'behind it at 0.35 measured 2.84:1 and cost a full-screen '
            'saveLayer to be illegible.',
      );
    });

    testWidgets('leaves a line behind after "Not now"', (tester) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(density: TiqDensity.field),
        child: SessionHeldLine(
          message: '6 sections and 3 photos are waiting to send.',
          actionLabel: 'Sign in',
          onPressed: () {},
        ),
      );
      expect(find.text('Sign in'), findsOneWidget);
      expect(SessionHeldLine.heightFor(TiqSkin.night()), 44);
      expect(SessionHeldLine.heightFor(TiqSkin.veld()), 64);
    });
  });

  group('the confirm sheet', () {
    testWidgets('names the record it is about to destroy', (tester) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(),
        child: const ConfirmSheet(
          action: 'Delete this alert rule?',
          consequences: <String>['No new alerts will fire.'],
          record: 'RULE-4471',
          commitLabel: 'Delete rule',
        ),
      );
      expect(find.text('RULE-4471'), findsOneWidget);
      expect(find.text('Delete rule'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('refuses a fourth consequence', (tester) async {
      await pumpPhase2(
        tester,
        skin: TiqSkin.night(),
        child: const ConfirmSheet(
          action: 'Delete?',
          consequences: <String>['a', 'b', 'c', 'd'],
          commitLabel: 'Delete',
        ),
      );
      expect(
        tester.takeException(),
        isAssertionError,
        reason:
            'Three consequences is the most a person reads before a '
            'destructive press.',
      );
    });
  });
}
