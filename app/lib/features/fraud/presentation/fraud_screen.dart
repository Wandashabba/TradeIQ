import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../data/fraud_repository.dart';
import '../data/fraud_view.dart';
import 'verdict_sheet.dart';

/// FRAUD REVIEW — the queue of visits the engine has accused, and the place a
/// person answers.
///
/// ```text
///   Fraud review                                  [ ⟳ ]
///   Risk is scored 0–100 on submit. The signals
///   are the evidence.
///   ( Open 4 )( Decided )( All )
///   ── Open ──────────────────────────────── 4 ──
///   ▌ ┌──┐
///   ▌ │TM│ Thandi Mokoena        Risk 82 · High risk
///   ▌ └──┘ Kasi Corner Spaza
///   ▌      GPS_JUMP, DWELL_SHORT
///   ▌      Checked in 4,2 km from the pin · 40 s on site
///   ▌      Rule on this visit    See the visit
///   …
///   Showing the 20 riskiest.
///   3 submitted visits have not been scored yet and
///   are not listed here.
///   [ nav pill ]
/// ```
///
/// ## Accusing a person is the most consequential thing this console does
///
/// So the row never leans on colour. The score is a figure, the band is a
/// **word**, the rules that fired are their own codes, and what they actually
/// found is printed underneath as the evidence. A crimson bar with no reason
/// behind it is not a finding.
///
/// And the row **names the agent** (#399/#400). The queue before this one said
/// `Visit 5f3c1a2b` — a UUID as the primary line on the screen where somebody
/// gets accused of faking their work, while the outlet at least got a name.
/// A manager cannot act on a hex string and cannot quote it down a phone
/// either. Where the roster does not carry the agent the row says "Unknown
/// agent" in words and drops the id to its own line in the mono identifier
/// face, which is the one place a raw id is legitimate: it is then the only
/// fact there is.
///
/// ## A ruled visit leaves the queue (#392)
///
/// The default list is the **open** queue, because a queue that never shortens
/// is a queue people stop opening — and the flagged visit that mattered went
/// unread among the ones already cleared. The rail's other two chips reach the
/// decided list and the whole list, so nothing is unreachable, and every row
/// carries its verdict whichever side you ask for.
///
/// ## The flag is a fact plus a word, and never amber
///
/// "Not yet reviewed" is a neutral flag chip: out of fence is a measurement,
/// not a verdict, and neither is a risk score. Amber is emitted light and
/// tells you where to look — it never tells you how bad something is, and it
/// would be exactly the wrong thing on a page of accusations.
///
/// ## The one amber, counted
///
/// A tab root: Night's budget is two, the nav's active tab is slot 1, and the
/// queue nominates nothing — no commit action is armed on a list. The ruling
/// sheet is an untabbed route with two grants, spends one on its commit, and
/// while it is up every amber beneath it goes out.
class FraudScreen extends ConsumerStatefulWidget {
  const FraudScreen({super.key});

  @override
  ConsumerState<FraudScreen> createState() => _FraudScreenState();
}

class _FraudScreenState extends ConsumerState<FraudScreen> {
  FlaggedReviewFilter _filter = FlaggedReviewFilter.open;

  void _refresh() {
    for (final filter in FlaggedReviewFilter.values) {
      ref.invalidate(fraudViewProvider(filter));
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(fraudViewProvider(_filter));

    Widget frame({required String phase, required List<Widget> children}) =>
        ConsoleFrame(
          phase: phase,
          active: ConsoleSlot.menu,
          header: TorchAppHeader(
            title: 'Fraud review',
            facts: const <String>[
              'Risk is scored 0–100 on submit. The signals are the evidence.',
            ],
            trailing: TorchIconButton(
              key: const ValueKey<String>('fraud-refresh'),
              icon: Icons.refresh,
              semanticLabel: 'Refresh the review queue',
              onPressed: _refresh,
            ),
          ),
          children: <Widget>[
            TorchBleed(
              extra: context.skin.space.gutter * 2,
              child: _Filters(
                filter: _filter,
                onFilter: (f) => setState(() => _filter = f),
              ),
            ),
            const SizedBox(height: TiqSpace.s6),
            ...children,
          ],
        );

    return view.when(
      loading: () => frame(
        phase: 'loading',
        children: <Widget>[
          Skeleton(
            label: 'flagged visits',
            child: const SkeletonRows(count: 4, rowHeight: 80),
          ),
        ],
      ),
      error: (error, stack) => frame(
        phase: 'error',
        children: <Widget>[
          TorchErrorRegion(
            name: 'flagged visits',
            child: ErrorState(
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('fraud-retry'),
                label: 'Try again',
                onPressed: _refresh,
              ),
            ),
          ),
        ],
      ),
      data: (data) => frame(
        phase: data.rows.isEmpty ? 'empty' : 'loaded',
        children: _body(data),
      ),
    );
  }

