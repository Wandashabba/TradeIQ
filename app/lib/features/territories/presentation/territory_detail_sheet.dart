import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../../users/data/users_repository.dart';
import '../data/territories_repository.dart';
import '../data/territories_view.dart';

/// THE TERRITORY, OPENED — coverage, the roster, and the two things a manager
/// can do about either.
///
/// It replaces an `AlertDialog` and two `RowAction` buttons. The dialog is
/// deleted outright (unify §1.7): one modal container covers every blocking
/// case, and the two verbs that used to live on the row live here, where the
/// evidence for pressing them is on the same surface.
///
/// ## The panes, and why there are two rather than two sheets
///
/// `Assign an agent` cross-fades **this sheet's own content** through
/// [TorchSheetSwap]. Sheets do not stack: two scrims is two dimmings of one
/// screen and the back gesture stops meaning anything. The evidence pane is
/// what a manager reads; the roster pane is what they act on; the title
/// changes with them so nobody loses their place.
///
/// ## The amber
///
/// A sheet is an untabbed route and the nav's tab beneath it has already gone
/// out, so both of Night's grants belong to the sheet. The **evidence pane
/// spends none** — coverage is a reading, not an action. The **roster pane
/// spends one**: `Assign` at rung 1. Day spends its single grant on the same
/// block, and nothing else on either pane asks.
Future<void> showTerritoryDetailSheet(
  BuildContext context, {
  required Territory territory,
  required bool canManage,
  bool assigning = false,
}) {
  return showTorchSheet<void>(
    context,
    builder: (_) => _TerritoryDetailSheet(
      territory: territory,
      canManage: canManage,
      assigning: assigning,
    ),
  );
}

class _TerritoryDetailSheet extends ConsumerStatefulWidget {
  const _TerritoryDetailSheet({
    required this.territory,
    required this.canManage,
    this.assigning = false,
  });

  final Territory territory;
  final bool canManage;

  /// Opens straight on the roster rather than on the evidence.
  ///
  /// False for every tap on a phone row — the evidence is what a manager came
  /// for and the roster is the second pane they ask for. True from the
  /// **detail pane**, where the evidence is already on screen beside the list
  /// and the only thing this sheet is still needed for is the pick: a sheet
  /// that opened on a copy of the pane behind it would make the manager press
  /// `Assign an agent` twice.
  final bool assigning;

  @override
  ConsumerState<_TerritoryDetailSheet> createState() =>
      _TerritoryDetailSheetState();
}

class _TerritoryDetailSheetState extends ConsumerState<_TerritoryDetailSheet> {
  static const String assignClaimId = 'assign-agent';

  late bool _assigning = widget.assigning;
  String? _picked;
  bool _submitting = false;

