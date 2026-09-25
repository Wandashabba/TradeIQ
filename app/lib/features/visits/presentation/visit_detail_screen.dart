import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/design/torch_scope.dart';
import '../../../core/rating_band.dart';
import '../../../core/theme/torchlight/console_skin.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/evidence_thumb.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../../fraud/data/fraud_view.dart';
import '../../templates/domain/template_schema.dart';
import '../data/visit_detail_repository.dart';

/// ONE VISIT, AS A MANAGER REVIEWS IT (#208).
///
/// Who went where and when, the score and what it is made of, what each
/// capture section found, the photographs, and the fraud signals.
///
/// ```text
///   ←  Spar Rosebank
///      Visit review · SPR-001 · thandi@acme.test
///      [ Out of fence 61 m ]
///   ── The visit ───────────────────────────────
///   Checked in                14 Sep 2026, 09:00
///   Submitted                 14 Sep 2026, 09:14
///   ── Perfect store score ─────────────────────
///   55 /100   ◣ Gap
///   ▬▬▬▬▬▬▬▬▬▬▬▬▬╎▬▬▬▬▬▬▬▬▬▬▬▬▬▬
///   Availability                             90
///   Share of shelf                            —
///   ▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨▨
///   ── What was captured 5 ─────────────────────
///   ── Photos 1 ───────────────────────────────
///   ── Fraud signals ──────────────────────────
///   [ ☾ ]
/// ```
///
/// Reached by `push` from any manager surface that lists a visit — alerts, the
/// fraud review, the agent trail — so the back control returns to that list. A
/// deep link has nothing to pop to, and gets a way back to the console
/// instead; that escape is a capability, not a nicety, and it has a test.
///
/// ## The amber, counted
///
/// A pushed route with no nav, so Night's budget is two and **this screen
/// spends none of it**. Nothing here is armed: a review screen records no
/// decision (the verdict control belongs to the fraud case), so there is no
/// primary to light. Every severity on it is crimson at two commitment levels
/// with its word beside it, the band is a mark plus a word, and the score's
/// hero is ink-1 at every band — a severity-coded figure at 72px is a hue
/// doing a number's job, and it is the one object large enough that its colour
/// would read as the whole message. Day and Veld: zero, on every phase.
///
/// ## Unknown is never zero
///
/// A dimension the server could not measure is **absent** from the payload,
/// not nought, and it renders as an em dash over a full-width falling hatch
/// with the reason in words. A visit with no scorecard says which of the two
/// reasons applies rather than printing 0. A missing geofence distance is
/// words, never `0,0 m`. A band this build does not recognise is not guessed
/// at: it shows as unbanded, with no severity and no mark.
///
/// ## Veld
///
/// Veld renders no thumbnails (unify §4), so the photo strip becomes the
/// figure list it always was for a screen reader: one row per photograph,
/// naming its section and the time it was taken.
class VisitDetailScreen extends ConsumerWidget {
  const VisitDetailScreen({super.key, required this.visitId});

  final String visitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final detail = ref.watch(visitDetailProvider(visitId));
    final error = detail.error;

    if (error is VisitNotFoundException && !detail.isLoading) {
      return _VisitFrame(
        phase: 'not-found',
        title: l10n.visitReviewTitle,
        children: <Widget>[_NotFound(visitId: visitId)],
      );
    }

