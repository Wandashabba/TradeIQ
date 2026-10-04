import 'package:flutter/widgets.dart';

import '../../theme/torchlight/tiq_skin.dart';
import 'list_action.dart';

/// THE CONSOLE'S ONLY SECTION MARKER — words on the ground.
///
/// The section's name, uppercase, letter-spaced, on the ground. No line across
/// the screen, no count chip, no emoji, and **never amber**.
///
/// ```dart
/// SectionRule('Needs a decision', count: 5)
/// SectionRule('Today’s field')
/// SectionRule(
///   'Needs a decision',
///   count: 12,
///   action: SectionRuleAction('See all', onTap: () => context.push('/work')),
/// )
/// ```
///
/// ## The rule went, 25 September 2026
///
/// This was a 1px line running gutter to gutter with the name knocked out of
/// it, and unify §1.17 said so — with The Floor named as the single exception,
/// and "every other screen keeps the knocked-out rule; this is not a licence
/// to delete it" written next to it. The owner has now looked at The Floor
/// finished and said to make its design "global and everywhere on the app", so
/// the exception is the grammar and the licence is granted. The override is
/// recorded in `docs/design/spec/unify.md` §1.17 and
/// `docs/design/torchlight-aisle.md` §9c.
///
/// The reasoning the ruling was built on is answered rather than thrown away:
///
/// * **"A line is how a reader knows a section started."** On a screen whose
///   rows are cards with a gap of ground between them, it is not. The card
///   grammar already puts air between blocks, and a line drawn across that air
///   is a second boundary saying what the gap has said — which is the
///   "one more box" the owner objected to twice.
/// * **"An uppercase kicker is the thing this component replaced."** It
///   replaced an *amber* kicker and a *numbered* one. This is neither: it is
///   ink-2 at the eyebrow role, it emits no light, and the count rides in the
///   words instead of in a mark beside them.
/// * **The string stays sentence case.** The uppercasing is presentation, so a
///   screen reader is handed the sentence and not a spelled-out shout — the
///   same split [Eyebrow] makes, and the reason the assert below is still
///   here.
///
/// ## What did not change
///
/// [count] and [action] are **information and capability** and both stay. A
/// restyle changes appearance, not what a screen can do: "Needs attention 3"
/// told a manager how big the pile was, and "See all" is a route. The count
/// simply sets in the marker's own words — `NEEDS ATTENTION · 3` — rather than
/// as a separate mono figure beside them, which is the "count chip" the
/// override names. [emptyLine] stays for the same reason it was written: a
/// section that vanishes when empty makes a manager think the feature is gone.
class SectionRule extends StatelessWidget {
  const SectionRule(
    this.name, {
    super.key,
    this.count,
    this.action,
    this.emptyLine,
    this.listAction = false,
  });

  /// Sentence case. Asserted, because the **data** must stay sentence case —
  /// `text.toUpperCase()` at a call site puts the shout into the string, where
  /// it reaches a screen reader that spells it out, a search index and the PDF
  /// exporter. Here it is a presentation of a sentence-case string.
  final String name;

  /// Follows the name inside the same marker: `NEEDS A DECISION · 5`.
  ///
  /// Not a chip and not a separate figure. It is how many are in the section,
  /// and a manager who is deciding whether to open it is reading exactly that.
  final int? count;

  /// A ghost text action at the right end. A route, and therefore kept.
  final SectionRuleAction? action;

  /// One `body` `ink2` line beneath, for a section that is empty. The marker
  /// still renders: a section that vanishes when empty makes a manager think
  /// the feature is gone.
  final String? emptyLine;

  /// ── THIS MARKER IS THE LIST PANE'S TOOLBAR ROW — 4 October 2026 ───────
  ///
  /// Set on the one marker per desk screen that names and counts **the
  /// records**, which is where the route's single header control belongs: with
  /// the count and the list's own verbs, not pinned to the pane's corner 470dp
  /// away. See [TorchListAction] for the owner's sentence and for why the
  /// control arrives through the tree rather than as an argument.
  ///
  /// **It changes nothing below the desk threshold.** There is no
  /// [TorchListAction] in a phone tree, so [TorchListAction.controlIn] is null
  /// and this marker lays out exactly as it did before — which matters because
  /// on every one of these screens the phone arm and the list pane are handed
  /// the *same instance*.
  ///
  /// It is false on a marker that heads some other block in the same pane
  /// (Dispatch's outlet picker, Sales targets' attainment levels, Outlets' pin
  /// reports, Templates' in-audits), which is the ambiguity that made a flag
  /// necessary instead of the frame simply taking the first marker it found.
  final bool listAction;

  /// The gap between the marker and an action beside it.
  static const double actionGap = TiqSpace.s3;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    assert(
      name.toUpperCase() != name || name.length < 3,
      'SectionRule: "$name" is already uppercase. The marker uppercases for '
      'display and hands the sentence-case string to anything that reads — a '
      'shout in the data reaches the screen reader, the search index and the '
      'PDF exporter.',
    );

