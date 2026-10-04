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
import '../../../core/widgets/torchlight/console_desk.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/console_record.dart';
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
/// marks are Oatmeal and `good`, and the file is a report. Day paints
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

  Widget _frame({
    required String phase,
    required List<Widget> children,
    ConsoleDeskRecords? desk,
  }) {
    final l10n = context.l10n;
    return ConsoleFrame(
      phase: phase,
      // Null on every phase but `loaded`. A skeleton and an error are not
      // records, and neither is an empty list: with no filter rail on this
      // screen there is no slice to widen, so the empty phase keeps the one
      // centred column that already carries its own headline, its body and
      // the create control.
      desk: desk,
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

    return _frame(
      phase: reports.isEmpty ? 'empty' : 'loaded',
      // ── WHAT THE DESK GETS, AND WHAT IT DOES NOT ───────────────────────
      //
      // The definitions, as records. Everything in here is **already built
      // below** for the phone arm — the same `_ReportRow`, the same
      // `SectionRule`, the same `PaginationFooter`, the same two controls —
      // so there is no second composition of this screen to keep in step.
      //
      // The pane is [ConsoleRecordDetail] and not a reused screen body,
      // because there is no read-only body to reuse: `ReportRunHistoryScreen`
      // is keyed to a **[ReportSchedule]**, which a [ReportDefinition] does
      // not carry — so a "Run history" verb on this record would have nothing
      // to pass it. What reaches run history from here is the Schedules hop,
      // and that is why it is in `lead` rather than dropped: `/alerts` could
      // drop its own `Manage rules` because `/alert-rules` is a rail
      // destination, and **`/reports/schedules` is not one**. Dropping it
      // would have left a manager on a desktop with no way to the schedules
      // or to the run history behind them.
      //
      // The section rule DOES stay in `lead`. `alerts_screen.dart` dropped
      // its own on the grounds that the selected filter chip above the list
      // already names and counts the slice; this screen has no filter rail,
      // so the marker is the only thing that names the list.
      //
      // The create control is in `footer`, under the records, which is where
      // the phone puts it — a `footer` is "the blocks under the list", and
      // `New report` is one of them. Put in `lead` it would have read as the
      // first thing on the screen.
      desk: reports.isEmpty
          ? null
          : ConsoleDeskRecords(
              toolbar: ConsoleDeskToolbar.marker,
              lead: <Widget>[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TorchTertiaryButton(
                    key: const ValueKey<String>('reports-schedules-desk'),
                    label: l10n.reportsSchedules,
                    onPressed: () => context.go('/reports/schedules'),
                  ),
                ),
                const SizedBox(height: TiqSpace.s6),
                SectionRule(
                  l10n.reportsSection,
                  count: reports.length,
                  listAction: true,
                ),
                const SizedBox(height: TiqSpace.s5),
              ],
              footer: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (page.nextCursor != null) ...<Widget>[
                    PaginationFooter(
                      key: const ValueKey<String>('reports-footer-desk'),
                      summary: _footerSummary(page),
                    ),
                    const SizedBox(height: TiqSpace.s6),
                  ],
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TorchSecondaryButton(
                      key: const ValueKey<String>('report-create-desk'),
                      label: l10n.reportsNew,
                      onPressed: _create,
                    ),
                  ),
                ],
              ),
              records: <ConsoleDeskRecord>[
                for (var i = 0; i < reports.length; i++)
                  ConsoleDeskRecord(
                    id: reports[i].id,
                    row: (context, selected) => _ReportRow(
                      key: ValueKey<String>('report-${reports[i].id}'),
                      report: reports[i],
                      outcome: _outcomes[reports[i].id],
                      last: i == reports.length - 1,
                      onRan: (outcome) =>
                          setState(() => _outcomes[reports[i].id] = outcome),
                      onDeleted: _refresh,
                    ),
                    detail: (context) => _ReportPane(
                      key: ValueKey<String>('report-pane-${reports[i].id}'),
                      report: reports[i],
                      outcome: _outcomes[reports[i].id],
                      onRan: (outcome) =>
                          setState(() => _outcomes[reports[i].id] = outcome),
                      onDeleted: _refresh,
                    ),
                  ),
              ],
            ),
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

