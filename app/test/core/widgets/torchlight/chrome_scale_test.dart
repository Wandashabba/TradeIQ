import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';

import 'chrome_test.dart' show agentSlots;
import 'torch_harness.dart';

/// 2.0× TEXT, THROUGHOUT.
///
/// The audit found no `textScale` handling anywhere in the app, which meant the
/// app's behaviour at the OS's largest font setting was whatever the layouts
/// happened to do. Every region in this folder is a **minimum height**, nothing
/// is pinned, and the two places where growth is not an option — the nav bar
/// and the header — have an explicit answer instead: the bar measures its
/// labels and drops them all, and the header caps its title, its facts and its
/// chips.
///
/// 640dp is a cheap Android's logical height and 40% of it is 256dp.
const double viewportHeight = 640;
const double headerCeiling = viewportHeight * 0.4;

void main() {
  final night = TiqSkin.night(density: TiqDensity.field);

  group('the header stays inside the 40% ceiling', () {
    testWidgets('Afrikaans, at 2.0×, with a back button and facts', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: night,
        size: const Size(360, viewportHeight),
        textScale: 2.0,
        locale: const Locale('af'),
        child: Align(
          alignment: Alignment.topCenter,
          child: TorchAppHeader(
            title: 'Besoek ’n winkel wat nie op my roete is nie',
            facts: const <String>[
              'Spaza',
              'Tembisa Uitbreiding 12',
              '1,2 km',
              'laas besoek 12 Aug',
            ],
            back: TorchIconButton(
              icon: Icons.arrow_back,
              semanticLabel: 'Terug na Vandag',
              onPressed: () {},
            ),
            trailing: TorchIconButton(
              icon: Icons.dark_mode_outlined,
              semanticLabel: 'Skerm: Nag. Dubbeltik vir Dag.',
              onPressed: () {},
            ),
          ),
        ),
      );

      final height = tester.getSize(find.byType(TorchAppHeader)).height;
      expect(
        height,
        lessThanOrEqualTo(headerCeiling),
        reason:
            'unify §4: "Headers cap at 40% of the viewport, then scroll." The '
            'cap is not a runtime measurement — it is the title capped at two '
            'lines, the facts at two, and the chips at two rows. This is the '
            'test that keeps those three caps honest, in the language and at '
            'the scale that broke it: an Afrikaans subtitle at 2.0× was '
            'measured taking 130dp of a 640dp viewport on its own.',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('and the header scrolls rather than pinning', (tester) async {
      await pumpTorch(
        tester,
        skin: night,
        size: const Size(360, viewportHeight),
        textScale: 2.0,
        child: TorchShell(
          profile: TorchShellProfile.agent,
          header: const TorchAppHeader(
            title: 'Besoek ’n winkel wat nie op my roete is nie',
            facts: <String>['Spaza', 'Tembisa Uitbreiding 12'],
          ),
          children: <Widget>[
            for (var i = 0; i < 20; i++) const SizedBox(height: 64),
          ],
        ),
      );
      final before = tester.getRect(find.byType(TorchAppHeader)).top;
      await tester.drag(find.byType(TorchShell), const Offset(0, -200));
      await tester.pump();
      expect(
        tester.getRect(find.byType(TorchAppHeader)).top,
        lessThan(before),
        reason:
            'the header is the first thing in the scroll view, so the body '
            'always gets the fold back. That is what "then scroll" means, and '
            'it is why the 40% number never has to be measured at runtime.',
      );
    });
  });

  group('the nav bar', () {
    testWidgets('goes icon-only as a whole at 2.0×', (tester) async {
      await pumpTorch(
        tester,
        skin: night,
        size: const Size(360, viewportHeight),
        textScale: 2.0,
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
      for (final slot in agentSlots) {
        expect(
          find.text(slot.label),
          findsNothing,
          reason: '${slot.label} is measured out, along with all the others',
        );
      }
      expect(find.byType(TorchGlyph), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the active slot is still a different silhouette', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: night,
        size: const Size(360, viewportHeight),
        textScale: 2.0,
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
      final glyphs = tester
          .widgetList<TorchGlyph>(find.byType(TorchGlyph))
          .toList();
      expect(glyphs.first.icon, agentSlots.first.activeIcon);
      expect(glyphs[1].icon, agentSlots[1].icon);
      expect(
        agentSlots.first.activeIcon,
        isNot(agentSlots.first.icon),
        reason:
            'icon-only removes the label and its 700 weight, so if the glyph '
            'did not change then "selected" would be carried by the amber '
            'fill alone — and colour is never the only signal.',
      );
    });

    testWidgets('its glyphs grow, but not past the pill that holds them', (
      tester,
    ) async {
      await pumpTorch(
        tester,
        skin: night,
        size: const Size(360, viewportHeight),
        textScale: 2.0,
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
      final glyph = tester.widget<TorchGlyph>(find.byType(TorchGlyph).first);
      expect(glyph.size, 32, reason: '24 scales up, capped at 32');
      expect(
        tester.getSize(find.byType(TorchNavPill)).height,
        64,
        reason: 'icon-only, so the bar does not need to grow at all',
      );
    });
  });

  group('the controls', () {
    testWidgets('a primary grows rather than ellipsising its verb', (
      tester,
    ) async {
      final heights = <double, double>{};
      for (final scale in <double>[1.0, 2.0]) {
        await pumpTorch(
          tester,
          skin: night,
          size: const Size(360, viewportHeight),
          textScale: scale,
          claims: const <TorchClaim>[TorchClaim.primaryCommit('commit')],
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(TiqSpace.s5),
              child: TorchPrimaryButton(
                claimId: 'commit',
                label: 'Stuur hierdie besoek',
                onPressed: () {},
              ),
            ),
          ),
        );
        heights[scale] = tester.getSize(find.byType(TorchPrimaryButton)).height;
        final text = tester.widget<Text>(find.text('Stuur hierdie besoek'));
        expect(
          text.overflow,
          isNot(TextOverflow.ellipsis),
          reason: 'a verb the reader cannot read is not a verb',
        );
        expect(text.softWrap, isTrue);
        expect(tester.takeException(), isNull);
      }
      expect(heights[1.0], greaterThanOrEqualTo(56));
      expect(
        heights[2.0]!,
        greaterThan(heights[1.0]!),
        reason: 'never pinned to 56 — it grows to intrinsic height',
      );
    });

    testWidgets('the skin cycle grows from 56 to 72', (tester) async {
      for (final entry in <double, double>{1.0: 56, 2.0: 72}.entries) {
        await pumpTorch(
          tester,
          skin: night,
          textScale: entry.key,
          child: Center(
            child: TorchSkinCycle(
              mode: SkinMode.night,
              onChanged: (_) {},
              semanticLabel: 'Screen: Night. Double-tap for Day.',
            ),
          ),
        );
        expect(tester.getSize(find.byType(TorchSkinCycle)).width, entry.value);
      }
    });

    testWidgets('an icon button keeps its glyph and grows its target', (
      tester,
    ) async {
      for (final entry in <double, double>{1.0: 48, 2.0: 56}.entries) {
        await pumpTorch(
          tester,
          skin: night,
          textScale: entry.key,
          child: Center(
            child: TorchIconButton(
              icon: Icons.close,
              semanticLabel: 'Close this sheet',
              onPressed: () {},
            ),
          ),
        );
        expect(tester.getSize(find.byType(TorchIconButton)).width, entry.value);
        expect(
          tester.widget<TorchGlyph>(find.byType(TorchGlyph)).size,
          24,
          reason:
              'a chevron is not a word; the target grows, the glyph does not',
        );
      }
    });

    testWidgets('the thumb zone grows with what it holds', (tester) async {
      final heights = <double, double>{};
      for (final scale in <double>[1.0, 2.0]) {
        await pumpTorch(
          tester,
          skin: night,
          size: const Size(360, viewportHeight),
          textScale: scale,
          claims: const <TorchClaim>[TorchClaim.primaryCommit('commit')],
          child: Align(
            alignment: Alignment.bottomCenter,
            child: TorchThumbZone(
              skinCycle: TorchSkinCycle(
                mode: SkinMode.night,
                onChanged: (_) {},
                semanticLabel: 'Screen: Night. Double-tap for Day.',
              ),
              primary: TorchPrimaryButton(
                claimId: 'commit',
                label: 'Stuur hierdie besoek',
                onPressed: () {},
              ),
            ),
          ),
        );
        heights[scale] = tester.getSize(find.byType(TorchThumbZone)).height;
        expect(tester.takeException(), isNull);
      }
      expect(heights[1.0], greaterThanOrEqualTo(96));
      expect(heights[2.0]!, greaterThan(heights[1.0]!));
    });
  });

  group('the whole frame at 2.0×', () {
    testWidgets('lays out in every skin with nothing overflowing', (
      tester,
    ) async {
      for (final skin in torchSkins) {
        await pumpTorch(
          tester,
          skin: skin,
          size: const Size(360, viewportHeight),
          textScale: 2.0,
          navRenders: true,
          tabbedRoute: true,
          claims: const <TorchClaim>[TorchClaim.navCircle('unplanned-visit')],
          child: TorchShell(
            profile: TorchShellProfile.agent,
            header: TorchAppHeader(
              title: 'Vandag',
              facts: const <String>['4 van 7 winkels', '12 km'],
              trailing: TorchIconButton(
                icon: Icons.wb_sunny_outlined,
                semanticLabel: 'Skerm: Veld.',
                onPressed: () {},
              ),
            ),
            navPill: TorchNavPill(
              slots: agentSlots,
              activeIndex: 0,
              onSelect: (_) {},
            ),
            navCircle: TorchNavCircle(
              claimId: 'unplanned-visit',
              expected: true,
              icon: Icons.add,
              expectedIcon: Icons.arrow_forward,
              semanticLabel: 'Begin ’n besoek êrens anders',
              expectedSemanticLabel: 'Begin ’n besoek hier',
              onPressed: () {},
            ),
            children: <Widget>[
              for (var i = 0; i < 6; i++) const SizedBox(height: 64),
            ],
          ),
        );
        expect(
          tester.takeException(),
          isNull,
          reason: '${skin.mode.name} overflowed at 2.0×',
        );
        expect(
          tester.getSize(find.byType(TorchNavCircle)).width,
          64,
          reason: 'the circle stays 64 at every scale',
        );
      }
    });
  });
}
