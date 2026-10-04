import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/card.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_desk.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/console_record.dart';
import '../../../core/widgets/torchlight/evidence_thumb.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../audit/data/photos_repository.dart';
import '../../users/data/users_repository.dart';
import '../data/tasks_admin_repository.dart';
import '../data/tasks_view.dart';
import 'close_with_photo_sheet.dart';

/// TASKS — open work with a clock on it, sorted by consequence.
///
/// ```text
///   Tasks                                         [ ⟳ ]
///   Risks, stockouts and price deviations open a task automatically.
///   ╭────────────────────────────────────────╮
///   │ ▲ OVERDUE                              │
///   │ 1 122                                  │
///   │ Past the deadline and still open.      │
///   │ ──────────────────────────────────     │
///   │ OPEN                           1 190   │
///   │ ──────────────────────────────────     │
///   │ AWAITING VERIFICATION             43   │
///   ╰────────────────────────────────────────╯
///   ( ✓ Open 1 190 )( Overdue 1 122 )( Done 31 178 )( All 32 368 )
///   ╭────────────────────────────────────────╮
///   │ ▌ Kasi Corner Spaza               [img]│
///   │ ▌ Shelf talker missing                 │
///   │ ▌ ▲ Overdue by 2 days · replace the …  │
///   │ ▌ Critical priority                    │
///   │ ▌ Assigned to Thandi Mokoena           │
///   │ ▌ Close with photo                     │
///   ╰────────────────────────────────────────╯
///   …
///   Showing the 50 open tasks with the earliest deadlines, of 1 190.
///   [ nav pill ]
/// ```
///
/// ## The page could not count, so it apologised
///
/// Until the counts landed, `GET /tasks` answered one page and a total, and
/// every figure above the list was derived from the fifty rows in hand. On a
/// real account that is fifty **closed** tasks — the server orders by deadline
/// across every status, and 31,178 of 32,368 tasks are closed — so the screen
/// read `Open 0 · Overdue 0 · Done 50 · All 50` over an account with 1,190
/// open tasks, and withheld its lead figure behind an em dash and a
/// not-measured mark because a zero over a cut page is genuinely an unknown.
/// The mark was right. The data was the defect.
///
/// Two changes end it, and the second is the reason the first is not enough:
///
/// 1. **The server counts the whole set.** `counts` rides on the list's own
///    answer — see `tasks.service.ts` for why it is not an endpoint of its
///    own — so the chips and the lead figure are measured figures, and the
///    footer's "the counts above are of these 50" line has nothing left to
///    say. The honest-unknown machinery is untouched and still fires for a
///    server that does not count.
/// 2. **The filter is the server's, not a `where` over the page.** Real counts
///    on their own would have made the screen more obviously wrong, not less:
///    a chip reading `Open 1 190` above an empty list, because the page it was
///    filtering was the fifty oldest deadlines and those are closed. Each chip
///    now fetches its own slice.
///
/// ## The one amber, counted
///
/// A tab root: the nav pill's active tab is slot 1 and this screen nominates
/// nothing. The overdue lead figure and the SLA phrasing carry the urgency —
/// a filled triangle, the crimson `bad` ink on the figure and a word — and the
/// earlier draft's reasoning that the filter chip should be lit *because a
/// slot was free* is not a possibility the ruling leaves open. Day paints
/// zero.
///
/// The one lit object in this feature is `Close task`, and it lives on the
/// closure sheet, where the amber beneath it has already gone out.
///
/// ## The clock is read once
///
/// [clock] is the screen's one time source, read once per build and threaded
/// down, so every "overdue" on the screen agrees on the same instant and a
/// test can pin it. The server reads its own clock for the `overdue` count and
/// uses the app's definition to the boundary instant — `slaDueAt <= now`,
/// status not closed — so the figure and the rows beneath it agree too.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key, this.clock = DateTime.now});

  final DateTime Function() clock;

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

