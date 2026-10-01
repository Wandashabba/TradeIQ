import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/torch_press.dart';
import '../../../core/widgets/torchlight/card.dart';
import '../../../core/widgets/torchlight/input/filter_chip.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/menu_sheet.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../data/floor_ask_view.dart';
import '../data/floor_repository.dart';

/// THE BRIEFING — one soft card per line, and **no heading over them**.
///
/// Radius 22, `surface` fill, no outline: [TorchCard] is that material already
/// and this block does not re-declare it. The gap between two cards is
/// `intraBlock` — they are one block, not three — and the gap to whatever
/// follows is `blockGap`, which the caller owns.
///
/// ## The kick is gone, 1 October 2026
///
/// It was an [Eyebrow] printing the window label — `LAST 30 DAYS` — and the
/// approved arrangement has no label over this block at all. The owner's word
/// for what they asked for is *simplistic*, and a screen earns that by what it
/// leaves out: three one-line cards under a photograph need no heading to be
/// read as three readings, and the window they were measured over is already
/// on the scope chip 12dp above them, on the control that sets it.
///
/// Nothing was dropped to achieve it. The window is still stated, once, by the
/// thing that owns it — which is the same argument that took the territory off
/// the hero cluster when the chip arrived.
///
/// **Amber: none.** A briefing is a reading. Nothing on it is armed, nothing on
/// it is the expected next move, and the dot beside each line is the standing's
/// own crimson or green at two commitment levels — which is not on the ladder
/// and never was.
class FloorBriefingBlock extends StatelessWidget {
  const FloorBriefingBlock({super.key, required this.briefs});

  final List<FloorBrief> briefs;

  @override
  Widget build(BuildContext context) {
    if (briefs.isEmpty) return const SizedBox.shrink();
    final skin = context.skin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < briefs.length; i++) ...<Widget>[
          if (i > 0) SizedBox(height: skin.space.intraBlock),
          _BriefCard(brief: briefs[i]),
        ],
      ],
    );
  }
}

class _BriefCard extends StatelessWidget {
  const _BriefCard({required this.brief});

  final FloorBrief brief;

