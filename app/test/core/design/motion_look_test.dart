import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/motion_budget.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/router/torch_page.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/core/widgets/torchlight/section_rule.dart';

import '../../features/agent_harness.dart' show loadAgentFonts;

/// MOTION, AS FRAMES — because a still image cannot show it and a description
/// of an easing curve is not a thing anyone can judge.
///
/// Each sequence is the same animation sampled at 0 / 25 / 50 / 75 / 100 per
/// cent of its own duration, named so that `ls` prints them in order. Put them
/// side by side and you are looking at the animation.
///
/// | sequence | what it shows | duration |
/// |---|---|---|
/// | `1-peer` | tapping a nav tab: Today → My work, shared axis horizontal | `TiqMotion.reveal` |
/// | `2-forward` | going into the capture flow: a tab root → a screen with no nav, shared axis scaled | `TiqMotion.reveal` |
/// | `3-navfade` | the nav's grant withdrawn and handed back — a sheet opening over a tab root | `TiqMotion.press` |
/// | `4-reduced` | the same peer change with `disableAnimations` on: a cross-fade, never a slide | `TiqMotion.reveal` |
///
/// **`1-peer` is also the nav-tab sequence, and that is the honest answer
/// rather than a dodge.** The pill does not travel between slots and cannot:
/// every screen builds its own `TorchNavPill` with a constant `activeIndex`,
/// so a tab change is a page change. Watch the lit pill in the four `1-peer`
/// frames — it is under *Today* in the outgoing bar and under *My work* in the
/// incoming one, and the two bars cross over the ground. Making one pill slide
/// between them needs the bar to outlive the route.
///
/// ## Why it does not run in CI
///
/// The reason `floor_look_test.dart` gives: CI rasterises anti-aliased Schibsted Grotesk
/// on `ubuntu-latest` and this repository is developed on macOS, so a pixel
/// comparison fails on the day it lands. These are an artefact to *look at*.
/// The pins are `motion_amber_test.dart` and `torch_page_test.dart`, which run
/// everywhere.
///
/// ```sh
/// MOTION_LOOK=1 MOTION_LOOK_DIR=/somewhere/ flutter test \
///   test/core/design/motion_look_test.dart --update-goldens
/// ```
const Key _boundary = ValueKey<String>('motion-look-boundary');

const List<int> _percents = <int>[0, 25, 50, 75, 100];

const List<TorchNavSlot> _slots = <TorchNavSlot>[
  TorchNavSlot(
    icon: Icons.today_outlined,
    activeIcon: Icons.today,
    label: 'Today',
  ),
  TorchNavSlot(
    icon: Icons.checklist_outlined,
    activeIcon: Icons.checklist,
    label: 'My work',
  ),
  TorchNavSlot(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'Map'),
  TorchNavSlot(
    icon: Icons.person_outline,
    activeIcon: Icons.person,
    label: 'Me',
  ),
];

/// A tab root: the nav bar, the standing circle, and enough body to see the
/// page move under the chrome.
Widget _tabRoot({required int activeIndex, required String title}) =>
    TorchShell(
      profile: TorchShellProfile.agent,
      header: TorchAppHeader(
        title: title,
        facts: const <String>['Thursday 18 September', 'Tembisa run'],
      ),
      navPill: TorchNavPill(
        slots: _slots,
        activeIndex: activeIndex,
        onSelect: (_) {},
      ),
      navCircle: TorchNavCircle(
        claimId: 'unplanned-visit',
        expected: true,
        icon: Icons.add,
        expectedIcon: Icons.arrow_forward,
        semanticLabel: 'Start a visit somewhere else',
        expectedSemanticLabel: 'Start a visit here',
        onPressed: () {},
      ),
      children: <Widget>[
        const SectionRule('Next up'),
        const SizedBox(height: TiqSpace.s5),
        for (var i = 0; i < 4; i++) ...<Widget>[
          _Row(label: '$title — row ${i + 1}'),
          const SizedBox(height: TiqSpace.s3),
        ],
      ],
    );

/// A screen with no nav bar: the other side of the rule that picks a kind.
Widget _pushed() => TorchShell(
  profile: TorchShellProfile.agent,
  header: const TorchAppHeader(
    title: 'Pick a store',
    facts: <String>['412 outlets'],
  ),
  children: <Widget>[
    const SectionRule('Nearby'),
    const SizedBox(height: TiqSpace.s5),
    for (var i = 0; i < 4; i++) ...<Widget>[
      _Row(label: 'Store ${i + 1}'),
      const SizedBox(height: TiqSpace.s3),
    ],
  ],
);

class _Row extends StatelessWidget {
  const _Row({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      height: 64,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: TiqSpace.s4),
      decoration: BoxDecoration(
        color: skin.palette.surface,
        borderRadius: BorderRadius.circular(skin.radii.card),
      ),
      child: Text(label, style: skin.text.body.style(color: skin.palette.ink1)),
    );
  }
}