  Future<void> _assign() async {
    final agentId = _picked;
    if (agentId == null || _submitting) return;
    setState(() => _submitting = true);
    final l10n = context.l10n;
    try {
      await ref
          .read(territoriesRepositoryProvider)
          .assignAgent(widget.territory.id, agentId);
      if (!mounted) return;
      // The row's coverage figure counted agents, so it is now stale.
      ref.invalidate(territoryCoverageProvider(widget.territory.id));
      Navigator.of(context).pop();
      showTorchToast(
        context,
        message: l10n.territoryAssignDone(widget.territory.name),
        kind: ToastKind.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      // The assignment did NOT happen, and the pane stays open with the pick
      // intact so the retry is one press rather than four.
      showTorchToast(
        context,
        message: l10n.territoryAssignFailed,
        kind: ToastKind.failure,
        action: TorchTertiaryButton(
          label: l10n.torchTryAgain,
          onPressed: _assign,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TorchSheet(
      title: _assigning
          ? l10n.territoryAssignTitle(widget.territory.name)
          : widget.territory.name,
      subtitle: _assigning
          ? l10n.territoryAssignSubtitle
          : widget.territory.code,
      claims: _assigning
          ? const <TorchClaim>[TorchClaim.primaryCommit(assignClaimId)]
          : const <TorchClaim>[],
      child: TorchSheetSwap(
        paneKey: _assigning ? 'roster' : 'evidence',
        child: _assigning
            ? _roster(context)
            : TerritoryDetailBody(
                territory: widget.territory,
                canManage: widget.canManage,
                onAssign: () => setState(() => _assigning = true),
              ),
      ),
    );
  }

  // ── The roster pane ─────────────────────────────────────────────────

  Widget _roster(BuildContext context) {
    final l10n = context.l10n;
    final users = ref.watch(usersListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        users.when(
          loading: () => Skeleton(
            label: l10n.territoryAssignSubtitle,
            slowLine: l10n.torchStillFetching,
            child: const SkeletonRows(count: 3, rowHeight: 80),
          ),
          error: (error, _) => TorchErrorRegion(
            name: 'roster',
            child: ErrorState(
              scope: ErrorScope.inline,
              message: TorchErrorMessage.sanitise(error),
              action: TorchTertiaryButton(
                label: l10n.torchTryAgain,
                onPressed: () => ref.invalidate(usersListProvider),
              ),
            ),
          ),
          data: (list) {
            final agents = list
                .where((u) => u.role == 'field_agent')
                .toList(growable: false);
            if (agents.isEmpty) {
              return EmptyState(
                scope: EmptyScope.inPanel,
                headline: l10n.territoryNoAgentsHeadline,
                body: l10n.territoryNoAgentsBody,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SectionRule(l10n.territoryFieldAgents, count: agents.length),
                const SizedBox(height: TiqSpace.s3),
                for (var i = 0; i < agents.length; i++)
                  PersonRow(
                    key: ValueKey<String>('assign-agent-${agents[i].id}'),
                    // The NAME, never the id. An account with no name falls
                    // back to the address people actually mail, which is still
                    // not a database key.
                    name: agents[i].displayName?.trim().isNotEmpty ?? false
                        ? agents[i].displayName
                        : agents[i].email,
                    role: l10n.roleFieldAgent,
                    deactivated: !agents[i].active,
                    trailingWord: !agents[i].active
                        ? l10n.territoryAgentInactive
                        : _picked == agents[i].id
                        ? l10n.territoryAgentPicked
                        : null,
                    onTap: agents[i].active
                        ? () => setState(() => _picked = agents[i].id)
                        : null,
                    separator: i == agents.length - 1
                        ? SoftRowSeparator.none
                        : SoftRowSeparator.auto,
                  ),
              ],
            );
          },
        ),

        const SizedBox(height: TiqSpace.s6),
        TorchPrimaryButton(
          key: const ValueKey<String>('assign-agent-confirm'),
          claimId: assignClaimId,
          label: l10n.territoryAssign,
          busy: _submitting,
          blockedReason: _picked == null ? l10n.territoryAssignBlocked : null,
          onPressed: _picked == null ? null : _assign,
        ),
        const SizedBox(height: TiqSpace.s3),
        // Back takes the bottom: the bottom-most control under a travelling
        // thumb is never the one that commits.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TorchTertiaryButton(
            key: const ValueKey<String>('assign-agent-back'),
            label: l10n.territoryAssignBack,
            onPressed: () => setState(() {
              _assigning = false;
              _picked = null;
            }),
          ),
        ),
      ],
    );
  }
}

/// ── THE EVIDENCE, AT TWO ADDRESSES ─────────────────────────────────────
///
/// This was `_TerritoryDetailSheetState._evidence` and it is the same tree,
/// lifted out so the **detail pane** can draw it without a scrim over the list
/// the manager chose from. The sheet still shows it on a phone, as its first
/// pane, and nothing about it moved: the region line, the coverage cluster in
/// whichever of its four states it is in, and the two verbs.
///
/// It is a [ConsumerWidget] rather than a method because the pane has no sheet
/// state to hang off, and the coverage request it watches is
/// `territoryCoverageProvider` — the one the row beside it is already
/// watching, so selecting a territory on the desk asks the server nothing it
/// has not already asked.
///
/// **Amber: none.** Coverage is a reading. `Assign` is a tertiary here and
/// only becomes a commit on the roster pane, where there is something to
/// commit.
class TerritoryDetailBody extends ConsumerWidget {
  const TerritoryDetailBody({
    super.key,
    required this.territory,
    required this.canManage,
    required this.onAssign,
  });

  final Territory territory;
  final bool canManage;