/// ── THE TWO VERBS, FROM EITHER SIDE OF THE DESK ────────────────────────
///
/// `Close with photo` and `Verify` sit in `SoftRow.actions` on a phone and are
/// **lifted into the detail pane** at desk width, which means two callers for
/// each. They are functions rather than two copies of a method because the
/// halves that matter are the ones a copy drifts on: the gate (no photo, no
/// closure), the upload contract the fraud engine reads, and the honesty on
/// failure — a task that did not close must still read as open, from whichever
/// control was pressed.
///
/// [setBusy] is the caller's own one-tap-one-outcome flag: the row holds it per
/// row, the screen holds it per selected record, and neither can see the
/// other's. [retry] is what the failure toast offers, so it is the caller's own
/// entry point rather than this function re-entering itself with a stale
/// `context`.
///
/// Closing a task means producing evidence it was actually fixed. The photo is
/// the evidence, so the capture is the gate.
///
/// The photo is geotagged at the shutter (#317), so the closure evidence also
/// says where the fix was photographed, and its `timestamp` is the capture time
/// in UTC — the same contract as the audit sections (#310). The fraud engine
/// does not place a closure photo against its visit's outlet
/// (`isTaskClosurePhoto`), so a closure taken away from the outlet, days later,
/// flags nobody. No fix means an empty tag and the closure goes ahead.
Future<void> closeTaskWithPhoto(
  BuildContext context,
  WidgetRef ref, {
  required TaskRow task,
  required ValueChanged<bool> setBusy,
  required VoidCallback onChanged,
  required VoidCallback retry,
}) async {
  final photo = await showCloseWithPhotoSheet(context, task: task);
  // Backing out leaves the task open, which is the correct outcome.
  if (photo == null || !context.mounted) return;

  setBusy(true);
  try {
    final result = await ref
        .read(photosRepositoryProvider)
        .uploadPhoto(
          visitId: task.visitId!,
          section: 'task_closure',
          dataUrl: photo.dataUrl,
          gpsTag: photo.gpsTag,
          timestamp: photo.capturedAt.toUtc().toIso8601String(),
        );
    await ref
        .read(tasksAdminRepositoryProvider)
        .closeTask(id: task.id, closurePhotoUrl: result.url);
    if (!context.mounted) return;
    setBusy(false);
    onChanged();
    showTorchToast(
      context,
      message: 'Closed · ${task.title}',
      kind: ToastKind.success,
    );
  } catch (error) {
    if (!context.mounted) return;
    // The task stays open and the failure is named. A closure that silently
    // did not happen is the worklist lying.
    setBusy(false);
    showTorchToast(
      context,
      message: 'That task was not closed. It is still open.',
      kind: ToastKind.failure,
      action: TorchTertiaryButton(label: 'Try again', onPressed: retry),
    );
  }
}