  /// The dot. 8dp, which is the smallest mark in this product that still reads
  /// as a deliberate object rather than as dust on the screen.
  static const double _dot = 8;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return Semantics(
      button: true,
      label: brief.semanticsLabel,
      // The line is a summary and its detail is one tap away — see
      // [FloorBrief.route]. `go`, not `push`: these are destinations the
      // console already has tabs for, not pages on top of The Floor.
      onTap: () => context.go(brief.route),
      excludeSemantics: true,
      child: TorchPressable(
        onPressed: () => context.go(brief.route),
        borderRadius: BorderRadius.circular(skin.radii.card),
        builder: (context, pressed) => TorchCard(
          key: ValueKey<String>('floor-brief-${brief.id}'),
          fill: pressed ? torchPressSurface(skin).fill : null,
          // COMPACT, AND IT HAS TO BE. `TorchCard`'s default inset is s4 on
          // every side, which is the grammar for a card a reader stops at.
          // A briefing line is a card a reader scans past, the mockup draws
          // it at roughly this inset, and on a 360x640 phone the difference
          // across three cards is exactly what decides whether the third line
          // clears the composer — see `floor_proportion_test.dart`.
          padding: const EdgeInsets.symmetric(
            horizontal: TiqSpace.s4,
            vertical: TiqSpace.s3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // The dot carries the verdict and the figure carries the number —
              // §16.2's split, and the reason the figure beside it is plain ink
              // on Night. The word is in the card's own semantics label, so the
              // hue is never the only channel.
              //
              // IT TAKES THE PALETTE DIRECTLY AND NOT `severityInk`, which was
              // the first version and rendered every dot grey. That function
              // answers "may this FIGURE be coloured", and on Night the answer
              // at `FigureRank.row` is no — which is the whole reason the dot
              // exists. Sending a mark through the figures' own suppression
              // rule turns off the channel that rule assumes is still on.
              SizedBox.square(
                dimension: _dot,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: switch (brief.standing) {
                      StatusLevel.critical ||
                      StatusLevel.watch => skin.palette.bad,
                      StatusLevel.onTarget => skin.palette.good,
                      _ => skin.palette.ink3,
                    },
                  ),
                ),
              ),
              SizedBox(width: skin.space.intraBlock),
              // ── ONE LINE: THE NAME, AND NOTHING UNDER IT ────────────
              //
              // The support sentence used to print here on every card, and
              // three cards at two lines each is what made the rejected screen
              // read as dense. The mockup draws a name on the left and a
              // figure on the right, full stop.
              //
              // THE ONE EXCEPTION IS NOT A RELAXATION, IT IS THE SAME RULE.
              // When the figure is an em dash the card has nothing on its
              // right to read, and a name beside a dash is the "unknown is not
              // zero" rule failing quietly — the reader is shown an absence
              // and not told what kind. So the sentence takes the place of the
              // figure it is standing in for, which is where the stat card
              // this line replaced printed it. A populated screen never sees
              // it: every line that has a number prints one line.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      brief.name,
                      style: skin.text.label.style(color: skin.palette.ink1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (brief.value == null)
                      Text(
                        brief.support,
                        style: skin.text.meta.style(color: skin.palette.ink3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              SizedBox(width: skin.space.intraBlock),
              // LUMINOUS INK-1 ON NIGHT, SEMANTIC ON DAY — and it is
              // `standingInk` at [FigureRank.row] that says so, not this file.
              // A briefing line is one figure among three of its kind, which is
              // precisely the rank whose colour Night withholds.
              FigureSlot(
                value: brief.value,
                role: skin.text.figureM,
                unit: brief.unit,
                decimals: brief.decimals,
                color: standingInk(skin, brief.standing, state: brief.state),
                state: brief.state,
                semanticsLabel: brief.semanticsLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// THE SUGGESTION CHIPS — what is worth asking about what is on the screen.
///
/// The same [TorchFilterChip] the assistant's own follow-ups use, for the
/// reason `FollowUpChips` gives: one selected vocabulary across every chip in
/// the app, and a chip that is never selected here. Three amber chips would be
/// the repeated fill unify §1.6 bans outright.
///
/// The row is allowed to be empty. See [floorSuggestions] — every chip is
/// gated on the condition that makes it true, and a chip that is always there
/// is decoration.
class FloorSuggestionChips extends StatelessWidget {
  const FloorSuggestionChips({
    super.key,
    required this.suggestions,
    required this.onAsk,
    this.enabled = true,
  });

  final List<FloorSuggestion> suggestions;
  final ValueChanged<String> onAsk;

  /// False while a turn streams and while offline. A disabled chip stays
  /// visible: hiding it would hide the fact that there is something to ask.
  final bool enabled;

  /// TWO, WHICH IS THE MOCKUP'S COUNT AND ALSO AN ARITHMETIC RESULT.
  ///
  /// [floorSuggestions] can derive three. A third chip wraps to a second row
  /// on a 360dp phone, the row is pinned above the composer, and the 44dp it
  /// costs comes straight off the briefing — which is the block this screen
  /// exists to show. Two fits one line on every supported phone.
  static const int maximum = 2;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    // ONE LINE THAT SCROLLS, never a `Wrap`. A wrapping row changes its own
    // height with the length of a territory's name, and this row is pinned
    // above the composer where a height change pushes the briefing off the
    // fold. A suggestion is an offer; an offer may sit just off the edge.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final suggestion in suggestions.take(maximum))
            Padding(
              padding: const EdgeInsets.only(right: TiqSpace.s2),
              child: TorchFilterChip(
                key: ValueKey<String>('floor-suggestion-${suggestion.id}'),
                label: suggestion.label,
                selected: false,
                semanticsLabel: enabled
                    ? 'Ask: ${suggestion.label}'
                    : 'Ask: ${suggestion.label}, not available right now',
                onSelected: enabled ? () => onAsk(suggestion.label) : null,
              ),
            ),
        ],
      ),
    );
  }
}

/// THE WAY TO EVERY OTHER DESTINATION, ON THE PLATE'S TOP BAND.
///
/// ## Why this exists at all
///
/// The Floor gave up its nav pill on 30 September 2026 so the bottom of the
/// screen could belong to the composer. Four labelled tabs became one control,
/// which is a real loss of discoverability and the one risk in the arrangement
/// the owner chose. Three things are spent buying it back:
///
/// 1. **It carries a surface.** A `surface` fill, an `edgeControl` rule and the
///    chip radius — the same material [PlateScopeChip] beside it wears. A bare
///    mark on this band is the case `entry_plate.dart` measured at **3.60:1**
///    on Night and had to scrim; a control on its own surface is ink on
///    `surface`, which is a declared pairing that passes in both skins and does
///    not depend on what is in the photograph. Measured rather than asserted —
///    see `floor_plate_contrast_test.dart`.
/// 2. **It is a word, not a glyph.** `Menu`, which is what the destination this
///    replaces was already called, beside the mark the nav slot already used.
///    A four-character label fits the band next to a two-fact scope chip on a
///    360dp phone; "More" would have been shorter and vaguer, and an icon
///    alone would have been the thing the owner was right to worry about.
/// 3. **The sheet is worth opening.** See [showFloorDestinations] — the
///    destinations carry their own live numbers, so the control answers
///    "is there anything in there for me" before it is pressed.
///
/// **Amber: none.** It is a control, and controls are never amber (unify §1.6).
class FloorDestinationsButton extends StatelessWidget {
  const FloorDestinationsButton({
    super.key,
    required this.onTap,
    this.compact = false,
  });

  final VoidCallback onTap;

  /// THE WORD GOES ON A NARROW PHONE, AND ONLY THERE.
  ///
  /// The label is worth 46dp of the plate's top band and the band is shared
  /// with the scope chip, which carries a territory name and a window and
  /// wraps to two lines rather than ellipsising — that is the chip's own rule,
  /// and it is the right one: a scope you cannot read is a scope you cannot
  /// trust.
  ///
  /// On a 360dp phone those 46dp are exactly what pushes the chip to its
  /// second line, and a two-line chip is 68dp tall against a strip light that
  /// rides at 0.38 of a 192dp plate — so the chip lands **on** the light. The
  /// render at 360×640 is where that showed up.
  ///
  /// So the word is dropped at the one width where keeping it breaks the plate
  /// underneath it. The spoken label does not change: a screen reader gets the
  /// same sentence at every width, because the control's meaning has not got
  /// narrower.
  final bool compact;

  /// Under this width the label is dropped. 390 is the narrowest phone the
  /// mockup was drawn at and the width at which the chip still fits one line.
  static const double compactUnder = 380;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final radius = BorderRadius.circular(skin.radii.chip);

    return Semantics(
      button: true,
      label: 'Menu. Work, territories, reports and settings.',
      onTap: onTap,
      excludeSemantics: true,
      child: TorchPressable(
        onPressed: onTap,
        borderRadius: radius,
        builder: (context, pressed) => Container(
          constraints: BoxConstraints(minHeight: skin.space.tapTarget),
          decoration: BoxDecoration(
            color: pressed ? torchPressSurface(skin).fill : p.surface,
            borderRadius: radius,
            border: Border.all(
              color: p.edgeControl,
              width: skin.depth.borderWidth,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: TiqSpace.s3,
            vertical: TiqSpace.s2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.menu,
                size: MarkScale.glyph(context, 18),
                color: p.ink1,
              ),
              if (!compact) ...<Widget>[
                const SizedBox(width: TiqSpace.s2),
                Text(
                  'Menu',
                  style: skin.text.label
                      .copyWith(weight: FontWeight.w600)
                      .style(color: p.ink1),
                  maxLines: 1,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// THE DESTINATIONS, WITH THEIR OWN NUMBERS ON THEM.
///
/// It is [showTorchMenuSheet] — the console's one menu, reading
/// `managerDestinations` — with two rows put in front of it: the two nav slots
/// The Floor gave up when the composer took the bottom of the screen.
///
/// **It is not a second destination list.** A parallel copy of the console's
/// destinations is exactly how The Floor ended up with a nav pill wired to
/// `(_) {}`, and the menu sheet's own doc says so. The rows below are the two
/// the pill carried and nothing else; everything further down the sheet is the
/// same list every other console route opens.
///
/// **The numbers are the point.** A destination that tells a manager whether to
/// go there is a better control than a tab that does not — and they come off
/// the [FloorView] this screen already has, so the sheet cannot disagree with
/// the briefing above it.
Future<void> showFloorDestinations(BuildContext context, FloorView view) {
  final overdue = view.decisions.length;
  final measured = view.phase == FloorPhase.measured;

  return showTorchMenuSheet(
    context,
    lead: <Widget>[
      const SectionRule('Where you were'),
      const SizedBox(height: TiqSpace.s3),
      Builder(
        builder: (rowContext) => SoftRow(
          key: const ValueKey<String>('floor-destination-work'),
          density: SoftRowDensity.compact,
          title: 'Work',
          // Withheld rather than zeroed when the list is: a scope whose
          // coverage request failed has an unknown backlog, and "0 need a
          // decision" is the one reading that is certainly wrong.
          subtitle: switch (view.scope) {
            FloorScope.failed || FloorScope.pending => null,
            _ when overdue == 0 => 'Everything triaged',
            _ =>
              '$overdue ${overdue == 1 ? 'thing needs' : 'things need'} '
                  'a decision',
          },
          trailing: const SoftRowChevron(),
          onTap: () {
            Navigator.of(rowContext).pop();
            rowContext.go('/tasks');
          },
        ),
      ),
      Builder(
        builder: (rowContext) => SoftRow(
          key: const ValueKey<String>('floor-destination-overview'),
          density: SoftRowDensity.compact,
          title: 'Overview',
          subtitle: measured
              ? 'Health ${view.snapshot.current.executionScore.round()} · '
                    'availability ${view.snapshot.current.osaPct.round()}%'
              : 'No visits in this window',
          trailing: const SoftRowChevron(),
          onTap: () {
            Navigator.of(rowContext).pop();
            rowContext.go('/dashboard/overview');
          },
        ),
      ),
      const SizedBox(height: TiqSpace.s6),

      // THE STANDING ACTION'S TWO VERBS, which lost their circle when the nav
      // row left. The circle sat beside the nav pill and went with it, and its
      // label has promised "Raise a task or assign a visit" since it was
      // drawn. Both rows are the same two destinations `showFloorStandingAction`
      // opened, so the capability moved rather than went — and a manager who
      // wants either can now also just ask for it in the composer, which is
      // the whole point of the screen they are standing on.
      const SectionRule('Put somebody on a problem'),
      const SizedBox(height: TiqSpace.s3),
      Builder(
        builder: (rowContext) => SoftRow(
          key: const ValueKey<String>('floor-standing-raise-task'),
          density: SoftRowDensity.compact,
          title: 'Raise a task',
          subtitle: 'Against a finding on the work queue',
          trailing: const SoftRowChevron(),
          onTap: () {
            Navigator.of(rowContext).pop();
            rowContext.go('/tasks');
          },
        ),
      ),
      Builder(
        builder: (rowContext) => SoftRow(
          key: const ValueKey<String>('floor-standing-assign-visit'),
          density: SoftRowDensity.compact,
          title: 'Assign a visit',
          subtitle: 'Send an agent to an outlet today',
          trailing: const SoftRowChevron(),
          onTap: () {
            Navigator.of(rowContext).pop();
            rowContext.go('/dispatch');
          },
        ),
      ),
      const SizedBox(height: TiqSpace.s6),
    ],
  );
}
