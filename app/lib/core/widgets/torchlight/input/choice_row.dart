import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';
import '../button/torch_press.dart';
import '../mark/tiq_mark.dart';

/// One option in a [ChoiceRow].
@immutable
class ChoiceOption<T> {
  const ChoiceOption({
    required this.value,
    required this.label,
    this.consequence,
    this.enabled = true,
    this.disabledReason,
  });

  final T value;

  /// The answer, in the reader's words.
  final String label;

  /// **What choosing it does**, at `meta` beneath the label. The skip-reason
  /// picker's whole argument: a reason without its consequence is a dropdown,
  /// and a reason with one is a decision.
  final String? consequence;

  final bool enabled;
  final String? disabledReason;
}

/// Which way a choice group laid itself out. Exposed so a test can assert the
/// collapse happened for the reason it should have.
enum ChoiceLayout {
  /// Two to four options side by side.
  row,

  /// Full-width rows, mark leading. Automatic on a measured width, and always
  /// in Veld.
  column,
}

/// ONE ANSWER FROM TWO TO FOUR OPTIONS, SHOWN ALL AT ONCE.
///
/// The shape most of the capture sections actually need, and the component
/// that exists because **nothing-selected is a state** rather than an absence.
/// A toggle sitting at off is a recorded *no*; a choice group with nothing
/// selected is an honest *not answered yet*, and that difference is the
/// difference between a shelf somebody looked at and a shelf nobody did.
///
/// Radius 6 — the chip material (unify §1.9), so there is **one** selected
/// vocabulary across chips and choices: `lifted` fill, a 1px ink-1 border, a
/// tick or a disc, and weight 700. Three channels, never amber.
///
/// Re-tapping a selected option does **not** deselect it. Clearing an answer
/// is an explicit action beneath the group, because an accidental deselect in
/// a shop loses a fact silently.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.notAnsweredLine = 'Not answered yet',
    this.error,
    this.clear,
  }) : assert(
         options.length >= 2 && options.length <= 4,
         'A choice group holds two to four options. One option is a '
         'statement, and five is a list — use a sheet.',
       );

  /// Names the question, and is what a screen reader reads before the options.
  final String label;

  final List<ChoiceOption<T>> options;

  /// Null is **nothing selected**, which is a real state and renders as one.
  final T? value;

  final ValueChanged<T>? onChanged;

  /// Shown at `meta` beneath the group while nothing is selected.
  final String notAnsweredLine;

  /// After a submit attempt: a 2px `bad` bar down the group's leading edge and
  /// a triangle-prefixed sentence. No individual option turns red.
  final String? error;

  /// A tertiary "Clear" beneath the group. The only way to get back to
  /// nothing-selected.
  final Widget? clear;

  /// Above 14 characters a label stops fitting a quarter of a 360dp phone, and
  /// the group becomes a column. Measured, never guessed — see [layoutFor].
  static const int longLabelCharacters = 14;

  /// The layout for a given width. Pure, so the collapse can be argued about
  /// in a unit test.
  static ChoiceLayout layoutFor({
    required TiqSkin skin,
    required List<String> labels,
    required double maxWidth,
    required TextScaler scaler,
    required TextDirection direction,
  }) {
    // Veld is ALWAYS a column: three side-by-side 56dp targets in the sun is a
    // mis-tap, whatever the arithmetic says.
    if (skin.density == TiqDensity.veld) return ChoiceLayout.column;
    if (!maxWidth.isFinite) return ChoiceLayout.row;
    final cell =
        (maxWidth - TiqSpace.s2 * (labels.length - 1)) / labels.length;
    for (final label in labels) {
      if (label.length > longLabelCharacters) return ChoiceLayout.column;
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: skin.text.label
              .copyWith(weight: FontWeight.w700)
              .style(color: skin.palette.ink1),
        ),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      // The mark plus its gap plus the option's own padding.
      if (width + 6 + TiqSpace.s2 + TiqSpace.s4 > cell) {
        return ChoiceLayout.column;
      }
    }
    return ChoiceLayout.row;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final bad = error != null;
    final nothingSelected = value == null;

    return Semantics(
      container: true,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              border: bad
                  ? Border(
                      left: BorderSide(
                        color: p.bad,
                        width: skin.depth.borderWidth * 2,
                      ),
                    )
                  : null,
            ),
            child: Padding(
              padding: EdgeInsets.only(left: bad ? TiqSpace.s3 : 0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final layout = layoutFor(
                    skin: skin,
                    labels: options.map((o) => o.label).toList(),
                    maxWidth: constraints.maxWidth,
                    scaler: MediaQuery.textScalerOf(context),
                    direction: Directionality.of(context),
                  );
                  final tiles = <Widget>[
                    for (var i = 0; i < options.length; i++)
                      _Option<T>(
                        option: options[i],
                        selected: options[i].value == value,
                        index: i,
                        total: options.length,
                        column: layout == ChoiceLayout.column,
                        onTap: onChanged == null || !options[i].enabled
                            ? null
                            : () => onChanged!(options[i].value),
                      ),
                  ];
                  if (layout == ChoiceLayout.column) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (var i = 0; i < tiles.length; i++) ...<Widget>[
                          if (i > 0) const SizedBox(height: TiqSpace.s2),
                          tiles[i],
                        ],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (var i = 0; i < tiles.length; i++) ...<Widget>[
                        if (i > 0) const SizedBox(width: TiqSpace.s2),
                        Expanded(child: tiles[i]),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
          if (bad) ...<Widget>[
            const SizedBox(height: TiqSpace.s2),
            Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: TiqMark(
                      shape: MarkShape.criticalTriangle,
                      color: p.bad,
                      size: MarkScale.glyph(context, 12),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      error!,
                      style: skin.text.meta
                          .copyWith(weight: FontWeight.w500)
                          .style(color: p.bad),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (nothingSelected) ...<Widget>[
            const SizedBox(height: TiqSpace.s2),
            // NOTHING SELECTED IS A STATE, and it says so in words. Without
            // this line an unanswered group and an answered one look the same
            // from two steps back.
            Text(
              notAnsweredLine,
              style: skin.text.meta.style(color: p.ink3),
            ),
          ],
          if (clear != null && !nothingSelected) ...<Widget>[
            const SizedBox(height: TiqSpace.s2),
            Align(alignment: Alignment.centerLeft, child: clear!),
          ],
        ],
      ),
    );
  }
}