/// Verifying a closure. See [closeTaskWithPhoto] for why these are functions.
Future<void> verifyTaskClosure(
  BuildContext context,
  WidgetRef ref, {
  required TaskRow task,
  required ValueChanged<bool> setBusy,
  required VoidCallback onChanged,
  required VoidCallback retry,
}) async {
  setBusy(true);
  try {
    await ref.read(tasksAdminRepositoryProvider).verifyTask(task.id);
    if (!context.mounted) return;
    setBusy(false);
    onChanged();
  } catch (error) {
    if (!context.mounted) return;
    setBusy(false);
    showTorchToast(
      context,
      message: 'That closure was not verified.',
      kind: ToastKind.failure,
      action: TorchTertiaryButton(label: 'Try again', onPressed: retry),
    );
  }
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  TaskFilter _filter = TaskFilter.open;

  /// The task whose closure or verification is in flight **from the detail
  /// pane**, or null.
  ///
  /// The pane is not a row and has no `_TaskRowTileState` to borrow: the row's
  /// own `_busy` is private to the element the manager did not press. One tap,
  /// one receipt, one outcome, on this side too.
  String? _paneBusy;

  void _refresh() {
    // Every slice, not only the one on screen. Closing a task changes the
    // overdue count and the done count at once, and a cached `Done` page that
    // still predates the closure is a manager pressing a chip and seeing the
    // task they just closed as open.
    for (final filter in TaskFilter.values) {
      ref.invalidate(tasksPageProvider(filter));
    }
    // The Floor reads the plain list; keeping them in step means a manager who
    // closes a task here does not walk back to a board that still shows it.
    ref.invalidate(tasksListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(tasksPageProvider(_filter));

    return page.when(
      loading: () => _frame(
        phase: 'loading',
        children: <Widget>[
          Skeleton(
            label: 'tasks',
            child: const SkeletonRows(count: 4, rowHeight: 76),
          ),
        ],
      ),
      error: (error, stack) => _frame(
        phase: 'error',
        children: <Widget>[
          TorchErrorRegion(
            name: 'tasks',
            child: ErrorState(
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('tasks-retry'),
                label: 'Try again',
                onPressed: _refresh,
              ),
            ),
          ),
        ],
      ),
      data: (data) => _loaded(
        TasksView.resolve(
          data.entries,
          widget.clock(),
          filter: _filter,
          nextCursor: data.nextCursor,
          total: data.total,
          counts: data.counts,
          owners: <String, String>{
            for (final user in ref.watch(userDirectoryProvider).values)
              user.id: user.label,
          },
        ),
      ),
    );
  }

  /// Closing from the **detail pane**, which has no row to hold the flag.
  void _setPaneBusy(String id, bool value) {
    if (!mounted) return;
    setState(() => _paneBusy = value ? id : null);
  }

  Future<void> _closeInPane(TaskRow task) async {
    if (_paneBusy != null) return;
    await closeTaskWithPhoto(
      context,
      ref,
      task: task,
      setBusy: (busy) => _setPaneBusy(task.id, busy),
      onChanged: _refresh,
      retry: () => _closeInPane(task),
    );
  }

  Future<void> _verifyInPane(TaskRow task) async {
    if (_paneBusy != null) return;
    await verifyTaskClosure(
      context,
      ref,
      task: task,
      setBusy: (busy) => _setPaneBusy(task.id, busy),
      onChanged: _refresh,
      retry: () => _verifyInPane(task),
    );
  }

  Widget _frame({
    required String phase,
    required List<Widget> children,
    ConsoleDeskRecords? desk,
  }) {
    return ConsoleFrame(
      phase: phase,
      // Null on `loading`, `error` and the whole-screen `empty`: a skeleton, a
      // failure and an account with no tasks at all are not records, so those
      // phases keep the rail and one centred column at desk width.
      desk: desk,
      // One of the two console routes that names its own subject — see
      // `ConsoleFrame.askHint` for why the other 25 do not.
      askHint: 'Ask about your tasks…',
      header: TorchAppHeader(
        title: 'Tasks',
        // ONE CLAUSE, not a paragraph. `facts` is a middot-joined line of
        // facts capped at two lines, and Alerts — the sibling worklist, same
        // frame, same grammar — carries six words there. This carried
        // seventeen across two lines, which is a third of the header's own
        // ceiling spent restating what the rows below say better. The
        // qualifier that went ("with a due date set by priority") is the
        // priority line on every row.
        facts: const <String>[
          'Risks, stockouts and price deviations open a task automatically.',
        ],
        // The header allows exactly one trailing control and on a console
        // worklist the one worth having is the refetch — the same choice
        // Alerts, Territories and Messages made, for the same reason.
        trailing: TorchIconButton(
          key: const ValueKey<String>('tasks-refresh'),
          icon: Icons.refresh,
          semanticLabel: 'Refresh the tasks list',
          onPressed: _refresh,
        ),
      ),
      children: children,
    );
  }

  Widget _loaded(TasksView view) {
    final visible = view.visible(_filter);
    final numbers = TiqNumber.of(context);
    final footer = view.footer((n) => numbers.format(n));

    // NOTHING AT ALL IS ITS OWN SCREEN, not a scoreboard of noughts.
    //
    // An account with no tasks under a lead card reading `OVERDUE 0` and four
    // chips reading zero is the same failure The Floor refuses with its
    // first-run board: a wall of measured noughts that says nothing except
    // that the product is on. The whole-screen empty state — a drawing, a
    // display headline and the sentence naming where tasks come from — is what
    // the rest of this app does with an empty route.
    //
    // It is gated on the *counted* set, never on the page: `rows.isEmpty` with
    // a cursor in hand would be a filter that found nothing on page one, which
    // is a different fact and has different words.
    if (view.countsAreMeasured && view.all == 0) {
      return _frame(
        phase: 'empty',
        children: const <Widget>[
          EmptyState(
            key: ValueKey<String>('tasks-empty'),
            scope: EmptyScope.wholeScreen,
            // The closed enum of three. A shelf, because a task is raised
            // against something that was wrong on one.
            drawing: EmptyDrawing.shelf,
            headline: 'No tasks yet.',
            body:
                'Tasks open automatically from risks, stockouts and price '
                'deviations on a submitted visit.',
          ),
        ],
      );
    }

    final lead = _LeadBlock(view: view);
    final filters = _Filters(
      filter: _filter,
      view: view,
      onChanged: (f) => setState(() => _filter = f),
    );

    return _frame(
      phase: visible.isEmpty ? 'filtered-empty' : 'loaded',
      // ── WHAT THE DESK GETS, AND WHAT IT DOES NOT ─────────────────────────
      //
      // The rows, the rail and the lead card — the same `_LeadBlock`, the same
      // `_Filters`, the same `_TaskRowTile` and the same `PaginationFooter`
      // instances the phone arm is handed below, so there is no second
      // composition of this screen to keep in step. The rows need no tap
      // suppressed because they have never had one: a task row is a dead end
      // on a phone, which is the whole reason this screen is wired here.
      //
      // What the pane adds is the record and **the two verbs, lifted**. They
      // keep `closeTaskWithPhoto` and `verifyTaskClosure` — the row's own
      // functions — and take `-pane` keys and this screen's own busy flag,
      // because the row's is private to an element nobody pressed.
      //
      // There is no `SectionRule` to put in `lead`: this screen dropped its
      // own when the counts landed, and the selected chip in `filters` is what
      // names and counts the slice. See the comment on the rail below.
      //
      // **What the desk loses, stated.** On `filtered-empty` the pane is
      // non-null so the rail stays reachable, but `children` is not drawn —
      // so `_FilteredEmpty`'s sentence and its `Show all tasks` button are
      // absent at desk width. The way out is the rail itself, one block above
      // the gap where the rows would be, and every chip on it carries the
      // account's own count, so the slice that has rows is readable without
      // the sentence. It is a real loss and `ConsoleDeskRecords` has no slot
      // for a filtered-to-nothing state to go in; the detail pane says
      // "Nothing to read yet." and that is the only words on the screen.
      desk: ConsoleDeskRecords(
        // ── NO MARKER HERE, SO THE RAIL IS THE TOOLBAR ──────────
        //
        // This pane deliberately has no section marker: the reason is
        // written above and it still holds — the selected chip names
        // and counts the slice better than a marker would. That makes
        // the rail the row where this list's own controls already are,
        // so the refresh lands on its trailing end rather than in the
        // pane's top-right corner. See `ConsoleDeskToolbar.filters`.
        toolbar: ConsoleDeskToolbar.filters,
        lead: <Widget>[lead, const SizedBox(height: TiqSpace.s4)],
        filters: filters,
        footer: footer == null
            ? null
            : PaginationFooter(
                key: const ValueKey<String>('tasks-footer-desk'),
                summary: footer.summary,
                narrowLine: footer.scope,
              ),
        records: <ConsoleDeskRecord>[
          for (var i = 0; i < visible.length; i++)
            ConsoleDeskRecord(
              id: visible[i].id,
              row: (context, selected) => _TaskRowTile(
                key: ValueKey<String>('task-row-${visible[i].id}'),
                task: visible[i],
                last: i == visible.length - 1,
                onChanged: _refresh,
              ),
              detail: (context) => _TaskDetail(
                task: visible[i],
                busy: _paneBusy == visible[i].id,
                onClose: () => _closeInPane(visible[i]),
                onVerify: () => _verifyInPane(visible[i]),
              ),
            ),
        ],
      ),
      children: <Widget>[
        // THE LEAD BLOCK. Overdue is the dominant figure because the SLA is
        // the axis that costs something; open and awaiting-verification are
        // its subordinates, not its peers.
        lead,
        const SizedBox(height: TiqSpace.s4),

        // THE RAIL IS THE SECTION MARKER on this screen, and that is why there
        // is no `SectionRule` under it any more.
        //
        // The marker printed the filter's name and the number of rows on the
        // page — `OPEN · 50` — directly beneath a chip printing the same word
        // and the account's own figure. Two numbers in one column under one
        // word is the failure §9f of the design document names by example on
        // the Execution overview, and with the counts landing it became a
        // contradiction rather than a duplication: `OPEN · 50` under
        // `Open 1 190`. The selected chip names the section and counts it, in
        // one object, and the footer says how much of it is on screen.
        // THE SAME RAIL THE LIST PANE HOLDS, and the same instance: the pane
        // supplies its own gutter, so there it is handed over un-bled.
        TorchBleed(child: filters),
        const SizedBox(height: TiqSpace.s4),

        if (visible.isEmpty)
          _FilteredEmpty(
            filter: _filter,
            view: view,
            onShowAll: () => setState(() => _filter = TaskFilter.all),
          )
        else
          TorchBleed(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < visible.length; i++)
                  _TaskRowTile(
                    key: ValueKey<String>('task-row-${visible[i].id}'),
                    task: visible[i],
                    last: i == visible.length - 1,
                    onChanged: _refresh,
                  ),
              ],
            ),
          ),

        // Only where the list was cut. There is no offer to narrow: the rail
        // above IS the narrowing, and it has already been applied by the
        // server — this sentence exists to say that the rows are a page of
        // that slice, not that the figures are.
        if (footer != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s5),
          TorchBleed(
            child: PaginationFooter(
              key: const ValueKey<String>('tasks-footer'),
              summary: footer.summary,
              narrowLine: footer.scope,
            ),
          ),
        ],
      ],
    );
  }
}

