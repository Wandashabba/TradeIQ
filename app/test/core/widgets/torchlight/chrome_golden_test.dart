import 'package:flutter/material.dart' show Icons;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';

import 'chrome_test.dart' show agentSlots;
import 'torch_harness.dart';

/// THE COMPOSED FRAME, ONE SKIN AT A TIME — **Night first, then Day, Veld
/// last**, which is the order the build plan gives and the order these groups
/// are written in.
///
/// These are pixel goldens without image files: the frame is rendered, read
/// back, and named coordinates are asserted against named tokens. A PNG would
/// say that something changed; this says what changed and why it mattered, and
/// it reviews in a diff.
///
/// Veld goes last for the reason unify §5 gives — it has the fewest users per
/// day and the highest per-component tax, and writing its goldens against
/// components that have stopped moving is the whole point of sequencing it
/// third.

/// A tab root: header with the skin cycle as its one trailing button, a body,
/// the nav pill and the circle.
Widget tabRoot(SkinMode mode) => TorchShell(
  profile: TorchShellProfile.agent,
  header: TorchAppHeader(
    title: 'Today',
    facts: const <String>['4 of 7 stores', '12 km'],
    trailing: TorchIconButton(
      icon: TorchSkinCycle.glyphFor(mode),
      semanticLabel: 'Screen: ${mode.name}. Double-tap to change it.',
      onPressed: () {},
    ),
  ),
  navPill: TorchNavPill(slots: agentSlots, activeIndex: 0, onSelect: (_) {}),
  navCircle: TorchNavCircle(
    claimId: 'unplanned-visit',
    expected: true,
    icon: Icons.add,
    expectedIcon: Icons.arrow_forward,
    semanticLabel: 'Start a visit somewhere else',
    expectedSemanticLabel: 'Start a visit here',
    onPressed: () {},
  ),
  children: const <Widget>[SizedBox(height: 240)],
);

/// A screen inside a visit: no nav, a thumb zone with the skin cycle and the
/// commit action.
Widget committing(SkinMode mode) => TorchShell(
  profile: TorchShellProfile.agent,
  header: TorchAppHeader(
    title: 'Submit',
    back: TorchIconButton(
      icon: Icons.arrow_back,
      semanticLabel: 'Back to the visit',
      onPressed: () {},
    ),
  ),
  skinCycle: TorchSkinCycle(
    mode: mode,
    onChanged: (_) {},
    semanticLabel: 'Screen: ${mode.name}. Double-tap to change it.',
  ),
  primary: TorchPrimaryButton(
    claimId: 'submit',
    label: 'Send this visit',
    onPressed: () {},
  ),
  children: const <Widget>[SizedBox(height: 240)],
);

/// Every widget type this system has a zero budget for.
void expectNoBlur(WidgetTester tester) {
  for (final widget in tester.allWidgets) {
    expect(
      widget,
      isNot(isA<BackdropFilter>()),
      reason: 'zero BackdropFilter in this application. The nav is opaque.',
    );
    expect(widget, isNot(isA<ImageFiltered>()));
    expect(widget, isNot(isA<ShaderMask>()));
  }
}

/// Night has no shadows at all — black on black is invisible — and neither
/// does Veld, which removes every one rather than softening it.
void expectNoShadow(WidgetTester tester) {
  for (final object in tester.allRenderObjects) {
    final decoration = switch (object) {
      RenderDecoratedBox() => object.decoration,
      RenderPhysicalModel() => null,
      _ => null,
    };
    if (decoration is BoxDecoration) {
      expect(
        decoration.boxShadow ?? const <BoxShadow>[],
        isEmpty,
        reason: 'a BoxShadow in a skin with no shadow budget',
      );
    }
  }
}

void expectNoGradient(WidgetTester tester) {
  for (final object in tester.allRenderObjects) {
    if (object is RenderDecoratedBox) {
      final decoration = object.decoration;
      if (decoration is BoxDecoration) {
        expect(
          decoration.gradient,
          isNull,
          reason:
              'Veld allows no gradient at all: every bloom, rim and falloff '
              'is removed there, not softened',
        );
      }
    }
  }
}