  /// What `Assign an agent` does. In the sheet it swaps to the roster pane; in
  /// the detail pane it opens the sheet already on that roster. Null draws no
  /// assign verb at all — a control with nowhere to go is dishonest chrome.
  final VoidCallback? onAssign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(territoryCoverageProvider(territory.id));
    final row = TerritoryRow.from(territory, async);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (territory.region != null)
          Text(
            territory.region!,
            style: context.skin.text.body.style(
              color: context.skin.palette.ink2,
            ),
          ),
        const SizedBox(height: TiqSpace.s5),

        switch (row.state) {
          TerritoryCoverageState.loading => Skeleton(
            label: l10n.territoryCoverageLoading,
            slowLine: l10n.torchStillFetching,
            child: const SkeletonRows(count: 2, rowHeight: 64),
          ),
          TerritoryCoverageState.failed => TorchErrorRegion(
            name: 'territory coverage',
            child: ErrorState(
              scope: ErrorScope.inline,
              message: TorchErrorMessage.sanitise(
                async is AsyncError ? (async as AsyncError).error : null,
              ),
              action: TorchTertiaryButton(
                key: const ValueKey<String>('coverage-retry'),
                label: l10n.torchTryAgain,
                onPressed: () =>
                    ref.invalidate(territoryCoverageProvider(territory.id)),
              ),
            ),
          ),
          _ => _CoverageCluster(row: row),
        },

        const SizedBox(height: TiqSpace.s6),
        // The verbs. `Assign` is a tertiary here and becomes the pane's
        // primary once the roster is up — a verb is only a commit when there
        // is something committed.
        Wrap(
          spacing: TiqSpace.s5,
          runSpacing: TiqSpace.s3,
          children: <Widget>[
            TorchTertiaryButton(
              key: ValueKey<String>('territory-map-${territory.id}'),
              label: l10n.territoryOpenMap,
              onPressed: () {
                // POP ONLY IF THERE IS A MODAL TO POP. In the sheet this
                // closes the scrim before navigating, which is the sheet's own
                // rule; in the **detail pane** there is no modal above the
                // route, and an unconditional pop would take the console
                // screen with it — the manager would arrive at the map having
                // also lost the list behind it. `alert_detail_sheet.dart` asks
                // the same question for the same reason.
                final navigator = Navigator.of(context);
                if (navigator.canPop()) navigator.pop();
                context.push('/territories/${territory.id}/map');
              },
            ),
            if (canManage && onAssign != null)
              TorchTertiaryButton(
                key: ValueKey<String>('territory-assign-${territory.id}'),
                label: l10n.territoryAssign,
                onPressed: onAssign,
              ),
          ],
        ),
      ],
    );
  }
}

/// Coverage, as figures rather than as a sentence with numbers in it.
class _CoverageCluster extends StatelessWidget {
  const _CoverageCluster({required this.row});

  final TerritoryRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final coverage = row.coverage!;
    final measured = row.state == TerritoryCoverageState.measured;
    final visited = coverage.outletsVisited;
    final total = coverage.outletsTotal;

    return StatCluster(
      semanticsLabel: l10n.territoryCoverageCluster,
      tiles: <StatTile>[
        StatTile(
          eyebrow: l10n.territoryCoveredWord,
          value: measured ? row.coverageRate : null,
          unit: measured ? TiqUnit.percent : TiqUnit.none,
          decimals: 0,
          noDataReason: measured ? null : l10n.territoryCoverageNoOutlets,
          meter: measured
              ? MeterData(value: row.coverageRate, maximum: 100)
              : null,
          // A measured zero keeps its place and its meter draws nothing —
          // the figure carries it.
          stateLine: measured && visited != null && total != null
              ? l10n.territoryVisitedOf(visited, total)
              : null,
        ),
        StatTile(
          eyebrow: l10n.territoryOutletsWord,
          // outletCount is the length of a list the server sent, so it is
          // measured whenever the block arrived at all — including at zero.
          value: coverage.outletCount,
          unit: TiqUnit.none,
        ),
        StatTile(
          eyebrow: l10n.territoryAgentsWord,
          value: coverage.agentCount,
          unit: TiqUnit.none,
          // An unassigned territory is the one state worth flagging, and the
          // flag is a word and a silhouette, never a colour on its own.
          severity: coverage.agentCount == 0 ? SeverityMarkKind.watch : null,
          stateLine: coverage.agentCount == 0
              ? l10n.territoryUnassignedLine
              : null,
        ),
      ],
    );
  }
}