/// THE HEAD OF THE PAGE: one figure that costs something, and two that
/// explain it.
///
/// Four things in one card, which is what §9f of the design document settled
/// for a lead card after the Execution overview's crimson rectangle came out:
/// the label with its mark, the figure, one supporting line, and the
/// subordinate figures under a rule.
///
/// ## Three channels, and none of them is a box
///
/// The standing is carried by the **silhouette** beside the eyebrow (a filled
/// triangle for overdue work, a filled circle for none, a barred square for a
/// count nobody could make), by the **word** in the eyebrow and the supporting
/// line, and by the **ink** on the figure — `bad` or `good` in the word grade,
/// from [severityInk], which is the one function in the product that decides
/// when a figure may carry a judgement.
///
/// It draws no outline. `StatTile(lead: true, severity: …)` is the one
/// configuration in the kit that does, at `radii.chip` — a radius-6 crimson
/// rectangle around the loudest object on a screen where everything else is
/// radius 22 — and §9f took it off the overview for exactly that reason.
///
/// ## The subordinates are figures, not a caption
///
/// They were a `meta` sentence — `12 open · 4 awaiting verification` — under
/// the figure, which is a run-on line a reader has to parse rather than two
/// numbers they can read. They are stacked figures now: the label left and the
/// figure right, so the two align on one right edge the way an instrument
/// panel does. Stacked rather than side by side because "AWAITING
/// VERIFICATION" in half a card at 2.0× is an ellipsis, and a label the reader
/// cannot finish is not a label.
///
/// **Owner override, 29 September 2026 — the rules are gone.** They were
/// [StatCluster.rule]s, a 1px line centred in each 12dp gap, and three of them
/// inside one card turned it into a table: *"let's remove this lined,
/// rectangular style"*. Separation is the gap alone now. The alignment the
/// rules were there to advertise does not need them — two figures on one right
/// edge already read as a pair, and the approved mockup separates its own stat
/// block with space rather than lines.
class _LeadBlock extends StatelessWidget {
  const _LeadBlock({required this.view});

