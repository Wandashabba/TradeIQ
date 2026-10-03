import 'package:flutter/widgets.dart';

import '../../theme/torchlight/tiq_skin.dart';
import 'card.dart';

/// ── THE RECORD, IN THE DETAIL PANE ─────────────────────────────────────
///
/// > *"Every list screen gets three panes … On the screens whose rows are
/// > dead ends the detail pane shows that record's own content — its fields,
/// > its figures, and the actions currently sitting on the row, lifted into
/// > the pane. That is the design."*
///
/// Nine of the console's list screens have no detail route at all: Tasks,
/// Orders, Reports, Messages, Sales targets, Visit verification, Incentives,
/// Webhooks and Dispatch. Their rows carry the whole record — a title, a
/// supporting line, a figure, and one or two verbs in `SoftRow.actions` — and
/// the first desk left every one of them at one column on the grounds that
/// there was nowhere for a second pane to point. **That is a statement about
/// routes, not about records**, and the record is right there.
///
/// So this is one component for the shape they all share, and the reason it is
/// shared rather than written nine times is that nine hand-made panes drift:
/// the ninth gets a different gap under its headline, a different weight on
/// its labels, and the console stops being one product at 1440dp.
///
/// ```text
///   ╭────────────────────────────────╮
///   │ ▲ Watch                        │  kicker  — the row's own mark + word
///   │ Kalahari Cola 2L out of stock  │  title   — the row's own title
///   │ Submitted · 3 lines            │  lede    — the row's own subtitle
///   │                                │
///   │ ┌────────────────────────────┐ │
///   │ │ Value          R 2,350.75  │ │  facts   — label on the left, figure
///   │ │ Lines                   3  │ │            on the right, on a well
///   │ │ Order        ord-aaaa…     │ │
///   │ └────────────────────────────┘ │
///   │                                │
///   │ [ Close with photo ]           │  actions — the row's own verbs, full
///   │ [ Verify ]                     │            width, in the pane
///   ╰────────────────────────────────╯
/// ```
///
/// ## IT IS A CARD, AND THE CARD IS WHY NOTHING HERE NEEDS RE-MEASURING
///
/// [TorchCard] fills with `palette.surface`, which is **opaque**, so the
/// console's two ambient washes cannot reach a single pixel inside this
/// component. Every contrast pairing in it is therefore the pairing the kit
/// already measured on `surface`, unchanged by the desk's lights — which is
/// the identical argument `alert_detail_sheet.dart` makes for drawing the
/// sheet's body in the pane. The wash is measured where it actually lands: the
/// ground around the card, the rail, and the list pane's own rows.
///
/// ## AMBER: NONE
///
/// A record at rest commits nothing. The verbs lifted off the row are the
/// row's own widgets — `TorchSecondaryButton` and `TorchTertiaryButton`, both
/// outline-and-ink forms that the ladder never lights — so the only amber on a
/// three-pane screen is still the ask bar's Send, at rung 1, exactly as
/// `ConsoleFrame` declares it. `console_wash_test.dart` counts the regions on
/// every desk screen in both skins and prints the bounds.
@immutable
class RecordFact {
  const RecordFact(this.label, this.value, {this.mono = false});

  /// What the figure is. Sentence case, never a heading.
  final String label;

  /// What it is, already formatted — this component does no arithmetic and
  /// knows no units. A screen that prints money passes what `TiqNumber`
  /// produced for the row, so the pane and the row cannot print two different
  /// amounts for one record.
  final String value;

  /// Identifiers only — an order id, a rule key, a URL. `monoIdent` is the
  /// face a support ticket quotes from.
  final bool mono;
}

/// See the file comment. Everything but [title] is optional, because the nine
/// screens do not all have the same amount to say.
class ConsoleRecordDetail extends StatelessWidget {
  const ConsoleRecordDetail({
    super.key,
    required this.title,
    this.kicker,
    this.lede,
    this.facts = const <RecordFact>[],
    this.blocks = const <Widget>[],
    this.actions = const <Widget>[],
  });

  /// The row's own title, at `titleL`. It wraps rather than truncating: the
  /// pane is where a record is finally allowed to take the space it needs,
  /// which is half of why the pane exists.
  final String title;

  /// The row's mark and the word beside it — a `SeverityMark`, a status chip,
  /// a `FlagChip`. Null on a record with no state worth naming.
  final Widget? kicker;

  /// The row's supporting line, as the row prints it.
  final String? lede;

  /// The record's fields, on one `well` block. See [RecordFact].
  final List<RecordFact> facts;

  /// Anything the record has that is not a label and a value — a progress
  /// meter, an evidence thumbnail, a nested list, a chart.
  final List<Widget> blocks;

  /// **The verbs currently sitting on the row**, lifted. Full width and
  /// stacked, because a pane is not a row and a 440dp column has room to say
  /// what each one does.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;

    return TorchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (kicker != null) ...<Widget>[
            Align(alignment: AlignmentDirectional.centerStart, child: kicker),
            const SizedBox(height: TiqSpace.s3),
          ],
          Semantics(
            header: true,
            child: Text(title, style: skin.text.titleL.style(color: p.ink1)),
          ),
          if (lede != null) ...<Widget>[
            const SizedBox(height: TiqSpace.s2),
            Text(lede!, style: skin.text.body.style(color: p.ink2)),
          ],
          if (facts.isNotEmpty) ...<Widget>[
            SizedBox(height: skin.space.blockGap),
            _Facts(facts: facts),
          ],
          for (final block in blocks) ...<Widget>[
            SizedBox(height: skin.space.blockGap),
            block,
          ],
          for (final action in actions) ...<Widget>[
            SizedBox(height: skin.space.intraBlock),
            action,
          ],
        ],
      ),
    );
  }
}

/// The fields, on one `well` block.
///
/// One block rather than one per field, and label-left/value-right rather than
/// label-over-value: a reader scanning a record is comparing the values, and
/// values in a column are comparable. The label column is [Flexible] and the
/// value is not, so a long label wraps and **a figure is never truncated** —
/// which is the whole subject of the change this component shipped in.
class _Facts extends StatelessWidget {
  const _Facts({required this.facts});

  final List<RecordFact> facts;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.well,
        borderRadius: BorderRadius.circular(skin.radii.control),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TiqSpace.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var i = 0; i < facts.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: TiqSpace.s2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                // THE VALUE GOES TO THE RIGHT EDGE OF THE BLOCK. Two
                // `Flexible` children in a `Row` are content-sized and then
                // packed to the start, which put `Value  R 2,350.75` as one
                // run in the middle of a 400dp block — the figures were not
                // in a column and so were not comparable, which is the whole
                // reason this is a table rather than a paragraph.
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      facts[i].label,
                      style: skin.text.body.style(color: p.ink3),
                    ),
                  ),
                  const SizedBox(width: TiqSpace.s3),
                  Flexible(
                    child: Text(
                      facts[i].value,
                      textAlign: TextAlign.end,
                      style: facts[i].mono
                          ? skin.text.monoIdent.style(color: p.ink2)
                          : skin.text.bodyStrong.style(color: p.ink1),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
