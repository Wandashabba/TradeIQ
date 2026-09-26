import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../core/design/figure_slot.dart';
import '../../../core/design/hatch_paint.dart';
import '../../../core/design/tiq_number.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/mark/tiq_mark.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../l10n/l10n.dart';
import '../answer/answer_motion.dart';
import '../answer/ask_light.dart';
import '../data/chat_controller.dart';
import 'answer_focus.dart';
import 'rich_figures.dart';
import 'stat_tiles_card.dart' show askUnitFor;

/// THE `ranked_bars` SPEC — a ranking, worst first.
///
/// ## The one lit bar is the server's choice
///
/// It used to be "the first", which was an inference dressed as a fact: what
/// "worst" means depends on the metric, and the sentence above may be about
/// the third outlet. #410 put `focusIndex` on the wire, so the light lands
/// where the sentence points — and when the server names none, **nothing is
/// lit**, which is the honest answer rather than a guess.
///
/// ## Four channels, not a hue
///
/// The focus bar carries fill, a 12dp bloom drawn inside the same
/// `BoxDecoration`, a 7dp filled triangle at its origin, and its label at
/// `body.strong`. Three of those four survive greyscale, deuteranopia, a
/// printed export and a sun-washed panel — which is why Day and Veld can drop
/// the hue entirely and lose nothing.
///
/// ## The label takes two lines before anything truncates
///
/// The previous build middle-truncated a single line, so "Shoprite
/// Klipfontein Mall" and "Shoprite Klipfontein Mall Ext 2" both rendered as
/// "Shoprite Kli…Mall" — on a row that is not tappable, so there was no path
/// to the full string. A ranked row is a name and a number, and the name is
/// the half you cannot guess.
class RankedBarsCard extends StatefulWidget {
  const RankedBarsCard({super.key, required this.artifact});

  final ChatArtifact artifact;

  /// Rows shown before the expander. The schema allows twelve.
  static const int shownRows = 6;

  @override
  State<RankedBarsCard> createState() => _RankedBarsCardState();
}

