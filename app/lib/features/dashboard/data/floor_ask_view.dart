import 'package:flutter/foundation.dart';

import '../../../core/design/tiq_number.dart' show FigureState, TiqUnit;
import '../../../core/widgets/torchlight/figure/sample_threshold.dart';
import '../../../core/widgets/torchlight/marks.dart'
    show StatusLevel, againstStandard;
import '../presentation/standards.dart';
import 'floor_repository.dart';

/// THE BRIEFING AND THE SUGGESTIONS — what The Floor says before it is asked.
///
/// Both are **pure functions of [FloorView]**, which is the whole point of the
/// file. The Floor learned to hold a composer on 30 September 2026, and the two
/// things that arrived with it — three lines saying what moved, and two chips
/// offering the question a manager was about to type — are the two things
/// easiest to fake. A hardcoded "Why is 73 down?" is a lie the moment the
/// territory changes, and a briefing assembled from a second endpoint is a
/// second version of the truth sitting directly above the first.
///
/// So: **no new feed.** Everything below is read off the `FloorView` the screen
/// already had — which is assembled in `floor_repository.dart` from
/// `dashboardSnapshotProvider`, `alertsListProvider`, `tasksListProvider`,
/// `outletsListProvider` and `territoryCoverageProvider`. If a figure is not on
/// this screen already, it is not in the briefing.
///
/// Being pure is what lets the suggestion strings be asserted against a scope
/// without pumping a frame: `floor_ask_view_test.dart` changes the territory
/// and reads the chips back.

/// A NOTE ON THE TONE, which is a [StatusLevel] and not an enum of its own.
///
/// The first draft of this file declared `FloorBriefTone { bad, good, neutral }`
/// and it was three names for something the console already has. `StatusLevel`
/// is the vocabulary every other standing in this product is stated in, and it
/// is what `standingInk` and `severityFor` take — so a briefing line gets the
/// screen's own ink rule for free, including the one that matters here:
/// [FigureRank.row] is **never coloured on Night** and takes its verdict's ink
/// on Day. A private enum would have needed that rule written a second time,
/// which is how two screens end up disagreeing about what 61% means.
///
/// `SoftRowSeverity` is the other candidate and is wrong for the opposite
/// reason: it is a property of a *finding*, it carries a required severity
/// word into a row's accessible name, and it has no value for good news.

/// ONE LINE OF THE BRIEFING: a dot, a name and a figure. **One line.**
///
/// It carried a second printed line on every card — `all of it in Ekurhuleni`,
/// `under the 95 standard` — until 1 October 2026. The mockup draws the card
/// as a name on the left and a figure on the right, and that second line is
/// most of why the screen the owner rejected read as dense: three cards at two
/// lines each is six lines of the fold spent before anything is asked.
///
/// The sentence is not deleted, it stops being **printed where there is a
/// figure to read instead**. It is always in [semanticsLabel], and it is
/// printed in the one case where the card would otherwise say nothing at all:
/// [state] is [FigureState.missing], the figure is an em dash, and *why there
/// is no number* is then the only content the line has. An em dash with
/// nothing beside it is the "unknown is not zero" rule failing quietly — see
/// [support].
@immutable
class FloorBrief {
  const FloorBrief({
    required this.id,
    required this.name,
    required this.support,
    required this.value,
    required this.standing,
    required this.semanticsLabel,
    required this.route,
    this.unit = TiqUnit.none,
    this.decimals = 0,
    this.state = FigureState.measured,
  });

  /// Stable across rebuilds, for the widget key and for a test to find a line
  /// without matching on prose.
  final String id;

  /// `Overdue work`, `On-shelf availability`, or an outlet's own name. The
  /// whole of what the card prints on its left when there is a figure.
  final String name;

  /// Why there is no figure, or where the work is. **Spoken always, printed
  /// only when [value] is absent.** See the note on this class.
  final String support;

  /// Null renders an em dash, never a zero. Unknown is not zero here either.
  final num? value;

  final TiqUnit unit;
  final int decimals;