  List<Widget> _body(FraudView view) {
    final gutter = context.skin.space.gutter;
    final numbers = TiqNumber.of(context);
    final unscored = view.unscoredNote(numbers.format);

    return <Widget>[
      SectionRule(
        _sectionName(),
        count: view.rows.isEmpty ? null : view.rows.length,
        emptyLine: view.rows.isEmpty ? _emptyLine() : null,
      ),
      const SizedBox(height: TiqSpace.s5),
      if (view.rows.isEmpty)
        EmptyState(
          key: const ValueKey<String>('fraud-empty'),
          scope: EmptyScope.inPanel,
          headline: _emptyHeadline(),
          body: _emptyBody(),
        )
      else
        TorchBleed(
          extra: gutter * 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var i = 0; i < view.rows.length; i++)
                _FlaggedRow(
                  key: ValueKey<String>('flagged-${view.rows[i].visitId}'),
                  row: view.rows[i],
                  last: i == view.rows.length - 1,
                  onRuled: _refresh,
                ),
            ],
          ),
        ),
      // An unscored visit is not a clean one. Say so wherever it is true,
      // including under an empty queue — a queue with nothing in it and three
      // visits nobody scored is not an all-clear (#236).
      if (unscored != null || view.hasMore) ...<Widget>[
        const SizedBox(height: TiqSpace.s6),
        TorchBleed(
          extra: gutter * 2,
          child: PaginationFooter(
            key: const ValueKey<String>('fraud-footer'),
            summary: view.hasMore
                ? 'Showing the ${numbers.format(view.rows.length)} riskiest.'
                : '',
            unscoredNote: unscored,
          ),
        ),
      ],
    ];
  }

  String _sectionName() => switch (_filter) {
    FlaggedReviewFilter.open => 'Open',
    FlaggedReviewFilter.decided => 'Decided',
    FlaggedReviewFilter.all => 'Every flagged visit',
  };

  String _emptyLine() => switch (_filter) {
    FlaggedReviewFilter.open => 'Nothing waiting on a ruling.',
    FlaggedReviewFilter.decided => 'Nothing ruled on yet.',
    FlaggedReviewFilter.all => 'Nothing flagged.',
  };

  String _emptyHeadline() => switch (_filter) {
    FlaggedReviewFilter.open => 'Nothing waiting on you.',
    FlaggedReviewFilter.decided => 'No rulings recorded yet.',
    FlaggedReviewFilter.all => 'Nothing flagged.',
  };

  String _emptyBody() => switch (_filter) {
    FlaggedReviewFilter.open =>
      'A visit appears here when the fraud engine scores one above the review '
          'threshold. Ruled visits move to Decided.',
    FlaggedReviewFilter.decided =>
      'A visit appears here once somebody records a ruling on it.',
    FlaggedReviewFilter.all =>
      'Visits appear here when the fraud engine scores one above the review '
          'threshold.',
  };
}

/// Which side of the review line the queue is answering about.
///
/// Selected is lifted + a 1px ink-1 border + a tick + weight 700 — three
/// channels, and never amber on any screen in any skin.
class _Filters extends StatelessWidget {
  const _Filters({required this.filter, required this.onFilter});

  final FlaggedReviewFilter filter;
  final ValueChanged<FlaggedReviewFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    return TorchFilterRail(
      semanticsLabel: 'Which flagged visits',
      chips: <Widget>[
        TorchFilterChip(
          key: const ValueKey<String>('fraud-filter-open'),
          label: 'Open',
          selected: filter == FlaggedReviewFilter.open,
          onSelected: () => onFilter(FlaggedReviewFilter.open),
        ),
        TorchFilterChip(
          key: const ValueKey<String>('fraud-filter-decided'),
          label: 'Decided',
          selected: filter == FlaggedReviewFilter.decided,
          onSelected: () => onFilter(FlaggedReviewFilter.decided),
        ),
        TorchFilterChip(
          key: const ValueKey<String>('fraud-filter-all'),
          label: 'All',
          selected: filter == FlaggedReviewFilter.all,
          onSelected: () => onFilter(FlaggedReviewFilter.all),
        ),
      ],
    );
  }
}

/// One accusation, as a row: who, where, how hard, on what evidence.
///
/// ONE row and one semantics node, with two real verbs beneath the text
/// column. The evidence goes in `meta` — words, and spelled into the row's
/// label — and the buttons go in `actions`, which is the only place in a
/// SoftRow where a verb keeps a node of its own. A tertiary button dropped
/// into `meta` paints, hit-tests and is announced nowhere; the worklists
/// shipped that way once and a semantics dump found zero nodes for it.
class _FlaggedRow extends ConsumerWidget {
  const _FlaggedRow({
    super.key,
    required this.row,
    required this.last,
    required this.onRuled,
  });