    return detail.when(
      loading: () => _VisitFrame(
        phase: 'loading',
        title: l10n.visitReviewTitle,
        children: <Widget>[
          Skeleton(
            label: l10n.visitReviewTitle,
            slowLine: l10n.torchStillFetching,
            child: const SkeletonRows(count: 5, rowHeight: 64),
          ),
        ],
      ),
      error: (error, _) => _VisitFrame(
        phase: 'error',
        title: l10n.visitReviewTitle,
        children: <Widget>[
          TorchErrorRegion(
            name: 'visit',
            child: ErrorState(
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('visit-detail-retry'),
                label: l10n.torchTryAgain,
                onPressed: () => ref.invalidate(visitDetailProvider(visitId)),
              ),
            ),
          ),
        ],
      ),
      data: (d) => _VisitFrame(
        phase: d.isDraft ? 'draft' : 'submitted',
        title: d.outlet.name,
        facts: <String>[
          l10n.visitReviewTitle,
          d.outlet.code,
          d.agent.email,
        ],
        flagChips: _flagChips(context, d),
        children: _body(context, d),
      ),
    );
  }

  /// The visit's standing, as chips in the header.
  ///
  /// Out of fence is a **measurement, not a verdict** (unify §1.6), so it wears
  /// the neutral flag treatment with the distance hung off it rather than a
  /// severity bar. Unfinished says the visit was never submitted, which is the
  /// reason half this screen is empty.
  static List<Widget> _flagChips(BuildContext context, VisitDetail d) {
    final l10n = context.l10n;
    final numbers = TiqNumber.of(context);
    return <Widget>[
      if (d.isDraft)
        FlagChip(
          key: const ValueKey<String>('visit-flag-unfinished'),
          kind: FlagKind.unfinished,
          label: l10n.visitInProgress,
        ),
      if (!d.geofencePass)
        FlagChip(
          key: const ValueKey<String>('visit-flag-out-of-fence'),
          kind: FlagKind.outOfFence,
          label: l10n.visitOutsideFence,
          detail: d.distanceM == null
              ? null
              : numbers.format(d.distanceM!, unit: TiqUnit.worded('m'), decimals: 1),
        ),
      if (d.pinDispute != null)
        FlagChip(
          key: const ValueKey<String>('visit-flag-pin'),
          kind: FlagKind.forReview,
          label: l10n.visitPinReported,
        ),
    ];
  }

  static List<Widget> _body(BuildContext context, VisitDetail d) {
    final gap = context.skin.space.blockGap;
    return <Widget>[
      _Facts(detail: d),
      SizedBox(height: gap),
      _Score(detail: d),
      for (final answers in d.templateResponses) ...<Widget>[
        SizedBox(height: gap),
        _TemplateAnswers(answers: answers),
      ],
      SizedBox(height: gap),
      _Sections(sections: d.sections),
      SizedBox(height: gap),
      _Photos(detail: d),
      if (d.signals.isNotEmpty) ...<Widget>[
        SizedBox(height: gap),
        _Fraud(detail: d),
      ],
    ];
  }
}

/// The frame every state of this route wears, so a skeleton, an error and the
/// real thing are the same screen in three conditions rather than three
/// screens.
class _VisitFrame extends StatelessWidget {
  const _VisitFrame({
    required this.phase,
    required this.title,
    required this.children,
    this.facts = const <String>[],
    this.flagChips = const <Widget>[],
  });

  final String phase;
  final String title;
  final List<String> facts;
  final List<Widget> flagChips;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canPop = Navigator.of(context).canPop();

    return TorchScope(
      skin: context.skin,
      phase: phase,
      navRenders: false,
      tabbedRoute: false,
      // Nothing on a review screen is armed. The claim list is empty by
      // construction rather than by argument.
      claims: const <TorchClaim>[],
      child: TorchShell(
        profile: TorchShellProfile.console,
        header: TorchAppHeader(
          title: title,
          facts: facts,
          flagChips: flagChips,
          // Named for where it goes, never "Back": a deep link has nothing to
          // pop to, and the console is the way out. Losing that escape is how
          // a reviewer ends up on a screen with no exit.
          back: TorchIconButton(
            key: const ValueKey<String>('visit-detail-back'),
            icon: Icons.arrow_back,
            semanticLabel: canPop ? l10n.visitBackToList : l10n.visitBackToFloor,
            onPressed: () =>
                canPop ? context.pop() : context.go('/dashboard'),
          ),
        ),
        skinCycle: const ConsoleSkinCycle(),
        children: children,
      ),
    );
  }
}

/// A visit id that resolves to nothing. A settled answer, with a way on.
class _NotFound extends StatelessWidget {
  const _NotFound({required this.visitId});

