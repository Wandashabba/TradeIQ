import 'package:flutter/widgets.dart';

import '../../theme/torchlight/tiq_skin.dart';

/// A DISPLAY HEADLINE THAT FITS, AND THE RULE THAT MAKES IT FIT.
///
/// `display` was the one prose role with no fitting rule while `hero.figure`
/// had one keyed to glyph count. It is keyed to **line count after layout**:
/// 1–2 lines stay at 40, 3 lines step to 32, 4 or more to 26, floor 26. An
/// Afrikaans headline at 2.0× therefore has a defined shape instead of eating
/// the screen. See [sizeFor].
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

  /// The three steps of the display fitting rule.
  static const List<double> steps = <double>[40, 32, 26];

  /// THE LINE-COUNT FITTING RULE, as a pure function.
  ///
  /// Lay the headline out at 40 and count the lines it takes; 1 or 2 keeps 40,
  /// 3 steps to 32, 4 or more to 26. The floor is 26 and there is no fourth
  /// step: below 26 a display headline is a title, and a title is what the
  /// in-panel scope already uses.
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