  /// HOW MUCH OF THE FIGURE IS REAL, and it is the same three-way answer the
  /// card this line replaced was already giving.
  ///
  /// `missing` is a window nobody visited — an em dash and a sentence, never a
  /// zero. `lowSample` is a rate computed off too few readings: the number
  /// stays, because a thin sample is a real measurement a reader should trust
  /// less rather than an absence, and the slot draws it at ink-2 so the
  /// distrust is visible without a second line of prose.
  final FigureState state;

  /// Where this reading stands. Null is "no verdict" — the figure takes plain
  /// ink, which is the honest render for a count that has no standard.
  final StatusLevel? standing;

  /// The whole line as one sentence. The dot's colour is never the only
  /// carrier of the tone — this is where the word goes.
  final String semanticsLabel;

  /// WHERE THE FIGURE BEHIND THIS LINE LIVES.
  ///
  /// Required rather than optional, because a briefing line that cannot be
  /// opened is the end of the road for a fact, and two of these three lines
  /// replaced a card that *was* openable — the availability card's own `onTap`
  /// went to the overview. A summary that loses the way into its own detail is
  /// a summary that has taken something away.
  final String route;
}

/// THE THREE LINES, IN THE ORDER THE MOCKUP PUTS THEM.
///
/// Overdue work, on-shelf availability, worst single outlet. The order is
/// fixed rather than ranked by severity: a briefing whose lines move between
/// visits is a briefing a manager has to read rather than glance at, and the
/// list below is already sorted worst-first for the reading that needs it.
///
/// A line is **omitted** rather than faked when the fact behind it is not
/// there: an unmeasured window has no availability reading, and a territory
/// with nothing wrong has no worst outlet. Two lines is a correct briefing;
/// three lines with an invented one is not.
List<FloorBrief> floorBriefing(FloorView view, DateTime now) {
  final briefs = <FloorBrief>[];
  final measured = view.phase == FloorPhase.measured;

  // 1. OVERDUE WORK — the same merged, ranked list the decision rows draw.
  //    Not a second count from a second place: `FloorView.decisions` is what
  //    the list below renders, so the briefing and the list can never
  //    disagree about how much there is.
  //
  //    Withheld, not zeroed, when the list itself is withheld: a scope whose
  //    coverage request failed has an unknown amount of overdue work, and
  //    "0" would be the one reading that is certainly wrong.
  if (view.scope != FloorScope.failed && view.scope != FloorScope.pending) {
    final count = view.decisions.length;
    briefs.add(
      FloorBrief(
        id: 'overdue',
        name: 'Overdue work',
        support: _whereItIs(view),
        value: count,
        // Overdue work has no published standard, so the only honest verdict
        // is the binary one: none is on target, any is not. `watch` would be
        // a band nobody has defined.
        standing: count == 0 ? StatusLevel.onTarget : StatusLevel.critical,
        // AN EMPTY SLICE AND AN EMPTY WORLD ARE DIFFERENT FACTS, and with the
        // decision list off this screen the sentence that used to keep them
        // apart ("Nothing needs a decision in Western Seaboard") went with it.
        // So the distinction moves here, where the figure it qualifies is:
        // `_whereItIs` names the territory when one is chosen.
        semanticsLabel:
            'Overdue work, '
            '${count == 0 ? 'none' : '$count ${count == 1 ? 'item' : 'items'}'}'
            '. ${_sentenceCase(_whereItIs(view))}.',
        route: '/tasks',
      ),
    );
  }

  // 2. ON-SHELF AVAILABILITY — `snapshot.current.osaPct`, against the same
  //    published 95 the overview reads it against.
  //
  //    THE LINE IS ALWAYS HERE, INCLUDING WHEN THE WINDOW WAS NEVER MEASURED.
  //    Omitting it would have been the easy read of "a line is omitted rather
  //    than faked", and it is the wrong one: an unmeasured window is not a
  //    window without availability, it is a window whose availability nobody
  //    knows, and those are the two facts unify §4 exists to keep apart. The
  //    figure renders an em dash and the support says why — which is what the
  //    card this replaced did, in the same words.
  final osa = view.snapshot.current.osaPct;
  final standing = measured
      ? againstStandard(osa, availabilityStandard)
      : null;
  final thin = TiqSample.isLow(
    MetricKind.rate,
    view.snapshot.current.sampleSizes.osaPct,
  );
  briefs.add(
    FloorBrief(
      id: 'availability',
      name: 'On-shelf availability',
      support: _availabilitySupport(view, standing),
      value: measured ? osa : null,
      unit: TiqUnit.percent,
      standing: standing,
      state: !measured
          ? FigureState.missing
          : thin
          ? FigureState.lowSample
          : FigureState.measured,
      semanticsLabel: measured
          ? 'On-shelf availability, ${osa.round()} percent. '
                '${_availabilitySupport(view, standing)}.'
          : 'On-shelf availability, ${_availabilitySupport(view, standing)}.',
      // Where the card that used to print this figure went, and where its
      // sparkline and its two supports still are.
      route: '/dashboard/overview',
    ),
  );

  // 3. THE WORST SINGLE OUTLET — the head of the list, which is already
  //    sorted worst-first by `FloorDecision.compare`.
  //
  //    THE FIGURE IS AN AGE AND THE UNIT IS NOT THIS LINE'S TO CHOOSE.
  //    It printed `17 207h` — 717 days — because the unit was typed here as a
  //    literal to match a column eleven lines down that typed the same
  //    literal. Both are gone: the ladder is `FloorAge`, it lives on
  //    `FloorDecision` beside the timestamp it reads, and every reader of an
  //    age on this screen gets the same unit because there is nowhere else to
  //    get one from. The mockup's `6d` falls out of it rather than being a
  //    second opinion.
  final worst = view.decisions.isEmpty ? null : view.decisions.first;
  if (worst != null) {
    final age = worst.ageAt(now);
    briefs.add(
      FloorBrief(
        id: 'worst-outlet',
        name: worst.outletName,
        support: worst.reason,
        value: age?.value,
        unit: age?.unit ?? TiqUnit.none,
        decimals: 0,
        // DECLARED, NOT PRODUCED. `FigureSlot`'s own doc: a caller that passes
        // a null value and no state has not declared an absence, it has made
        // one. A finding nobody timestamped has an unknown age, and the slot
        // has to be told so in order to draw the em dash at ink-3 and refuse
        // the verdict colour it would otherwise take from `standing`.
        state: age == null ? FigureState.missing : FigureState.measured,
        standing: StatusLevel.critical,
        semanticsLabel: age == null
            ? '${worst.outletName}, ${worst.reason}. No time recorded.'
            : '${worst.outletName}, ${worst.reason}. ${age.spoken}.',
        // The decision's own route — the same one the Work queue carries.
        route: worst.route,
      ),
    );
  }

  return briefs;
}

