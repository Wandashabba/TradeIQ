import 'package:flutter/material.dart' show Icons, MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/download/file_download.dart';
import '../../../core/network/paginated_response.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../data/reports_repository.dart';
import 'report_form_screen.dart';

/// REPORTS — saved definitions a manager runs against live data.
///
/// ```text
///   Reports                                     [ ⟳ ]
///   Definitions run on demand against live data.
///   Schedules
///   ── Reports 7 ────────────────────────────────
///   Outlet coverage
///   outlet_coverage · 1 284 rows        ● Generated
///   Run   Delete
///   …
///   [ New report ]
///   [ nav pill ]
/// ```
///
/// ## Run downloads the file the server already wrote (#390)
///
/// The old Run asked for `GET /reports/:id/generate`, parsed the JSON, kept
/// `rowCount` and **threw every row away**. The manager saw a number and got
/// nothing. The server has produced a CSV at `?format=csv` the whole time:
/// Run now asks for that, and the file lands on the manager's disk.
///
/// The row count is then counted from the bytes that were saved, not taken
/// from a second request — one run, one answer, and no chance of a count that
/// disagrees with the file beside it. **Zero rows is a real answer**: it shows
/// as a measured `0` with the comparison square and the sentence, never as an
/// error and never suppressed.
///
/// ## The one amber, counted
///
/// A tab root: the nav pill's active tab is slot 1, and this screen nominates
/// **no content amber**. Nothing here is armed — Run is a ghost, the state
/// marks are Oatmeal and `good`, and the file is a report. Day and Veld paint
/// zero, because the ladder's one rung on a light ground is the primary commit
/// block and a list of definitions has none.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  /// What each report returned the last time it was run **in this session**,
  /// keyed by id. Deliberately not persisted: the count is about the run, and
  /// a count remembered across a restart would claim a freshness nobody has.
  final Map<String, ReportRunOutcome> _outcomes = <String, ReportRunOutcome>{};

  void _refresh() => ref.invalidate(reportsPageProvider);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final page = ref.watch(reportsPageProvider);

    return page.when(
      loading: () => _frame(
        phase: 'loading',
        children: <Widget>[
          Skeleton(
            label: l10n.reportsSkeleton,
            child: const SkeletonRows(count: 4, rowHeight: 64),
          ),
        ],
      ),
      error: (error, stack) => _frame(
        phase: 'error',
        children: <Widget>[
          TorchErrorRegion(
            name: l10n.reportsSkeleton,
            child: ErrorState(
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('reports-retry'),
                label: l10n.torchTryAgain,
                onPressed: _refresh,
              ),
            ),
          ),
        ],
      ),
      data: _loaded,
    );
  }

  Widget _frame({required String phase, required List<Widget> children}) {
    final l10n = context.l10n;
    return ConsoleFrame(
      phase: phase,
      active: ConsoleSlot.menu,
      header: TorchAppHeader(
        title: l10n.reportsTitle,
        facts: <String>[l10n.reportsFact],
        trailing: TorchIconButton(
          key: const ValueKey<String>('reports-refresh'),
          icon: Icons.refresh,
          semanticLabel: l10n.reportsRefresh,
          onPressed: _refresh,
        ),
      ),
      children: children,
    );
  }

  Widget _loaded(PaginatedResponse<ReportDefinition> page) {
    final l10n = context.l10n;
    final reports = page.data;
    final gutter = context.skin.space.gutter;

    return _frame(
      phase: reports.isEmpty ? 'empty' : 'loaded',
      children: <Widget>[
        // Schedules hang off their reports rather than taking a nav slot of
        // their own, and a manager reading "run on demand" should be able to
        // go and see what already runs without it.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TorchTertiaryButton(
            key: const ValueKey<String>('reports-schedules'),
            label: l10n.reportsSchedules,
            onPressed: () => context.go('/reports/schedules'),
          ),
        ),
        const SizedBox(height: TiqSpace.s6),

        SectionRule(
          l10n.reportsSection,
          count: reports.isEmpty ? null : reports.length,
        ),
        const SizedBox(height: TiqSpace.s5),

        if (reports.isEmpty)
          EmptyState(
            scope: EmptyScope.inPanel,
            headline: l10n.reportsEmptyHeadline,
            body: l10n.reportsEmptyBody,
            action: TorchSecondaryButton(
              key: const ValueKey<String>('report-create-empty'),
              label: l10n.reportsNew,
              onPressed: _create,
            ),
          )
        else
          TorchBleed(
            extra: gutter * 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < reports.length; i++)
                  _ReportRow(
                    key: ValueKey<String>('report-${reports[i].id}'),
                    report: reports[i],
                    outcome: _outcomes[reports[i].id],
                    last: i == reports.length - 1,
                    onRan: (outcome) =>
                        setState(() => _outcomes[reports[i].id] = outcome),
                    onDeleted: _refresh,
                  ),
              ],
            ),
          ),

        // The list was cut. It does not offer to narrow, because there is no
        // filter here that could bring the rest into view — and it never
        // invents the total the endpoint does not send.
        if (page.nextCursor != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s6),
          TorchBleed(
            extra: gutter * 2,
            child: PaginationFooter(
              key: const ValueKey<String>('reports-footer'),
              summary: _footerSummary(page),
            ),
          ),
        ],

        if (reports.isNotEmpty) ...<Widget>[
          const SizedBox(height: TiqSpace.s6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TorchSecondaryButton(
              key: const ValueKey<String>('report-create'),
              label: l10n.reportsNew,
              onPressed: _create,
            ),
          ),
        ],
      ],
    );
  }

  String _footerSummary(PaginatedResponse<ReportDefinition> page) {
    final l10n = context.l10n;
    final numbers = TiqNumber.of(context);
    final shown = numbers.format(page.data.length);
    final total = page.total;
    return total == null
        ? l10n.reportsFooterMore(shown)
        : l10n.reportsFooterOf(shown, numbers.format(total));
  }

  void _create() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (context) => const ReportFormScreen()),
  );
}

