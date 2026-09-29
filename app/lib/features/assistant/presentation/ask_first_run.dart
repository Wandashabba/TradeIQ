import 'package:flutter/widgets.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/display_headline.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state/empty_drawing.dart';
import '../../../core/widgets/torchlight/state/empty_state.dart';
import '../../../l10n/l10n.dart';

/// One example question and what it will actually read.
@immutable
class AskSuggestion {
  const AskSuggestion(this.question, this.reads);

  final String question;

  /// The teaching. It is part of the row **and** part of the spoken label,
  /// because a manager who knows a question reads visit history and scorecards
  /// asks a better second question.
  final String reads;
}

/// The four, in the manager's own words.
List<AskSuggestion> askSuggestions(AppLocalizations l10n) => <AskSuggestion>[
  AskSuggestion(l10n.askExampleTeam, l10n.askExampleTeamReads),
  AskSuggestion(l10n.askExampleStock, l10n.askExampleStockReads),
  AskSuggestion(l10n.askExampleShelf, l10n.askExampleShelfReads),
  AskSuggestion(l10n.askExampleFraud, l10n.askExampleFraudReads),
];

/// THE OPENING — an invitation to ask a question, and **not an empty state**.
///
/// It used to be built from [EmptyState] with the shelf drawing on top of it,
/// and that was the wrong grammar twice over. Nothing is missing on this
/// screen: there is no list that came back empty, no filter that found
/// nothing, no route that has run out of content. There is a capability the
/// reader has not used yet. Dressing that in the "no data" vocabulary tells a
/// manager something failed to load, and the placeholder frame the drawing
/// shipped inside — a dashed box around a schematic — closed the argument: on
/// a phone it read as a broken image at the top of the reader's own territory.
///
/// So the headline leads, and there is no drawing at all. That is also the
/// only reading the design law supports: unify §1.12 grants a 64dp drawing to
/// a **whole-screen empty state** and to nothing else, so a mark here would be
/// artwork on a surface no rule covers. The precedent for a bespoke opening is
/// already in the building — the manager home's zero-data case is
/// `FirstRunBoard`, "a different screen", not an `EmptyState`.
///
/// **Left-aligned and top-anchored, never centred.** A centred block grows in
/// both directions, and at 2.0× with a four-line Afrikaans headline it pushes
/// its own content off the bottom at exactly the setting that needed it most.
///
/// ## The promise is made once
///
/// The screen used to carry the read-only promise **twice**: the body's "I
/// cannot change anything" and a closing footnote, "Read-only. Nothing you ask
/// here changes your data." Two sentences for one fact is the defect §19 names
/// on the Tasks page — a screen apologising in more than one place on every
/// load — and the footnote was the weaker of the two: `meta`/ink-3, at the
/// bottom, below the fold on a 390×844 phone, where the body's sentence is in
/// the first screenful at prose strength. The promise is real and a manager is
/// owed it, so it stays where it is read. The footnote goes.
///
/// ## Rows, and no chevron
///
/// Rows, not chips: a sentence-length chip wraps badly in Afrikaans and this
/// is a teaching state, so each suggestion gets a row with a second line
/// saying what it reads. (Unify §1.6's "follow-up chips are the filter chip
/// component" is about the chips under a landed answer, which are short.)
///
/// They lost their [SoftRowChevron]. A chevron is a disclosure mark: it
/// promises a page on the other side of the tap. These do not navigate — they
/// put a question in the composer and send it, which is why the spoken label
/// begins "Ask:". Four chevrons stacked down the fold were the single thing
/// making an invitation read as a settings list. The row is already a card —
/// radius 22, `surface`, a gap of ground to the next — and a card that presses
/// does not need an arrow to say it is pressable.
///
/// ## Amber
///
/// **Zero content amber, in every skin.** Send is disabled here — there is
/// nothing typed to send — so it carries no rim, and the whole screen is an
/// instruction rather than a commit. In Night the route's count is the nav's
/// active tab alone.
class AskFirstRun extends StatelessWidget {
  const AskFirstRun({
    super.key,
    required this.onAsk,
    this.enabled = true,
    this.loading = false,
  });

  final ValueChanged<String> onAsk;

  /// False offline. The rows drop to ink-mute and take no press; the reason is
  /// said **once**, by the route's `OfflineHeldBanner` above the composer,
  /// which is where a reader is looking when the thing they cannot do is type.
  /// It is deliberately not repeated on each of the four rows. The teaching
  /// text stays at full strength, because it is still true.
  final bool enabled;

  /// The gate is still resolving. The headline and the body are already true
  /// and are shown immediately; only the rows are held, because a question
  /// sent before the gate answers is a question that may be refused.
  ///
  /// (The old doc here said "only the rows are skeletons". They were never
  /// skeletons — this flag has only ever disabled them. The sentence is
  /// corrected rather than implemented: see below.)
  ///
  /// **No call site passes this today.** `AssistantGate` renders its own
  /// `_GateSkeleton` while `/clients/me` is in flight and `ChatScreen` only
  /// ever passes [enabled], so this branch is reachable from tests and from
  /// `ask_look_test.dart` and nowhere else. It is kept because it is the
  /// declared behaviour for the state and the gate may yet hand it over;
  /// removing it is an owner's call, not a tidy-up.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final suggestions = askSuggestions(l10n);

    return Column(
      key: const ValueKey<String>('ask-first-run'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          container: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TorchDisplayHeadline(l10n.askEmptyHeadline),
              const SizedBox(height: TiqSpace.s2),
              // Max 32em: a line of prose longer than that is a line the eye
              // loses its place in. The second sentence is the read-only
              // promise, and it is the only place the screen makes it.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: skin.text.body.size * 32,
                ),
                child: Text(
                  l10n.askEmptyBody,
                  style: skin.text.body.style(color: skin.palette.ink2),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: skin.space.blockGap),
        SectionRule(l10n.askTryOneOfThese),
        SizedBox(height: skin.space.intraBlock),
        Semantics(
          container: true,
          label: l10n.askSuggestionsGroup,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (var i = 0; i < suggestions.length; i++)
                SoftRow(
                  key: ValueKey<String>('ask-suggestion-$i'),
                  density: SoftRowDensity.tall,
                  title: suggestions[i].question,
                  subtitle: suggestions[i].reads,
                  enabled: enabled && !loading,
                  separator: i == suggestions.length - 1
                      ? SoftRowSeparator.none
                      : SoftRowSeparator.auto,
                  semanticsLabel: l10n.askSuggestionSemantic(
                    suggestions[i].question,
                    suggestions[i].reads,
                  ),
                  onTap: () => onAsk(suggestions[i].question),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The tenant is outside the rollout.
///
/// **This one is a real empty state** and keeps its drawing. The difference
/// from the opening above is the whole distinction: there, a capability is
/// waiting to be used; here, it is genuinely not there. It names who can act,
/// because "contact your administrator" sends people to the wrong place: a
/// client admin cannot turn this on, by design. An empty state, never an
/// error.
class AskNotEnabled extends StatelessWidget {
  const AskNotEnabled({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return EmptyState(
      key: const ValueKey<String>('ask-not-enabled'),
      scope: EmptyScope.wholeScreen,
      drawing: EmptyDrawing.envelope,
      headline: l10n.askNotEnabledHeadline,
      body: l10n.askNotEnabledBody,
    );
  }
}