  final TasksView view;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final overdue = view.overdue;

    // THE ONE REMAINING UNKNOWN, and it is no longer this screen's normal
    // state. The server counts the whole set, so a zero here is a measured
    // nought. Where it does NOT — an older or stubbed server that answers no
    // `counts` — a zero over a cut page still says nothing about the rest of
    // the list, and the em dash and the barred square still say so. Removing
    // that with the defect it described would have been replacing an honest
    // unknown with a confident wrong number.
    final unknown = !view.countsAreMeasured && overdue == 0;
    final state = unknown ? FigureState.missing : FigureState.measured;
    final mark = unknown
        ? SeverityMarkKind.notMeasured
        : overdue > 0
        ? SeverityMarkKind.critical
        : SeverityMarkKind.onTarget;
    final loaded = TiqNumber.of(context).format(view.rows.length);
    final supporting = unknown
        ? 'None among the $loaded tasks loaded. The rest of the list was not '
              'fetched.'
        : overdue > 0
        ? !view.countsAreMeasured
              ? 'At least this many: counted over the $loaded tasks loaded.'
              : 'Past the deadline and still open.'
        : 'Nothing is past its deadline.';

    return TorchCard(
      key: const ValueKey<String>('tasks-lead'),
      child: Semantics(
        container: true,
        label: 'Overdue',
        value: unknown ? supporting : '$overdue',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // 1. THE LABEL, with the silhouette on its own line rather than in
            //    a column of its own beside the figure. The mark used to sit
            //    in a 12dp gutter to the left of the whole tile, which made it
            //    a free-floating box next to a number instead of a mark on a
            //    word.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SeverityMark(kind: mark),
                const SizedBox(width: 6),
                const Flexible(child: Eyebrow('Overdue')),
              ],
            ),
            const SizedBox(height: TiqSpace.s2),

            // 2. THE FIGURE. `hero.figure.compact` first, measured: on a
            //    390dp phone a four-digit count fits it and gets the presence
            //    the head of a page needs, and a six-digit one steps down to
            //    `figure.l` by measurement rather than by a guess about how
            //    big the account is.
            FigureSlot(
              key: const ValueKey<String>('tasks-overdue-figure'),
              value: unknown ? null : overdue,
              role: skin.text.heroFigureCompact,
              fit: <TiqTypeToken>[
                skin.text.heroFigureCompact,
                skin.text.figureL,
                skin.text.figureM,
              ],
              state: state,
              color: severityInk(skin, mark, state: state),
              semanticsLabel: unknown ? supporting : null,
            ),
            const SizedBox(height: TiqSpace.s2),

            // 3. THE SUPPORTING LINE. Mandatory when the figure is absent —
            //    an em dash on its own is a puzzle — and worth having when it
            //    is not, because "1 122" does not say what was counted.
            Text(supporting, style: skin.text.meta.style(color: skin.palette.ink3)),
            const SizedBox(height: StatCluster.gap),

            // 4. THE SUBORDINATES.
            _Subordinate(
              key: const ValueKey<String>('tasks-subordinate-open'),
              label: 'Open',
              value: view.open,
              measured: view.countsAreMeasured,
              scopeNote: 'among the $loaded tasks loaded',
            ),
            const SizedBox(height: StatCluster.gap),
            _Subordinate(
              key: const ValueKey<String>('tasks-subordinate-awaiting'),
              label: 'Awaiting verification',
              value: view.awaitingVerification,
              measured: view.countsAreMeasured,
              scopeNote: 'among the $loaded tasks loaded',
            ),
          ],
        ),
      ),
    );
  }
}

/// One subordinate figure: the label left, the figure right, on one row.
///
/// The label is `Expanded` and the figure is a bounded box, which is the
/// [StatTile] horizontal layout's own arrangement and the reason a column of
/// these aligns on one right edge.
///
/// A subordinate never carries a severity ink. It is context for the figure
/// above it, and a second coloured number in the same card would make the
/// reader hunt for which one the card is about.
class _Subordinate extends StatelessWidget {
  const _Subordinate({
    super.key,
    required this.label,
    required this.value,
    required this.measured,
    required this.scopeNote,
  });

  final String label;
  final int value;