/// ── A REPORT'S TWO VERBS, WRITTEN ONCE ─────────────────────────────────
///
/// The row carries Run and Delete, and at desk width the **detail pane
/// carries the same two**, lifted. Writing them twice is how the pane and the
/// row end up disagreeing about what a refused save says or which sheet a
/// delete asks through — the drift `console_record.dart` exists to stop. So
/// the two requests, their toasts and their outcomes live here, in one copy,
/// mixed into both states.
///
/// What each state keeps of its own is the **busy flag**, because that is a
/// property of the control that was pressed and not of the report: the ghost
/// that says "Running…" is the one you touched. The cost is that pressing Run
/// in the pane does not lock the row beside it, and the two could in principle
/// be pressed together — the result is the same either way, because the
/// outcome lands in the screen's own `_outcomes` map, which both read.
abstract class _ReportVerbHost extends ConsumerStatefulWidget {
  const _ReportVerbHost({super.key});

  ReportDefinition get report;
  ReportRunOutcome? get outcome;
  ValueChanged<ReportRunOutcome> get onRan;
  VoidCallback get onDeleted;
}

mixin _ReportVerbs<W extends _ReportVerbHost> on ConsumerState<W> {
  bool running = false;
  bool deleting = false;

  /// Either verb in flight locks both, on the row and in the pane alike.
  bool get busy => running || deleting;

  Future<void> run() async {
    if (running) return;
    final l10n = context.l10n;
    setState(() => running = true);
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
      setState(() => running = false);
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
      setState(() => running = false);
      widget.onRan(const ReportRunOutcome.failed());
      showTorchToast(
        context,
        message: TorchErrorMessage.sanitise(error).body,
        kind: ToastKind.failure,
        action: TorchTertiaryButton(
          label: l10n.torchTryAgain,
          onPressed: run,
        ),
      );
    }
  }

  Future<void> delete() async {
    if (deleting) return;
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
    setState(() => deleting = true);
    try {
      await ref
          .read(reportsRepositoryProvider)
          .deleteReport(widget.report.id);
      if (!mounted) return;
      widget.onDeleted();
    } catch (error) {
      if (!mounted) return;
      setState(() => deleting = false);
      showTorchToast(
        context,
        message: l10n.reportDeleteFailed(
          TorchErrorMessage.sanitise(error).body,
        ),
        kind: ToastKind.failure,
      );
    }
  }
}

/// A run's state as the mark and the word, in one function.
///
/// The row prints these and so does the detail pane beside it. Two copies of
/// this ladder is how a row says "Generated" next to a pane that says "Ready".
(MarkShape, String) _runMark(
  AppLocalizations l10n, {
  required bool running,
  required ReportRunOutcome? outcome,
}) => running
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

/// The mark's ink: `good` for a circle, `bad` for a triangle, Oatmeal for the
/// square that is neither.
Color _runMarkColour(TiqSkin skin, MarkShape mark) =>
    mark == MarkShape.onTargetCircle
    ? skin.palette.good
    : mark == MarkShape.watchTriangle
    ? skin.palette.bad
    : skin.palette.ink2;

/// What the row's subtitle says about the last run, or null before there was
/// one. Read by the row and by the pane's lede, so the two cannot differ.
String? _runLine(
  AppLocalizations l10n,
  TiqNumber numbers,
  ReportRunOutcome? outcome,
) => outcome != null && !outcome.failed && (outcome.rows ?? 0) > 0
    ? l10n.reportRowsAndFile(
        numbers.format(outcome.rows!),
        outcome.filename!,
      )
    : null;

/// One saved definition, as a row.
///
/// Run is optimistic in its busy state only, never in its result: the row
/// locks and the ghost says "Running…" from the touch-up, and the count that
/// appears afterwards is the one that came back.
class _ReportRow extends _ReportVerbHost {
  const _ReportRow({
    super.key,
    required this.report,
    required this.outcome,
    required this.last,
    required this.onRan,
    required this.onDeleted,
  });

  @override
  final ReportDefinition report;
  @override
  final ReportRunOutcome? outcome;
  final bool last;
  @override
  final ValueChanged<ReportRunOutcome> onRan;
  @override
  final VoidCallback onDeleted;

