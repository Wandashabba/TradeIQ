import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/plate/plate.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../data/floor_repository.dart';
import 'the_floor_screen.dart';

/// WHAT A BRAND-NEW CLIENT SEES INSTEAD OF A SCOREBOARD OF ZEROS.
///
/// The Floor is never a scoreboard of zeros, so when a tenant has nothing on
/// the books it hands off to this — a different screen, not an empty variant
/// of the same one. The difference is the entire point: a zero is a
/// measurement and an absence is not, and a console that prints `0%` for a
/// client who has never taken a visit has told them something false on their
/// first morning.
///
/// The screen is a ladder and an instrument. The ladder says what has to exist
/// before the console can speak; the instrument is the real stat cluster in
/// its no-data state — eyebrows intact, em dashes in ink-3, a sentence under
/// each, no deltas and no zeros. Showing the instrument unlit rather than
/// hiding it is what makes the console legible on day one: this is the thing
/// you are building towards, and here is why it is blank.
///
/// **Amber: none spent here.** The nav pill's active tab is slot 1; the
/// remaining grant would go to the primary commit block, which is the
/// chrome workstream's button. Until it lands this screen renders zero amber
/// objects, which is legal — a budget is a ceiling.
class FirstRunBoard extends ConsumerWidget {
  const FirstRunBoard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = context.skin;
    final view = ref
        .watch(floorViewProvider)
        .maybeWhen(data: (v) => v, orElse: () => null);

    return TorchScope(
      skin: skin,
      phase: 'first-run',
      navRenders: true,
      tabbedRoute: true,
      claims: const <TorchClaim>[],
      child: FloorScaffold(
        children: <Widget>[
          // 1. THE UNLIT PLATE. The same fallback drawing, deliberately with
          //    no strip light: amber is withheld because there is nothing to
          //    light. A lit plate over an empty console is a product
          //    pretending to have data.
          SizedBox(
            height: 240,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                const PlateFallback(),
                Positioned(
                  left: skin.space.gutter,
                  right: skin.space.gutter,
                  bottom: TiqSpace.s5,
                  child: Text(
                    'No shelf yet. This becomes your territory’s availability '
                    'when the first visits land.',
                    style: skin.text.meta.style(color: skin.palette.ink3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: TiqSpace.s8),

          _Gutter(
            child: Text(
              'Nothing has been measured yet.',
              style: skin.text.display.style(color: skin.palette.ink1),
            ),
          ),
          const SizedBox(height: TiqSpace.s3),
          _Gutter(
            child: Text(
              'Four things have to exist before the console has anything to '
              'say.',
              style: skin.text.body.style(color: skin.palette.ink2),
            ),
          ),
          const SizedBox(height: TiqSpace.s6),

          // 2. THE SETUP LADDER.
          _Gutter(child: _SetupLadder(outletsTotal: view?.outletsTotal)),
          const SizedBox(height: TiqSpace.s8),

          // 3. THE INSTRUMENT, UNLIT.
          _Gutter(child: const SectionRule('What this board will show')),
          const SizedBox(height: TiqSpace.s5),
          _Gutter(
            child: StatCluster(
              semanticsLabel:
                  'The figures this console will show once visits land. '
                  'None of them is measured yet.',
              tiles: <StatTile>[
                StatTile(
                  eyebrow: 'On-shelf availability',
                  value: null,
                  unit: TiqUnit.percent,
                  noDataReason: 'no visits in this window',
                ),
                StatTile(
                  eyebrow: 'Coverage',
                  value: null,
                  unit: TiqUnit.percent,
                  noDataReason: 'no visits in this window',
                ),
                StatTile(
                  eyebrow: 'Open critical alerts',
                  value: null,
                  noDataReason: 'no visits in this window',
                ),
              ],
            ),
          ),
          const SizedBox(height: TiqSpace.s6),
          _Gutter(
            child: Text(
              'These fill in as visits are submitted. Nothing here is a zero — '
              'it is an absence.',
              style: skin.text.meta.style(color: skin.palette.ink3),
            ),
          ),
        ],
      ),
    );
  }
}

class _Gutter extends StatelessWidget {
  const _Gutter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: context.skin.space.gutter),
    child: child,
  );
}

/// Four rungs, each a real precondition. No animation: nothing has happened
/// yet, so nothing draws in.
class _SetupLadder extends StatelessWidget {
  const _SetupLadder({required this.outletsTotal});

  final int? outletsTotal;

  @override
  Widget build(BuildContext context) {
    final rungs = <({String label, SectionState state, String? count})>[
      (
        label: 'Add outlets',
        state: (outletsTotal ?? 0) > 0
            ? SectionState.done
            : SectionState.notStarted,
        count: outletsTotal == null ? null : '$outletsTotal so far',
      ),
      (label: 'Add agents', state: SectionState.notStarted, count: null),
      (label: 'Draw a territory', state: SectionState.notStarted, count: null),
      (label: 'First visit lands', state: SectionState.notStarted, count: null),
    ];

    return Semantics(
      container: true,
      label: 'Setup, ${rungs.length} steps.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (var i = 0; i < rungs.length; i++)
            _Rung(
              index: i,
              total: rungs.length,
              label: rungs[i].label,
              state: rungs[i].state,
              count: rungs[i].count,
            ),
        ],
      ),
    );
  }
}

class _Rung extends StatelessWidget {
  const _Rung({
    required this.index,
    required this.total,
    required this.label,
    required this.state,
    required this.count,
  });

  final int index;
  final int total;
  final String label;
  final SectionState state;
  final String? count;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final word = SectionStateToken.of(skin, state).word;
    return Semantics(
      label: 'Step ${index + 1} of $total, $label, $word.',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // The 2px vertical ladder rule is deleted (unify §1.5): the rungs
            // carry their own 3:1 edges and a line crossing them is decoration.
            SectionStateGlyph(state: state),
            const SizedBox(width: TiqSpace.s4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    style: skin.text.titleM.style(color: skin.palette.ink1),
                  ),
                  if (count != null) ...<Widget>[
                    const SizedBox(height: TiqSpace.s1),
                    Text(
                      count!,
                      style: skin.text.meta.style(color: skin.palette.ink3),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