  /// False where the figure is the page's own count rather than the account's.
  /// The figure still renders — it is a real number, just of a smaller thing —
  /// and the scope is said in words beside it rather than being implied.
  final bool measured;

  final String scopeNote;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Eyebrow(label),
              if (!measured)
                Text(
                  scopeNote,
                  style: skin.text.meta.style(color: skin.palette.ink3),
                ),
            ],
          ),
        ),
        const SizedBox(width: TiqSpace.s3),
        FigureSlot(value: value, role: skin.text.figureM, textAlign: TextAlign.end),
      ],
    );
  }
}

/// A filter with nothing in it — which, now that the counts are real, is a
/// fact about the account rather than about the page.
///
/// Three things separate this from the plain "No data" it replaces:
///
/// * the headline says which absence it is, per filter;
/// * the body says what **is** there, using the counted figures — "1 190 tasks
///   are open and inside their deadline" is the sentence a manager wanted when
///   they pressed Overdue and got nothing, and "Clear the filter to see the
///   rest" was not;
/// * the way back is a [TorchTertiaryButton] rather than a full-width outlined
///   block. It is the treatment The Floor uses for exactly this control — the
///   one-tap way out of a scope that found nothing — and a full-width
///   secondary button was the loudest object on an empty screen.
class _FilteredEmpty extends StatelessWidget {
  const _FilteredEmpty({
    required this.filter,
    required this.view,
    required this.onShowAll,
  });

  final TaskFilter filter;
  final TasksView view;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final numbers = TiqNumber.of(context);
    String n(int value) => numbers.format(value);

    final headline = switch (filter) {
      TaskFilter.open => 'Nothing is outstanding.',
      TaskFilter.overdue => 'Nothing is overdue.',
      TaskFilter.done => 'Nothing has been closed yet.',
      TaskFilter.all => 'Nothing to show.',
    };

    // What is there instead, in the account's own figures. Only where they are
    // measured: a page-derived "0 open" beside an empty list would be the
    // screen agreeing with itself about a number it never checked.
    final body = !view.countsAreMeasured
        ? 'Nothing on this page matches. The rest of the list was not fetched.'
        : switch (filter) {
            TaskFilter.overdue when view.open > 0 =>
              '${n(view.open)} tasks are open and inside their deadline.',
            TaskFilter.overdue =>
              'Every task in the account is closed.',
            TaskFilter.open when view.closed > 0 =>
              'All ${n(view.closed)} tasks in the account are closed.',
            TaskFilter.open => 'Nothing is open.',
            TaskFilter.done =>
              '${n(view.open)} tasks are still open. A task closes with a '
                  'photograph of the fix.',
            TaskFilter.all => 'There is nothing filed under this account.',
          };

    return EmptyState(
      key: const ValueKey<String>('tasks-filtered-empty'),
      scope: EmptyScope.inPanel,
      headline: headline,
      body: body,
      // Only where there is somewhere to go back to. On `All` this button
      // would re-select the filter that is already selected.
      action: filter == TaskFilter.all
          ? null
          : TorchTertiaryButton(
              key: const ValueKey<String>('clear-filters'),
              label: 'Show all tasks',
              onPressed: onShowAll,
            ),
    );
  }
}

/// THE RAIL, carrying the account's own figures.
///
/// Every chip is a real count of the whole set, which is what makes the rail
/// worth reading: it used to print `Open 0 · Overdue 0 · Done 50 · All 50`
/// over an account of 32,368 tasks, which is four numbers about a page nobody
/// asked about.
///
/// Selected is `lifted` + a 1px ink-1 border + a tick + weight 700, and it is
/// **never amber** (unify §1.6) — four channels, three of which survive
/// greyscale. The chip is the chip material at `radii.chip`; a rail of
/// radius-22 pills would be the card grammar applied to a control, which §9c
/// scopes out by name.
class _Filters extends StatelessWidget {
  const _Filters({
    required this.filter,
    required this.view,
    required this.onChanged,
  });

  final TaskFilter filter;
  final TasksView view;
  final ValueChanged<TaskFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return TorchFilterRail(
      semanticsLabel: 'Filters',
      chips: <Widget>[
        for (final f in TaskFilter.values)
          TorchFilterChip(
            key: ValueKey<String>('filter-${f.name}'),
            label: f.label,
            count: view.countFor(f),
            selected: filter == f,
            onSelected: () => onChanged(f),
          ),
      ],
    );
  }
}

/// The SLA's silhouette, from the SLA's own state.
///
/// Read by the row, which draws it beside the reason line, and by the detail
/// pane, which draws it beside the severity word in its kicker. Null on a task
/// that is open and inside its deadline: a mark there would be a silhouette
/// for "nothing in particular".
SeverityMarkKind? taskMarkKind(TaskSlaState state) => switch (state) {
  TaskSlaState.overdue => SeverityMarkKind.critical,
  TaskSlaState.dueSoon => SeverityMarkKind.watch,
  TaskSlaState.closed || TaskSlaState.verified => SeverityMarkKind.onTarget,
  TaskSlaState.open => null,
};

