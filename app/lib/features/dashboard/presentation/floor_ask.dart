import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/torch_press.dart';
import '../../../core/widgets/torchlight/card.dart';
import '../../../core/widgets/torchlight/input/filter_chip.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/menu_sheet.dart';
import '../../../core/widgets/torchlight/plate/plate.dart'
    show plateQuietButtonAlpha, plateQuietExtent, plateQuietRadius;
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../data/floor_ask_view.dart';
import '../data/floor_repository.dart';

/// THE BRIEFING — one soft card per line, and **no heading over them**.
///
/// Radius 22, `surface` fill, no outline: [TorchCard] is that material already
/// and this block does not re-declare it. The gap to whatever follows is
/// `blockGap`, which the caller owns.
///
/// ## THE GAP BETWEEN TWO CARDS IS [cardGap], NOT `intraBlock` — 1 Oct 2026
///
/// It was `skin.space.intraBlock`, which is 12dp. The mockup's is
/// `margin-bottom:5px`, which is **6.5dp** at 1.3 dp/px — so the drawn block
/// was carrying 24dp of air across three cards where the drawing carries 13,
/// and the owner read the result as cards "much taller with a much larger
/// gap". Measured, the cards are within a dp of the drawing's height; **it was
/// the gap doing all of it**, which is why nothing about [_BriefCard]'s own
/// inset changed in this pass.
///
/// `intraBlock` was the honest token for "between two things inside one
/// section" and it is still the right one for the rest of this screen. These
/// three cards are tighter than that: they are one reading broken into three
/// lines, not three things that happen to be near each other, and the drawing
/// says so with a gap half the size of every other gap on the screen.
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

  /// The air between two briefing lines: the mockup's 6.5dp, taken to the
  /// nearest step on the 4dp scale. See the note on this class for why it is
  /// not `space.intraBlock`.
  static const double cardGap = TiqSpace.s2;

  @override
  Widget build(BuildContext context) {
    if (briefs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < briefs.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: cardGap),
          _BriefCard(brief: briefs[i]),
        ],
      ],
    );
  }
}

/// THE BRIEFING LINE'S SEVERITY DOT, at the two commitment levels the rest of
/// the console already draws.
///
/// | standing | silhouette | ink |
/// |---|---|---|
/// | `critical` | filled disc | `badSolid` |
/// | `watch` | 2px ring, hollow | `bad` |
/// | `onTarget` | filled disc | `good` |
/// | anything else | filled disc | `ink3` |
///
/// The inks are `SeverityMarkToken`'s, not this file's choice: `badSolid` is
/// the fill grade and `bad` the word grade, and a ring is mostly outline so it
/// takes the grade that is legible as a stroke. See the long note at the call
/// site for the defect this replaced.
class _BriefDot extends StatelessWidget {
  const _BriefDot({required this.standing});

  final StatusLevel? standing;

  /// 8dp, which is the smallest mark in this product that still reads as a
  /// deliberate object rather than as dust on the screen. It scales with the
  /// text because it carries meaning.
  static const double extent = 8;

  @override
  Widget build(BuildContext context) {
    final p = context.skin.palette;
    // A RING, NOT A PALER DISC. unify's severity rule is a second silhouette
    // rather than a lower opacity — a 50% crimson disc is a crimson disc to
    // anyone looking at a phone in sunlight, and it is indistinguishable from
    // a disc at full strength in greyscale.
    final watch = standing == StatusLevel.watch;
    final ink = switch (standing) {
      StatusLevel.critical => p.badSolid,
      StatusLevel.watch => p.bad,
      StatusLevel.onTarget => p.good,
      _ => p.ink3,
    };
    final size = MarkScale.glyph(context, extent);
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: watch ? null : ink,
          border: watch
              ? Border.all(color: ink, width: context.skin.depth.borderWidth * 2)
              : null,
        ),
      ),
    );
  }
}

class _BriefCard extends StatelessWidget {
  const _BriefCard({required this.brief});

