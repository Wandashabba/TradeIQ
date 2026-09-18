import 'package:flutter/material.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';

/// Two fixture routes for the amber golden harness, plus one that is wrong on
/// purpose.
///
/// A harness nothing exercises is not a harness: a pixel census that is never
/// pointed at a real layout will pass forever, including on the day somebody
/// lights six things. These are not Phase 1 components — they are the smallest
/// arrangements that exercise the two shapes a route can have (tabbed with
/// chrome, untabbed without) plus the failure the harness exists to catch.
///
/// Every one of them reads its amber from [TorchScope]. None of them decides
/// for itself whether it is lit, which is the behaviour Phase 1 components
/// have to copy.

/// A tabbed dashboard: nav pill on screen, one focus bar in a ranked list.
///
/// Night: the nav's active tab is slot 1 and the focus bar is slot 2 — two
/// lit objects, exactly the budget. Day and Veld: the tab is an Abyssal
/// block, the focus bar is ink-1, and the single amber is the primary commit
/// block at the bottom.
class AmberDashboardFixture extends StatelessWidget {
  const AmberDashboardFixture({super.key, this.phase = 'loaded'});

  final String phase;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return TorchScope(
      skin: skin,
      phase: phase,
      navRenders: true,
      tabbedRoute: true,
      claims: <TorchClaim>[
        // One content claim, because the nav is slot 1 whenever it renders
        // and this is a tab root. The ranked list declares no focus here: on
        // a tabbed Night route there is no second content grant to give it,
        // and a bar that asked and lost would be the ruling's open question 1
        // rather than a fixture.
        TorchClaim.primaryCommit('commit'),
      ],
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 40),
            _RankedBars(focusId: 'worst-outlet'),
            const Spacer(),
            _PrimaryBlock(claimId: 'commit'),
            SizedBox(height: skin.space.blockGap),
            const _NavPill(activeIndex: 0),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// An untabbed visit route: no nav, a plate with a strip light and a live
/// pulse for the agent who is mid-visit.
///
/// Night: two content grants, both taken. Day and Veld: the plate is unlit,
/// the pulse is a `lifted` dot and the word Live, and there is no amber at
/// all — nothing is armed.
class AmberVisitFixture extends StatelessWidget {
  const AmberVisitFixture({super.key, this.phase = 'in-visit'});

  final String phase;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return TorchScope(
      skin: skin,
      phase: phase,
      navRenders: false,
      tabbedRoute: false,
      claims: <TorchClaim>[
        TorchClaim.plateStripLight('plate'),
        TorchClaim.livePulse('agent-here'),
      ],
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 40),
            _Plate(claimId: 'plate'),
            SizedBox(height: skin.space.blockGap),
            _LivePulse(claimId: 'agent-here'),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// Wrong on purpose: four amber objects painted directly, with no scope to
/// ask. The pixel census is the only thing that can catch this, because
/// nothing here ever spoke to the allocator — which is precisely the failure
/// mode a claim-time assert cannot see.
class AmberOverLitFixture extends StatelessWidget {
  const AmberOverLitFixture({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.skin.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 40),
        _Block(color: p.flame600, height: 48),
        const SizedBox(height: 24),
        _Block(color: p.flame500, height: 48),
        const SizedBox(height: 24),
        _Block(color: p.flame700, height: 48),
        const SizedBox(height: 24),
        _Block(color: p.flame900, height: 48),
        const Spacer(),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.color, required this.height});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: context.skin.space.gutter),
    child: Container(height: height, color: color),
  );
}

class _RankedBars extends StatelessWidget {
  const _RankedBars({required this.focusId});

  final String focusId;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final lit = TorchScope.lit(context, focusId);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: skin.space.gutter),
      child: Column(
        children: <Widget>[
          for (var i = 0; i < 4; i++) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  flex: 4 - i,
                  child: Container(
                    height: 12,
                    // The focus channel is amber only where amber is light.
                    // On a light ground it is ink-1 plus the weight and the
                    // marker, which is the whole point of `amberIsInk`.
                    color: i == 0
                        ? (lit
                              ? p.flame600
                              : (skin.amberIsInk ? p.ink1 : p.chartNeutral))
                        : p.chartNeutral,
                  ),
                ),
                Expanded(flex: i + 1, child: const SizedBox(height: 12)),
              ],
            ),
            SizedBox(height: skin.space.intraBlock),
          ],
        ],
      ),
    );
  }
}

class _PrimaryBlock extends StatelessWidget {
  const _PrimaryBlock({required this.claimId});

  final String claimId;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final lit = TorchScope.lit(context, claimId);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: skin.space.gutter),
      child: Container(
        height: skin.space.primaryActionHeight,
        decoration: BoxDecoration(
          // Unlit, the commit action is a ghost: an edge-control outline on
          // the ground. It is still the primary; it is simply not carrying
          // the route's light.
          color: lit ? p.flame600 : null,
          border: lit ? null : Border.all(color: p.edgeControl),
          borderRadius: BorderRadius.circular(skin.radii.control),
        ),
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  const _NavPill({required this.activeIndex});

  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: p.well,
          border: Border.all(color: p.edgeStructure),
          borderRadius: BorderRadius.circular(999),
        ),
        padding: const EdgeInsets.all(6),
        child: Row(
          children: <Widget>[
            for (var i = 0; i < 4; i++)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    // In Night the active tab is a solid flame-600 pill. On a
                    // light ground it is a solid Abyssal block — amber leaves
                    // the chrome entirely.
                    color: i == activeIndex
                        ? (skin.amberIsInk ? p.lifted : p.flame600)
                        : null,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Plate extends StatelessWidget {
  const _Plate({required this.claimId});

  final String claimId;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final lit = TorchScope.lit(context, claimId);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: skin.space.gutter),
      child: Stack(
        children: <Widget>[
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: p.well,
              borderRadius: BorderRadius.circular(skin.radii.plate),
            ),
          ),
          if (lit)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              // The strip light: a 3dp amber bar, not a blur. Every bloom in
              // this system is a gradient in the existing draw call.
              child: Container(height: 3, color: p.flame600),
            ),
        ],
      ),
    );
  }
}

class _LivePulse extends StatelessWidget {
  const _LivePulse({required this.claimId});

  final String claimId;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final lit = TorchScope.lit(context, claimId);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: skin.space.gutter),
      child: Row(
        children: <Widget>[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              // Under reduce-motion and on a light ground this is a filled
              // square plus the word Live; the harness only cares that it is
              // not amber there.
              color: lit ? p.flame600 : p.lifted,
              shape: lit ? BoxShape.circle : BoxShape.rectangle,
            ),
          ),
        ],
      ),
    );
  }
}