  final String visitId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    return Column(
      key: const ValueKey<String>('visit-not-found'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        EmptyState(
          headline: l10n.visitNotFoundHeadline,
          body: l10n.visitNotFoundBody,
          drawing: EmptyDrawing.envelope,
          action: TorchSecondaryButton(
            key: const ValueKey<String>('visit-not-found-alerts'),
            label: l10n.visitBackToAlerts,
            onPressed: () => context.go('/alerts'),
          ),
        ),
        const SizedBox(height: TiqSpace.s4),
        // The id in the identifier face, so a manager can read it back to
        // support. It is a reference, never a name (unify §1.15).
        Text(
          visitId,
          textAlign: TextAlign.center,
          style: skin.text.monoIdent.style(color: skin.palette.ink3),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// The visit — who, where, when
// ═══════════════════════════════════════════════════════════════════════

class _Facts extends StatelessWidget {
  const _Facts({required this.detail});

  final VisitDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final numbers = TiqNumber.of(context);
    final gutter = skin.space.gutter;
    final dwell = detail.dwellMinutes;
    final dispute = detail.pinDispute;

    final rows = <Widget>[
      _FactRow(
        rowKey: const ValueKey<String>('visit-checked-in'),
        label: l10n.visitCheckedIn,
        value: formatVisitTime(detail.checkinTs),
        note: l10n.visitDeviceClock,
      ),
      _FactRow(
        rowKey: const ValueKey<String>('visit-submitted'),
        label: l10n.visitSubmitted,
        value: detail.submittedAtClient == null
            ? l10n.visitNotYet
            : formatVisitTime(detail.submittedAtClient!),
        note: dwell == null ? null : l10n.visitMinutesOnSite(dwell),
      ),
      _FactRow(
        rowKey: const ValueKey<String>('visit-geofence'),
        label: l10n.visitGeofence,
        // A missing distance is words. `0,0 m` would be a measurement nobody
        // took, and it reads as a perfect check-in.
        value: detail.distanceM == null
            ? emDash
            : numbers.format(
                detail.distanceM!,
                unit: TiqUnit.worded('m'),
                decimals: 1,
              ),
        note: detail.distanceM == null
            ? l10n.visitNoDistance
            : (detail.geofencePass
                  ? l10n.visitInsideFence
                  : l10n.visitOutsideFence),
        missing: detail.distanceM == null,
      ),
      // Outside the fence BECAUSE the agent said the pin is wrong (#386).
      // Without this a reviewer cannot tell a depot-pinned outlet from a
      // faked visit, and that is the whole difference.
      if (dispute != null)
        _FactRow(
          rowKey: const ValueKey<String>('visit-pin-dispute'),
          label: l10n.visitPin,
          value: l10n.visitPinReported,
          note: <String>[
            switch (dispute.status) {
              'applied' => dispute.resolvedByLabel == null
                  ? l10n.visitPinMoved
                  : l10n.visitPinMovedBy(dispute.resolvedByLabel!),
              'rejected' => dispute.resolvedByLabel == null
                  ? l10n.visitPinKept
                  : l10n.visitPinKeptBy(dispute.resolvedByLabel!),
              _ => l10n.visitPinWaiting,
            },
            if (dispute.note case final note?) '“$note”',
          ].join(' · '),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionRule(l10n.visitTheVisit),
        const SizedBox(height: TiqSpace.s4),
        TorchBleed(
          extra: gutter * 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (var i = 0; i < rows.length; i++)
                _last(rows[i], i == rows.length - 1),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _last(Widget row, bool last) =>
      row is _FactRow ? row.copyAsLast(last) : row;
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.rowKey,
    required this.label,
    required this.value,
    this.note,
    this.missing = false,
    this.last = false,
  });

  final Key rowKey;
  final String label;
  final String value;
  final String? note;
  final bool missing;
  final bool last;

  _FactRow copyAsLast(bool isLast) => _FactRow(
    rowKey: rowKey,
    label: label,
    value: value,
    note: note,
    missing: missing,
    last: isLast,
  );

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return SoftRow(
      key: rowKey,
      density: SoftRowDensity.standard,
      title: label,
      subtitle: note,
      trailing: Text(
        value,
        textAlign: TextAlign.end,
        style: skin.text.figureS.style(
          color: missing ? skin.palette.ink3 : skin.palette.ink1,
        ),
      ),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: <String>[label, value, ?note].join('. '),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// The score
// ═══════════════════════════════════════════════════════════════════════

/// The band's mark. Healthy is a filled circle, Watch a half-filled triangle,
/// Gap a filled one — severity at two commitment levels plus a silhouette plus
/// the word, all three of which survive greyscale.
SeverityMarkKind markForBand(RatingBand band) => switch (band) {
  RatingBand.healthy => SeverityMarkKind.onTarget,
  RatingBand.watch => SeverityMarkKind.watch,
  RatingBand.gap => SeverityMarkKind.critical,
};

Color bandInk(TiqSkin skin, RatingBand band) => switch (band) {
  RatingBand.healthy => skin.palette.good,
  RatingBand.watch || RatingBand.gap => skin.palette.bad,
};

/// The dimension's name in the reader's language. The wire's six keys, and an
/// unknown key keeps the server's own string rather than being dropped.
String dimensionLabel(AppLocalizations l10n, String key) => switch (key) {
  'availability' => l10n.outcomeDimensionAvailability,
  'visibility' => l10n.outcomeDimensionVisibility,
  'display' => l10n.outcomeDimensionDisplay,
  'pricing' => l10n.outcomeDimensionPricing,
  'competitive' => l10n.outcomeDimensionCompetitive,
  'salesCapability' => l10n.outcomeDimensionSalesCapability,
  _ => key,
};

class _Score extends StatelessWidget {
  const _Score({required this.detail});

  final VisitDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final score = detail.score;

    if (score == null) {
      return Column(
        key: const ValueKey<String>('visit-score'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SectionRule(l10n.visitScoreHeading),
          const SizedBox(height: TiqSpace.s4),
          EmptyState(
            scope: EmptyScope.inPanel,
            headline: l10n.visitNotScored,
            // Two different facts, and the reviewer needs to know which.
            body: detail.isDraft
                ? l10n.visitScoredOnSubmit
                : l10n.visitNoScorecard,
          ),
        ],
      );
    }

    final band = RatingBand.fromWire(score.ratingBand);
    final word = band == null ? l10n.visitUnbanded : band.word(l10n);
    final gutter = skin.space.gutter;

    return Column(
      key: const ValueKey<String>('visit-score'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionRule(l10n.visitScoreHeading),
        const SizedBox(height: TiqSpace.s4),
        Semantics(
          container: true,
          label: l10n.visitReviewScoreSemantics(score.weightedTotal.round(), word),
          excludeSemantics: true,
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: TiqSpace.s3,
            runSpacing: TiqSpace.s2,
            children: <Widget>[
              FigureSlot(
                key: const ValueKey<String>('visit-score-figure'),
                value: score.weightedTotal.round(),
                role: skin.text.heroFigure,
                fit: <TiqTypeToken>[
                  skin.text.heroFigure,
                  skin.text.heroFigureCompact,
                  skin.text.display,
                ],
                // ink-1 at every band. The band is the mark and the word.
                color: skin.palette.ink1,
              ),
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
                    // A band this build does not know gets no mark and no
                    // severity: it is not guessed at.
                    if (band != null) ...<Widget>[
                      SeverityMark(kind: markForBand(band)),
                      const SizedBox(width: TiqSpace.s2),
                    ],
                    Flexible(
                      child: Text(
                        word,
                        key: const ValueKey<String>('visit-band'),
                        style: skin.text.label.style(
                          color: band == null
                              ? skin.palette.ink3
                              : bandInk(skin, band),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: TiqSpace.s4),
        Meter(
          value: score.weightedTotal,
          target: score.target,
          semanticsValue: l10n.visitScoreMeterSemantics(
            score.weightedTotal.round(),
            score.target.round(),
          ),
        ),
        const SizedBox(height: TiqSpace.s6),
        SectionRule(l10n.visitHowScored),
        const SizedBox(height: TiqSpace.s4),
        TorchBleed(
          extra: gutter * 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (var i = 0; i < score.dimensions.length; i++)
                _DimensionRow(
                  dimension: score.dimensions[i],
                  target: score.target,
                  last: i == score.dimensions.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ONE DIMENSION: its name, its figure, and the bar that explains it.
class _DimensionRow extends StatelessWidget {
  const _DimensionRow({
    required this.dimension,
    required this.target,
    required this.last,
  });

  final ScoreDimension dimension;
  final double target;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final label = dimensionLabel(l10n, dimension.key);
    final value = dimension.score;
    final measured = value != null;
    final reason = l10n.outcomeNotMeasuredGeneric;
    final onTarget = measured && value >= target;

    return SoftRow(
      key: ValueKey<String>('visit-dimension-${dimension.key}'),
      density: SoftRowDensity.tall,
      title: label,
      // The word, always — never the bar's colour on its own.
      subtitle: measured
          ? (onTarget ? l10n.visitOnTarget : l10n.visitBelowTarget)
          : l10n.trendsNotMeasured,
      meta: measured
          ? Meter(
              value: value,
              target: target,
              semanticsValue: l10n.outcomeDimensionSemantics(
                label,
                value.round(),
              ),
            )
          // The em dash, the full-width falling hatch and the reason — all
          // three, because a hatch without a sentence is a puzzle and a
          // partial hatch reads as a hatched value.
          : NotMeasured(
              key: ValueKey<String>('visit-unmeasured-${dimension.key}'),
              reason: reason,
              role: skin.text.figureS,
              semanticsLabel: l10n.outcomeDimensionUnmeasuredSemantics(
                label,
                reason,
              ),
            ),
      trailing: measured
          ? FigureSlot(
              value: value.round(),
              role: skin.text.figureS,
              textAlign: TextAlign.end,
            )
          : null,
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: measured
          ? '${l10n.outcomeDimensionSemantics(label, value.round())} '
                '${onTarget ? l10n.visitOnTarget : l10n.visitBelowTarget}'
          : l10n.outcomeDimensionUnmeasuredSemantics(label, reason),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Client questions
// ═══════════════════════════════════════════════════════════════════════

/// The visit's answers to the client's audit template (#122), each under the
/// question the template asked. The template's own score, when its schema is
/// weighted, is shown here only — it is not part of the perfect-store score.
class _TemplateAnswers extends StatelessWidget {
  const _TemplateAnswers({required this.answers});

  final VisitTemplateAnswers answers;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final gutter = skin.space.gutter;
    final schema = TemplateSchema.parse(answers.schema);
    final given = Map<String, Object?>.from(answers.answers);
    final known = <String>{for (final f in schema.fields) f.id};
    final orphans = <MapEntry<String, Object?>>[
      for (final entry in given.entries)
        if (!known.contains(entry.key)) entry,
    ];
    final maxScore = schema.maxScore;

    final rows = <Widget>[
      for (final field in schema.fields)
        // A question hidden by its condition was never put to the agent.
        if (field.isVisible(given))
          _AnswerRow(
            rowKey: ValueKey<String>('visit-template-answer-${field.id}'),
            label: field.label,
            value: _answerText(l10n, field, given),
            missing: !field.isAnswered(given),
            required: field.blocksSubmit,
          ),
      for (final entry in orphans)
        _AnswerRow(
          rowKey: ValueKey<String>('visit-template-answer-${entry.key}'),
          label: l10n.visitAnswerOrphan(entry.key),
          value: _plain(l10n, entry.value),
          missing: false,
          required: false,
        ),
    ];

    return Column(
      key: ValueKey<String>('visit-template-${answers.templateId}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionRule(l10n.visitReviewClientQuestions(answers.templateName)),
        const SizedBox(height: TiqSpace.s3),
        Text(
          answers.answeredOlderVersion
              ? l10n.visitAnsweredOlderVersion(
                  answers.templateVersion,
                  answers.currentVersion,
                )
              : l10n.visitAnsweredVersion(answers.templateVersion),
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
        if (maxScore > 0) ...<Widget>[
          const SizedBox(height: TiqSpace.s3),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusChip(
              key: const ValueKey<String>('visit-template-score'),
              level: StatusLevel.held,
              label: l10n.visitTemplateScore(
                _trim(schema.scoreFor(given)),
                _trim(maxScore),
              ),
            ),
          ),
        ],
        const SizedBox(height: TiqSpace.s4),
        if (rows.isEmpty)
          EmptyState(
            scope: EmptyScope.inPanel,
            headline: l10n.visitNoAnswersHeadline,
            body: l10n.visitNoAnswersBody,
          )
        else
          TorchBleed(
            extra: gutter * 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: rows,
            ),
          ),
        if (maxScore > 0) ...<Widget>[
          const SizedBox(height: TiqSpace.s3),
          Text(
            l10n.visitTemplateScoreNote,
            style: skin.text.meta.style(color: skin.palette.ink3),
          ),
        ],
      ],
    );
  }

  static String _answerText(
    AppLocalizations l10n,
    TemplateField field,
    Map<String, Object?> given,
  ) {
    if (field.type == TemplateFieldType.photo) return l10n.visitNotCaptured;
    if (!field.isAnswered(given)) return l10n.visitNotAnswered;
    return _plain(l10n, given[field.id]);
  }

  static String _plain(AppLocalizations l10n, Object? value) => switch (value) {
    true => l10n.visitYes,
    false => l10n.visitNo,
    final num n => _trim(n.toDouble()),
    null => emDash,
    _ => '$value',
  };

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({
    required this.rowKey,
    required this.label,
    required this.value,
    required this.missing,
    required this.required,
  });

  /// Carried onto the `SoftRow` itself rather than onto this wrapper, so a
  /// test that finds the row by key gets the row.
  final Key rowKey;

  final String label;
  final String value;
  final bool missing;

  /// Whether the template blocks a submit on this question. A required
  /// question left unanswered is a different fact from an optional one.
  final bool required;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    return SoftRow(
      key: rowKey,
      density: SoftRowDensity.standard,
      title: required ? l10n.visitRequiredQuestion(label) : label,
      trailing: Text(
        value,
        textAlign: TextAlign.end,
        style: missing
            ? skin.text.body.style(color: skin.palette.ink3)
            : skin.text.bodyStrong.style(color: skin.palette.ink1),
      ),
      semanticsLabel: '$label. $value',
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// What was captured
// ═══════════════════════════════════════════════════════════════════════

/// A section's state as a glyph and a word.
///
/// Nothing captured is `notStarted` — a ring — and it is excluded from no
/// count here because this screen reports rather than gates. A flagged risk is
/// an in-store hazard and takes the critical bar; everything else with a flag
/// is an execution gap and takes the watch bar.
({SectionState state, SoftRowSeverity severity}) sectionStanding(
  VisitSectionSummary s,
) {
  if (s.count == 0) {
    return (state: SectionState.notStarted, severity: SoftRowSeverity.none);
  }
  if (s.flagged == 0) {
    return (state: SectionState.done, severity: SoftRowSeverity.none);
  }
  return (
    state: SectionState.inProgress,
    severity: s.key == 'risks'
        ? SoftRowSeverity.critical
        : SoftRowSeverity.watch,
  );
}

String sectionLabel(AppLocalizations l10n, String key) => switch (key) {
  'stock' => l10n.visitSectionStock,
  'visibility' => l10n.visitSectionVisibility,
  'pricing' => l10n.visitSectionPricing,
  'competitive' => l10n.visitSectionCompetitive,
  'risks' => l10n.visitSectionRisks,
  _ => key,
};

class _Sections extends StatelessWidget {
  const _Sections({required this.sections});

  final List<VisitSectionSummary> sections;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final gutter = context.skin.space.gutter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionRule(
          l10n.visitWhatWasCaptured,
          count: sections.isEmpty ? null : sections.length,
          emptyLine: sections.isEmpty ? l10n.visitNothingCaptured : null,
        ),
        const SizedBox(height: TiqSpace.s4),
        if (sections.isNotEmpty)
          TorchBleed(
            extra: gutter * 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var i = 0; i < sections.length; i++)
                  _SectionRow(
                    section: sections[i],
                    last: i == sections.length - 1,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.section, required this.last});

  final VisitSectionSummary section;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final standing = sectionStanding(section);
    final label = sectionLabel(l10n, section.key);
    final word = section.count == 0
        ? l10n.visitNotCapturedSection
        : section.flagged == 0
        ? l10n.visitClear
        : l10n.visitNFlagged(section.flagged);
    // Visibility is captured or not; there is no meaningful count of it.
    final countWord = section.key == 'visibility'
        ? (section.count == 0 ? l10n.visitNothingCaptured : l10n.visitCaptured)
        : l10n.visitNCaptured(section.count);

    return SoftRow(
      key: ValueKey<String>('visit-section-${section.key}'),
      density: SoftRowDensity.tall,
      leading: SectionStateGlyph(state: standing.state),
      title: label,
      subtitle: '$word · $countWord',
      severity: standing.severity,
      severityLabel: standing.severity == SoftRowSeverity.none
          ? null
          : (standing.severity == SoftRowSeverity.critical
                ? l10n.visitSeverityCritical
                : l10n.visitSeverityWatch),
      meta: section.findings.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final f in section.findings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: TiqSpace.s1),
                    child: Text(
                      f,
                      style: skin.text.meta.style(color: skin.palette.ink2),
                    ),
                  ),
                if (section.truncated)
                  Text(
                    l10n.visitFindingsTruncated,
                    style: skin.text.meta.style(color: skin.palette.ink3),
                  ),
              ],
            ),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      // `meta` is inside the row's excluded label, so the findings are
      // painted and announced nowhere unless they are said here (§18.10).
      semanticsLabel: <String>[
        label,
        word,
        countWord,
        ...section.findings,
        if (section.truncated) l10n.visitFindingsTruncated,
        if (section.findings.isEmpty)
          section.count == 0
              ? l10n.visitNothingRecorded
              : l10n.visitNoFindings,
      ].join('. '),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Photos
// ═══════════════════════════════════════════════════════════════════════

class _Photos extends StatelessWidget {
  const _Photos({required this.detail});

  final VisitDetail detail;

  static const double _size = 96;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final shown = detail.photos.length;
    // Veld renders no thumbnails at all (unify §4). The figure list that
    // replaces them is what a screen reader has always been given.
    final veld = skin.mode == SkinMode.veld;

    return Column(
      key: const ValueKey<String>('visit-photos'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionRule(
          l10n.visitPhotos,
          count: detail.photoTotal == 0 ? null : detail.photoTotal,
          emptyLine: detail.photos.isEmpty ? l10n.visitNoPhotos : null,
        ),
        if (detail.photos.isNotEmpty) ...<Widget>[
          const SizedBox(height: TiqSpace.s4),
          if (veld)
            TorchBleed(
              extra: skin.space.gutter * 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (var i = 0; i < detail.photos.length; i++)
                    SoftRow(
                      key: ValueKey<String>(
                        'visit-photo-${detail.photos[i].id}',
                      ),
                      density: SoftRowDensity.compact,
                      title: detail.photos[i].section,
                      trailing: Text(
                        clockOf(detail.photos[i].timestamp.toLocal()),
                        style: skin.text.figureS.style(
                          color: skin.palette.ink1,
                        ),
                      ),
                      separator: i == detail.photos.length - 1
                          ? SoftRowSeparator.none
                          : SoftRowSeparator.auto,
                    ),
                ],
              ),
            )
          else
            Wrap(
              spacing: TiqSpace.s3,
              runSpacing: TiqSpace.s3,
              children: <Widget>[
                for (final p in detail.photos)
                  SizedBox(
                    key: ValueKey<String>('visit-photo-${p.id}'),
                    width: _size,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        TorchEvidenceThumb(
                          photoId: p.id,
                          size: _size,
                          semanticLabel: l10n.visitPhotoSemantics(
                            detail.outlet.name,
                            p.section,
                            clockOf(p.timestamp.toLocal()),
                          ),
                        ),
                        const SizedBox(height: TiqSpace.s1),
                        Text(
                          p.section,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: skin.text.meta.style(
                            color: skin.palette.ink2,
                          ),
                        ),
                        Text(
                          clockOf(p.timestamp.toLocal()),
                          style: skin.text.meta.style(
                            color: skin.palette.ink3,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          if (shown < detail.photoTotal) ...<Widget>[
            const SizedBox(height: TiqSpace.s3),
            Text(
              l10n.visitShowingOf(shown, detail.photoTotal),
              style: skin.text.meta.style(color: skin.palette.ink3),
            ),
          ],
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Fraud
// ═══════════════════════════════════════════════════════════════════════

class _Fraud extends StatelessWidget {
  const _Fraud({required this.detail});

  final VisitDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final gutter = skin.space.gutter;
    // The band is a fact about the number and lives with the data, so this
    // screen and the review queue cannot drift into calling 71 "High risk" in
    // one place and "Elevated" in the other.
    final band = FraudRiskBand.of(detail.riskScore);
    final mark = switch (band) {
      FraudRiskBand.high => SeverityMarkKind.critical,
      FraudRiskBand.elevated => SeverityMarkKind.watch,
      FraudRiskBand.low => null,
    };

    return Column(
      key: const ValueKey<String>('visit-fraud'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SectionRule(l10n.visitFraudSignals, count: detail.signals.length),
        const SizedBox(height: TiqSpace.s4),
        Semantics(
          container: true,
          label: l10n.visitRiskSemantics(
            detail.riskScore.round(),
            band.word(l10n),
          ),
          excludeSemantics: true,
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: TiqSpace.s3,
            runSpacing: TiqSpace.s2,
            children: <Widget>[
              FigureSlot(
                key: const ValueKey<String>('visit-risk-figure'),
                value: detail.riskScore.round(),
                role: skin.text.figureL,
                // A risk figure is not a severity carrier either: the mark and
                // the word beside it are.
                color: skin.palette.ink1,
              ),
              Text(
                l10n.visitRiskOfHundred,
                style: skin.text.meta.style(color: skin.palette.ink3),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (mark != null) ...<Widget>[
                    SeverityMark(kind: mark),
                    const SizedBox(width: TiqSpace.s2),
                  ],
                  Flexible(
                    child: Text(
                      band.word(l10n),
                      key: const ValueKey<String>('visit-risk-band'),
                      style: skin.text.label.style(
                        color: mark == null
                            ? skin.palette.ink2
                            : skin.palette.bad,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: TiqSpace.s5),
        TorchBleed(
          extra: gutter * 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (var i = 0; i < detail.signals.length; i++)
                SoftRow(
                  key: ValueKey<String>(
                    'visit-signal-${detail.signals[i].code}',
                  ),
                  density: SoftRowDensity.tall,
                  title: detail.signals[i].detail,
                  // The rule's own code, in the identifier face: a reviewer
                  // quotes it to support, and it is not a name.
                  meta: Text(
                    detail.signals[i].code,
                    style: skin.text.monoIdent.style(color: skin.palette.ink3),
                  ),
                  separator: i == detail.signals.length - 1
                      ? SoftRowSeparator.none
                      : SoftRowSeparator.auto,
                  semanticsLabel:
                      '${detail.signals[i].detail}. '
                      '${detail.signals[i].code}',
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Formatting
// ═══════════════════════════════════════════════════════════════════════

const _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// `09:12`, in the viewer's local time.
String clockOf(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

/// `14 Sep 2026, 09:12`, in the viewer's local time.
String formatVisitTime(DateTime t) {
  final local = t.toLocal();
  return '${local.day} ${_months[local.month - 1]} ${local.year}, '
      '${clockOf(local)}';
}