  final FloorBrief brief;

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
              //
              // ── WATCH IS NOT CRITICAL, AND THE DOT SAID IT WAS ──────────
              //
              // A DEFECT, FOUND 1 OCTOBER 2026, AND IT WAS A REAL ONE.
              //
              // This switch read `critical || watch => bad`, so the only two
              // faces a dot had were "crimson" and "green". On-shelf
              // availability at 94 against a published 95 is
              // `StatusLevel.watch` — `againstStandard` has a 10-point watch
              // band, so 85..94 is watch and only under 85 is critical — and
              // the card beside the dot was already saying so in words:
              // `close to the 95 standard`. The screen was stating one
              // severity in prose and a harder one in colour, about the same
              // figure, eight dp apart. The prose was right.
              //
              // It was crimson because crimson was the only thing wired up,
              // which is the owner's own test for a defect rather than a
              // choice.
              //
              // THE TWO LEVELS ARE THE SYSTEM'S OWN, not a new pair invented
              // here. `SeverityMarkToken` has drawn critical and watch as one
              // hue at two commitment levels since the severity vocabulary
              // landed — `badSolid` filled against `bad` outlined — and
              // `standingInk`'s doc names the distinction in as many words:
              // *"the mark beside the figure is what carries the level, by
              // fill against outline… a filled dot against an outlined one."*
              // That sentence described a dot this file was not drawing. It is
              // drawing it now.
              //
              // The ring is 2px of a 8dp dot, leaving a 4dp hole — visible at
              // 1.0× and growing with the mark scale. The hue barely moves
              // between the two levels on purpose: the LEVEL is carried by the
              // silhouette, which survives greyscale and survives both kinds
              // of red-green colour blindness, and the word is in the card's
              // own semantics label either way. Nothing here is the only
              // channel.
              _BriefDot(standing: brief.standing),
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
                // THE PLATE-SIDE WEIGHT. An offer above a composer, not a
                // filter in a rail — and at the rail's drawn height the
                // second chip was cut off at the screen edge on the owner's
                // own render. See [TorchFilterChip.quiet].
                quiet: true,
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
/// the owner chose. Two things are spent buying it back:
///
/// 1. **It carries a wash of the ground.** [plateQuietButtonAlpha] of
///    `ground`, which is the mockup's `rgba(11,16,23,.55)`. A bare mark on
///    this band is the case `entry_plate.dart` measured at **3.60:1** on Night
///    and had to scrim; this control's ink lands on a declared wash instead,
///    which passes in both skins over every committed photograph. Measured
///    rather than asserted — see `floor_plate_contrast_test.dart`.
/// 2. **The sheet is worth opening.** See [showFloorDestinations] — the
///    destinations carry their own live numbers, so the control answers
///    "is there anything in there for me" before it is pressed.
///
/// ## THE WORD IS GONE AT EVERY WIDTH — 1 October 2026
///
/// The third thing that used to be spent here was the printed word `Menu`, and
/// the argument for it was good: *"a four-character label fits the band next
/// to a two-fact scope chip on a 360dp phone… an icon alone would have been
/// the thing the owner was right to worry about."*
///
/// **The mockup has no label at any width.** The previous round had already
/// conceded half of this — the word dropped below 380dp, as a repair for a
/// two-line scope chip landing on the strip light — and a control whose
/// discoverability argument is abandoned on the narrower of two supported
/// phones was never really making that argument. The drawing is `width:22px;
/// height:22px; border-radius:7px` with a `☰` in it and nothing else. So the
/// word goes, the `compact` flag goes with it, and the control is one size on
/// both phones instead of two sizes on two.
///
/// **The spoken label is untouched, and it is the whole point of keeping it.**
/// `Menu. Work, territories, reports and settings.` is what a screen reader
/// has always been given and the only thing it has — a glyph says nothing to
/// anyone who cannot see it, so the sentence is now carrying the control's
/// entire meaning for those readers rather than merely repeating a word
/// beside it. It is required, not optional, for exactly that reason.
///
/// What was bought with the word: 46dp of the band back on every phone, which
/// is what lets the scope chip hold one line at 360dp without the drop-the-
/// label special case, and the band's clearance over the strip light stops
/// depending on a width test. `floor_proportion_test.dart` measures it.
///
/// **Amber: none.** It is a control, and controls are never amber (unify §1.6).
class FloorDestinationsButton extends StatelessWidget {
  const FloorDestinationsButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final radius = BorderRadius.circular(plateQuietRadius);

    return Semantics(
      button: true,
      // THE ONLY THING A SCREEN READER HAS, now that the word is gone. See the
      // note on this class.
      label: 'Menu. Work, territories, reports and settings.',
      onTap: onTap,
      excludeSemantics: true,
      child: TorchPressable(
        onPressed: onTap,
        borderRadius: radius,
        // A 29dp drawn square centred in a 44dp transparent target: the
        // mockup's weight, the rule's reach. See [plateQuietExtent].
        builder: (context, pressed) => SizedBox.square(
          dimension: skin.space.tapTarget,
          child: Center(
            child: Container(
              width: plateQuietExtent,
              height: plateQuietExtent,
              decoration: BoxDecoration(
                color: pressed
                    ? torchPressSurface(skin).fill
                    : p.ground.withValues(alpha: plateQuietButtonAlpha),
                borderRadius: radius,
                // No border. The mockup has none, and the wash is what gives
                // the glyph its floor.
              ),
              child: Center(
                // The mockup's `font-size:11px` is 14dp at 1.3 dp/px.
                child: Icon(
                  Icons.menu,
                  size: MarkScale.glyph(context, 14),
                  color: p.ink1,
                ),
              ),
            ),
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
///
/// ## [view] IS NULLABLE SINCE 2 OCTOBER 2026, and that is the whole change
///
/// This is now the sheet the grid button opens from **every** console screen,
/// and Webhooks has no [FloorView]. A null view is the same epistemic state
/// the `failed` and `pending` scopes below already have a branch for — the
/// backlog is unknown — so the subtitles are **withheld rather than zeroed**,
/// by the same rule and in the same `switch`. "0 need a decision" is the one
/// reading that is certainly wrong.
///
/// What does **not** change is the rows, their order, their keys or where they
/// go. One sheet, one destination list, one gesture; the live numbers are an
/// upgrade the screen that has them gets, never a different menu.
Future<void> showFloorDestinations(BuildContext context, FloorView? view) {
  final overdue = view?.decisions.length;
  final measured = view != null && view.phase == FloorPhase.measured;

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
          subtitle: switch (view?.scope) {
            // No view at all — a screen that is not The Floor — reads the
            // same as a scope whose coverage request failed: unknown.
            null || FloorScope.failed || FloorScope.pending => null,
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
          // Three states, not two: measured prints the reading, a measured-
          // but-empty window says so, and NO VIEW says nothing. "No visits in
          // this window" off a screen that never asked about a window would
          // be the sheet inventing a fact.
          subtitle: view == null
              ? null
              : measured
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