/// `all of it at Kasi Corner Spaza` → `All of it at Kasi Corner Spaza`.
///
/// The supports are written as fragments, because they are read as fragments
/// under a name. A screen reader gets them as the second sentence of a label,
/// and a sentence that starts lower case is a sentence that was not meant to
/// be one.
String _sentenceCase(String fragment) => fragment.isEmpty
    ? fragment
    : fragment[0].toUpperCase() + fragment.substring(1);

/// `all of it in Ekurhuleni`, `across 4 outlets`, or `everything triaged`.
///
/// It says WHERE the work is, because the count already says how much. The
/// single-outlet case is the one worth naming outright: a manager whose whole
/// backlog is in one shop has a different morning from one whose backlog is
/// spread across the province, and the count alone cannot tell them apart.
String _whereItIs(FloorView view) {
  // AN EMPTY SLICE AND AN EMPTY WORLD ARE DIFFERENT FACTS. The sentence that
  // kept them apart stood under the section marker ("Nothing needs a decision
  // in Western Seaboard over last 30 days") and went with the decision list on
  // 1 October 2026. It is this clause now: the scope chip on the plate names
  // the territory for every printed figure under it, and the spoken label for
  // the one figure that can be a zero names it too.
  if (view.decisions.isEmpty) {
    return view.isFiltered
        ? 'everything triaged in ${view.territoryName}'
        : 'everything triaged';
  }
  final outlets = <String>{
    for (final d in view.decisions)
      if (d.outletName.isNotEmpty) d.outletName,
  };
  if (outlets.length == 1) return 'all of it at ${outlets.first}';
  return 'across ${outlets.length} outlets';
}

