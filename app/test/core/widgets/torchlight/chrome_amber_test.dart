import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';

import '../../design/amber_golden.dart';
import 'chrome_test.dart' show agentSlots;
import 'torch_harness.dart';

/// THE CENSUS FOR A REAL FRAME.
///
/// [TorchScope] asserts that a route does not *claim* too much amber. This
/// counts what the Phase 1 chrome actually *paints*, on the one arrangement
/// the arithmetic in unify §1.1 is written about: a Night tab root with the nav
/// on screen and a commit action in its body.
///
/// It is the agent's Today screen, in miniature — the nav pill at the bottom
/// and "Check in here" on the next-up row. Two lit objects, which is exactly
/// the budget: the nav's active tab is slot 1 whenever the nav renders, and the
/// primary takes the single content grant a tabbed route has left.
///
/// The nav circle is declared as well, and loses — not on budget but by rule,
/// because rung 4 is inadmissible on a route with a primary commit.
Widget tabRootWithPrimary({bool circleExpected = true}) => TorchShell(
  profile: TorchShellProfile.agent,
  header: const TorchAppHeader(
    title: 'Today',
    facts: <String>['4 of 7 stores', '12 km'],
  ),
  navPill: TorchNavPill(slots: agentSlots, activeIndex: 0, onSelect: (_) {}),
  navCircle: TorchNavCircle(
    claimId: 'unplanned-visit',
    expected: circleExpected,
    icon: Icons.add,
    expectedIcon: Icons.arrow_forward,
    semanticLabel: 'Start a visit somewhere else',
    expectedSemanticLabel: 'Start a visit here',
    onPressed: () {},
  ),
  children: <Widget>[
    const SizedBox(height: TiqSpace.s7),
    TorchPrimaryButton(
      claimId: 'check-in',
      label: 'Check in here',
      onPressed: () {},
    ),
  ],
);

const routeClaims = <TorchClaim>[
  TorchClaim.primaryCommit('check-in'),
  TorchClaim.navCircle('unplanned-visit'),
];

