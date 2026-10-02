import 'package:flutter/widgets.dart';

import '../../theme/torchlight/tiq_skin.dart';

/// A DISPLAY HEADLINE THAT FITS, AND THE RULE THAT MAKES IT FIT.
///
/// `display` was the one prose role with no fitting rule while `hero.figure`
/// had one keyed to glyph count. It is keyed to **line count after layout**:
/// 1–2 lines stay at `display`, 3 lines step to `display.m`, 4 or more to
/// `display.s`, which is the floor. An Afrikaans headline at 2.0× therefore
/// has a defined shape instead of eating the screen. See [sizeFor].
///
/// It lives here rather than inside `EmptyState` because it is not an
/// empty-state idea. A whole-screen empty state opens with one of these, and
/// so does Ask TradeIQ's opening, which is an invitation rather than a report
/// of absence — two different screens that owe the reader the same promise
/// about how big the first line gets. `EmptyState.displaySizeFor` and
/// `EmptyState.displaySteps` remain as they were and delegate here, because
/// they are the names the scale tests already call.
///
/// It announces itself as a `header`: this is the first thing on the route and
/// the one node a screen reader should be able to jump to.
class TorchDisplayHeadline extends StatelessWidget {
  const TorchDisplayHeadline(this.headline, {super.key});

  final String headline;

  /// The three steps of the display fitting rule, **read from the scale**.
  ///
  /// It was the literal `[40, 32, 26]` until 1 October 2026, and that was a
  /// real bug rather than a tidy-up: the prose reduction took `display` to 37,
  /// `display.m` to 30 and `display.s` to 24, and this list went on painting
  /// every headline at the old sizes. The token comment on [TiqType.displayM]
  /// says exactly why the three steps are declared members of the scale —
  /// *"a size that only exists inside one screen's helper is a size no
  /// contrast walk, no render sampler and no text-scale cap ever sees"* — and
  /// a hardcoded copy of them here was the same mistake one level down.
  ///
  /// `final` rather than `const` because Dart will not read an instance field
  /// off a const object in a const expression. Nothing used it in a const
  /// context.
  static final List<double> steps = <double>[
    TiqType.console.display.size,
    TiqType.console.displayM.size,
    TiqType.console.displayS.size,
  ];

  /// THE LINE-COUNT FITTING RULE, as a pure function.
  ///
  /// Lay the headline out at the top rung and count the lines it takes; 1 or 2
  /// keeps it, 3 steps to the middle rung, 4 or more to the floor. There is no
  /// fourth step: below the floor a display headline is a title, and a title
  /// is what the in-panel scope already uses.
  static double sizeFor({
    required String headline,
    required TiqTypeToken role,
    required double maxWidth,
    required TextScaler scaler,
    required TextDirection direction,
  }) {
    if (!maxWidth.isFinite || maxWidth <= 0) return steps.first;
    final painter = TextPainter(
      text: TextSpan(
        text: headline,
        style: role.copyWith(size: steps.first).style(),
      ),
      textDirection: direction,
      textScaler: scaler,
    )..layout(maxWidth: maxWidth);
    final lines = painter.computeLineMetrics().length;
    painter.dispose();
    if (lines <= 2) return steps[0];
    if (lines == 3) return steps[1];
    return steps[2];
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = sizeFor(
          headline: headline,
          role: skin.text.display,
          maxWidth: constraints.maxWidth,
          scaler: MediaQuery.textScalerOf(context),
          direction: Directionality.of(context),
        );
        return Semantics(
          header: true,
          child: Text(
            headline,
            style: skin.text.display
                .copyWith(size: size)
                .style(color: skin.palette.ink1),
          ),
        );
      },
    );
  }
}
