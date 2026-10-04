import 'package:flutter/material.dart' show Icons, MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../data/contests_repository.dart';
import 'contest_form_screen.dart';
import 'contest_labels.dart';

/// CONTESTS (#124) — time-boxed competitions over the points ledger.
///
/// ```text
///   Contests                                      [ ⟳ ]
///   Agents are ranked by the points they earn…
///   ── Contests                             3 ────
///   Spring push                            Active
///   3 days left
///   2026-09-01 → 2026-09-30 · All territories · …
///   Edit   Cancel                              ›
///   …
///   [ New contest ]
///   [ nav pill ]
/// ```
///
/// ## The amber, counted
///
/// A tab root: the nav pill's active tab is slot 1 in Night whenever the nav
/// renders, and this route declines the one content grant it has left.
/// Nothing here is armed — creating a contest is a ghost at the foot of the
/// list, not a commit, and the status chips are a `live` dot and an Oatmeal
/// square. Day has one rung, the primary commit block, and this
/// route has no primary: they paint **zero**.
///
/// While a confirm sheet is up every amber beneath it goes out, which
/// [ConsoleFrame] wires through [TorchSheetAware].
///
/// ## Destroying one asks first, and names what it costs
///
/// Cancel and Delete both go through a [ConfirmSheet] — the console's instance
/// of the decision-sheet anatomy — rather than the dialog unify §1.7 deleted.
/// The contest's own id rides in the sheet's `record` slot, in mono, so a
/// manager can check they are cancelling the right one.
class ContestsScreen extends ConsumerWidget {
  const ContestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contests = ref.watch(contestsListProvider);

    return contests.when(
      loading: () => _frame(
        context,
        ref,
        phase: 'loading',
        children: <Widget>[
          Skeleton(
            label: 'contests',
            child: const SkeletonRows(count: 4, rowHeight: 80),
          ),
        ],
      ),
      error: (error, stack) => _frame(
        context,
        ref,
        phase: 'error',
        children: <Widget>[
          TorchErrorRegion(
            name: 'contests',
            child: ErrorState(
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('contests-retry'),
                label: 'Try again',
                onPressed: () => ref.invalidate(contestsListProvider),
              ),
            ),
          ),
        ],
      ),
      data: (page) => _loaded(context, ref, page),
    );
  }

  /// The frame every phase is drawn in — **including the create control.**
  ///
  /// The control lives here and not in `_loaded` on purpose. Creating a
  /// contest is `POST /contests`; it does not depend on whether
  /// `GET /contests` came back. Before the migration this was a
  /// `floatingActionButton` on the scaffold, outside the async section, and it
  /// survived every phase. Building it inside `_loaded` quietly took it away
  /// from the reader who needs it most: a manager whose list 500s and who is
  /// then offered nothing but "Try again".
  ///
  /// The amber is unchanged — a [TorchSecondaryButton] claims nothing.
  Widget _frame(
    BuildContext context,
    WidgetRef ref, {
    required String phase,
    required List<Widget> children,
    ConsoleDeskRecords? desk,
  }) {
    return ConsoleFrame(
      phase: phase,
      // Null on the skeleton, on the error and on an empty list: none of them
      // is a list of records, and with no filter rail on this screen the
      // empty phase has no slice to widen — it keeps the one centred column
      // its own empty state and its create control were written for.
      desk: desk,
      header: TorchAppHeader(
        title: 'Contests',
        facts: const <String>[
          'Agents are ranked by the points they earn between a contest’s '
              'dates, counted in your timezone.',
        ],
        trailing: TorchIconButton(
          key: const ValueKey<String>('contests-refresh'),
          icon: Icons.refresh,
          semanticLabel: 'Refresh the contests list',
          onPressed: () => ref.invalidate(contestsListProvider),
        ),
      ),
      children: <Widget>[
        ...children,
        const SizedBox(height: TiqSpace.s7),
        // A ghost at the foot of the list, not a floating button: a FAB here
        // would collide with the nav circle's position vocabulary, and
        // creating a contest is not the commit this screen is about.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TorchSecondaryButton(
            key: const ValueKey<String>('contest-create'),
            label: 'New contest',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ContestFormScreen(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _loaded(
    BuildContext context,
    WidgetRef ref,
    PaginatedResponse<Contest> page,
  ) {
    final l10n = context.l10n;
    final list = page.data;

    return _frame(
      context,
      ref,
      phase: list.isEmpty ? 'empty' : 'loaded',
      // ── WHAT THE DESK GETS, AND WHAT IT DOES NOT ───────────────────────
      //
      // The contests, as records, drawn by the same `_ContestRow` the phone
      // draws, minus its push to `/contests/:id` — the frame's own gesture
      // takes the tap, because a row that opened the standings route would
      // replace the pane the manager is reading with a full screen.
      //
      // **`ContestStandingsScreen`'s body is NOT reused**, and the reason is
      // the same one `leaderboard_screen.dart` gives: it watches
      // `contestStandingsProvider(contestId)`, so putting it in the pane
      // would make *selecting a row* fire a request, which
      // `ConsoleDeskRecord.detail` forbids in as many words — "selecting a
      // record cannot refetch". Splitting a read-only body out of it would
      // not help, because the fetch is the body. So the pane is built from
      // the contest the list is already holding — which is every fact the
      // standings screen prints above its board — and the board itself is the
      // tertiary at the foot of the pane.
      //
      // The section rule stays in `lead`: there is no filter rail here to
      // name and count the slice, so the marker is the only thing that names
      // the list. The create control is in `footer`, under the records, where
      // the phone puts it.
      desk: list.isEmpty
          ? null
          : ConsoleDeskRecords(
              toolbar: ConsoleDeskToolbar.marker,
              lead: <Widget>[
                SectionRule('Contests', count: list.length, listAction: true),
                const SizedBox(height: TiqSpace.s5),
              ],
              footer: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (page.nextCursor != null) ...<Widget>[
                    PaginationFooter(
                      key: const ValueKey<String>('contests-footer-desk'),
                      summary: l10n.contestsShowing(list.length),
                    ),
                    const SizedBox(height: TiqSpace.s6),
                  ],
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TorchSecondaryButton(
                      key: const ValueKey<String>('contest-create-desk'),
                      label: 'New contest',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ContestFormScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              records: <ConsoleDeskRecord>[
                for (var i = 0; i < list.length; i++)
                  ConsoleDeskRecord(
                    id: list[i].id,
                    row: (context, selected) => _ContestRow(
                      key: ValueKey<String>('contest-row-${list[i].id}'),
                      contest: list[i],
                      last: i == list.length - 1,
                      onDesk: true,
                    ),
                    detail: (context) => _ContestPane(
                      key: ValueKey<String>('contest-pane-${list[i].id}'),
                      contest: list[i],
                    ),
                  ),
              ],
            ),
      children: <Widget>[
        // A section that vanishes when empty makes a manager think the
        // feature is gone, so the rule and its name render whatever the
        // count is.
        SectionRule('Contests', count: list.isEmpty ? null : list.length),
        const SizedBox(height: TiqSpace.s5),

        if (list.isEmpty)
          const EmptyState(
            key: ValueKey<String>('contests-empty'),
            scope: EmptyScope.inPanel,
            headline: 'No contests yet.',
            body: 'Create one to rank agents by the points they earn between '
                'two dates, for a prize.',
          )
        else
          TorchBleed(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < list.length; i++)
                  _ContestRow(
                    key: ValueKey<String>('contest-row-${list[i].id}'),
                    contest: list[i],
                    last: i == list.length - 1,
                  ),
              ],
            ),
          ),
        // WHAT THE LIST IS SHOWING. The count beside the marker was the
        // length of page one, and `listContests` used to read only
        // `response.data['data']` — so the envelope's `nextCursor` never
        // reached Dart and nothing downstream could detect truncation even in
        // principle. Never a total: the server sends a cursor, not a count.
        if (page.nextCursor != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s4),
          PaginationFooter(summary: l10n.contestsShowing(list.length)),
        ],
      ],
    );
  }
}

