import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/rating_band.dart';
import '../../../core/theme/torchlight/agent_skin.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../data/scorecards_repository.dart';
import '../data/seen_score.dart';
import 'audit_shell_screen.dart' show VisitFrame;

/// HOW THE VISIT WENT.
///
/// The score is the point of the visit, so it is where the visit *ends* — not
/// a form section the agent goes and opens after the fact. It is the first
/// thing they see when they walk out of the shop.
///
/// ```text
///   Visit submitted                             Kasi Corner Spaza
///   PERFECT-STORE SCORE
///   71 /100   ◺ Watch
///   ▲ +6  from your last visit here (65).
///   ── How it was scored ───────────────────────
///   Availability                              83
///   ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬╎▬▬
///   Share of shelf                             —
///   ▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨
///   No competitor on shelf — not counted against you.
///   [ ☾ ] [            Next store              ]
/// ```
///
/// ## It shows the server's score, or none at all
///
/// The app **can** compute a scorecard offline (ADR 0005), and it never shows
/// it. That one is a proxy: it scores pricing as "did you capture anything"
/// and uses the default weights rather than this client's, so it would show a
/// number that quietly changes once the visit reaches the server. An agent
/// whose score moves overnight has no reason to believe the next one. The
/// refusal is *stated in a sentence* rather than left as an absence.
///
/// ## Unknown is never zero (#93)
///
/// A dimension the server could not measure is **absent** from the payload,
/// not zero, and it renders as an em dash over a full-width falling hatch with
/// the reason in words. A zero would read as "you scored nothing on this" for
/// something the agent was never given a chance to do.
///
/// ## The reconciliation line (#377/#390/#398)
///
/// A score the agent already read that is later changed on review is the event
/// that ends trust in every subsequent score. When this phone has shown a
/// number for this visit and the server now says a different one, the line
/// says so — "Now scored 71 — it was 84 when you saw it" — instead of letting
/// them find out.
///
/// ## Amber
///
/// An untabbed route with no nav, so the content has two grants in Night and
/// this screen spends exactly one of them in every phase: `Next store`. The
/// score figure is ink-1 even when the band is Gap — a severity-coded figure
/// is a hue doing a number's job — and the meter's target tick is ink-1
/// everywhere (unify §1.1 deleted `TorchClaim.meterTick`: a target is an
/// annotation, and six amber ticks is a repeated fill wearing a different hat).
class VisitOutcomeScreen extends ConsumerWidget {
  const VisitOutcomeScreen({
    super.key,
    required this.visitDraftId,
    required this.outletId,
    required this.outletName,
  });

  final String visitDraftId;
  final String outletId;
  final String outletName;

  /// The primary's claim id. One id across all three phases: only one is ever
  /// on screen, and a census failure names the phase.
  static const String nextStoreClaimId = 'outcome-next-store';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcomeAsync = ref.watch(
      visitOutcomeProvider((visitDraftId: visitDraftId, outletId: outletId)),
    );
    final l10n = context.l10n;

    Widget frame({required String phase, required List<Widget> children}) =>
        VisitFrame(
          phase: phase,
          title: l10n.outcomeTitle,
          facts: <String>[outletName],
          showSyncChip: true,
          claimSubmit: true,
          claimId: VisitOutcomeScreen.nextStoreClaimId,
          submit: TorchPrimaryButton(
            key: const ValueKey<String>('next-store'),
            claimId: VisitOutcomeScreen.nextStoreClaimId,
            label: l10n.outcomeNextStore,
            semanticLabel: l10n.outcomeNextStoreSemantics,
            // Both ways off this screen go forward. There is no way back into
            // a submitted visit.
            onPressed: () => context.go('/today'),
          ),
          secondary: TorchSecondaryButton(
            key: const ValueKey<String>('outcome-my-work'),
            label: l10n.outcomeOpenMyWork,
            onPressed: () => context.go('/my-work'),
          ),
          children: children,
        );

    return TorchlightRoute(
      child: outcomeAsync.when(
        loading: () => frame(
          phase: 'scoring',
          children: const <Widget>[_ScoringSkeleton()],
        ),
        // Failing to *read* the score is not failing to submit. The captures
        // are in the outbox either way, and saying so is the only thing that
        // matters to someone walking out of a shop.
        error: (_, _) => frame(
          phase: 'held-unreachable',
          children: const <Widget>[_HeldOnPhone(unreachable: true)],
        ),
        data: (outcome) {
          if (outcome.isHeldOnPhone) {
            return frame(
              phase: 'held',
              children: const <Widget>[_HeldOnPhone(unreachable: false)],
            );
          }
          return frame(
            phase: 'scored',
            children: <Widget>[
              _Scored(outcome: outcome, visitDraftId: visitDraftId),
            ],
          );
        },
      ),
    );
  }
}

