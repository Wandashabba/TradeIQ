import 'package:flutter/material.dart' show SelectionArea;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/figure/eyebrow.dart';
import '../../../core/widgets/torchlight/state/toast.dart';
import '../../../l10n/l10n.dart';
import '../data/chat_controller.dart';
import '../view_specs/instrument_panel.dart';
import '../view_specs/rich_figures.dart';
import '../view_specs/view_spec_registry.dart';
import 'answer_markdown.dart';
import 'answer_runs.dart';
import 'answer_view.dart';
import 'web_sources.dart';
import 'working_steps.dart';

/// THE BRIEF — an answer set as a dated one-page document, not a chat bubble.
///
/// > *"Let's redesign the output of the Ask chat, it doesn't look appetising
/// > nor nice. it is very basic"* — the owner, 6 October 2026, then choosing
/// > **H** from G, H and I.
///
/// What H is, top to bottom, and where each piece comes from:
///
/// | H                              | here                                       |
/// |--------------------------------|--------------------------------------------|
/// | `ANSWER · ALL TERRITORIES`     | [BriefHeader] eyebrow, scope from the filter |
/// | `6 Oct 2026 · 10:47`           | the question's `askedAt`, mono              |
/// | the question, muted            | the user turn's text                        |
/// | `400` / outlets / across…      | [briefHeroFor] — a figure the turn already  |
/// |                                | carries (see below), or nothing              |
/// | the table                      | `AnswerPanel` — the figures the tools returned |
/// | `WHAT THIS MEANS` + paragraph  | the prose after the headline                |
/// | `✓ findTerritories · 0.4s`     | `StepsSummaryRow`, unchanged                |
/// | the follow-up pills, right     | `FollowUpChips`, aligned end                |
///
/// **Nothing here is invented.** A brief has slots; a turn fills the ones it
/// has data for and the rest are simply absent. In particular the hero figure
/// is never computed from the prose by this widget: it is either the one bare
/// `stat_tiles` tile the tools returned, or the figure the model itself set in
/// bold at the head of its one-sentence answer. A turn with neither leads with
/// its headline sentence, which is what every turn did before.
///
/// **Only on a desk.** The threshold is `askSplitMinWidth` in the chat screen;
/// below it the phone's transcript — bubble, prose, panel, steps — is exactly
/// what it was, and the phone tests pin that.
///
/// **Amber: none.** The brief is a document; its one lit object, when the
/// answer has one, is inside the panel and arbitrated there.
const double briefMaxWidth = 760;

/// The brief's masthead, standing where the question bubble stands on a phone.
///
/// Left-aligned — H retires the transcript's one right-alignment on a desk,
/// because a brief's question is its title line, not a message from across
/// the table. The eyebrow names the scope the question was asked in; the stamp
/// is when, in mono, because a date is a figure.
class BriefHeader extends StatelessWidget {
  const BriefHeader({
    super.key,
    required this.question,
    required this.scope,
    required this.askedAt,
  });

  final String question;

  /// "All territories", or the territory in scope. Null when the territory
  /// list has not loaded yet, in which case the eyebrow says only ANSWER.
  final String? scope;

