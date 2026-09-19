import 'package:flutter/widgets.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';
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

/// THE EMPTY FIRST RUN — teaching a manager what this is good at, in one
/// screen, without a blank box.
///
/// **Left-aligned and top-anchored, never centred.** A centred block grows in
/// both directions, and at 2.0× with a four-line Afrikaans headline it pushes
/// its own content off the bottom at exactly the setting that needed it most.
///
/// Rows, not chips: a sentence-length chip wraps badly in Afrikaans and this
/// is a teaching state, so each suggestion gets a row with a second line
/// saying what it reads.
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

  /// False offline: the rows drop to ink-mute and say why, while the teaching
  /// text stays at full strength, because it is still true.
  final bool enabled;

  /// The gate is still resolving. The headline and the body are already true
  /// and are shown immediately; only the rows are skeletons.
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
        EmptyState(
          scope: EmptyScope.wholeScreen,
          // The closed enum of three. A shelf, because this is a surface
          // about what is on one — not a sparkle, not a robot, not a wand.
          drawing: EmptyDrawing.shelf,
          headline: l10n.askEmptyHeadline,
          body: l10n.askEmptyBody,
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
                  trailing: const SoftRowChevron(),
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
        SizedBox(height: skin.space.blockGap),
        Text(
          l10n.askReadOnlyFootnote,
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
      ],
    );
  }
}

/// The tenant is outside the rollout.
///
/// The same grammar, different words — an **empty state, never an error**.
/// It names who can act, because "contact your administrator" sends people to
/// the wrong place: a client admin cannot turn this on, by design.
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