class _RankedBarsCardState extends State<RankedBarsCard> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final number = TiqNumber.of(context);
    final data = RankedBarsData.from(widget.artifact.data);
    // An empty set is dropped entirely — never a block saying there is
    // nothing to rank.
    if (data.items.isEmpty) return const SizedBox.shrink();

    final max = data.maxAbs;
    // The server's choice, through the turn's `focus` events; lit only when
    // this block is the route's one target and the route holds the grant.
    final focus = AnswerFocusScope.focusIndexFor(context, widget.artifact);
    final lit = AnswerFocusScope.isLit(context, widget.artifact);
    final shown = _all
        ? data.items.length
        : (data.items.length <= RankedBarsCard.shownRows
              ? data.items.length
              : RankedBarsCard.shownRows);

    final skin = context.skin;
    final title = data.title;
    final comparedTo = data.comparedTo;

    // One value column for every row, as wide as its widest figure. Without
    // it each track is whatever a row's label and figure leave over, so the
    // bars start and end in different places and a longer bar can stand for
    // a smaller number — the one thing a ranking may not do.
    var valueWidth = 0.0;
    for (final item in data.items) {
      valueWidth = math.max(
        valueWidth,
        FigureSlot.measure(
          context,
          value: item.value,
          role: skin.text.figureS,
          unit: askUnitFor(l10n, data.unit, item.value.abs()),
          decimals: data.decimals,
          signed: data.diverging,
        ),
      );
    }
    valueWidth = valueWidth.ceilToDouble() + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // What is being ranked, and over what — the server's words. Without
        // them a column of sixes and fours is a ranking of nothing.
        if (title != null) ...<Widget>[
          Text(
            title,
            key: const ValueKey<String>('ranked-bars-title'),
            style: skin.text.label.style(color: skin.palette.ink1),
          ),
          if (comparedTo != null) ...<Widget>[
            const SizedBox(height: TiqSpace.s1),
            Text(
              comparedTo,
              style: skin.text.meta.style(color: skin.palette.ink3),
            ),
          ],
          SizedBox(height: skin.space.intraBlock),
        ],
        for (var i = 0; i < shown; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: TiqSpace.s2),
          _BarRow(
            key: ValueKey<String>(
              i == focus ? 'ranked-bars-focus' : 'ranked-bars-row-$i',
            ),
            item: data.items[i],
            index: i,
            total: data.items.length,
            fraction: max == 0 ? 0 : data.items[i].value.abs() / max,
            valueLabel: data.label(data.items[i].value, number: number),
            unit: askUnitFor(l10n, data.unit, data.items[i].value.abs()),
            decimals: data.decimals,
            diverging: data.diverging,
            // A single item is never a focus: one bar cannot be ranked.
            focus: i == focus,
            lit: lit,
            valueWidth: valueWidth,
          ),
        ],
        if (shown < data.items.length) ...<Widget>[
          const SizedBox(height: TiqSpace.s2),
          SoftRow(
            key: const ValueKey<String>('ranked-bars-show-all'),
            density: SoftRowDensity.compact,
            title: l10n.askShowAll(data.items.length),
            separator: SoftRowSeparator.none,
            onTap: () => setState(() => _all = true),
          ),
        ],
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    super.key,
    required this.item,
    required this.index,
    required this.total,
    required this.fraction,
    required this.valueLabel,
    required this.unit,
    required this.decimals,
    required this.diverging,
    required this.focus,
    required this.lit,
    required this.valueWidth,
  });

  final RankedBarItem item;
  final int index;
  final int total;

  /// |value| / the largest |value|, 0–1.
  final double fraction;
  final String valueLabel;
  final TiqUnit unit;
  final int? decimals;
  final bool diverging;
  final bool focus;

  /// Whether the route's arbiter granted this block its one amber object.
  final bool lit;

  /// The shared width of the value column, so every track is the same length.
  final double valueWidth;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final p = skin.palette;
    final veld = skin.mode == SkinMode.veld;
    final negative = item.value < 0;
    final zero = item.value == 0;
    final track = veld ? 8.0 : 6.0;

    final Color fill;
    if (focus) {
      fill = AskLight.focusFill(skin, lit: lit);
    } else if (diverging) {
      // Positives solid `good`; negatives `bad` AND hatched, because
      // #FF7D8C against chart-neutral is 1.55:1 in colour and 1.26:1 in
      // protanopia. The hatch is the channel; the hue is the courtesy.
      fill = negative ? p.bad : p.good;
    } else {
      fill = p.chartNeutral;
    }

    Widget bar(AlignmentDirectional from) {
      if (zero) {
        // No bar drawn, "0" printed, and a 2dp tick at the origin so the row
        // is not read as missing. A measured zero is a reading.
        return Align(
          alignment: from,
          child: SizedBox(width: 2, height: track, child: ColoredBox(color: p.ink3)),
        );
      }
      return GrowIn(
        duration: const Duration(milliseconds: 600),
        delay: Duration(milliseconds: 60 * index),
        builder: (context, t) => FractionallySizedBox(
          key: ValueKey<String>('ranked-bar-fill-$index'),
          alignment: from,
          widthFactor: (fraction * t).clamp(0.0, 1.0),
          child: _Bar(
            height: track,
            fill: fill,
            hatched: diverging && negative,
            // The bloom is drawn inside the bar's own decoration — never a
            // blur, never a BoxShadow, and never a second draw call.
            bloom: focus ? AskLight.focusBloom(skin, lit: lit) : null,
            radius: veld ? 0 : track / 2,
            growsFromStart: from == AlignmentDirectional.centerStart,
          ),
        ),
      );
    }

    final Widget trackRow;
    if (diverging) {
      trackRow = Row(
        children: <Widget>[
          Expanded(
            child: negative ? bar(AlignmentDirectional.centerEnd) : const SizedBox(),
          ),
          // The centre axis is edge-control, never amber: a 1dp ink axis at
          // 15:1 is more visible than amber would be, and amber there would
          // displace the focus row for no legibility gain.
          SizedBox(
            width: skin.depth.borderWidth,
            height: track * 2,
            child: ColoredBox(color: p.edgeControl),
          ),
          Expanded(
            child: negative ? const SizedBox() : bar(AlignmentDirectional.centerStart),
          ),
        ],
      );
    } else {
      trackRow = bar(AlignmentDirectional.centerStart);
    }

    final labelStyle = focus
        ? skin.text.bodyStrong.style(color: p.ink1)
        : skin.text.body.style(color: p.ink1);

    return Semantics(
      label: <String>[
        item.label,
        valueLabel,
        l10n.askBarSemantic(item.label, valueLabel, index + 1, total),
        // The server orders worst first and names the bar the sentence is
        // about; "worst" is said of that bar, not guessed from position.
        if (focus) l10n.askBarWorst,
      ].skip(2).join(', '),
      excludeSemantics: true,
      child: RepaintBoundary(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: veld ? TiqSpace.s3 : TiqSpace.s2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // 38% of the row, and two lines before anything gives. Tight,
              // so a short name does not hand its space to the track.
              Expanded(
                flex: 38,
                child: Text(item.label, style: labelStyle, maxLines: 2),
              ),
              const SizedBox(width: TiqSpace.s3),
              // The triangle's slot is kept on every row so the focus row's
              // track is not shorter than its neighbours'.
              if (!focus)
                SizedBox(width: MarkScale.glyph(context, veld ? 9 : 7) + TiqSpace.s1),
              if (focus) ...<Widget>[
                // A filled triangle at the bar's origin, pointing right. One
                // of the focus bar's four channels, and the one that survives
                // greyscale and a printed export.
                RotatedBox(
                  quarterTurns: 1,
                  child: TiqMark(
                    shape: MarkShape.deltaUp,
                    color: AskLight.focusFill(skin, lit: lit),
                    size: MarkScale.glyph(context, veld ? 9 : 7),
                  ),
                ),
                const SizedBox(width: TiqSpace.s1),
              ],
              Expanded(
                flex: 62,
                // THE TRACK IS `well` ON PAPER — 26 September 2026, and the
                // same value `Meter._trackFill` resolves. `lifted` is a dark
                // block in all three skins (#2C3B4D, #2C3B4D, #1B2632): on
                // Night that is a step up from the ground and reads as a
                // recess, and on Day's Palladian paper it is a navy channel
                // with a small `good` bar floating in it. A track recesses by
                // *welling* into the surface, so on a light skin it takes
                // `well` and not the dark block.
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: skin.brightness == Brightness.dark
                        ? p.lifted
                        : p.well,
                    borderRadius: BorderRadius.circular(veld ? 0 : track / 2),
                  ),
                  child: SizedBox(
                    height: track * 2,
                    child: Center(
                      // Tight across: a fractional bar under a loose Center
                      // takes its own width and is centred — every bar would
                      // grow from a different origin.
                      child: SizedBox(
                        height: track,
                        width: double.infinity,
                        child: trackRow,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: TiqSpace.s3),
              SizedBox(
                width: valueWidth,
                child: FigureSlot(
                  value: item.value,
                  role: skin.text.figureS,
                  unit: unit,
                  decimals: decimals,
                  signed: diverging,
                  textAlign: TextAlign.end,
                  color: p.ink1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One bar: a fill, optionally hatched, optionally blooming.
///
/// **Square at the origin, rounded at the data end** — 26 September 2026, and
/// it is the same correction `Meter` took. A fill rounded on all four corners
/// is a lozenge floating in a track rather than a measurement growing out of
/// an axis, and the shorter the reading the worse it gets: at a 12% share on a
/// 6dp track it is a capsule, and on Day's paper it reads as a nub adrift in a
/// dark channel. A bar starts at the origin; only the end it stopped at is a
/// measurement, so only that end is shaped.
///
/// A fill shorter than it is tall keeps square corners at both ends. Rounding
/// a 4dp-wide bar by 3dp on one side leaves a wedge, which is a different
/// shape again.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.height,
    required this.fill,
    required this.hatched,
    required this.bloom,
    required this.radius,
    required this.growsFromStart,
  });

  final double height;
  final Color fill;
  final bool hatched;
  final Gradient? bloom;
  final double radius;

  /// Which end is the origin. A diverging bar's negative half grows leftward
  /// from the centre axis, so *its* square end is the trailing one.
  final bool growsFromStart;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final body = LayoutBuilder(
      builder: (context, constraints) {
        // Measured, not assumed: the caller cannot know the laid-out width of
        // a `FractionallySizedBox` child, and this is the one number the
        // rounding decision turns on.
        final short =
            constraints.hasBoundedWidth && constraints.maxWidth <= height;
        final end = (radius == 0 || short)
            ? Radius.zero
            : Radius.circular(radius);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            gradient: bloom,
            borderRadius: BorderRadiusDirectional.horizontal(
              start: growsFromStart ? Radius.zero : end,
              end: growsFromStart ? end : Radius.zero,
            ),
          ),
          child: SizedBox(height: height),
        );
      },
    );
    if (!hatched) return body;
    // 45° hard-stop stripes, drawn by the shared registry — never a pattern
    // under 4dp, and never inside a glyph. The stripe direction is what
    // carries the sign; the hue is the courtesy.
    return CustomPaint(
      foregroundPainter: _NegativeHatch(
        HatchPaint.spec(skin, HatchPattern.negative),
      ),
      child: body,
    );
  }
}

/// The negative side of a diverging bar, striped.
class _NegativeHatch extends CustomPainter {
  const _NegativeHatch(this.spec);

  final HatchSpec spec;

  @override
  void paint(Canvas canvas, Size size) {
    // The registry refuses anything under 4dp, and a 6dp track is the
    // smallest thing on this surface that may carry a pattern at all.
    if (size.shortestSide < HatchPaint.minimumMarkExtent) return;
    HatchPaint.paint(canvas, Offset.zero & size, spec);
  }

  @override
  bool shouldRepaint(_NegativeHatch old) => old.spec != spec;
}
