import 'package:flutter/material.dart'
    show Icons, Theme, ThemeData, ThemeExtension;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';

import 'torch_harness.dart';

/// The agent's four destinations, and the manager's.
const agentSlots = <TorchNavSlot>[
  TorchNavSlot(
    icon: Icons.today_outlined,
    activeIcon: Icons.today,
    label: 'Today',
  ),
  TorchNavSlot(
    icon: Icons.inventory_2_outlined,
    activeIcon: Icons.inventory_2,
    label: 'Work',
  ),
  TorchNavSlot(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'Map'),
  TorchNavSlot(
    icon: Icons.person_outline,
    activeIcon: Icons.person,
    label: 'Me',
  ),
];

TorchNavCircle navCircle({
  bool expected = true,
  String claimId = 'unplanned-visit',
}) => TorchNavCircle(
  claimId: claimId,
  expected: expected,
  icon: Icons.add,
  expectedIcon: Icons.arrow_forward,
  semanticLabel: 'Start a visit somewhere else',
  expectedSemanticLabel: 'Start a visit here',
  onPressed: () {},
);

void main() {
  final night = TiqSkin.night(density: TiqDensity.field);

  group('Nav pill — geometry', () {
    // ── SHAPE A: 64 TALL, AND NO MATERIAL AT ALL — 4 October 2026 ───────
    //
    // This test used to be called "Night and Day float: 64 tall, radius 999,
    // opaque well" and it asserted the `edgeStructure` outline on the bar's
    // top pixel row and the ground showing through its rounded top-left
    // corner. Both of those were statements about a pill, and shape A has no
    // pill: the owner picked the mockup in which the bar has no fill and no
    // outline and the slots sit on the shell's ground.
    //
    // THE HEIGHT AND THE INSETS ARE UNCHANGED AND ARE STILL ASSERTED. That is
    // the part of the old test that was about the bar's place on the screen
    // rather than about its material, and shape A did not move it — 64dp, 16
    // from each gutter, 20 above the safe area. What replaces the two colour
    // assertions is their inverse, which is the claim that now needs holding:
    // every pixel along the bar's own top row is the ground, corner to
    // corner, because there is nothing there to paint.
    testWidgets('Night and Day sit on the ground: 64 tall, no fill, no '
        'outline', (tester) async {
      for (final skin in <TiqSkin>[night, TiqSkin.day()]) {
        await pumpTorch(
          tester,
          skin: skin,
          navRenders: true,
          tabbedRoute: true,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: TorchNavPill(
                slots: agentSlots,
                activeIndex: 0,
                onSelect: (_) {},
              ),
            ),
          ),
        );
        final rect = tester.getRect(find.byType(TorchNavPill));
        expect(rect.height, 64, reason: '${skin.mode.name} bar height');
        expect(rect.left, 16, reason: 'inset 16 from the gutter');
        expect(rect.right, 344);

        final pixels = await torchPixels(tester);
        // The top row, sampled across the whole bar rather than at one point:
        // an outline is a line, and a line is caught by looking along it.
        for (final x in <double>[
          rect.left + 1,
          rect.left + 40,
          rect.center.dx,
          rect.right - 40,
          rect.right - 1,
        ]) {
          expect(
            pixels.at(x, rect.top + 0.5),
            skin.palette.ground,
            reason:
                '${skin.mode.name}: no outline and no fill — the bar paints '
                'nothing of its own, so its own top pixel row is the ground '
                'at x=$x',
          );
        }
        // And the resting slots are quiet: the three inactive ones have no
        // fill either, so a point beside the second slot's glyph is ground.
        final second = tester.getRect(find.text('Work'));
        expect(
          pixels.at(second.center.dx, rect.top + 2),
          skin.palette.ground,
          reason: 'an inactive slot is quiet: ink and glyph, no surface',
        );
      }
    });

    testWidgets('five slots will not build', (tester) async {
      expect(
        () => TorchNavPill(
          slots: <TorchNavSlot>[
            ...agentSlots,
            const TorchNavSlot(
              icon: Icons.menu,
              activeIcon: Icons.menu_open,
              label: 'Menu',
            ),
          ],
          activeIndex: 0,
          onSelect: (_) {},
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('Nav pill — the active tab', () {
    // ── THE THREE STATES OF THE FOURTH CHANNEL ───────────────────────────
    //
    // All three of these tests used to sample `slot.right + 10, slot.center.dy`
    // — a point ten pixels right of the label, halfway up the slot — and read
    // the **fill of the active block** there: `flame600` on Night, `lifted`
    // (the Abyssal block) on Day and beneath a sheet. Shape A has no block, so
    // that point is now the bar's quiet ground on Night and the `well` groove
    // on the other two, and the thing worth measuring moved to the bottom of
    // the slot.
    //
    // They are rewritten rather than deleted because the RULE they hold did
    // not change: Night granted is amber, Day is never amber, and a sheet puts
    // the grant out. Only the drawing did.
    //
    // The edge is sampled at the slot's own bottom row and at its horizontal
    // centre, which is where `TorchNavPill.edgeExtent` puts it.
    Offset edgeAt(WidgetTester tester) {
      final bar = tester.getRect(find.byType(TorchNavPill));
      final slot = tester.getRect(find.text('Work'));
      // 8dp of vertical inset, so the slot box ends 8dp above the bar's own
      // bottom edge and the 2dp edge is the last of it.
      return Offset(slot.center.dx, bar.bottom - 8 - 1);
    }

    testWidgets('Night names it with a 2dp amber edge, and takes the grant '
        'from TorchScope', (tester) async {
      await pumpTorch(
        tester,
        skin: night,
        navRenders: true,
        tabbedRoute: true,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: TorchNavPill(
            slots: agentSlots,
            activeIndex: 1,
            onSelect: (_) {},
          ),
        ),
      );
      final pixels = await torchPixels(tester);
      expect(
        pixels.at(edgeAt(tester).dx, edgeAt(tester).dy),
        night.palette.flame600,
        reason: 'the edge under the active label, flat flame-600',
      );
      // AND THE SLOT IS NOT FILLED, which is the half that makes this shape A
      // rather than a block with a line under it.
      final slot = tester.getRect(find.text('Work'));
      expect(
        pixels.at(slot.right + 10, slot.center.dy),
        night.palette.ground,
        reason:
            'no fill behind the active tab on Night: the edge is the whole of '
            'the fourth channel there',
      );
      // And the three inactive slots have no edge.
      final today = tester.getRect(find.text('Today'));
      expect(
        pixels.at(today.center.dx, edgeAt(tester).dy),
        night.palette.ground,
        reason: 'the lane is reserved in every slot and painted in one',
      );
    });

    testWidgets('a sheet above the route puts the edge out and the groove in', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: night,
        navRenders: true,
        tabbedRoute: true,
        beneathSheet: true,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: TorchNavPill(
            slots: agentSlots,
            activeIndex: 1,
            onSelect: (_) {},
          ),
        ),
      );
      final pixels = await torchPixels(tester);
      expect(
        pixels.at(edgeAt(tester).dx, edgeAt(tester).dy),
        night.palette.well,
        reason:
            'the grant is withdrawn, so the edge is transparent and what is '
            'at that pixel is the groove showing through the lane',
      );
      final slot = tester.getRect(find.text('Work'));
      expect(
        pixels.at(slot.right + 10, slot.center.dy),
        night.palette.well,
        reason:
            'the denied form is MenuFlatRow\'s own: a `well` groove, so the '
            'sheet genuinely owns the screen and the tab still says which '
            'one you are standing on',
      );
    });

    testWidgets('Day uses the well groove, never amber', (tester) async {
      final skin = TiqSkin.day();
      await pumpTorch(
        tester,
        skin: skin,
        navRenders: true,
        tabbedRoute: true,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: TorchNavPill(
            slots: agentSlots,
            activeIndex: 1,
            onSelect: (_) {},
          ),
        ),
      );
      final pixels = await torchPixels(tester);
      final slot = tester.getRect(find.text('Work'));
      expect(
        pixels.at(slot.right + 10, slot.center.dy),
        skin.palette.well,
        reason:
            'on a light ground amber is a carrier of ink, and the one object '
            'allowed to be that is the primary. `torch_scope.dart` denies the '
            'nav tab by rule before any budget is consulted, so the groove is '
            'not a fallback for a spent budget — it is the only Day form.',
      );
      expect(
        pixels.at(edgeAt(tester).dx, edgeAt(tester).dy),
        skin.palette.well,
        reason: 'and the edge lane is empty: no amber anywhere on Day',
      );
      // SELECTION WITHOUT COLOUR, measured in the other channel the Day form
      // leans on: the active label is w700 and the inactive ones are w500.
      final active = tester.widget<Text>(find.text('Work'));
      final inactive = tester.widget<Text>(find.text('Today'));
      expect(active.style?.fontWeight, FontWeight.w700);
      expect(inactive.style?.fontWeight, FontWeight.w500);
    });

    testWidgets('each slot says which tab it is, and whether it is on', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: night,
        navRenders: true,
        tabbedRoute: true,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: TorchNavPill(
            slots: agentSlots,
            activeIndex: 2,
            onSelect: (_) {},
          ),
        ),
      );
      expect(
        tester.getSemantics(find.text('Map')),
        isSemantics(label: 'Map, tab 3 of 4', isSelected: true),
      );
      expect(
        tester.getSemantics(find.text('Today')),
        isSemantics(isSelected: false),
      );
    });

    testWidgets('tapping a slot reports its index', (tester) async {
      var picked = -1;
      await pumpTorch(
        tester,
        skin: night,
        navRenders: true,
        tabbedRoute: true,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: TorchNavPill(
            slots: agentSlots,
            activeIndex: 0,
            onSelect: (i) => picked = i,
          ),
        ),
      );
      await tester.tap(find.text('Me'));
      await tester.pump();
      expect(picked, 3);
    });
  });

  group('Nav circle', () {
    testWidgets('64dp, and amber when it is expected and nothing outranks it', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: night,
        navRenders: true,
        tabbedRoute: true,
        claims: <TorchClaim>[TorchNavCircle.claim('unplanned-visit')],
        child: Center(child: navCircle()),
      );
      final rect = tester.getRect(find.byType(TorchNavCircle));
      expect(rect.width, 64);
      expect(rect.height, 64);
      final pixels = await torchPixels(tester);
      // On the disc's own radial ramp rather than equal to flame-600: this
      // sample is 6dp down from the top, which is near the hot core. See
      // [isOnAmberRamp].
      expect(
        pixels.at(rect.center.dx, rect.top + 6),
        isOnAmberRamp(night),
        reason: 'the granted standing action, lit',
      );
    });

    testWidgets('a primary on the route outranks it outright', (tester) async {
      await pumpTorch(
        tester,
        skin: night,
        navRenders: true,
        tabbedRoute: true,
        claims: <TorchClaim>[
          TorchPrimaryButton.claim('commit'),
          TorchNavCircle.claim('unplanned-visit'),
        ],
        child: Center(child: navCircle()),
      );
      final rect = tester.getRect(find.byType(TorchNavCircle));
      final pixels = await torchPixels(tester);
      expect(
        pixels.at(rect.center.dx, rect.top + 6),
        night.palette.lifted,
        reason:
            'rung 4, and denied by rule rather than by budget: a screen with '
            'a commit action on it is a screen about that commit action',
      );
    });

    testWidgets('expected is a different glyph, not a different colour', (
      tester,
    ) async {
      for (final expected in <bool>[true, false]) {
        await pumpTorch(
          tester,
          skin: TiqSkin.day(),
          child: Center(child: navCircle(expected: expected)),
        );
        final glyph = tester.widget<TorchGlyph>(
          find.descendant(
            of: find.byType(TorchNavCircle),
            matching: find.byType(TorchGlyph),
          ),
        );
        expect(glyph.icon, expected ? Icons.arrow_forward : Icons.add);
        expect(
          tester.getSemantics(find.byType(TorchNavCircle)).label,
          expected ? 'Start a visit here' : 'Start a visit somewhere else',
        );
      }
    });
  });

  group('Skin cycle', () {
    testWidgets('one glyph per skin, and the cycle is Day, Night', (
      tester,
    ) async {
      expect(TorchSkinCycle.next(SkinMode.day), SkinMode.night);
      expect(TorchSkinCycle.next(SkinMode.night), SkinMode.day);
      // `auto` is a preference, not a position: the control always shows a
      // real glyph, and a tap from there lands on the agent default.
      expect(TorchSkinCycle.next(SkinMode.auto), SkinMode.night);

      final glyphs = <IconData>{
        TorchSkinCycle.glyphFor(SkinMode.day),
        TorchSkinCycle.glyphFor(SkinMode.night),
      };
      expect(
        glyphs,
        hasLength(2),
        reason: 'two cycle positions, each a different glyph',
      );
    });

    testWidgets('is 56dp in both skins, and asks for the next one', (
      tester,
    ) async {
      SkinMode? asked;
      for (final skin in torchSkins) {
        await pumpTorch(
          tester,
          skin: skin,
          child: Center(
            child: TorchSkinCycle(
              mode: skin.mode,
              onChanged: (m) => asked = m,
              semanticLabel: 'Screen: Day. Double-tap for Night.',
            ),
          ),
        );
        expect(tester.getSize(find.byType(TorchSkinCycle)).width, 56);
        await tester.tap(find.byType(TorchSkinCycle));
        await tester.pump();
        expect(asked, TorchSkinCycle.next(skin.mode));
      }
    });
  });

  group('Thumb zone', () {
    testWidgets('a screen with a primary gets 96dp and a full-bleed rule', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: night,
        claims: <TorchClaim>[TorchPrimaryButton.claim('commit')],
        child: Align(
          alignment: Alignment.bottomCenter,
          child: TorchThumbZone(
            skinCycle: TorchSkinCycle(
              mode: SkinMode.night,
              onChanged: (_) {},
              semanticLabel: 'Screen: Night. Double-tap for Day.',
            ),
            primary: const TorchPrimaryButton(
              claimId: 'commit',
              label: 'Send',
              onPressed: null,
              blockedReason: 'Nothing captured yet.',
            ),
          ),
        ),
      );
      final rect = tester.getRect(find.byType(TorchThumbZone));
      expect(rect.height, greaterThanOrEqualTo(96));
      expect(rect.left, 0, reason: 'the rule crosses the full bleed');
      expect(rect.right, 360);
    });

    testWidgets('a screen with no primary gets 76dp and no rule', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: night,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: TorchThumbZone(
            skinCycle: TorchSkinCycle(
              mode: SkinMode.night,
              onChanged: (_) {},
              semanticLabel: 'Screen: Night. Double-tap for Day.',
            ),
          ),
        ),
      );
      expect(
        tester.getRect(find.byType(TorchThumbZone)).height,
        greaterThanOrEqualTo(76),
      );
      final pixels = await torchPixels(tester);
      final top = tester.getRect(find.byType(TorchThumbZone)).top;
      expect(
        pixels.at(180, top),
        night.palette.ground,
        reason: 'never a rule over nothing',
      );
    });

    testWidgets('an empty zone will not build', (tester) async {
      expect(
        // ignore: prefer_const_constructors
        () => TorchThumbZone(),
        throwsA(isA<AssertionError>()),
      );
    });

    // ── A GHOST ON ITS OWN — 4 October 2026 ─────────────────────────────
    //
    // `TorchShell._bottomRegion` returned null when the primary and the skin
    // cycle were both absent, which dropped a [secondary] on the floor.
    // Nothing bit while it was written: every screen passing a secondary also
    // passed a primary or the cycle. Taking the cycle off the six call sites
    // is the condition that armed it, and two real screens were holding a
    // lone ghost at the time —
    //
    //   * the store picker's **Add a store**, the only way to file a shop
    //     that is not on the agent's list;
    //   * the visit's `locating` phase, whose **Back to my route** is the only
    //     control on the screen. `VisitFrame` passes no header back button, so
    //     losing it leaves an agent on a radar waiting for a GPS fix with no
    //     way off it at all.
    //
    // Both are asserted at the shell, not at the zone: the zone was never the
    // thing that dropped them.
    //
    // Four per-screen tests already fail on the unfixed shell, so this is not
    // the only net. It is the one that states the RULE — a bottom region is
    // dropped only when every slot is empty — rather than restating two
    // screens' current contents, which is what made the defect reachable in
    // the first place.
    testWidgets('a lone secondary still gets a bottom region', (tester) async {
      await pumpTorch(
        tester,
        skin: night,
        child: TorchShell(
          profile: TorchShellProfile.agent,
          header: const TorchAppHeader(title: 'Select an Outlet'),
          secondary: TorchSecondaryButton(
            label: 'Add a store',
            onPressed: () {},
          ),
          children: const <Widget>[SizedBox(height: 400)],
        ),
      );

      expect(
        find.byType(TorchThumbZone),
        findsOneWidget,
        reason: 'a screen whose only action is a ghost still has a bottom '
            'region — dropping it takes the action with it',
      );
      expect(find.text('Add a store'), findsOneWidget);
      expect(
        tester.getSize(find.byType(TorchSecondaryButton)).height,
        greaterThanOrEqualTo(44),
        reason: 'still a tap target',
      );
      // The ghost is the bottom-most thing in the zone, with no empty control
      // row under it: the row is built only when something goes in it.
      final zone = tester.getRect(find.byType(TorchThumbZone));
      final ghost = tester.getRect(find.byType(TorchSecondaryButton));
      expect(
        zone.bottom - ghost.bottom,
        lessThanOrEqualTo(night.space.intraBlock + 1),
        reason: 'no dead gap where the skin cycle used to be',
      );
    });

    testWidgets('an under-primary on its own still gets a bottom region', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: night,
        child: TorchShell(
          profile: TorchShellProfile.agent,
          header: const TorchAppHeader(title: 'Sign in'),
          underPrimary: TorchTertiaryButton(
            label: 'Forgot password?',
            onPressed: () {},
          ),
          children: const <Widget>[SizedBox(height: 400)],
        ),
      );
      expect(find.byType(TorchThumbZone), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('a bottom region with nothing in it does not render', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: night,
        child: const TorchShell(
          profile: TorchShellProfile.agent,
          header: TorchAppHeader(title: 'Contests'),
          children: <Widget>[SizedBox(height: 400)],
        ),
      );
      expect(
        find.byType(TorchThumbZone),
        findsNothing,
        reason: 'an empty strip above the safe area is not a bottom region',
      );
    });
  });

  group('App header', () {
    testWidgets('carries a title, a fact line and one trailing button', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: night,
        child: TorchAppHeader(
          title: 'Kwikspar Tembisa',
          facts: const <String>['Spaza', 'Tembisa Ext 12', '1,2 km'],
          trailing: TorchIconButton(
            icon: Icons.dark_mode_outlined,
            semanticLabel: 'Screen: Night. Double-tap for Day.',
            onPressed: () {},
          ),
        ),
      );
      expect(find.text('Kwikspar Tembisa'), findsOneWidget);
      expect(find.text('Spaza · Tembisa Ext 12 · 1,2 km'), findsOne);
      expect(find.byType(TorchIconButton), findsOneWidget);
      expect(
        find.bySemanticsLabel('Spaza, Tembisa Ext 12, 1,2 km'),
        findsOneWidget,
        reason:
            'a screen reader hears a sentence; nobody wants to hear "middot" '
            'three times',
      );
    });

    testWidgets('caps the flag chips at two rows and offers an expander', (
      tester,
    ) async {
      final chips = <Widget>[
        for (var i = 0; i < 12; i++)
          SizedBox(
            width: 120,
            height: 28,
            child: ColoredBox(color: night.palette.well, child: Text('f$i')),
          ),
      ];
      await pumpTorch(
        tester,
        skin: night,
        child: TorchAppHeader(title: 'Flags', flagChips: chips),
      );
      // The hidden count is published after layout, so the expander's label
      // arrives on the next frame.
      await tester.pump();

      expect(find.text('and 8 more'), findsOneWidget);
      final capped = tester.getSize(find.byType(TorchChipWrap)).height;
      expect(
        capped,
        28 * 2 + 12,
        reason: 'two rows of 28dp chips and one 12dp run gap — and no more',
      );

      await tester.tap(find.text('and 8 more'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Show fewer'), findsOneWidget);
      expect(
        tester.getSize(find.byType(TorchChipWrap)).height,
        greaterThan(capped),
        reason: 'the expander opens the rest in place',
      );
    });
  });

  group('Shell', () {
    testWidgets('a tab root floats the nav row and has no thumb zone', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: night,
        navRenders: true,
        tabbedRoute: true,
        claims: <TorchClaim>[TorchNavCircle.claim('unplanned-visit')],
        child: TorchShell(
          profile: TorchShellProfile.agent,
          header: const TorchAppHeader(title: 'Today'),
          navPill: TorchNavPill(
            slots: agentSlots,
            activeIndex: 0,
            onSelect: (_) {},
          ),
          navCircle: navCircle(),
          children: const <Widget>[SizedBox(height: 400)],
        ),
      );
      expect(find.byType(TorchThumbZone), findsNothing);
      final pill = tester.getRect(find.byType(TorchNavPill));
      final circle = tester.getRect(find.byType(TorchNavCircle));
      expect(
        circle.left - pill.right,
        TorchNavCircle.gap,
        reason: '12dp, and outside the bar',
      );
      expect(circle.width, 64);
    });

    testWidgets('a screen with a primary gets a thumb zone and no nav', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: night,
        claims: <TorchClaim>[TorchPrimaryButton.claim('commit')],
        child: TorchShell(
          profile: TorchShellProfile.agent,
          header: const TorchAppHeader(title: 'Submit'),
          skinCycle: TorchSkinCycle(
            mode: SkinMode.night,
            onChanged: (_) {},
            semanticLabel: 'Screen: Night. Double-tap for Day.',
          ),
          primary: TorchPrimaryButton(
            claimId: 'commit',
            label: 'Send',
            onPressed: () {},
          ),
          children: const <Widget>[SizedBox(height: 400)],
        ),
      );
      expect(find.byType(TorchThumbZone), findsOneWidget);
      expect(find.byType(TorchNavPill), findsNothing);
    });

    testWidgets('a nav and a primary on one route will not build', (
      tester,
    ) async {
      expect(
        () => TorchShell(
          profile: TorchShellProfile.agent,
          navPill: TorchNavPill(
            slots: agentSlots,
            activeIndex: 0,
            onSelect: (_) {},
          ),
          primary: TorchPrimaryButton(
            claimId: 'commit',
            label: 'Send',
            onPressed: () {},
          ),
          children: const <Widget>[],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    testWidgets('the keyboard takes the nav away — and says so', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360, 720)
        ..devicePixelRatio = 1.0
        ..viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 720),
            viewInsets: EdgeInsets.only(bottom: 280),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Theme(
              data: ThemeData(extensions: <ThemeExtension<dynamic>>[night]),
              child: Builder(
                builder: (context) {
                  expect(
                    TorchShell.navWillRender(context, hasNav: true),
                    isFalse,
                    reason:
                        'and a route asks this same question when it builds '
                        'its TorchScope, so the grant the nav gave up goes '
                        'back to the content',
                  );
                  return TorchShell(
                    profile: TorchShellProfile.agent,
                    navPill: TorchNavPill(
                      slots: agentSlots,
                      activeIndex: 0,
                      onSelect: (_) {},
                    ),
                    children: const <Widget>[SizedBox(height: 100)],
                  );
                },
              ),
            ),
          ),
        ),
      );
      expect(find.byType(TorchNavPill), findsNothing);
    });

    testWidgets('the console gutter widens past 1080dp', (tester) async {
      final console = TiqSkin.night();
      expect(console.space.gutterFor(360).left, 20);
      expect(console.space.gutterFor(1200).left, 40);
    });
  });
}