/// What a run returned, as the row reports it afterwards.
class ReportRunOutcome {
  const ReportRunOutcome.saved(this.rows, this.filename, this.location)
    : failed = false;
  const ReportRunOutcome.failed()
    : rows = null,
      filename = null,
      location = null,
      failed = true;

  /// A measured count, including a measured **zero**. Null only means the run
  /// has not happened.
  final int? rows;
  final String? filename;
  final String? location;
  final bool failed;
}

/// One saved definition, as a row.
///
/// Run is optimistic in its busy state only, never in its result: the row
/// locks and the ghost says "Running…" from the touch-up, and the count that
/// appears afterwards is the one that came back.
class _ReportRow extends ConsumerStatefulWidget {
  const _ReportRow({
    super.key,
    required this.report,
    required this.outcome,
    required this.last,
    required this.onRan,
    required this.onDeleted,
  });

  final ReportDefinition report;
  final ReportRunOutcome? outcome;
  final bool last;
  final ValueChanged<ReportRunOutcome> onRan;
  final VoidCallback onDeleted;

  @override
  ConsumerState<_ReportRow> createState() => _ReportRowState();
}

class _ReportRowState extends ConsumerState<_ReportRow> {
  bool _running = false;
  bool _deleting = false;

  Future<void> _run() async {
    if (_running) return;
    final l10n = context.l10n;
    setState(() => _running = true);
    try {
      final csv = await ref
          .read(reportsRepositoryProvider)
          .generateCsv(widget.report.id, slug: widget.report.type);
      final saved = await ref
          .read(fileDownloaderProvider)
          .save(
            bytes: csv.bytes,
            filename: csv.filename,
            mimeType: 'text/csv;charset=utf-8',
          );
      if (!mounted) return;
      setState(() => _running = false);
      widget.onRan(
        ReportRunOutcome.saved(csv.rows, saved.filename, saved.location),
      );
      showTorchToast(
        context,
        message: saved.location == null
            ? l10n.reportDownloaded(saved.filename)
            : l10n.reportSavedTo(saved.filename, saved.location!),
        kind: ToastKind.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _running = false);
      widget.onRan(const ReportRunOutcome.failed());
      showTorchToast(
        context,
        message: TorchErrorMessage.sanitise(error).body,
        kind: ToastKind.failure,
        action: TorchTertiaryButton(
          label: l10n.torchTryAgain,
          onPressed: _run,
        ),
      );
    }
  }

