import 'package:flutter/material.dart'
    show DefaultMaterialLocalizations, Icons, Theme, ThemeData, ThemeExtension;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/motion_budget.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/router/torch_page.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';

import 'amber_golden.dart';

/// THE AMBER CENSUS, ACROSS AN ANIMATION RATHER THAN AT REST.
///
/// Every other census in this repository renders a settled frame. That is the
/// right thing to pin and the wrong thing to stop at: the budget is a promise
/// about what a person's eye meets, and a person's eye meets the frames in
/// between. An animation that painted a third light for 80ms would pass every
/// existing test in the tree and still be a bug — the ladder says two, and
/// "two, except while something is moving" is not a budget.
///
/// Two motions are checked, at 0 / 25 / 50 / 75 / 100 per cent:
///
/// 1. **The chrome's state fade.** The nav's active tab and the standing
///    circle cross from amber to their unlit forms when a sheet takes the
///    grant away, and back when it closes. 120ms, `TiqMotion.press`.
///
/// 2. **A page transition between two tab roots**, which is the one that
///    genuinely could have gone wrong: for the length of the transition
///    **two** routes are mounted, so two nav bars and two standing circles are
///    in the tree at once — four amber objects' worth of widget against a
///    Night budget of two.
///
/// The second passes for a reason worth writing down rather than being lucky
/// about. The census counts *emitted light*: hue 20–48°, saturation ≥ 0.12 and
/// **value ≥ 0.90**. A fading page is composited over `skin.palette.ground`,
/// and Burning Flame at even 80% over a `#0B1017` ground has already fallen to
/// value ≈ 0.82. It leaves the census before it leaves the screen. That is the
/// same value floor the harness's own doc comment justifies for a bloom's tail
/// — "counting a halo as a second light is how a budget check gets switched
/// off for being noisy" — and it is doing the identical job here.
const List<double> _steps = <double>[0.0, 0.25, 0.5, 0.75, 1.0];

/// A Night tab root that spends the whole budget at rest: the nav's active tab
/// (slot 1, granted whenever the nav renders) plus the standing circle (rung 4,
/// admissible because there is no primary commit on this route).
Widget _tabRoot({required int activeIndex}) => TorchShell(
  profile: TorchShellProfile.agent,
  header: const TorchAppHeader(title: 'Today'),
  navPill: TorchNavPill(
    slots: const <TorchNavSlot>[
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
      TorchNavSlot(
        icon: Icons.map_outlined,
        activeIcon: Icons.map,
        label: 'Map',
      ),
      TorchNavSlot(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'Me',
      ),
    ],
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
  children: const <Widget>[SizedBox(height: TiqSpace.s7)],
);

const _claims = <TorchClaim>[TorchClaim.navCircle('unplanned-visit')];

void main() {
  const size = Size(360, 720);

  Widget frame(TiqSkin skin, {required bool beneathSheet, Widget? child}) {
    Widget tree = TorchScope(
      skin: skin,
      phase: 'motion',
      navRenders: true,
      tabbedRoute: true,
      beneathSheet: beneathSheet,
      claims: _claims,
      child: child ?? _tabRoot(activeIndex: 0),
    );
    tree = RepaintBoundary(
      // The key the amber harness reads back from.
      key: const ValueKey<String>('amber-golden-boundary'),
      child: ColoredBox(
        color: skin.palette.ground,
        child: SizedBox.fromSize(size: size, child: tree),
      ),
    );
    // MOVING, explicitly. Every other harness in this tree pins `frozen` to
    // photograph the resting frame; this file exists to photograph the frames
    // in between, so it has to ask for them.
    tree = MotionBudgetScope(budget: MotionBudget.moving, child: tree);
    tree = Theme(
      data: ThemeData(extensions: <ThemeExtension<dynamic>>[skin]),
      child: tree,
    );
    tree = Localizations(
      locale: const Locale('en'),
      delegates: const <LocalizationsDelegate<dynamic>>[
        DefaultWidgetsLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
      ],
      child: tree,
    );
    tree = Directionality(textDirection: TextDirection.ltr, child: tree);
    return MediaQuery(
      data: const MediaQueryData(size: size, devicePixelRatio: 1.0),
      child: tree,
    );
  }

  group('the chrome state fade', () {
    for (final withdraw in <bool>[true, false]) {
      testWidgets(
        withdraw
            ? 'stays inside the budget while the grant is taken away'
            : 'stays inside the budget while the grant comes back',
        (tester) async {
          final skin = TiqSkin.night(density: TiqDensity.field);
          tester.view
            ..physicalSize = size
            ..devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(frame(skin, beneathSheet: !withdraw));
          await tester.pumpAndSettle();

          // Flip it. Nothing has moved yet: this is 0%.
          await tester.pumpWidget(frame(skin, beneathSheet: withdraw));

          var elapsed = Duration.zero;
          for (final step in _steps) {
            final target = TiqMotion.press * step;
            await tester.pump(target - elapsed);
            elapsed = target;
            final census = await amberCensus(tester);
            expectWithinAmberBudget(
              census,
              skin,
              route: 'agent tab root',
              phase:
                  '${withdraw ? 'grant withdrawn' : 'grant restored'} '
                  '${(step * 100).round()}%',
            );
          }
        },
      );
    }
  });

  group('a page transition between two tab roots', () {
    testWidgets('never paints a third light, at any point in the 320ms', (
      tester,
    ) async {
      final skin = TiqSkin.night(density: TiqDensity.field);
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      var index = 0;
      late StateSetter setIndex;

      Widget navigator() => StatefulBuilder(
        builder: (context, setState) {
          setIndex = setState;
          return Navigator(
            pages: <Page<void>>[
              // `CustomTransitionPage` is a `Page`, so the real helper drives
              // a plain `Navigator` here without a router in the way.
              torchPage(
                _tabRoot(activeIndex: index),
                key: ValueKey<int>(index),
              ),
            ],
            onDidRemovePage: (_) {},
          );
        },
      );

      await tester.pumpWidget(
        frame(skin, beneathSheet: false, child: navigator()),
      );
      await tester.pumpAndSettle();

      setIndex(() => index = 1);
      await tester.pump();

      var elapsed = Duration.zero;
      final counts = <int>[];
      for (final step in _steps) {
        final target = TiqMotion.reveal * step;
        await tester.pump(target - elapsed);
        elapsed = target;
        final census = await amberCensus(tester);
        counts.add(census.objectCount);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'agent tab root -> agent tab root',
          phase: 'shared axis ${(step * 100).round()}%',
        );
      }

      // And the point of the test, stated positively: two routes were mounted
      // for the whole of that and the frame never carried more light than one
      // of them is allowed on its own.
      expect(
        counts.every((c) => c <= TorchScope.budgetFor(skin)),
        isTrue,
        reason: 'object counts across the transition were $counts',
      );
      await tester.pumpAndSettle();
    });
  });
}
