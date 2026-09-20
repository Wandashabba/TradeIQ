import 'package:flutter/material.dart' show Icons;
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';

import '../../design/amber_golden.dart';
import 'torch_harness.dart';

/// One test per state, per member of the button family.
///
/// The goldens are **pixel** goldens rather than image files: the frame is
/// rendered, read back, and specific coordinates are asserted to be specific
/// declared tokens. A PNG would tell us that something changed; this tells us
/// what, and it reviews as text.
void main() {
  const claim = 'commit';
  final night = TiqSkin.night(density: TiqDensity.field);

  Widget primary({
    VoidCallback? onPressed,
    String? blockedReason,
    bool busy = false,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(TiqSpace.s5),
      child: TorchPrimaryButton(
        claimId: claim,
        label: 'Send this visit',
        onPressed: onPressed,
        blockedReason: blockedReason,
        busy: busy,
      ),
    ),
  );

  group('Primary button — Night, the granted form', () {
    testWidgets('is a lifted block with an amber rim and a top bleed', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: night,
        child: primary(onPressed: () {}),
        claims: <TorchClaim>[TorchPrimaryButton.claim(claim)],
      );

      final rect = tester.getRect(find.byType(TorchPrimaryButton));
      final pixels = await torchPixels(tester);

      // The rim is the outermost pixel of the block; the fill is inside it.
      expect(
        pixels.at(rect.center.dx, rect.top + 0.5),
        night.palette.flame600,
        reason: 'the 1px rim along the top edge',
      );
      expect(
        pixels.at(rect.left + 0.5, rect.center.dy),
        night.palette.flame600,
        reason: 'the rim runs all the way round, not only across the top',
      );
      expect(
        pixels.at(rect.center.dx, rect.bottom - 6),
        night.palette.lifted,
        reason:
            'the block itself is NOT amber in Night — it is a dark block '
            'that is lit. Amber there would be a second solid amber object '
            'on every screen that has a commit action.',
      );
    });

    testWidgets('the rim and the bleed are counted as ONE amber object', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: night,
        child: primary(onPressed: () {}),
        claims: <TorchClaim>[TorchPrimaryButton.claim(claim)],
      );
      final census = await amberCensus(tester);
      expect(
        census.objectCount,
        1,
        reason:
            'unify §1.7: "rim + 2dp top bleed is one object". They touch, so '
            'the connected-components walk sees one region.\n'
            '${census.describe()}',
      );
    });

    testWidgets('press floods to flame-500 and the ink stays dark', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: night,
        child: primary(onPressed: () {}),
        claims: <TorchClaim>[TorchPrimaryButton.claim(claim)],
      );
      final rect = tester.getRect(find.byType(TorchPrimaryButton));
      final gesture = await tester.startGesture(rect.center);
      await tester.pump();

      final pixels = await torchPixels(tester);
      expect(
        pixels.at(rect.center.dx, rect.bottom - 6),
        night.palette.amberPressed,
        reason: 'flame-500 — one ramp step darker than the Day block',
      );
      expect(night.palette.amberPressed, night.palette.flame500);
      expect(
        night.palette.onAmberPressed,
        const Color(0xFF0B1017),
        reason:
            'the ink stays dark at 8.59:1. The pressed state that put '
            'flame-900 on flame-500 measured 2.00:1 and made the label vanish '
            'at the moment of commitment.',
      );

      await gesture.up();
      await tester.pump();
    });
  });

  group('Primary button — the other two skins', () {
    testWidgets('Day is a solid amber block with dark ink', (tester) async {
      final day = TiqSkin.day();
      await pumpTorch(
        tester,
        skin: day,
        child: primary(onPressed: () {}),
        claims: <TorchClaim>[TorchPrimaryButton.claim(claim)],
      );
      final rect = tester.getRect(find.byType(TorchPrimaryButton));
      final pixels = await torchPixels(tester);
      expect(pixels.at(rect.center.dx, rect.bottom - 6), day.palette.flame600);
      expect(day.palette.onAmber, day.palette.ink1);
    });

    testWidgets('Veld is a square amber block with a 2px ink border', (
      tester,
    ) async {
      final veld = TiqSkin.veld();
      await pumpTorch(
        tester,
        skin: veld,
        child: primary(onPressed: () {}),
        claims: <TorchClaim>[TorchPrimaryButton.claim(claim)],
      );
      final rect = tester.getRect(find.byType(TorchPrimaryButton));
      final pixels = await torchPixels(tester);
      expect(pixels.at(rect.center.dx, rect.bottom - 6), veld.palette.flame600);
      expect(
        pixels.at(rect.left + 0.5, rect.top + 0.5),
        veld.palette.ink1,
        reason:
            'radius 0 and a 2px ink border: the very corner pixel is the '
            'border, not the ground showing through a rounded shoulder.',
      );
      expect(veld.radii.control, 0);
      expect(veld.depth.borderWidth, 2);
      expect(
        tester.getSize(find.byType(TorchPrimaryButton)).height,
        greaterThanOrEqualTo(64),
        reason: 'Veld targets are 56 and its primary is 64',
      );
    });
  });

  group('Primary button — the states that are not lit', () {
    testWidgets('a sheet above it puts its light out', (tester) async {
      await pumpTorch(
        tester,
        skin: night,
        child: primary(onPressed: () {}),
        claims: <TorchClaim>[TorchPrimaryButton.claim(claim)],
        beneathSheet: true,
      );
      final census = await amberCensus(tester);
      expect(
        census.objectCount,
        0,
        reason:
            'While a modal sheet is up, every amber beneath it goes out — '
            'which is what lets the scrim stay at 72% and keep the held work '
            'visible behind it.\n${census.describe()}',
      );
    });

    testWidgets('disabled carries a BarNote ABOVE it, and no amber', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: night,
        child: primary(
          blockedReason: 'Stock and Pricing still need finishing.',
        ),
        claims: <TorchClaim>[TorchPrimaryButton.claim(claim)],
      );

      expect(find.byType(TorchBarNote), findsOneWidget);
      expect(
        tester.getRect(find.byType(TorchBarNote)).bottom,
        lessThanOrEqualTo(tester.getRect(find.text('Send this visit')).top),
        reason:
            'above, not beneath: the primary lives at the bottom edge of a '
            '96dp thumb zone and there is nothing under it to put a sentence '
            'in.',
      );
      expect(find.text('Stock and Pricing still need finishing.'), findsOne);

      final census = await amberCensus(tester);
      expect(census.objectCount, 0);
    });

    testWidgets('a disabled primary without a reason will not build', (
      tester,
    ) async {
      expect(
        () => TorchPrimaryButton(
          claimId: claim,
          label: 'Send this visit',
          onPressed: null,
        ),
        throwsA(isA<AssertionError>()),
        reason:
            'A dead grey button with no explanation is, in a shop, a phone '
            'call to the office.',
      );
    });

    testWidgets('busy swallows the tap and says so out loud', (tester) async {
      var taps = 0;
      await pumpTorch(
        tester,
        skin: night,
        child: primary(onPressed: () => taps++, busy: true),
        claims: <TorchClaim>[TorchPrimaryButton.claim(claim)],
      );
      expect(find.byType(TorchBusyDots), findsOneWidget);
      expect(find.text('Send this visit'), findsNothing);
      await tester.tap(find.byType(TorchPrimaryButton));
      await tester.pump();
      expect(taps, 0);

      final semantics = tester.getSemantics(find.byType(TorchPrimaryButton));
      expect(semantics.label, 'Send this visit, sending');
    });

    testWidgets('a double tap commits once', (tester) async {
      var taps = 0;
      await pumpTorch(
        tester,
        skin: night,
        child: primary(onPressed: () => taps++),
        claims: <TorchClaim>[TorchPrimaryButton.claim(claim)],
      );
      await tester.tap(find.byType(TorchPrimaryButton));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(TorchPrimaryButton));
      await tester.pump();
      expect(
        taps,
        1,
        reason:
            'the cost of a double-tapped commit is a duplicate visit, so the '
            'second tap inside 400ms is swallowed',
      );
    });
  });

  group('Secondary button', () {
    testWidgets('is a ghost at the primary geometry, and never amber', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: night,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(TiqSpace.s5),
            child: TorchSecondaryButton(label: 'Skip', onPressed: () {}),
          ),
        ),
      );
      final rect = tester.getRect(find.byType(TorchSecondaryButton));
      final pixels = await torchPixels(tester);
      expect(
        pixels.at(rect.left + 0.5, rect.center.dy),
        night.palette.edgeControl,
      );
      expect(
        pixels.at(rect.center.dx, rect.bottom - 6),
        night.palette.ground,
        reason: 'no fill of its own — it is the ground with an edge on it',
      );
      expect(
        rect.height,
        night.space.primaryActionHeight,
        reason:
            'the same height as a primary on a label that fits. An '
            'alternative that is also smaller is a hint, not a choice.',
      );
      final census = await amberCensus(tester);
      expect(census.objectCount, 0);
    });

    testWidgets('press changes the fill AND doubles the edge', (tester) async {
      await pumpTorch(
        tester,
        skin: night,
        child: Center(
          child: TorchSecondaryButton(label: 'Start over', onPressed: () {}),
        ),
      );
      final rect = tester.getRect(find.byType(TorchSecondaryButton));
      final gesture = await tester.startGesture(rect.center);
      await tester.pump();
      final pixels = await torchPixels(tester);
      expect(
        pixels.at(rect.center.dx, rect.bottom - 6),
        night.palette.lifted,
        reason: 'the fill is the channel that survives reduce-motion',
      );
      expect(
        pixels.at(rect.left + 1.5, rect.center.dy),
        night.palette.edgeControl,
        reason: 'and the edge has stepped from 1px to 2px',
      );
      await gesture.up();
      await tester.pump();
    });
  });

  group('Tertiary button', () {
    testWidgets('carries a rule under the label, in a 48dp target', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: night,
        child: Center(
          child: TorchTertiaryButton(
            label: 'Retry sending the shelf photo',
            onPressed: () {},
          ),
        ),
      );
      final rect = tester.getRect(find.byType(TorchTertiaryButton));
      expect(rect.height, greaterThanOrEqualTo(48));
      final pixels = await torchPixels(tester);
      var hasRule = false;
      for (var y = rect.top; y < rect.bottom; y++) {
        hasRule |= pixels.rowHas(
          night.palette.edgeControl,
          y,
          from: rect.left,
          to: rect.right,
        );
      }
      expect(
        hasRule,
        isTrue,
        reason:
            'the underline is what makes the action findable without colour',
      );
    });

    testWidgets('disabled loses the rule as well as the ink', (tester) async {
      await pumpTorch(
        tester,
        skin: night,
        child: const Center(
          child: TorchTertiaryButton(label: 'Retry', onPressed: null),
        ),
      );
      final pixels = await torchPixels(tester);
      final rect = tester.getRect(find.byType(TorchTertiaryButton));
      for (var y = rect.top; y < rect.bottom; y++) {
        expect(
          pixels.rowHas(
            night.palette.edgeControl,
            y,
            from: rect.left,
            to: rect.right,
          ),
          isFalse,
        );
      }
    });

    testWidgets('the destructive variant leads with a drawn triangle', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: night,
        child: Center(
          child: TorchTertiaryButton(
            label: 'Discard',
            destructive: true,
            onPressed: () {},
          ),
        ),
      );
      expect(find.byType(TorchTriangle), findsOneWidget);
    });
  });

  group('Destructive button', () {
    testWidgets('is outlined crimson with a filled triangle', (tester) async {
      await pumpTorch(
        tester,
        skin: night,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(TiqSpace.s5),
            child: TorchDestructiveButton(
              label: 'Discard 12 held captures',
              onPressed: () {},
            ),
          ),
        ),
      );
      final rect = tester.getRect(find.byType(TorchDestructiveButton));
      final pixels = await torchPixels(tester);
      expect(pixels.at(rect.left + 0.5, rect.center.dy), night.palette.bad);
      expect(
        pixels.at(rect.center.dx, rect.bottom - 6),
        night.palette.ground,
        reason: 'outlined, never the primary geometry-and-fill',
      );
      expect(find.byType(TorchTriangle), findsOneWidget);
    });

    testWidgets('the confirming form is solid, and only that one', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: night,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(TiqSpace.s5),
            child: TorchDestructiveButton.confirming(
              label: 'Delete and start over',
              onPressed: () {},
            ),
          ),
        ),
      );
      final rect = tester.getRect(find.byType(TorchDestructiveButton));
      final pixels = await torchPixels(tester);
      expect(
        pixels.at(rect.center.dx, rect.bottom - 6),
        night.palette.badSolid,
      );
    });

    testWidgets('disabled outlines the triangle rather than hiding it', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: night,
        child: const Center(
          child: TorchDestructiveButton(
            label: 'Start over',
            onPressed: null,
            blockedReason: 'Nothing has been captured yet.',
          ),
        ),
      );
      final triangle = tester.widget<TorchTriangle>(find.byType(TorchTriangle));
      expect(triangle.filled, isFalse);
      expect(find.byType(TorchBarNote), findsOneWidget);
    });
  });

  group('Icon button', () {
    testWidgets('cannot be built without a label', (tester) async {
      expect(
        () => TorchIconButton(
          icon: Icons.close,
          semanticLabel: '',
          onPressed: () {},
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    testWidgets('toggled on is a block plus a word, and says toggled', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: night,
        child: const Center(
          child: TorchIconButton(
            icon: Icons.flashlight_on_outlined,
            semanticLabel: 'Torch',
            stateWord: 'On',
            toggledOn: true,
            onPressed: null,
          ),
        ),
      );
      expect(find.text('On'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(TorchIconButton)),
        isSemantics(isToggled: true),
        reason: 'the state is announced, never inferred from a fill',
      );
    });

    testWidgets('toggled on without a word will not build', (tester) async {
      expect(
        () => TorchIconButton(
          icon: Icons.flashlight_on_outlined,
          semanticLabel: 'Torch',
          toggledOn: true,
          onPressed: () {},
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    testWidgets('meets the tap-target floor in every skin', (tester) async {
      for (final skin in torchSkins) {
        await pumpTorch(
          tester,
          skin: skin,
          child: Center(
            child: TorchIconButton(
              icon: Icons.close,
              semanticLabel: 'Close this sheet',
              onPressed: () {},
            ),
          ),
        );
        final size = tester.getSize(find.byType(TorchIconButton));
        final floor = skin.mode == SkinMode.veld ? 56.0 : 48.0;
        expect(size.width, greaterThanOrEqualTo(floor));
        expect(size.height, greaterThanOrEqualTo(floor));
      }
    });

    testWidgets('names no amber token in any skin', (tester) async {
      for (final skin in torchSkins) {
        await pumpTorch(
          tester,
          skin: skin,
          child: const Center(
            child: TorchIconButton(
              icon: Icons.wb_sunny_outlined,
              semanticLabel: 'Screen: Day',
              stateWord: 'On',
              toggledOn: true,
              onPressed: null,
            ),
          ),
        );
        final census = await amberCensus(tester);
        expect(
          census.objectCount,
          0,
          reason:
              'unify §1.23: the spec gave a toggled-on icon button an amber '
              'glyph on light grounds and it does not get one. A toggle '
              'state is a label.\n${census.describe()}',
        );
      }
    });
  });

  // ── THE ACTION, NOT ONLY THE FLAG ─────────────────────────────────────
  //
  // Every one of these buttons announced itself as a button and carried no
  // `SemanticsAction.tap`, for as long as the kit has existed: the node was
  // a `Semantics(button: true, …, excludeSemantics: true)` wrapped AROUND a
  // `TorchPressable`, and `excludeSemantics` drops the descendant
  // `GestureDetector`'s node — the only thing that held the tap. The result
  // reads correct in the source and is inert in the hand: TalkBack focuses
  // it, reads it, double-taps, and nothing happens.
  //
  // `tester.tap` cannot see this, because it sends a pointer. These fire the
  // action the platform fires, through the binding.
  group('a button a screen reader can reach, it can also press', () {
    Future<void> activate(WidgetTester tester, Finder finder) async {
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          type: SemanticsAction.tap,
          nodeId: tester.getSemantics(finder).id,
          viewId: tester.view.viewId,
        ),
      );
      await tester.pump();
    }

    for (final skin in torchSkins) {
      testWidgets('${skin.mode.name}: every member of the family', (
        tester,
      ) async {
        var taps = 0;
        await pumpTorch(
          tester,
          skin: skin,
          claims: <TorchClaim>[TorchPrimaryButton.claim(claim)],
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TorchPrimaryButton(
                  claimId: claim,
                  label: 'Send this visit',
                  onPressed: () => taps++,
                ),
                TorchSecondaryButton(label: 'Save a draft', onPressed: () {}),
                TorchTertiaryButton(label: 'Skip it', onPressed: () {}),
                TorchDestructiveButton(
                  label: 'Discard this visit',
                  onPressed: () {},
                ),
                TorchIconButton(
                  icon: Icons.close,
                  semanticLabel: 'Close this sheet',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        );

        for (final type in <Type>[
          TorchPrimaryButton,
          TorchSecondaryButton,
          TorchTertiaryButton,
          TorchDestructiveButton,
          TorchIconButton,
        ]) {
          final node = tester.getSemantics(find.byType(type));
          expect(
            node,
            isSemantics(isButton: true, hasTapAction: true),
            reason:
                '$type announces as a button. Without a tap action on the '
                'same node it is a label: focusable, unactivatable.',
          );
        }

        // ...and the action is the real one, with the press debounce and the
        // haptic behind it, not a second path that skips them.
        await activate(tester, find.byType(TorchPrimaryButton));
        expect(taps, 1);
        await activate(tester, find.byType(TorchPrimaryButton));
        expect(
          taps,
          1,
          reason:
              'the semantics tap goes through the SAME debounced fire as the '
              'finger, so a commit cannot be doubled through assistive tech '
              'either',
        );
      });
    }

    testWidgets('a disabled primary announces disabled and does not fire', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: night,
        claims: <TorchClaim>[TorchPrimaryButton.claim(claim)],
        child: primary(blockedReason: 'Nothing to send yet'),
      );
      expect(
        // The blocked form is a Column of the note and the button, so the
        // button's own node is the pressable's.
        tester.getSemantics(
          find.descendant(
            of: find.byType(TorchPrimaryButton),
            matching: find.byType(TorchPressable),
          ),
        ),
        isSemantics(isButton: true, isEnabled: false, hasTapAction: false),
        reason:
            'a disabled control is ALLOWED to carry no action — that is what '
            'disabled means, and it is the only thing that is allowed to',
      );
    });
  });
}