Future<void> _confirmThen(
  BuildContext context,
  WidgetRef ref, {
  required Contest contest,
  required String action,
  required List<String> consequences,
  required String commitLabel,
  required String failure,
  required Future<void> Function(ContestsRepository repo) run,
}) async {
  final confirmed = await showTorchSheet<bool>(
    context,
    builder: (_) => ConfirmSheet(
      action: action,
      consequences: consequences,
      commitLabel: commitLabel,
      // The record a manager is about to act on, in mono, so they can check
      // it is the right one before a destructive press.
      record: contest.id,
      cancelLabel: 'Keep it',
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await run(ref.read(contestsRepositoryProvider));
    ref.invalidate(contestsListProvider);
  } catch (error) {
    if (!context.mounted) return;
    showTorchToast(
      context,
      message: '$failure ${TorchErrorMessage.sanitise(error).body}',
      kind: ToastKind.failure,
    );
  }
}

/// ── THE VERBS A CONTEST'S STATUS ALLOWS, WRITTEN ONCE ──────────────────
///
/// The row carries these and, at desk width, so does the detail pane beside
/// it. Two copies of this ladder is how a cancelled contest ends up offering
/// Edit in one place and not the other, so the status rules, the confirm
/// sheets and their consequences live here and both callers read them.
///
/// [keySuffix] is empty on the row and `-pane` in the pane: the two are on
/// screen together, and a key is not a label.
List<Widget> _contestVerbs(
  BuildContext context,
  WidgetRef ref,
  Contest c, {
  String keySuffix = '',
}) => <Widget>[
  if (!c.isCancelled)
    TorchTertiaryButton(
      key: ValueKey<String>('contest-edit-${c.id}$keySuffix'),
      label: 'Edit',
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ContestFormScreen(contest: c)),
      ),
    ),
  if (c.isActive || c.isUpcoming)
    TorchTertiaryButton(
      key: ValueKey<String>('contest-cancel-${c.id}$keySuffix'),
      label: 'Cancel',
      onPressed: () => _confirmThen(
        context,
        ref,
        contest: c,
        action: 'Cancel “${c.name}”?',
        consequences: const <String>[
          'Agents stop seeing it straight away.',
          'You keep its standings.',
          'It cannot be edited or restarted.',
        ],
        commitLabel: 'Cancel contest',
        failure: 'The contest was not cancelled.',
        run: (repo) => repo.cancelContest(c.id),
      ),
    ),
  if (c.isUpcoming || c.isCancelled)
    TorchTertiaryButton(
      key: ValueKey<String>('contest-delete-${c.id}$keySuffix'),
      label: 'Delete',
      onPressed: () => _confirmThen(
        context,
        ref,
        contest: c,
        action: 'Delete “${c.name}”?',
        consequences: const <String>['It is removed for good.'],
        commitLabel: 'Delete contest',
        failure: 'The contest was not deleted.',
        run: (repo) => repo.deleteContest(c.id),
      ),
    ),
];