    // THE LIFTED CONTROL, OR NOTHING AT ALL. Non-null only at desk width, on
    // the pane whose frame installed one, and on the marker that said it is
    // the toolbar row. Every other case is null and the layout below is the
    // one this component has always had.
    final lifted = listAction ? TorchListAction.controlIn(context) : null;

    final printed = count == null ? name : '$name · $count';
    final label = Semantics(
      header: true,
      label: count == null ? name : '$name, $count',
      excludeSemantics: true,
      child: Text(
        printed.toUpperCase(),
        // Two, which is the eyebrow role's own allowance: at 2.0× in
        // Afrikaans a one-line marker would ellipsise, and half a section
        // marker is worse than a marker that wraps.
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: skin.text.eyebrow.style(color: skin.palette.ink2),
      ),
    );

    // ── THE CONTROL GOES WITH THE WORDS, NOT AT THE PANE'S EDGE ─────────
    //
    // > *"The refresh belongs there, with the count and the list's own verbs,
    // > not pinned to the pane's corner."*
    //
    // The first draft of this hung the control on the **right** of the row and
    // the render disproved it: `SectionRuleAction` shrink-wraps, so a marker
    // reads `PLANS · 3  New plan` at the pane's leading edge and a glyph at
    // the far right was 400dp of nothing away from it — the owner's own
    // complaint, moved down one row. So the control joins the group: the
    // marker's words, the verb if there is one, then the control.
    //
    // **The verb's measurement does not have to learn about it.** `Flexible`
    // lays its child out against `available − gap − control`, so the
    // `LayoutBuilder` beneath still sees the width the verb actually has and
    // `_actionStacks` keeps deciding correctly without a reserve anybody has
    // to maintain.
    Widget withLifted(Widget marker) => lifted == null
        ? marker
        : Row(
            // Centred, which is right in the case that matters: a marker with
            // a verb is already `tapTarget` tall from `SectionRuleAction`'s
            // own floor, so the glyph and the words sit on one line. The
            // marker that stacks — Afrikaans at 2.0× — puts the glyph between
            // its two lines rather than beside the first, which is the honest
            // cost of not giving a toolbar row a second layout nobody can see.
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Flexible(child: marker),
              const SizedBox(width: actionGap),
              lifted,
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (action == null)
          withLifted(label)
        else
          withLifted(
            LayoutBuilder(
              builder: (context, constraints) {
                // MEASURE THE ACTION, DO NOT RESERVE FOR IT. A constant cannot
                // know how long a verb is in Afrikaans: "Add a scheme" at 2.0×
                // is roughly three times TiqSpace.s11, and a fixed reservation
                // is what once ran an action 168dp off the right of a 360dp
                // phone. This is the same measurement the rule form made, with
                // the rule's own minimum run taken out of it.
                final stacked = _actionStacks(
                  context,
                  skin,
                  constraints.maxWidth,
                );
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[label, action!],
                  );
                }
                return Row(
                  // SHRINK-WRAPPED, so the arrangement reports the width its
                  // words actually take and a lifted control can sit beside
                  // them rather than at the pane's edge. It changes no pixel
                  // without one: the row was already start-aligned in a
                  // full-width column with the verb immediately after the
                  // marker, and `desk_phone_identity_test.dart` holds that as
                  // a sha256.
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Flexible(child: label),
                    const SizedBox(width: actionGap),
                    action!,
                  ],
                );
              },
            ),
          ),
        if (emptyLine != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s3),
          Text(
            emptyLine!,
            style: skin.text.body.style(color: skin.palette.ink2),
          ),
        ],
      ],
    );
  }

  /// Whether the marker and its action stop fitting on one line.
  bool _actionStacks(BuildContext context, TiqSkin skin, double maxWidth) {
    if (!maxWidth.isFinite) return false;
    final scaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    double widthOf(String text, TiqTypeToken token) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: token.style(color: skin.palette.ink1),
        ),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final marker = widthOf(
      (count == null ? name : '$name · $count').toUpperCase(),
      skin.text.eyebrow,
    );
    final verb = widthOf(action!.label, skin.text.label);
    return marker + actionGap + verb > maxWidth;
  }
}

/// The ghost text action a section marker may carry at its right end.
///
/// **The node carries the tap itself.** `excludeSemantics` drops the
/// descendant `GestureDetector`'s node, so an outer `Semantics(button: true)`
/// without its own `onTap` announces a button a screen-reader user can focus
/// and cannot activate — the kit-wide defect the button family was repaired
/// for, which this one widget still had. `section_rule_test.dart` performs the
/// action through `SemanticsAction.tap` so it cannot come back.
class SectionRuleAction extends StatelessWidget {
  const SectionRuleAction(this.label, {super.key, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: skin.space.tapTarget),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              label,
              style: skin.text.label.style(color: skin.palette.ink2),
            ),
          ),
        ),
      ),
    );
  }
}