/// Where availability stands, in the words the rest of the console uses.
///
/// The number in the sentence is [availabilityStandard] itself rather than a
/// typed `95`: the standard is published in one place and this line quotes it,
/// so a client whose standard moves does not get a briefing that still names
/// the old one.
String _availabilitySupport(
  FloorView view,
  StatusLevel? standing,
) => switch (standing) {
  StatusLevel.onTarget => 'on the ${availabilityStandard.round()} standard',
  StatusLevel.watch => 'close to the ${availabilityStandard.round()} standard',
  StatusLevel.critical => 'under the ${availabilityStandard.round()} standard',
  // CAPITALISED, AND ALONE AMONG THE FOUR. The other three are modifiers of a
  // figure printed beside them ("under the 95 standard"); this one stands in
  // for a figure that is not there, and it is the sentence the stat card
  // printed in this exact case. A lower-case fragment under an em dash reads
  // as a caption for a number, which is the one thing it must not be.
  _ => 'No visits in this window',
};

/// ONE SUGGESTED QUESTION.
@immutable
class FloorSuggestion {
  const FloorSuggestion({required this.id, required this.label});

  final String id;

  /// What the chip prints AND what pressing it sends. They are the same string
  /// on purpose: a chip that sends something other than what it says is the
  /// one behaviour that makes a manager stop trusting the row.
  final String label;
}

/// THE CHIPS, DERIVED FROM WHAT IS ON THE SCREEN.
///
/// Every one of them interpolates a live figure or a live name and every one
/// is gated on the condition that makes it true. There is deliberately **no
/// fallback list of generic questions**: a chip that is always there is
/// decoration, and this row is allowed to be empty.
///
/// The mockup's two are "Why is 73 down?" and "Show Ekurhuleni". Both are
/// here, and neither is a string — the first carries the live execution score
/// and appears only when the score actually fell, the second carries the name
/// of the place the work is actually in.
List<FloorSuggestion> floorSuggestions(FloorView view) {
  final out = <FloorSuggestion>[];
  final measured = view.phase == FloorPhase.measured;

  // "Why is 73 down?" — the hero figure, and only while it is genuinely down.
  // The threshold is the one the plate's own delta uses, so the chip and the
  // `▼ 19` beside it can never disagree about the direction.
  final change = view.snapshot.of((k) => k.executionScore).change;
  if (measured && change != null && change <= -0.05) {
    out.add(
      FloorSuggestion(
        id: 'why-down',
        label: 'Why is ${view.snapshot.current.executionScore.round()} down?',
      ),
    );
  }

  // "Show Ekurhuleni" — the place the backlog is actually in. The worst
  // outlet when the work is concentrated in one, otherwise the territory in
  // scope; and nothing at all when there is no work and nothing is scoped,
  // because "Show all territories" is the state the manager is already in.
  final where = _somewhereToLook(view);
  if (where != null) {
    out.add(FloorSuggestion(id: 'show-where', label: 'Show $where'));
  }

  // "What needs me first?" — only with a backlog to rank, and only when the
  // list is genuinely this territory's. It is the one question the ranked
  // list below cannot answer, because ranking by severity and age is not the
  // same as ranking by what a person should do next.
  if (view.decisions.length > 1 && view.scope != FloorScope.failed) {
    out.add(
      const FloorSuggestion(id: 'what-first', label: 'What needs me first?'),
    );
  }

  return out;
}

/// The place worth asking about, or null when the screen is already there.
String? _somewhereToLook(FloorView view) {
  final outlets = <String>{
    for (final d in view.decisions)
      if (d.outletName.isNotEmpty) d.outletName,
  };
  if (outlets.length == 1) return outlets.first;
  if (view.decisions.isNotEmpty) return view.decisions.first.outletName;
  // Nothing is wrong anywhere. A scoped screen can still usefully be asked
  // about its own territory; an unscoped one has nowhere in particular to
  // point at.
  return view.isFiltered ? view.territoryName : null;
}

/// WHAT THE COMPOSER SAYS IT WILL ASK ABOUT.
///
/// `Ask about Gauteng North…`, and `Ask about your territories…` when nothing
/// is scoped — never the literal `All territories`, which reads as a place.
String floorComposerHint(FloorView view) => view.isFiltered
    ? 'Ask about ${view.territoryName}…'
    : 'Ask about your territories…';