void main() {
  group('a tab root with a nav and a primary', () {
    testWidgets('Night lands on exactly two lit objects', (tester) async {
      final skin = TiqSkin.night(density: TiqDensity.field);
      await pumpTorch(
        tester,
        skin: skin,
        navRenders: true,
        tabbedRoute: true,
        claims: routeClaims,
        child: tabRootWithPrimary(),
      );

      final census = await amberCensus(tester);
      expectWithinAmberBudget(
        census,
        skin,
        route: 'today (tab root + primary)',
        phase: 'loaded',
      );
      expect(
        census.objectCount,
        2,
        reason:
            'the nav tab is slot 1 whenever the nav renders; the primary '
            'takes the one content grant a tabbed route has left. Two, not '
            'one and not three.\n${census.describe()}',
      );

      // And they are the two we meant, not two of anything.
      final pill = tester.getRect(find.byType(TorchNavPill));
      final primary = tester.getRect(find.byType(TorchPrimaryButton));
      final regions = census.regions;
      expect(
        regions.any((r) => pill.contains(r.bounds.center)),
        isTrue,
        reason: 'one of them is inside the nav pill',
      );
      expect(
        regions.any((r) => primary.inflate(2).contains(r.bounds.center)),
        isTrue,
        reason: "and the other is the primary's rim",
      );
    });

    testWidgets('the nav circle asked, and lost by rule', (tester) async {
      final skin = TiqSkin.night(density: TiqDensity.field);
      final allocation = TorchScope.resolve(
        skin: skin,
        claims: routeClaims,
        navRenders: true,
        tabbedRoute: true,
      );
      expect(
        allocation.denied.entries
            .where((e) => e.key.kind == TorchClaimKind.navCircle)
            .single
            .value,
        TorchDenial.circleWithPrimary,
      );

      await pumpTorch(
        tester,
        skin: skin,
        navRenders: true,
        tabbedRoute: true,
        claims: routeClaims,
        child: tabRootWithPrimary(),
      );
      final circle = tester.getRect(find.byType(TorchNavCircle));
      final census = await amberCensus(tester);
      expect(
        census.regions.any((r) => circle.contains(r.bounds.center)),
        isFalse,
        reason:
            'the circle sits below the primary on the ladder, so on a route '
            'with a commit action it is its ink form',
      );
    });

    testWidgets('Day and Veld light exactly one — the primary block', (
      tester,
    ) async {
      for (final skin in <TiqSkin>[TiqSkin.day(), TiqSkin.veld()]) {
        await pumpTorch(
          tester,
          skin: skin,
          navRenders: true,
          tabbedRoute: true,
          claims: routeClaims,
          child: tabRootWithPrimary(),
        );
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'today (tab root + primary)',
          phase: 'loaded',
        );
        final primary = tester.getRect(find.byType(TorchPrimaryButton));
        expect(
          census.objectCount,
          1,
          reason:
              '${skin.mode.name}: on a light ground amber is a carrier of '
              'ink and there is exactly one of those.\n${census.describe()}',
        );
        expect(
          primary.inflate(2).contains(census.regions.single.bounds.center),
          isTrue,
          reason: 'and it is the primary, never the nav',
        );
      }
    });

    testWidgets('a sheet over the route puts both of them out', (tester) async {
      final skin = TiqSkin.night(density: TiqDensity.field);
      await pumpTorch(
        tester,
        skin: skin,
        navRenders: true,
        tabbedRoute: true,
        beneathSheet: true,
        claims: routeClaims,
        child: tabRootWithPrimary(),
      );
      final census = await amberCensus(tester);
      expect(
        census.objectCount,
        0,
        reason:
            'the nav tab drops to its ink form and the primary loses its rim, '
            'so the sheet genuinely owns the screen at a 72% scrim rather '
            'than an 88% one that hides the held work behind it.\n'
            '${census.describe()}',
      );
    });

    testWidgets('the keyboard hands the nav grant back to the content', (
      tester,
    ) async {
      final skin = TiqSkin.night(density: TiqDensity.field);
      // Keyboard up: the shell does not render the nav, and the route says so
      // to TorchScope. Two content grants are then available, which is what
      // makes "a focused field plus a lit primary" fit the budget.
      // Three claimants against two grants is a genuine over-claim and the
      // allocator asserts on it in debug. That is the point of the scenario,
      // so this exercises the release path the documented way.
      debugTorchAssertOverClaim = false;
      addTearDown(() => debugTorchAssertOverClaim = true);

      final withNav = TorchScope.resolve(
        skin: skin,
        claims: const <TorchClaim>[
          TorchClaim.primaryCommit('check-in'),
          TorchClaim.textFieldFocus('note'),
        ],
        navRenders: true,
        tabbedRoute: true,
      );
      expect(withNav.isLit('check-in'), isTrue);
      expect(
        withNav.isLit('note'),
        isFalse,
        reason: 'three claimants, two grants, and the nav took one',
      );

      final withoutNav = TorchScope.resolve(
        skin: skin,
        claims: const <TorchClaim>[
          TorchClaim.primaryCommit('check-in'),
          TorchClaim.textFieldFocus('note'),
        ],
      );
      expect(withoutNav.isLit('check-in'), isTrue);
      expect(withoutNav.isLit('note'), isTrue);
      expect(withoutNav.isOverClaimed, isFalse);
    });
  });

  group('the chrome that never lights anything', () {
    testWidgets('a shell with no nav and no primary paints no amber', (
      tester,
    ) async {
      for (final skin in torchSkins) {
        await pumpTorch(
          tester,
          skin: skin,
          child: TorchShell(
            profile: TorchShellProfile.console,
            header: const TorchAppHeader(
              title: 'Reports',
              facts: <String>['August', 'Gauteng'],
            ),
            skinCycle: TorchSkinCycle(
              mode: skin.mode,
              onChanged: (_) {},
              semanticLabel: 'Screen: Night. Double-tap for Day.',
            ),
            children: const <Widget>[SizedBox(height: 300)],
          ),
        );
        final census = await amberCensus(tester);
        expect(
          census.objectCount,
          0,
          reason:
              '${skin.mode.name}: the shell is the unlit room. It hosts its '
              "screen's amber and paints none of its own.\n"
              '${census.describe()}',
        );
      }
    });
  });
}