class _Option<T> extends StatelessWidget {
  const _Option({
    required this.option,
    required this.selected,
    required this.index,
    required this.total,
    required this.column,
    required this.onTap,
  });

  final ChoiceOption<T> option;
  final bool selected;
  final int index;
  final int total;
  final bool column;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final enabled = option.enabled && onTap != null;
    final veld = skin.density == TiqDensity.veld;
    final height = veld
        ? 64.0
        : (column ? 56.0 : skin.space.tapTarget);
    final radius = BorderRadius.circular(skin.radii.chip);

    final Color? fill;
    final Color border;
    final Color ink;
    if (!enabled) {
      fill = null;
      border = p.inkMute;
      ink = p.inkMute;
    } else if (selected) {
      fill = veld ? p.lifted : p.lifted;
      border = veld ? p.ink1 : p.ink1;
      ink = torchOnAbyssal(skin);
    } else {
      fill = null;
      border = p.edgeControl;
      ink = p.ink2;
    }

    final labelStyle = skin.text.label
        .copyWith(weight: selected ? FontWeight.w700 : FontWeight.w500)
        .style(color: ink);

    final mark = selected
        ? TiqMark(
            shape: MarkShape.filledCircle,
            color: ink,
            size: MarkScale.glyph(context, 6),
          )
        : SizedBox.square(dimension: MarkScale.glyph(context, 6));

    final text = Column(
      crossAxisAlignment: column
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          option.label,
          style: labelStyle,
          textAlign: column ? TextAlign.start : TextAlign.center,
          // Labels never ellipsise: a truncated answer is an answer you
          // cannot identify.
        ),
        if (option.consequence != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s1),
          Text(
            option.consequence!,
            style: skin.text.meta.style(color: enabled ? p.ink3 : p.inkMute),
          ),
        ],
        if (!option.enabled && option.disabledReason != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s1),
          Text(
            option.disabledReason!,
            style: skin.text.meta.style(color: p.inkMute),
          ),
        ],
      ],
    );

    final body = Row(
      mainAxisSize: column ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: column
          ? MainAxisAlignment.start
          : MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        mark,
        const SizedBox(width: TiqSpace.s2),
        column ? Expanded(child: text) : Flexible(child: text),
      ],
    );

    Widget tile = Container(
      constraints: BoxConstraints(minHeight: height),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(color: border, width: skin.depth.borderWidth),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: TiqSpace.s3,
        vertical: TiqSpace.s2,
      ),
      alignment: Alignment.center,
      child: body,
    );

    if (!option.enabled) {
      tile = CustomPaint(foregroundPainter: _StrikePainter(p.inkMute), child: tile);
    }

    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      enabled: enabled,
      // The consequence is read WITH the reason, so a screen-reader user makes
      // the same informed choice a sighted one does.
      label: option.consequence == null
          ? option.label
          : '${option.label}. ${option.consequence}',
      hint: '${index + 1} of $total',
      excludeSemantics: true,
      child: TorchPressable(
        onPressed: onTap,
        borderRadius: radius,
        builder: (context, pressed) => DecoratedBox(
          decoration: BoxDecoration(
            color: pressed ? torchPressSurface(skin).fill : null,
            borderRadius: radius,
          ),
          child: tile,
        ),
      ),
    );
  }
}

/// The 2px diagonal strike over a disabled option. A silhouette, so the state
/// survives greyscale — `inkMute` alone is deliberately sub-AA and must never
/// be the only cue.
class _StrikePainter extends CustomPainter {
  const _StrikePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, 0),
      Paint()
        ..color = color
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_StrikePainter old) => old.color != color;
}
