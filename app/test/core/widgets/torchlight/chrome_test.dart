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
    testWidgets('Night and Day float: 64 tall, radius 999, opaque well', (
      tester,
    ) async {
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
        expect(
          pixels.at(rect.center.dx, rect.top + 0.5),
          skin.palette.edgeStructure,
          reason: 'a 1px edge-structure outline, not a frosted edge',
        );
        expect(
          pixels.at(rect.left + 1, rect.top + 1),
          skin.palette.ground,
          reason:
              'radius 999: the bar does not reach into its own top-left '
              'corner, so that pixel is still the ground',
        );
      }
    });

    testWidgets('Veld docks: full bleed, 72 tall, 2px top border, radius 0', (
      tester,
    ) async {
      final veld = TiqSkin.veld();
      await pumpTorch(
        tester,
        skin: veld,
        navRenders: true,
        tabbedRoute: true,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: TorchNavPill(
            slots: agentSlots,
            activeIndex: 0,
            onSelect: (_) {},
          ),
        ),
      );
      final rect = tester.getRect(find.byType(TorchNavPill));
      expect(rect.height, 72);
      expect(rect.left, 0, reason: 'full bleed');
      expect(rect.right, 360);

      final pixels = await torchPixels(tester);
      expect(
        pixels.at(rect.left + 1, rect.top + 1),
        veld.palette.edgeStructure,
        reason:
            'radius 0 and a 2px top border: the corner pixel is the border. '
            'A white pill floating on white under glare stops reading as a '
            'bar, and Veld has no radius but 0.',
      );
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
    testWidgets('Night lights it amber, and takes the grant from TorchScope', (
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
            activeIndex: 1,
            onSelect: (_) {},
          ),
        ),
      );
      final slot = tester.getRect(find.text('Work'));
      final pixels = await torchPixels(tester);
      expect(
        pixels.at(slot.right + 10, slot.center.dy),
        night.palette.flame600,
      );
    });

    testWidgets('a sheet above the route puts the tab out', (tester) async {
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
      final slot = tester.getRect(find.text('Work'));
      final pixels = await torchPixels(tester);
      expect(
        pixels.at(slot.right + 10, slot.center.dy),
        night.palette.lifted,
        reason:
            'the tab drops to its ink form — an Abyssal block — so the sheet '
            'genuinely owns the screen at a 72% scrim',
      );
    });

    testWidgets('Day and Veld use an Abyssal block, never amber', (
      tester,
    ) async {
      for (final skin in <TiqSkin>[TiqSkin.day(), TiqSkin.veld()]) {
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
        final slot = tester.getRect(find.text('Work'));
        final pixels = await torchPixels(tester);
        expect(
          pixels.at(slot.right + 10, slot.center.dy),
          skin.palette.lifted,
          reason:
              '${skin.mode.name}: on a light ground amber is a carrier of '
              'ink, and the one object allowed to be that is the primary.',
        );
      }
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
      expect(pixels.at(rect.center.dx, rect.top + 6), night.palette.flame600);
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
          skin: TiqSkin.veld(),
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
    testWidgets('one glyph per skin, and the cycle is Day, Veld, Night', (
      tester,
    ) async {
      expect(TorchSkinCycle.next(SkinMode.day), SkinMode.veld);
      expect(TorchSkinCycle.next(SkinMode.veld), SkinMode.night);
      expect(TorchSkinCycle.next(SkinMode.night), SkinMode.day);

      final glyphs = <IconData>{
        TorchSkinCycle.glyphFor(SkinMode.day),
        TorchSkinCycle.glyphFor(SkinMode.veld),
        TorchSkinCycle.glyphFor(SkinMode.night),
      };
      expect(
        glyphs,
        hasLength(3),
        reason: 'three cycle positions, each a different glyph',
      );
    });

    testWidgets('is 56dp, 64 in Veld, and asks for the next skin', (
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
              semanticLabel: 'Screen: Day. Double-tap for Veld.',
            ),
          ),
        );
        final size = tester.getSize(find.byType(TorchSkinCycle));
        expect(size.width, skin.mode == SkinMode.veld ? 64 : 56);
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