/// One contest, as a row, carrying only the verbs its status allows.
class _ContestRow extends ConsumerWidget {
  const _ContestRow({
    super.key,
    required this.contest,
    required this.last,
    this.onDesk = false,
  });

  final Contest contest;
  final bool last;

  /// True in the desk's list pane, where the row's tap is the **selection**.
  ///
  /// Pushing `/contests/:id` there would cover the list the manager chose
  /// from with the standings screen, beside a pane already naming the same
  /// contest. So the tap goes to the frame — `_Record` in
  /// `console_desk.dart` — and the standings route is the tertiary at the
  /// foot of the pane. Nothing else about the row changes.
  final bool onDesk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = contest;
    final statusWord = contestStatusWord(c.status);
    final when = contestWhenSummary(c);
    final facts =
        '${c.startDate} → ${c.endDate} · ${contestScopeSummary(c)} · '
        '${contestCountsSummary(c)}';

    final verbs = _contestVerbs(context, ref, c);

    return SoftRow(
      key: ValueKey<String>('contest-${c.id}'),
      density: SoftRowDensity.tall,
      title: c.name,
      subtitle: when,
      meta: Text(facts),
      // A status is a label, so it is a word and a silhouette — never a hue
      // on its own, and never a severity: a cancelled contest is a decision
      // somebody made, not a fault.
      trailing: StatusChip(level: contestLevel(c.status), label: statusWord),
      // The verbs live in the row's action slot, not in `meta`: `meta` is
      // inside the row's excluded label, so a button there paints, hit-tests
      // and is announced nowhere.
      actions: verbs.isEmpty ? null : Wrap(spacing: TiqSpace.s4, children: verbs),
      onTap: onDesk ? null : () => context.push('/contests/${c.id}'),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: <String>[
        statusWord,
        c.name,
        when,
        facts,
      ].join('. '),
    );
  }
}

/// ── ONE CONTEST, IN THE DETAIL PANE ────────────────────────────────────
///
/// Everything `ContestStandingsScreen` prints **above** its board, from the
/// contest the list is already holding: the name, the status as the same chip
/// the row wears, where it is in time, its dates, its prize, its territory
/// and what it counts. The four fact labels are the ones that screen already
/// uses for the same four values, so the two cannot drift apart.
///
/// What is not here is the board. See the `desk:` note on `_loaded`: the
/// standings are a second request keyed to the contest id, and a detail pane
/// that fetched on selection is the thing `ConsoleDeskRecord.detail` exists
/// to stop. The board is one click away, named, at the foot.
class _ContestPane extends ConsumerWidget {
  const _ContestPane({super.key, required this.contest});

  final Contest contest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = contest;
    final skin = context.skin;
    final statusWord = contestStatusWord(c.status);

    return ConsoleRecordDetail(
      title: c.name,
      // The row's own trailing widget, lifted: a word and a silhouette, never
      // a hue on its own and never a severity — a cancelled contest is a
      // decision somebody made, not a fault.
      kicker: StatusChip(level: contestLevel(c.status), label: statusWord),
      lede: contestWhenSummary(c),
      facts: <RecordFact>[
        RecordFact('Dates', '${c.startDate} → ${c.endDate} (inclusive)'),
        // Never invented: a contest with no prize says so in words rather
        // than showing a blank a manager would read as "loading".
        RecordFact('Prize', c.prizeDescription ?? 'None set'),
        RecordFact('Territory', contestScopeSummary(c)),
        RecordFact('Counts', contestCountsSummary(c)),
      ],
      blocks: <Widget>[
        if (c.description != null)
          Text(
            c.description!,
            style: skin.text.body.style(color: skin.palette.ink2),
          ),
      ],
      // THE ROW'S VERBS, LIFTED — the same three off the same status rules,
      // through the same confirm sheets. See [_contestVerbs].
      actions: <Widget>[
        TorchTertiaryButton(
          key: ValueKey<String>('contest-standings-${c.id}-pane'),
          label: 'Standings',
          onPressed: () => context.push('/contests/${c.id}'),
        ),
        ..._contestVerbs(context, ref, c, keySuffix: '-pane'),
      ],
    );
  }
}