/// THE SCORE, and how it was worked out.
class _Scored extends ConsumerStatefulWidget {
  const _Scored({required this.outcome, required this.visitDraftId});

  final VisitOutcome outcome;
  final String visitDraftId;

  @override
  ConsumerState<_Scored> createState() => _ScoredState();
}

class _ScoredState extends ConsumerState<_Scored> {
  /// Whether the "this is what the agent saw" record has been scheduled.
  /// Once per mount, not once per build: the notifier's own load rebuilds this
  /// widget, and a post-frame callback registered on every build is a callback
  /// per frame for a write that is already idempotent.
  bool _recorded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final score = widget.outcome.score!;
    final band = RatingBand.ofWire(score.ratingBand);
    final total = score.weightedTotal.round();

    // No latch and no local copy. `record` never overwrites an entry, so once
    // the store has answered this map either holds the number the agent saw
    // last time — and the line renders for as long as the visit exists — or it
    // holds this one, and there is nothing to reconcile. A latch taken on the
    // first frame would read the empty map the notifier starts with and the
    // line would never appear at all.
    final seenBefore = ref.watch(seenScoresProvider)[widget.visitDraftId];
    // Record what is on the screen now, so a change made on review later has
    // something to reconcile against. Deferred to after the frame: a provider
    // written during build is a rebuild loop.
    if (!_recorded) {
      _recorded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(seenScoresProvider.notifier)
            .record(widget.visitDraftId, total);
      });
    }

    final changed = seenBefore != null && seenBefore != total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Eyebrow(l10n.outcomePerfectStoreScore),
        const SizedBox(height: TiqSpace.s2),
        // A Wrap, so at 2.0× the band drops to its own line rather than the
        // hero clipping. Nothing here is pinned.
        Semantics(
          container: true,
          label: l10n.outcomeHeroSemantics(total, band.word(l10n)),
          excludeSemantics: true,
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: TiqSpace.s3,
            runSpacing: TiqSpace.s2,
            children: <Widget>[
              FigureSlot(
                key: const ValueKey<String>('score-hero'),
                value: total,
                role: skin.text.heroFigure,
                fit: <TiqTypeToken>[
                  skin.text.heroFigure,
                  skin.text.heroFigureCompact,
                  skin.text.display,
                ],
                // ink-1, never the band's hue: a severity-coded figure at 72px
                // is a colour doing a number's job. The band is the mark and
                // the word, both of which survive greyscale.
                color: skin.palette.ink1,
              ),
              // The unit is a sibling of the figure inside the Wrap and not a
              // child of a min-size Row beside it: at 2.0× a 115px figure plus
              // a 48px unit is wider than a 320dp gutter box, and the Row's
              // answer to that is to overflow rather than to wrap. The unit,
              // the band and the delta each take their own line instead.
              Padding(
                padding: const EdgeInsets.only(bottom: TiqSpace.s2),
                child: Text(
                  '/100',
                  style: skin.text.figureM.style(color: skin.palette.ink3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: TiqSpace.s2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SeverityMark(kind: _markFor(band)),
                    const SizedBox(width: TiqSpace.s2),
                    Flexible(
                      child: Text(
                        band.word(l10n),
                        key: const ValueKey<String>('score-band'),
                        style: skin.text.label.style(
                          color: _bandInk(skin, band),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (changed) ...<Widget>[
          const SizedBox(height: TiqSpace.s3),
          ReconciliationLine(
            key: const ValueKey<String>('outcome-reconciled'),
            finalValue: total,
            seenValue: seenBefore,
            voice: ReconciliationVoice.agent,
            reason: l10n.outcomeReconciledReason,
            strings: ReconciliationStrings(
              agentLead: l10n.outcomeReconciledLead,
              agentTail: l10n.outcomeReconciledTail,
            ),
            semanticsLabel: l10n.outcomeReconciledSemantics(
              total,
              seenBefore,
            ),
          ),
        ],
        const SizedBox(height: TiqSpace.s3),
        _DeltaLine(outcome: widget.outcome, shown: total),
        const SizedBox(height: TiqSpace.s7),
        SectionRule(l10n.outcomeHowScored),
        const SizedBox(height: TiqSpace.s5),
        for (final (i, entry) in kDimensionLabels.entries.indexed)
          _DimensionRow(
            label: _dimensionLabel(l10n, entry.key, entry.value),
            // Absent means the server could not measure it. It shows as an em
            // dash over a hatch, never as a zero (#93).
            score: score.scoreOf(entry.key),
            unmeasurableReason: _unmeasurableReason(l10n, entry.key),
            last: i == kDimensionLabels.length - 1,
          ),
      ],
    );
  }
}

/// The band's mark. Healthy is a filled circle, Watch a half-filled triangle,
/// Gap a filled one — severity at two commitment levels plus a silhouette plus
/// the word, and never amber.
SeverityMarkKind _markFor(RatingBand band) => switch (band) {
  RatingBand.healthy => SeverityMarkKind.onTarget,
  RatingBand.watch => SeverityMarkKind.watch,
  RatingBand.gap => SeverityMarkKind.critical,
};

/// The band word's ink. `good` or `bad` — Watch and Gap share a hue on purpose
/// and are told apart by the mark and the word.
Color _bandInk(TiqSkin skin, RatingBand band) => switch (band) {
  RatingBand.healthy => skin.palette.good,
  RatingBand.watch || RatingBand.gap => skin.palette.bad,
};

/// UP OR DOWN since this agent's last visit to this store — the only
/// comparison that is theirs to own.
class _DeltaLine extends StatelessWidget {
  const _DeltaLine({required this.outcome, required this.shown});

  final VisitOutcome outcome;

  /// The hero figure exactly as it is printed above this line. The delta is
  /// worked out from it, never from the raw totals.
  final int shown;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final previous = outcome.previous;

    // No previous visit: a sentence, never a delta beside nothing.
    if (outcome.delta == null || previous == null) {
      return Text(
        l10n.outcomeFirstScored,
        key: const ValueKey<String>('outcome-first-visit'),
        style: skin.text.meta.style(color: skin.palette.ink3),
      );
    }

    // The three numbers on this line and the hero above it must add up on the
    // screen. Rounding the raw difference does not: 71.4 against 64.6 is a
    // hero of 71, a baseline of 65 and a raw 6.8 that rounds to +7, and 71.4
    // against 71.6 is "71" beside "same as last time (72)". So the delta is
    // the difference of the two figures as printed, and the flat case is those
    // two figures being equal.
    final was = previous.weightedTotal.round();
    final rounded = shown - was;
    final flat = rounded == 0;

    return Delta(
      key: const ValueKey<String>('outcome-delta'),
      data: DeltaData(
        direction: flat
            ? DeltaDirection.flat
            : rounded > 0
            ? DeltaDirection.up
            : DeltaDirection.down,
        // A perfect-store score going up is good. This is the one metric in
        // the product where the direction and the verdict genuinely agree, and
        // it is stated rather than derived in the component.
        sentiment: flat
            ? TiqSentiment.neutral
            : rounded > 0
            ? TiqSentiment.good
            : TiqSentiment.bad,
        magnitude: rounded,
        comparedTo: flat ? null : l10n.outcomeDeltaFromLast(was),
      ),
      strings: DeltaStrings(noChange: l10n.outcomeDeltaSame(was)),
      semanticsLabel: flat
          ? l10n.outcomeDeltaSame(was)
          : '${rounded > 0 ? l10n.outcomeDeltaUp(rounded.abs()) : l10n.outcomeDeltaDown(rounded.abs())} '
                '${l10n.outcomeDeltaFromLast(was)}',
    );
  }
}

/// ONE DIMENSION: its name, its figure, and the bar that explains it.
class _DimensionRow extends StatelessWidget {
  const _DimensionRow({
    required this.label,
    required this.score,
    required this.unmeasurableReason,
    required this.last,
  });

  final String label;
  final double? score;
  final String? unmeasurableReason;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final value = score;
    final measured = value != null;
    final reason = unmeasurableReason ?? l10n.outcomeNotMeasuredGeneric;

    return Semantics(
      container: true,
      label: measured
          ? l10n.outcomeDimensionSemantics(label, value.round())
          : l10n.outcomeDimensionUnmeasuredSemantics(label, reason),
      excludeSemantics: true,
      child: Container(
        key: ValueKey<String>('dimension-$label'),
        padding: const EdgeInsets.symmetric(vertical: TiqSpace.s3),
        decoration: BoxDecoration(
          // A non-tappable row takes the decorative hairline; the 3:1
          // edge-structure rule is for rows a thumb can open.
          border: last
              ? null
              : Border(
                  bottom: BorderSide(
                    color: skin.palette.hairline,
                    width: skin.depth.borderWidth,
                  ),
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    label,
                    style: skin.text.titleM.style(color: skin.palette.ink1),
                  ),
                ),
                const SizedBox(width: TiqSpace.s3),
                if (measured)
                  FigureSlot(
                    value: value.round(),
                    role: skin.text.figureS,
                    color: skin.palette.ink1,
                    textAlign: TextAlign.end,
                  ),
              ],
            ),
            const SizedBox(height: TiqSpace.s2),
            if (measured)
              Meter(
                value: value,
                // The published perfect-store standard, not an invented scale.
                target: 80,
                semanticsValue: l10n.outcomeDimensionSemantics(
                  label,
                  value.round(),
                ),
              )
            else
              // The em dash, the full-width falling hatch and the reason — all
              // three, because a hatch without a sentence is a puzzle and a
              // partial hatch reads as a hatched value.
              NotMeasured(
                key: ValueKey<String>('unmeasured-$label'),
                reason: reason,
                role: skin.text.figureS,
                semanticsLabel: l10n.outcomeDimensionUnmeasuredSemantics(
                  label,
                  reason,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// SUBMITTED, AND STILL ON THE PHONE. The ordinary case in a shop with no
/// signal, so it is a receipt and not an error.
class _HeldOnPhone extends StatelessWidget {
  const _HeldOnPhone({required this.unreachable});

  /// True when the server could not be read; false when there is no signal.
  final bool unreachable;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;

    return Semantics(
      container: true,
      label: l10n.outcomeHeldSemantics,
      excludeSemantics: true,
      child: Column(
        key: const ValueKey<String>('outcome-held'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Oatmeal plus a square plus a word. Held is never crimson and
              // never Truffle: working offline is the normal state of South
              // African field work.
              const RowMarkTile(mark: RowMark.square),
              const SizedBox(width: TiqSpace.s3),
              Expanded(
                child: Text(
                  l10n.outcomeHeldTitle,
                  style: skin.text.titleL.style(color: skin.palette.ink1),
                ),
              ),
            ],
          ),
          const SizedBox(height: TiqSpace.s3),
          Text(
            unreachable
                ? l10n.outcomeHeldBodyUnreachable
                : l10n.outcomeHeldBodyNoSignal,
            style: skin.text.body.style(color: skin.palette.ink2),
          ),
          const SizedBox(height: TiqSpace.s6),
          OfflineHeldBanner(
            key: const ValueKey<String>('outcome-held-banner'),
            state: SyncState.held,
            label: l10n.outcomeScoredWhenSends,
            subtitle: l10n.outcomeScoredOnServer,
          ),
          const SizedBox(height: TiqSpace.s4),
          // Not showing a number here is deliberate, and worth one sentence:
          // an agent shown 74 in the shop who finds 68 in the morning will not
          // trust the third one. The refusal is stated, not left as a gap.
          Text(
            l10n.outcomeNoGuess,
            key: const ValueKey<String>('outcome-no-guess'),
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
        ],
      ),
    );
  }
}

/// The scored screen's real geometry, empty. Not a spinner.
class _ScoringSkeleton extends StatelessWidget {
  const _ScoringSkeleton();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Skeleton(
      label: context.l10n.outcomeSending,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SkeletonLine(role: skin.text.eyebrow, widthFactor: 0.4),
          const SizedBox(height: TiqSpace.s2),
          SkeletonLine(role: skin.text.heroFigure, widthFactor: 0.5),
          const SizedBox(height: TiqSpace.s7),
          const SkeletonRows(count: 6, rowHeight: 64),
        ],
      ),
    );
  }
}

/// A dimension's name in the active language. The keys are the API's
/// ([kDimensionLabels]); an unknown key keeps the repository's English label.
String _dimensionLabel(AppLocalizations l10n, String key, String fallback) =>
    switch (key) {
      'availability' => l10n.outcomeDimensionAvailability,
      'visibility' => l10n.outcomeDimensionVisibility,
      'display' => l10n.outcomeDimensionDisplay,
      'pricing' => l10n.outcomeDimensionPricing,
      'competitive' => l10n.outcomeDimensionCompetitive,
      'salesCapability' => l10n.outcomeDimensionSalesCapability,
      _ => fallback,
    };

/// Why a dimension could not be scored ([kUnmeasurableReasons]), localised.
String? _unmeasurableReason(AppLocalizations l10n, String key) =>
    switch (key) {
      'competitive' => l10n.outcomeUnmeasurableCompetitive,
      'salesCapability' => l10n.outcomeUnmeasurableSalesCapability,
      _ => kUnmeasurableReasons[key],
    };