void main() {
  group('NIGHT — first', () {
    final skin = TiqSkin.night(density: TiqDensity.field);

    testWidgets('a tab root: the bar floats, the tab is lit, the circle sits '
        'outside it', (tester) async {
      await pumpTorch(
        tester,
        skin: skin,
        size: const Size(360, 720),
        navRenders: true,
        tabbedRoute: true,
        claims: const <TorchClaim>[TorchClaim.navCircle('unplanned-visit')],
        child: tabRoot(SkinMode.night),
      );

      final bar = tester.getRect(find.byType(TorchNavPill));
      final circle = tester.getRect(find.byType(TorchNavCircle));
      expect(bar.height, 64);
      expect(bar.left, 16, reason: 'inset 16 from the gutter');
      expect(720 - bar.bottom, 20, reason: '20dp above the safe area');
      expect(circle.width, 64);
      expect(circle.left - bar.right, 12);

      final pixels = await torchPixels(tester);
      expect(pixels.at(180, 4), skin.palette.ground);
      expect(
        pixels.at(bar.center.dx, bar.top + 0.5),
        skin.palette.edgeStructure,
        reason: 'a 1px outline on an opaque well — never a frosted edge',
      );
      expect(
        pixels.at(bar.left + 10, bar.center.dy),
        skin.palette.flame600,
        reason: "the active tab, holding the frame's first grant",
      );
      expect(
        pixels.at(circle.center.dx, circle.top + 8),
        skin.palette.flame600,
        reason:
            'no primary on this route, so rung 4 is admissible and the '
            'standing action is the expected next move',
      );

      expectNoBlur(tester);
      expectNoShadow(tester);
    });

    testWidgets('a commit screen: 96dp thumb zone, cycle at the gutter', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: skin,
        size: const Size(360, 720),
        claims: const <TorchClaim>[TorchClaim.primaryCommit('submit')],
        child: committing(SkinMode.night),
      );

      final zone = tester.getRect(find.byType(TorchThumbZone));
      final cycle = tester.getRect(find.byType(TorchSkinCycle));
      final primary = tester.getRect(find.byType(TorchPrimaryButton));
      expect(zone.height, greaterThanOrEqualTo(96));
      expect(zone.left, 0, reason: 'the rule crosses the full bleed');
      expect(cycle.width, 56);
      expect(cycle.left, skin.space.gutter, reason: 'at the leading gutter');
      expect(primary.left - cycle.right, 12);
      expect(find.byType(TorchNavPill), findsNothing);

      final pixels = await torchPixels(tester);
      expect(
        pixels.at(180, zone.top),
        skin.palette.hairline,
        reason: 'a 1px hairline above the thumb zone, full bleed',
      );
      expect(
        pixels.at(primary.center.dx, primary.top + 0.5),
        skin.palette.flame600,
        reason: 'the rim',
      );
      expect(
        pixels.at(primary.center.dx, primary.bottom - 6),
        skin.palette.lifted,
        reason: 'the block is lit, not amber',
      );
      expectNoBlur(tester);
      expectNoShadow(tester);
    });
  });

  group('DAY — second', () {
    final skin = TiqSkin.day();

    testWidgets('the tab is an Abyssal block and the circle is amber', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: skin,
        size: const Size(360, 720),
        navRenders: true,
        tabbedRoute: true,
        claims: const <TorchClaim>[TorchClaim.navCircle('unplanned-visit')],
        child: tabRoot(SkinMode.day),
      );
      final bar = tester.getRect(find.byType(TorchNavPill));
      final circle = tester.getRect(find.byType(TorchNavCircle));
      final pixels = await torchPixels(tester);
      expect(
        pixels.at(bar.left + 10, bar.center.dy),
        skin.palette.lifted,
        reason: 'never amber on a light ground',
      );
      expect(
        pixels.at(circle.center.dx, circle.top + 8),
        skin.palette.surface,
        reason:
            'and neither is the circle: Day has one amber block per screen '
            'and it belongs to the primary commit action, which this route '
            'does not have — so nothing is armed and nothing is lit',
      );
      expectNoBlur(tester);
    });

    testWidgets('the primary is the one amber block on the screen', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: skin,
        size: const Size(360, 720),
        claims: const <TorchClaim>[TorchClaim.primaryCommit('submit')],
        child: committing(SkinMode.day),
      );
      final primary = tester.getRect(find.byType(TorchPrimaryButton));
      final pixels = await torchPixels(tester);
      expect(
        pixels.at(primary.center.dx, primary.bottom - 6),
        skin.palette.flame600,
      );
      expect(
        pixels.at(primary.left + 0.5, primary.center.dy),
        skin.palette.ink1,
        reason:
            'a real edge: an amber block on Palladian is 1.6:1 on its own '
            'ground and nothing here is identified by a fill alone',
      );
      expectNoBlur(tester);
    });
  });

  group('VELD — last', () {
    final skin = TiqSkin.veld();

    testWidgets('the bar docks, and every target clears 56', (tester) async {
      await pumpTorch(
        tester,
        skin: skin,
        size: const Size(360, 720),
        navRenders: true,
        tabbedRoute: true,
        claims: const <TorchClaim>[TorchClaim.navCircle('unplanned-visit')],
        child: tabRoot(SkinMode.veld),
      );
      final bar = tester.getRect(find.byType(TorchNavPill));
      expect(bar.height, 72);
      expect(bar.left, 0);
      expect(bar.right, 360, reason: 'full bleed, no float, no radius');
      expect(
        tester.getSize(find.byType(TorchIconButton).first).height,
        greaterThanOrEqualTo(56),
      );

      final pixels = await torchPixels(tester);
      expect(
        pixels.at(180, bar.top + 0.5),
        skin.palette.edgeStructure,
        reason: 'a 2px top border, which is every hairline in Veld',
      );
      expect(
        pixels.at(bar.left + 10, bar.center.dy),
        skin.palette.lifted,
        reason: 'a solid ink block with white on it at 15.33:1',
      );
      expectNoBlur(tester);
      expectNoShadow(tester);
      expectNoGradient(tester);
    });

    testWidgets('the commit block is square, amber and bordered', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: skin,
        size: const Size(360, 720),
        claims: const <TorchClaim>[TorchClaim.primaryCommit('submit')],
        child: committing(SkinMode.veld),
      );
      final primary = tester.getRect(find.byType(TorchPrimaryButton));
      expect(primary.height, greaterThanOrEqualTo(64));
      final pixels = await torchPixels(tester);
      expect(
        pixels.at(primary.left + 0.5, primary.top + 0.5),
        skin.palette.ink1,
        reason: 'radius 0: the very corner pixel is the 2px border',
      );
      expect(
        pixels.at(primary.center.dx, primary.bottom - 8),
        skin.palette.flame600,
      );
      expect(
        tester.getSize(find.byType(TorchSkinCycle)).width,
        64,
        reason: 'Veld grows the cycle to 64 and kills its press scale',
      );
      expectNoBlur(tester);
      expectNoShadow(tester);
      expectNoGradient(tester);
    });
  });
}