  Future<void> _delete() async {
    if (_deleting) return;
    final l10n = context.l10n;
    // A saved definition somebody else's schedule runs is not a one-tap
    // delete.
    final confirmed = await showTorchSheet<bool>(
      context,
      builder: (_) => ConfirmSheet(
        key: const ValueKey<String>('report-delete-sheet'),
        action: l10n.reportDeleteAction(widget.report.name),
        consequences: <String>[
          l10n.reportDeleteConsequenceEveryone,
          l10n.reportDeleteConsequenceSchedules,
          l10n.reportDeleteConsequenceFiles,
        ],
        commitLabel: l10n.reportDeleteCommit,
        cancelLabel: l10n.reportDeleteCancel,
        record: widget.report.type,
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref
          .read(reportsRepositoryProvider)
          .deleteReport(widget.report.id);
      if (!mounted) return;
      widget.onDeleted();
    } catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      showTorchToast(
        context,
        message: l10n.reportDeleteFailed(
          TorchErrorMessage.sanitise(error).body,
        ),
        kind: ToastKind.failure,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final report = widget.report;
    final outcome = widget.outcome;
    final numbers = TiqNumber.of(context);

    final (MarkShape mark, String word) = _running
        ? (MarkShape.heldSquare, l10n.reportWordRunning)
        : outcome == null
        ? (MarkShape.heldSquare, l10n.reportWordReady)
        : outcome.failed
        ? (MarkShape.watchTriangle, l10n.reportWordFailed)
        : outcome.rows == 0
        // Zero is a real answer, and it gets the COMPARISON square rather than
        // a severity: a query that matched nothing is not a fault. It must not
        // get `notMeasuredBarredSquare` — that silhouette means "we did not
        // measure this", so it would contradict the "0 rows" beside it and
        // send a manager to re-run a query that ran correctly. The mark is
        // what survives greyscale and a glance; the word cannot rescue it.
        ? (MarkShape.heldSquare, l10n.reportWordZeroRows)
        : (MarkShape.onTargetCircle, l10n.reportWordGenerated);

    final slug = Text(
      report.type,
      style: skin.text.monoIdent.style(color: skin.palette.ink3),
    );

    return SoftRow(
      key: ValueKey<String>('report-row-${report.id}'),
      density: SoftRowDensity.tall,
      title: report.name,
      subtitle: outcome != null && !outcome.failed && (outcome.rows ?? 0) > 0
          ? l10n.reportRowsAndFile(
              numbers.format(outcome.rows!),
              outcome.filename!,
            )
          : null,
      leading: TiqMark(
        shape: mark,
        color: mark == MarkShape.onTargetCircle
            ? skin.palette.good
            : mark == MarkShape.watchTriangle
            ? skin.palette.bad
            : skin.palette.ink2,
        size: MarkScale.glyph(context, 16),
      ),
      meta: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Machine-facing: a manager can quote the slug straight back into a
          // definition, so it wears the identifier face.
          slug,
          const SizedBox(height: TiqSpace.s1),
          Text(word, style: skin.text.meta.style(color: skin.palette.ink3)),
        ],
      ),
      // The verbs live in the row's own action slot. `meta` is inside the
      // row's excluded label, so a button there is painted and announced
      // nowhere — the kit-wide bug that lost three worklists their actions.
      actions: Wrap(
        spacing: TiqSpace.s4,
        children: <Widget>[
          TorchTertiaryButton(
            key: ValueKey<String>('run-${report.id}'),
            label: _running ? l10n.reportRunning : l10n.reportRun,
            onPressed: _running || _deleting ? null : _run,
          ),
          TorchTertiaryButton(
            key: ValueKey<String>('delete-${report.id}'),
            label: l10n.reportDelete,
            onPressed: _running || _deleting ? null : _delete,
          ),
        ],
      ),
      separator: widget.last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: <String>[
        report.name,
        report.type,
        word,
        if (outcome != null && !outcome.failed && (outcome.rows ?? 0) > 0)
          l10n.reportRowsSpoken(numbers.format(outcome.rows!)),
      ].join('. '),
    );
  }
}