void main() {
  final looking = Platform.environment['MOTION_LOOK'] == '1';
  final dir = Platform.environment['MOTION_LOOK_DIR'] ?? 'goldens/';

  setUpAll(() async {
    await loadAgentFonts();
    await _loadIcons();
  });

  const phone = Size(390, 844);

  Widget harness({
    required TiqSkin skin,
    required Widget child,
    required bool beneathSheet,
    required bool reduced,
  }) => MediaQuery(
    data: MediaQueryData(
      size: phone,
      devicePixelRatio: 1.0,
      disableAnimations: reduced,
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Localizations(
        locale: const Locale('en'),
        delegates: const <LocalizationsDelegate<dynamic>>[
          DefaultWidgetsLocalizations.delegate,
          DefaultMaterialLocalizations.delegate,
        ],
        child: Theme(
          data: AppTheme.torchlight(skin),
          child: MotionBudgetScope(
            budget: reduced ? MotionBudget.frozen : MotionBudget.moving,
            child: RepaintBoundary(
              key: _boundary,
              child: ColoredBox(
                color: skin.palette.ground,
                child: SizedBox.fromSize(
                  size: phone,
                  child: TorchScope(
                    skin: skin,
                    phase: 'motion-look',
                    navRenders: true,
                    tabbedRoute: true,
                    beneathSheet: beneathSheet,
                    claims: const <TorchClaim>[
                      TorchClaim.navCircle('unplanned-visit'),
                    ],
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  /// Drive one `torchPage` transition through a plain `Navigator` and write a
  /// frame at each percentage. `CustomTransitionPage` is a `Page`, so this is
  /// the real helper and not a re-implementation of it.
  Future<void> shootTransition(
    WidgetTester tester, {
    required String name,
    required TiqSkin skin,
    required String skinName,
    required TorchPageKind kind,
    required Widget from,
    required Widget to,
    bool reduced = false,
  }) async {
    tester.view
      ..physicalSize = phone
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var second = false;
    late StateSetter setSecond;

    Widget navigator() => StatefulBuilder(
      builder: (context, setState) {
        setSecond = setState;
        return Navigator(
          pages: <Page<void>>[
            torchPage(
              second ? to : from,
              key: ValueKey<bool>(second),
              kind: kind,
            ),
          ],
          onDidRemovePage: (_) {},
        );
      },
    );

    await tester.pumpWidget(
      harness(
        skin: skin,
        child: navigator(),
        beneathSheet: false,
        reduced: reduced,
      ),
    );
    await tester.pumpAndSettle();

    setSecond(() => second = true);
    await tester.pump();

    var elapsed = Duration.zero;
    for (final percent in _percents) {
      final target = TiqMotion.reveal * (percent / 100);
      await tester.pump(target - elapsed);
      elapsed = target;
      await expectLater(
        find.byKey(_boundary),
        matchesGoldenFile(
          '$dir$name-$skinName-${percent.toString().padLeft(3, '0')}.png',
        ),
      );
    }
    await tester.pumpAndSettle();
  }

  for (final (skinName, skin) in <(String, TiqSkin)>[
    ('night', TiqSkin.night(density: TiqDensity.field)),
    ('day', TiqSkin.day()),
  ]) {
    // ── 1. A nav-tab change, which is a peer page change ──────────────────
    testWidgets('1-peer — Today to My work, $skinName', (tester) async {
      await shootTransition(
        tester,
        name: '1-peer',
        skin: skin,
        skinName: skinName,
        kind: TorchPageKind.peer,
        from: _tabRoot(activeIndex: 0, title: 'Today'),
        to: _tabRoot(activeIndex: 1, title: 'My work'),
      );
    }, skip: !looking);

    // ── 2. Into the capture flow ──────────────────────────────────────────
    testWidgets('2-forward — a tab root into a pushed screen, $skinName', (
      tester,
    ) async {
      await shootTransition(
        tester,
        name: '2-forward',
        skin: skin,
        skinName: skinName,
        kind: TorchPageKind.forward,
        from: _tabRoot(activeIndex: 0, title: 'Today'),
        to: _pushed(),
      );
    }, skip: !looking);

    // ── 3. The nav's own fade: a sheet takes the grant ────────────────────
    //
    // The one piece of chrome motion that is NOT a page change. In Night the
    // active tab crosses from Burning Flame to the Abyssal block and the
    // standing circle goes out with it; in Day there is no amber to lose and
    // the fade is the press/Abyssal pair alone — which is worth seeing, since
    // "Day has nothing to show here" is itself a claim.
    testWidgets('3-navfade — the grant withdrawn, $skinName', (tester) async {
      tester.view
        ..physicalSize = phone
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Widget frame(bool beneathSheet) => harness(
        skin: skin,
        child: _tabRoot(activeIndex: 0, title: 'Today'),
        beneathSheet: beneathSheet,
        reduced: false,
      );

      await tester.pumpWidget(frame(false));
      await tester.pumpAndSettle();
      await tester.pumpWidget(frame(true));

      var elapsed = Duration.zero;
      for (final percent in _percents) {
        final target = TiqMotion.press * (percent / 100);
        await tester.pump(target - elapsed);
        elapsed = target;
        await expectLater(
          find.byKey(_boundary),
          matchesGoldenFile(
            '${dir}3-navfade-$skinName-'
            '${percent.toString().padLeft(3, '0')}.png',
          ),
        );
      }
      await tester.pumpAndSettle();
    }, skip: !looking);

    // ── 4. The same tab change, for somebody who asked for less motion ────
    testWidgets(
      '4-reduced — the peer change under reduced motion, $skinName',
      (tester) async {
        await shootTransition(
          tester,
          name: '4-reduced',
          skin: skin,
          skinName: skinName,
          kind: TorchPageKind.peer,
          from: _tabRoot(activeIndex: 0, title: 'Today'),
          to: _tabRoot(activeIndex: 1, title: 'My work'),
          reduced: true,
        );
      },
      skip: !looking,
    );
  }
}

/// Material's icon font, so a glyph is a glyph and not a box.
Future<void> _loadIcons() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  final cache = root != null
      ? Directory('$root/bin/cache')
      : File(Platform.resolvedExecutable).parent.parent.parent;
  final font = File(
    '${cache.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!font.existsSync()) return;
  await (FontLoader(
    'MaterialIcons',
  )..addFont(font.readAsBytes().then((b) => ByteData.view(b.buffer)))).load();
}