  final DateTime? askedAt;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: question));
    if (!context.mounted) return;
    showTorchToast(context, message: context.l10n.askQuestionCopied);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final p = skin.palette;
    final eyebrow = scope == null
        ? l10n.askAnswer
        : l10n.askBriefEyebrow(scope!);

    return Semantics(
      container: true,
      label: '${l10n.askYourQuestion}. $question',
      onLongPress: () => _copy(context),
      child: GestureDetector(
        onLongPress: () => _copy(context),
        // Aligned, then capped: the desk column stretches its children, and a
        // cap on a child that is being stretched is not a cap.
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            key: const ValueKey<String>('brief-header'),
            constraints: const BoxConstraints(maxWidth: briefMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Expanded(
                      child: Eyebrow(
                        eyebrow,
                        key: const ValueKey<String>('brief-eyebrow'),
                        maxLines: 1,
                      ),
                    ),
                    if (askedAt != null) ...<Widget>[
                      const SizedBox(width: TiqSpace.s4),
                      Text(
                        formatBriefStamp(context, askedAt!),
                        key: const ValueKey<String>('brief-stamp'),
                        style: skin.text.monoIdent.style(color: p.ink3),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: skin.space.intraBlock),
                ExcludeSemantics(
                  child: Text.rich(
                    TextSpan(
                      children: answerSpans(
                        answerRuns(question, streaming: false),
                        skin: skin,
                        base: skin.text.body.style(color: p.ink3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The figure a brief leads with, and what it was lifted from.
@immutable
class BriefHero {
  const BriefHero({
    required this.figure,
    required this.label,
    this.subline,
    this.liftedArtifact,
  });

  /// The number, formatted — `400`, `R1 284 990,50`, `12%`.
  final String figure;

  /// What it counts: `outlets`, `Sell-in, units`.
  final String label;

  /// The rest of the sentence, markdown intact: `across 13 territories`.
  final String? subline;

  /// The `stat_tiles` artifact whose one tile became the hero, so the panel
  /// does not draw it a second time. Null for a hero taken from the prose.
  final ChatArtifact? liftedArtifact;
}

/// The one figure a turn already carries at its head, or null.
///
/// Two honest sources, tried in order:
///
/// 1. **One bare tile.** The turn's figures hold exactly one `stat_tiles`
///    artifact with exactly one tile, and that tile is a plain total — a
///    value with no delta, no meter, no comparison, no sample size and no
///    reconciliation. "400 outlets" is such a tile; "share of shelf 61%, up
///    2.1 pts on last month, n = 14" is not, and stays in the panel where the
///    tile component knows how to say all of that.
/// 2. **The model's own bold figure.** The answer opens with a headline (one
///    short paragraph — `ParsedAnswer.headline`) whose first bold run is a
///    figure followed by one to three words, after a lead-in of at most three
///    plain words: *"We have **400 outlets** across 13 territories."* The
///    model chose to set that figure apart; the brief sets it apart further.
///    The lead-in is dropped and the remainder becomes the subline.
///
/// Anything else — a headline without a bold figure, a bold figure deep in
/// the sentence, a negation before it — leads with the sentence as written.
BriefHero? briefHeroFor(
  ParsedAnswer parsed,
  AnswerFigures figures, {
  required AppLocalizations l10n,
  required TiqNumber number,
}) {
  if (!figures.suppressed) {
    final tiled = figures.internal
        .where((a) => a.type == 'stat_tiles')
        .toList();
    if (tiled.length == 1 && tiled.single.reconciled.isEmpty) {
      final tiles = StatTileData.listFrom(tiled.single.data);
      if (tiles.length == 1) {
        final tile = tiles.single;
        final value = tile.value;
        final bare =
            value != null &&
            tile.delta == null &&
            tile.meter == null &&
            tile.comparedTo == null &&
            tile.sampleSize == null &&
            tile.baselineSampleSize == null &&
            !tile.provenance.isOutside;
        if (bare) {
          return BriefHero(
            figure: formatAmount(
              value,
              tile.unit,
              number: number,
              decimals: tile.decimals,
              pointsWord: l10n.askPoints,
            ),
            label: tile.label,
            subline: _headlineSubline(parsed),
            liftedArtifact: tiled.single,
          );
        }
      }
    }
  }

  final headline = parsed.headline;
  if (headline == null) return null;
  final match = _boldFigureLead.firstMatch(headline.text);
  if (match == null) return null;
  final leadIn = match.group(1)!.trim();
  final label = match.group(3)!.trim();
  if (!_isPlainLeadIn(leadIn) || !_isLabel(label)) return null;
  final rest = _trimSentence(match.group(4)!);
  return BriefHero(
    figure: match.group(2)!,
    label: label,
    subline: rest.isEmpty ? null : rest,
  );
}

/// `We have **400 outlets** across 13 territories.` → lead-in, figure, label,
/// rest. The figure token is the prose figure rule's own.
final RegExp _boldFigureLead = RegExp(
  r'^([^*\n]*?)\*\*(' + figureTokenSource + r')[  ]+([^*\d\n]{1,40}?)\*\*(.*)$',
  dotAll: true,
);

/// At most three words of plain language before the figure — "We have",
/// "There are", "You have" — and nothing that could turn the sentence: no
/// digit, no dash, no colon, no question mark.
bool _isPlainLeadIn(String leadIn) {
  if (leadIn.isEmpty) return true;
  if (!RegExp(r"^[\p{L}' ]+$", unicode: true).hasMatch(leadIn)) return false;
  return leadIn.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length <= 3;
}

/// One to three words, none of them a figure.
bool _isLabel(String label) {
  final words = label.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  return words.isNotEmpty && words.length <= 3;
}

/// The headline without its closing full stop, for a subline that sits under
/// a figure rather than ending a sentence.
String _trimSentence(String text) {
  var out = text.trim();
  while (out.endsWith('.')) {
    out = out.substring(0, out.length - 1).trimRight();
  }
  return out;
}

/// The headline sentence as a tile hero's subline — the model's one sentence
/// said under the number it is about.
String? _headlineSubline(ParsedAnswer parsed) {
  final headline = parsed.headline;
  if (headline == null) return null;
  final text = _trimSentence(headline.text);
  return text.isEmpty ? null : text;
}

/// THE BRIEF'S BODY — everything under the masthead.
class AnswerBrief extends StatelessWidget {
  const AnswerBrief({
    super.key,
    required this.message,
    required this.parsed,
    required this.figures,
    required this.trailing,
    required this.followUpsEnabled,
    required this.foot,
  });

  final ChatMessage message;
  final ParsedAnswer parsed;
  final AnswerFigures figures;

  /// The incomplete notice and the outside-data band, after the prose.
  final List<Widget> trailing;

  final bool followUpsEnabled;

  /// What closes the turn — the stopped line, the copy / ask-again row —
  /// built by the caller, which knows the question they act on.
  final List<Widget> foot;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final p = skin.palette;

    final hero = briefHeroFor(
      parsed,
      figures,
      l10n: l10n,
      number: TiqNumber.of(context),
    );
    // The panel draws what the hero did not lift. Same figures object
    // otherwise, so the suppression rule and the outside routing are the
    // panel's own and unchanged.
    final panelFigures = hero?.liftedArtifact == null
        ? figures
        : AnswerFigures(
            internal: <ChatArtifact>[
              for (final a in figures.internal)
                if (!identical(a, hero!.liftedArtifact)) a,
            ],
            outside: figures.outside,
            suppressed: figures.suppressed,
          );
    final panel = AnswerPanel(figures: panelFigures);
    final hasPanel =
        panelFigures.internal.isNotEmpty || panelFigures.suppressed;

    final blocks = parsed.blocks;
    final headline = parsed.headline;
    // A hero from the prose has consumed the headline sentence; a hero from a
    // tile says it as its subline. Either way the sentence is not set again.
    final leadsWithHeadline = hero == null && headline != null;
    final rest = headline != null ? blocks.sublist(1) : blocks;
    // The eyebrow is a promise that something was already said above it.
    // With no hero and no headline the prose IS the answer, and it is set
    // plain.
    final hasLead = hero != null || leadsWithHeadline;

    Widget rule() => SizedBox(
      height: skin.depth.borderWidth,
      child: ColoredBox(color: p.hairline),
    );

    Widget prose(List<AnswerBlock> group, int offset) => ConstrainedBox(
      constraints: BoxConstraints(maxWidth: answerProseWidth(skin)),
      child: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var i = 0; i < group.length; i++) ...<Widget>[
              if (i > 0) SizedBox(height: skin.space.intraBlock),
              KeyedSubtree(
                key: ValueKey<String>(
                  'block-${offset + i}-${group[i].kind.name}',
                ),
                child: AnswerBlockView(
                  block: group[i],
                  streaming: false,
                  headline: false,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    final hasFooter = message.tools.isNotEmpty || parsed.followUps.isNotEmpty;
    final searched = message.tools.any(
      (t) => AnswerFigures.webTools.contains(t.name),
    );

    final lead = <Widget>[
      if (hero != null)
        _HeroLead(hero: hero)
      else if (leadsWithHeadline)
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: answerProseWidth(skin)),
          child: SelectionArea(
            child: AnswerBlockView(
              key: const ValueKey<String>('brief-headline'),
              block: headline,
              streaming: false,
              headline: true,
            ),
          ),
        ),
    ];

    // What stands between the lead and the footer. Named so the rules around
    // it can be counted: a brief with nothing here would otherwise draw the
    // lead's rule and the footer's rule a block gap apart with nothing between
    // them, which reads as a dropped section.
    final middle = <Widget>[
      if (hasPanel) panel,
      if (rest.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (hasLead) ...<Widget>[
              Eyebrow(
                l10n.askWhatThisMeans,
                key: const ValueKey<String>('brief-what-this-means'),
              ),
              SizedBox(height: skin.space.intraBlock),
            ],
            prose(rest, headline != null ? 1 : 0),
          ],
        ),
      ...trailing,
    ];

    final sections = <Widget>[
      ...lead,
      if (hasLead) rule(),
      ...middle,
      if (hasFooter) ...<Widget>[
        if (middle.isNotEmpty || !hasLead) rule(),
        _BriefFooter(
          tools: message.tools,
          followUps: parsed.followUps,
          followUpsEnabled: followUpsEnabled,
        ),
      ],
      // Only when it has something to say: an empty sources block still took
      // a block gap above and below, and the actions row floated.
      if (message.sources.isNotEmpty || searched)
        WebSources(sources: message.sources, searched: searched),
      ...foot,
    ];

    return Semantics(
      container: true,
      label: l10n.askAnswer,
      // Aligned, then capped — see [BriefHeader]. The two caps are the same
      // number so the masthead and the body share a right edge as well as a
      // left one.
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          key: const ValueKey<String>('ask-brief'),
          constraints: const BoxConstraints(maxWidth: briefMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (var i = 0; i < sections.length; i++) ...<Widget>[
                if (i > 0) SizedBox(height: skin.space.blockGap),
                sections[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// `400` at 72, `outlets` beside its foot, the rest of the sentence under
/// that. H's `align-items: flex-end` row.
class _HeroLead extends StatelessWidget {
  const _HeroLead({required this.hero});

  final BriefHero hero;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    return Semantics(
      container: true,
      label: <String>[
        hero.figure,
        hero.label,
        if (hero.subline != null) hero.subline!,
      ].join(', '),
      excludeSemantics: true,
      child: Padding(
        key: const ValueKey<String>('brief-hero'),
        padding: const EdgeInsets.only(
          top: TiqSpace.s1 + 2,
          bottom: TiqSpace.s4 + 2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            _HeroFigure(text: hero.figure),
            const SizedBox(width: TiqSpace.s5),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: TiqSpace.s1 + 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      hero.label,
                      key: const ValueKey<String>('brief-hero-label'),
                      style: skin.text.titleL.style(color: p.ink1),
                    ),
                    if (hero.subline != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: answerSpans(
                            answerRuns(hero.subline!, streaming: false),
                            skin: skin,
                            base: skin.text.body.style(color: p.ink3),
                          ),
                        ),
                        key: const ValueKey<String>('brief-hero-subline'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A formatted figure at hero size, with the figure ladder's glyph rule:
/// ≤3 glyphs `hero.figure` (72), 4–6 `hero.figure.compact` (56), 7+ `display`
/// (40) — the same thresholds `FigureSlot` documents, applied to a figure that
/// arrives already formatted. Affixes (`R`, `%`, `pts`) are language and take
/// the prose face at the same size, as they do in every other figure.
class _HeroFigure extends StatelessWidget {
  const _HeroFigure({required this.text});

  final String text;

  static final RegExp _affixes = RegExp(
    r'^(R[   ]?)?(.*?)([   ]?(?:%|pts|pt))?$',
  );

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final match = _affixes.firstMatch(text)!;
    final prefix = match.group(1) ?? '';
    final run = match.group(2) ?? text;
    final suffix = match.group(3) ?? '';
    final glyphs = run.replaceAll(RegExp(r'[^0-9]'), '').length;
    final token = glyphs <= 3
        ? skin.text.heroFigure
        : glyphs <= 6
        ? skin.text.heroFigureCompact
        : skin.text.display;
    final digits = token
        .style(color: p.ink1)
        .copyWith(
          fontFamily: TiqFonts.mono,
          fontFamilyFallback: TiqFonts.monoFallback,
          letterSpacing: 0,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        );
    final affix = digits.copyWith(
      fontFamily: TiqFonts.prose,
      fontFamilyFallback: TiqFonts.proseFallback,
      fontFeatures: const <FontFeature>[],
    );
    final cap = token.maxTextScale;
    final scaler = MediaQuery.textScalerOf(context);
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          if (prefix.isNotEmpty) TextSpan(text: prefix, style: affix),
          TextSpan(text: run, style: digits),
          if (suffix.isNotEmpty) TextSpan(text: suffix, style: affix),
        ],
      ),
      key: const ValueKey<String>('brief-hero-figure'),
      textScaler: cap == null ? scaler : scaler.clamp(maxScaleFactor: cap),
      maxLines: 1,
      softWrap: false,
    );
  }
}

/// What ran, on the left; what to ask next, on the right.
class _BriefFooter extends StatelessWidget {
  const _BriefFooter({
    required this.tools,
    required this.followUps,
    required this.followUpsEnabled,
  });

  final List<ToolActivity> tools;
  final List<String> followUps;
  final bool followUpsEnabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey<String>('brief-footer'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (tools.isNotEmpty)
          Expanded(flex: 2, child: StepsSummaryRow(tools: tools))
        else
          const Spacer(flex: 2),
        if (followUps.isNotEmpty) ...<Widget>[
          const SizedBox(width: TiqSpace.s4),
          // Expanded, not Flexible: the wrap must be handed its whole share
          // for `WrapAlignment.end` to have anything to align against.
          Expanded(
            flex: 3,
            child: Padding(
              // Level with the summary row's text, which sits in a tap-height
              // box.
              padding: const EdgeInsets.only(top: TiqSpace.s1),
              child: FollowUpChips(
                questions: followUps,
                enabled: followUpsEnabled,
                alignment: WrapAlignment.end,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
