import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';
import '../display_headline.dart';
import 'empty_drawing.dart';

/// Where an empty state sits, which is what decides whether it gets a drawing.
enum EmptyScope {
  /// The whole route has nothing in it. 64dp drawing + a display headline.
  wholeScreen,

  /// One panel inside a screen that has other content. No drawing, `title.l`.
  inPanel,

  /// A region of a list or a form. No drawing, `title.m`.
  inline,
}

/// SAYING WHAT TO DO NEXT, IN A PLACE WHERE THERE IS NOTHING.
///
/// Never merely reporting the absence, and never centred.
///
/// ```dart
/// EmptyState(
///   scope: EmptyScope.wholeScreen,
///   drawing: EmptyDrawing.shelf,
///   headline: 'No outlets within 2 km',
///   body: 'Search by name, or scan a shelf barcode.',
///   action: TorchSecondaryButton(label: 'Search by name', onPressed: …),
/// )
/// ```
///
/// ## Left-aligned, and the reason is not taste
///
/// A centred block grows in both directions. At 2.0× with a four-line
/// Afrikaans headline, a vertically centred empty state pushes its own action
/// off the bottom of the screen at exactly the text setting that needed it
/// most. Left-aligned and top-anchored, growth only ever goes downward, into
/// a scroll that already exists.
///
/// ## The drawing is whole-screen only
///
/// [EmptyScope.inPanel] and [EmptyScope.inline] get **no drawing** (unify
/// §1.12): a 64dp illustration inside a panel that is itself 200dp tall is a
/// decoration competing with the sentence beside it.
///
/// And the drawing is for **an empty state**, which is the only placement
/// §1.12 grants. A screen that is inviting the reader to do something rather
/// than reporting that there is nothing is not one of these, however
/// convenient this widget is — see `AskFirstRun`, which used to open with the
/// shelf and now opens on its headline.
///
/// ## The headline fits by line count
///
/// See [TorchDisplayHeadline], which owns the rule: 1–2 lines stay at 40, 3
/// lines step to 32, 4 or more to 26, floor 26. [displaySizeFor] forwards to
/// it.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.headline,
    this.scope = EmptyScope.wholeScreen,
    this.drawing,
    this.body,
    this.action,
  }) : assert(
         scope == EmptyScope.wholeScreen || drawing == null,
         'Only a whole-screen empty state carries a drawing (unify §1.12). '
         'In a panel or inline it is a headline and a sentence.',
       );

  /// One short sentence. A `header` for a screen reader.
  final String headline;

  final EmptyScope scope;

  /// Required in practice for a whole-screen empty state; null renders without
  /// one, which is the correct thing for a finished route where the absence is
  /// an achievement rather than a gap.
  final EmptyDrawing? drawing;

  /// One line naming the **next physical action**, in the reader's world.
  final String? body;

  /// One secondary button, left-aligned at its intrinsic width — and a real
  /// destination, never "Refresh" where a pull-to-refresh already exists.
  final Widget? action;

  /// The three steps of the display fitting rule. Lives on
  /// [TorchDisplayHeadline] now; kept here because this is the name the scale
  /// tests call.
  static const List<double> displaySteps = TorchDisplayHeadline.steps;

  /// THE LINE-COUNT FITTING RULE — see [TorchDisplayHeadline.sizeFor], which
  /// is where it lives and what this forwards to.
  static double displaySizeFor({
    required String headline,
    required TiqTypeToken role,
    required double maxWidth,
    required TextScaler scaler,
    required TextDirection direction,
  }) => TorchDisplayHeadline.sizeFor(
    headline: headline,
    role: role,
    maxWidth: maxWidth,
    scaler: scaler,
    direction: direction,
  );

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final whole = scope == EmptyScope.wholeScreen;

    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (whole && drawing != null) ...<Widget>[
            EmptyStateDrawing(drawing: drawing!),
            const SizedBox(height: TiqSpace.s6),
          ],
          if (whole)
            TorchDisplayHeadline(headline)
          else
            Semantics(
              header: true,
              child: Text(
                headline,
                style:
                    (scope == EmptyScope.inPanel
                            ? skin.text.titleL
                            : skin.text.titleM)
                        .style(color: p.ink1),
              ),
            ),
          if (body != null) ...<Widget>[
            const SizedBox(height: TiqSpace.s2),
            // Max 32em: a line of prose longer than that is a line the eye
            // loses its place in.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: skin.text.body.size * 32),
              child: Text(body!, style: skin.text.body.style(color: p.ink2)),
            ),
          ],
          if (action != null) ...<Widget>[
            const SizedBox(height: TiqSpace.s6),
            Align(alignment: Alignment.centerLeft, child: action!),
          ],
        ],
      ),
    );
  }
}