  @override
  ConsumerState<_ReportRow> createState() => _ReportRowState();
}

class _ReportRowState extends ConsumerState<_ReportRow>
    with _ReportVerbs<_ReportRow> {
  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final report = widget.report;
    final outcome = widget.outcome;
    final numbers = TiqNumber.of(context);

    final (MarkShape mark, String word) = _runMark(
      l10n,
      running: running,
      outcome: outcome,
    );

    final slug = Text(
      report.type,
      style: skin.text.monoIdent.style(color: skin.palette.ink3),
    );

    return SoftRow(
      key: ValueKey<String>('report-row-${report.id}'),
      density: SoftRowDensity.tall,
      title: report.name,
      subtitle: _runLine(l10n, numbers, outcome),
      leading: TiqMark(
        shape: mark,
        color: _runMarkColour(skin, mark),
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
            label: running ? l10n.reportRunning : l10n.reportRun,
            onPressed: busy ? null : run,
          ),
          TorchTertiaryButton(
            key: ValueKey<String>('delete-${report.id}'),
            label: l10n.reportDelete,
            onPressed: busy ? null : delete,
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

/// ── THE RECORD, IN THE DETAIL PANE ─────────────────────────────────────
///
/// A [ReportDefinition] is three fields on the wire — an id, a name and a
/// slug — so this pane is short, and it is short because the record is. There
/// is no format, no schedule and no last-run timestamp to print: the one
/// thing this screen knows about a run is what it ran **in this session**,
/// which is the screen's own `_outcomes` map, and that is where the kicker and
/// the lede come from. A pane that printed a "Last run" line would be
/// inventing a fact the endpoint does not send.
///
/// It is a [StatefulWidget] for one reason: the two verbs. Run locks while the
/// CSV is in flight and the ghost says so, exactly as it does on the row, and
/// both press the same code — see [_ReportVerbs].
class _ReportPane extends _ReportVerbHost {
  const _ReportPane({
    super.key,
    required this.report,
    required this.outcome,
    required this.onRan,
    required this.onDeleted,
  });

  @override
  final ReportDefinition report;
  @override
  final ReportRunOutcome? outcome;
  @override
  final ValueChanged<ReportRunOutcome> onRan;
  @override
  final VoidCallback onDeleted;

  @override
  ConsumerState<_ReportPane> createState() => _ReportPaneState();
}

class _ReportPaneState extends ConsumerState<_ReportPane>
    with _ReportVerbs<_ReportPane> {
  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final report = widget.report;
    final numbers = TiqNumber.of(context);
    final (MarkShape mark, String word) = _runMark(
      l10n,
      running: running,
      outcome: widget.outcome,
    );

    return ConsoleRecordDetail(
      title: report.name,
      // The row's own mark and the word beside it, at the row's own glyph
      // size and in the row's own meta face.
      kicker: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TiqMark(
            shape: mark,
            color: _runMarkColour(skin, mark),
            size: MarkScale.glyph(context, 16),
          ),
          const SizedBox(width: TiqSpace.s2),
          Text(word, style: skin.text.meta.style(color: skin.palette.ink3)),
        ],
      ),
      lede: _runLine(l10n, numbers, widget.outcome),
      // The slug, machine-facing, in the identifier face — the one fact a
      // definition carries beyond its name, and the one a manager quotes back.
      facts: <RecordFact>[
        RecordFact(l10n.reportFormType, report.type, mono: true),
      ],
      // THE ROW'S VERBS, LIFTED. The same two ghosts, the same two handlers,
      // the same lock while either is in flight — and distinct keys, because
      // the row is on screen beside this pane and a key is not a label.
      actions: <Widget>[
        TorchTertiaryButton(
          key: ValueKey<String>('run-${report.id}-pane'),
          label: running ? l10n.reportRunning : l10n.reportRun,
          onPressed: busy ? null : run,
        ),
        TorchTertiaryButton(
          key: ValueKey<String>('delete-${report.id}-pane'),
          label: l10n.reportDelete,
          onPressed: busy ? null : delete,
        ),
      ],
    );
  }
}