/// One task, as a row.
///
/// The SLA is a phrase in the reason line, behind its own mark — "Overdue by
/// 2 days · replace the shelf talker" — rather than a pill. A pill is a badge
/// somebody decodes; a sentence is read.
class _TaskRowTile extends ConsumerStatefulWidget {
  const _TaskRowTile({
    super.key,
    required this.task,
    required this.last,
    required this.onChanged,
  });

  final TaskRow task;
  final bool last;
  final VoidCallback onChanged;

  @override
  ConsumerState<_TaskRowTile> createState() => _TaskRowTileState();
}

class _TaskRowTileState extends ConsumerState<_TaskRowTile> {
  /// True from the tap until the closure or the verification resolves. One
  /// tap, one receipt, one outcome.
  bool _busy = false;

  /// The row's own copy of the busy flag. `setState` only where the element is
  /// still mounted, which is the guard the two verbs used to carry inline.
  void _setBusy(bool value) {
    if (mounted) setState(() => _busy = value);
  }

  Future<void> _close() async {
    if (_busy) return;
    await closeTaskWithPhoto(
      context,
      ref,
      task: widget.task,
      setBusy: _setBusy,
      onChanged: widget.onChanged,
      retry: _close,
    );
  }

  Future<void> _verify() async {
    if (_busy) return;
    await verifyTaskClosure(
      context,
      ref,
      task: widget.task,
      setBusy: _setBusy,
      onChanged: widget.onChanged,
      retry: _verify,
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final task = widget.task;
    final markKind = taskMarkKind(task.slaState);
    // ONE CRIMSON FOR BOTH COMMITMENT LEVELS, in the word grade. Overdue read
    // `badSolid`, which is a FILL: it is 4.09:1 on Night's `surface`, and this
    // is a phrase on a card. The level is carried by the mark beside it —
    // `markKind` above is a filled triangle against an outlined one — which is
    // where a commitment level belongs.
    final phraseInk = switch (task.slaState) {
      TaskSlaState.overdue || TaskSlaState.dueSoon => skin.palette.bad,
      _ => skin.palette.ink2,
    };

    final verbs = <Widget>[
      // Closure uploads the photo against the visit, so a task with no visit
      // gets no closure action at all — not a disabled one that would fail
      // afterwards.
      if (!task.isClosed && task.visitId != null)
        TorchTertiaryButton(
          key: ValueKey<String>('close-${task.id}'),
          label: 'Close with photo',
          busy: _busy,
          onPressed: _close,
        ),
      if (task.slaState == TaskSlaState.closed)
        TorchTertiaryButton(
          key: ValueKey<String>('verify-${task.id}'),
          label: 'Verify',
          busy: _busy,
          onPressed: _verify,
        ),
    ];

    // THE STORE IS THE FIRST LINE — 26 September 2026.
    //
    // It was the finding type: three tasks in a row all titled "Stockout",
    // with the store that has the problem demoted to the second line. A
    // manager works a worklist by store — that is what The Floor's decision
    // row does, outlet over reason, and it is what makes a column of rows
    // scannable instead of a column of one repeated word.
    //
    // The finding is not lost. It reads at the end of the meta line, where the
    // SLA phrase and the required fix already are, which is also where it
    // stops competing with the store's name for the eye.
    //
    // Middle-truncated, for the reason every outlet name in the product is:
    // "Shoprite Klipspruit Mall" and "Shoprite Klipfontein Mall" end-truncate
    // to the same string.
    return SoftRow(
      key: ValueKey<String>('task-${task.id}'),
      density: SoftRowDensity.tall,
      title: task.outletName,
      titleTruncation: SoftRowTruncation.middle,
      subtitle: task.title,
      severity: task.severity,
      severityLabel: task.severity == SoftRowSeverity.none
          ? null
          : task.severityLabel,
      // The thumbnail IS the evidence — a task with no photo shows no thumb
      // and no placeholder.
      trailing: task.evidencePhotoId != null && task.visitId != null
          ? TorchEvidenceThumb(
              photoId: task.evidencePhotoId!,
              semanticLabel:
                  'Shelf photograph from ${task.outletName} for ${task.title}',
            )
          : null,
      meta: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // The SLA, in words, behind its own silhouette — never a hue alone.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (markKind != null) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: SeverityMark(kind: markKind),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  '${task.slaPhrase} · ${task.requiredFix}',
                  style: skin.text.meta.style(color: phraseInk),
                ),
              ),
            ],
          ),
          // The priority, as a word on the row. The bar is the SLA — a High
          // and a Normal task both due on Friday carry the same watch bar —
          // so without this line the axis the list is SORTED by is invisible,
          // and the severity word only exists for a screen reader.
          if (!task.isClosed)
            Text(
              task.priorityPhrase,
              key: ValueKey<String>('priority-${task.id}'),
              style: skin.text.meta.style(color: skin.palette.ink2),
            ),
          // Who owns the fix, by name. An owner the roster cannot name is
          // left out rather than printed as an id (#399/#400).
          if (task.owner != null)
            Text(
              'Assigned to ${task.owner}',
              key: ValueKey<String>('owner-${task.id}'),
              style: skin.text.meta.style(color: skin.palette.ink2),
            ),
        ],
      ),
      // The verbs, beneath the reason and outside the row's excluded label:
      // a button in `meta` is painted and announced nowhere, which is a
      // manager on TalkBack who can hear the task and cannot close it.
      actions: verbs.isEmpty
          ? null
          : Wrap(spacing: TiqSpace.s4, children: verbs),
      separator: widget.last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: <String>[
        if (task.severity != SoftRowSeverity.none) task.severityLabel,
        task.slaPhrase,
        if (!task.isClosed) task.priorityPhrase,
        task.title,
        task.requiredFix,
        task.outletName,
        if (task.owner != null) 'Assigned to ${task.owner}',
      ].join('. '),
    );
  }
}