  final FraudRow row;
  final bool last;
  final VoidCallback onRuled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = context.skin;
    final numbers = TiqNumber.of(context);
    final score = numbers.format(row.riskScore, decimals: 0);
    final verdict = row.verdict;
    final standing = verdict == null
        ? 'Not yet reviewed'
        : _verdictWord(verdict.kind);

    void openSheet() =>
        showVerdictSheet(context, ref, row: row, onRuled: onRuled);

    return PersonRow(
      name: row.agentName,
      // Without a name the role and the outlet move up into the title, so the
      // role carries the absence in words — "Unknown agent · Kasi Corner
      // Spaza", never the shop's name alone, because the subject of this row
      // is a person and an accusation against a shop is not a thing. The
      // leading tile takes the barred ring rather than invented initials, and
      // the visit reference drops to its own line in the mono identifier
      // face: the one place a raw id belongs, because it is then the only
      // fact there is.
      role: row.agentName == null ? FraudView.unknownAgent : 'Field agent',
      outlet: row.outletName,
      identifier: row.agentName == null ? row.visitId : null,
      identifierLabel: row.agentName == null ? 'Visit' : null,
      // Crimson at two commitment levels, and the band's WORD beside it. A
      // score under the review threshold takes no bar at all: the lane is
      // still reserved, so the column does not shift.
      severity: row.band.severity,
      severityLabel: row.band.word,
      trailing: Text(
        'Risk $score',
        textAlign: TextAlign.end,
        maxLines: 2,
        style: skin.text.figureS.style(color: skin.palette.ink2),
      ),
      trailingLabel: 'Risk $score of 100',
      meta: _Evidence(row: row, standing: standing),
      metaLabel: <String>[
        standing,
        if (row.codes.isNotEmpty) row.codes,
        if (row.evidence.isNotEmpty) row.evidence,
        if (verdict != null) _standingSentence(verdict, numbers),
      ].join('. '),
      actions: Wrap(
        spacing: TiqSpace.s4,
        runSpacing: TiqSpace.s2,
        children: <Widget>[
          TorchTertiaryButton(
            key: ValueKey<String>('fraud-rule-${row.visitId}'),
            label: verdict == null ? 'Rule on this visit' : 'See the ruling',
            onPressed: openSheet,
          ),
          TorchTertiaryButton(
            key: ValueKey<String>('view-visit-${row.visitId}'),
            label: 'See the visit',
            onPressed: () => context.push('/visits/${row.visitId}'),
          ),
        ],
      ),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
    );
  }

  static String _verdictWord(FraudVerdictKind kind) => switch (kind) {
    FraudVerdictKind.cleared => 'Cleared',
    FraudVerdictKind.confirmed => 'Confirmed',
    FraudVerdictKind.needsEvidence => 'Needs evidence',
  };

  /// Who ruled, what they ruled, and the score they were looking at when they
  /// did — because a rescore can move the number afterwards and a clearing
  /// read later must not look as though it was made against a figure nobody
  /// ever saw.
  static String _standingSentence(FraudVerdict verdict, TiqNumber numbers) {
    final at = verdict.riskScoreAtReview;
    final who = verdict.reviewerLabel.isEmpty
        ? 'A reviewer'
        : verdict.reviewerLabel;
    final seen = at == null
        ? ' The visit was unscored at the time.'
        : ' They were looking at risk ${numbers.format(at)}.';
    return '$who ruled it ${_verdictWord(verdict.kind).toLowerCase()}.$seen';
  }
}

/// What the rules found, under the person it is about.
///
/// A flag is a **fact plus a word**, never a colour alone and never amber.
/// "Not yet reviewed" is not a second accusation on top of the first — it is
/// where this visit stands, and a visit nobody has looked at has not been
/// cleared.
class _Evidence extends StatelessWidget {
  const _Evidence({required this.row, required this.standing});

  final FraudRow row;
  final String standing;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final numbers = TiqNumber.of(context);
    final verdict = row.verdict;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FlagChip(
          key: ValueKey<String>('fraud-flag-${row.visitId}'),
          kind: FlagKind.forReview,
          label: row.band.word,
          detail: standing,
          cleared: verdict?.kind == FraudVerdictKind.cleared,
        ),
        if (row.codes.isNotEmpty) ...<Widget>[
          const SizedBox(height: TiqSpace.s2),
          Text(
            row.codes,
            key: ValueKey<String>('fraud-codes-${row.visitId}'),
            style: skin.text.monoIdent.style(color: skin.palette.ink3),
          ),
        ],
        if (row.evidence.isNotEmpty) ...<Widget>[
          const SizedBox(height: TiqSpace.s1),
          Text(row.evidence),
        ],
        if (verdict != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s1),
          Text(
            _FlaggedRow._standingSentence(verdict, numbers),
            key: ValueKey<String>('fraud-verdict-${row.visitId}'),
          ),
        ],
      ],
    );
  }
}