/// ONE TASK, IN THE DETAIL PANE — the record, and the verbs off the row.
///
/// A task row is a dead end on a phone: no `onTap`, no route, and the whole
/// record spread across its title, its subtitle and three lines of `meta`.
/// So the pane is [ConsoleRecordDetail] over exactly those lines — the store
/// in the headline where the row puts it, the finding under it, and the SLA
/// phrase, the required fix, the priority and the owner as the record's
/// fields.
///
/// **The outlet is not repeated as a fact.** It is the title, because it is
/// the row's title; a record whose headline and whose first field are the same
/// string is a field spent on nothing.
///
/// **The evidence is the same thumbnail.** `TorchEvidenceThumb` with the same
/// `photoId` the row hands it — a task with no photo shows no thumb and no
/// placeholder here either.
///
/// ## The verbs, lifted
///
/// `Close with photo` and `Verify` are the row's own
/// [TorchTertiaryButton]s on the row's own functions, keyed `-pane` so a row
/// and a pane showing one task do not collide, and driven by the screen's
/// [_TasksScreenState._paneBusy] rather than the row's private flag. They are
/// offered on exactly the conditions the row offers them on: no visit, no
/// closure — not a disabled control that would fail afterwards.
///
/// **Amber: none.** Both are outline-and-ink forms the ladder never lights,
/// and the one lit object in this feature is still `Close task` on the closure
/// sheet, where the amber beneath it has already gone out.
class _TaskDetail extends StatelessWidget {
  const _TaskDetail({
    required this.task,
    required this.busy,
    required this.onClose,
    required this.onVerify,
  });

  final TaskRow task;

  /// True from the tap in this pane until the closure or the verification
  /// resolves.
  final bool busy;

  final VoidCallback onClose;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final mark = taskMarkKind(task.slaState);

    return ConsoleRecordDetail(
      key: ValueKey<String>('task-detail-${task.id}'),
      title: task.outletName,
      // The row's two surviving channels: the silhouette and the word. Never
      // the hue alone, and never the hue at all on an open task inside its
      // deadline, which has no silhouette to wear.
      kicker: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (mark != null) ...<Widget>[
            SeverityMark(kind: mark),
            const SizedBox(width: TiqSpace.s2),
          ],
          Flexible(child: Eyebrow(task.severityLabel)),
        ],
      ),
      lede: task.title,
      facts: <RecordFact>[
        RecordFact('Deadline', task.slaPhrase),
        RecordFact('Required fix', task.requiredFix),
        // The axis the list is SORTED by. The bar is the SLA — a High and a
        // Normal task both due on Friday carry the same bar — so without this
        // the sort order is invisible here as well as on the row.
        if (!task.isClosed) RecordFact('Priority', task.priorityPhrase),
        // An owner the roster cannot name is left out rather than printed as
        // an id (#399/#400), exactly as the row leaves them out.
        if (task.owner != null) RecordFact('Assigned to', task.owner!),
      ],
      blocks: <Widget>[
        if (task.evidencePhotoId != null && task.visitId != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TorchEvidenceThumb(
              photoId: task.evidencePhotoId!,
              semanticLabel:
                  'Shelf photograph from ${task.outletName} for ${task.title}',
            ),
          ),
      ],
      actions: <Widget>[
        if (!task.isClosed && task.visitId != null)
          TorchTertiaryButton(
            key: ValueKey<String>('close-${task.id}-pane'),
            label: 'Close with photo',
            busy: busy,
            onPressed: onClose,
          ),
        if (task.slaState == TaskSlaState.closed)
          TorchTertiaryButton(
            key: ValueKey<String>('verify-${task.id}-pane'),
            label: 'Verify',
            busy: busy,
            onPressed: onVerify,
          ),
      ],
    );
  }
}
