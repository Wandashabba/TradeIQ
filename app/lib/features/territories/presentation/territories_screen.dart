import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../data/territories_repository.dart';
import '../data/territories_view.dart';
import 'territory_detail_sheet.dart';

/// TERRITORIES — the ground, divided, and who is walking it.
///
/// ```text
///   Territories                                   [ ☾ ]
///   A territory groups outlets and the agents who work them.
///   ── All territories  14 ──────────────── New territory
///   Gauteng North                                    67%
///   GP-N · Gauteng · 3 outlets · 2 agents
///   Western Cape                                      —
///   WC · 0 outlets · no agents · Unassigned
///   …
///   [ nav pill ]
/// ```
///
/// ## The one amber, counted
///
/// A tab root reached from the Menu, so the nav's active tab is slot 1 and the
/// content has one grant left. **It declines it**, on every phase: nothing on
/// a list of places is armed. `New territory` is the section rule's action
/// slot — a tertiary verb beside the count — rather than a lit circle, because
/// the ladder's rung 4 is for the role's *standing* action and a manager
/// reaches this screen to read it far more often than to add to it.
///
/// On Day and Veld the ladder has one rung, the primary commit block, and this
/// route has none: **zero**.
///
/// ## Coverage is three absences, not one zero
///
/// `GET /territories/:id/coverage` answers per territory, so each row carries
/// its own request and its own state. Three of the four states have no figure
/// and each says something different:
///
/// * **loading** — a skeleton line where the figure goes;
/// * **failed** — an em dash and "Coverage did not load", with no per-row
///   Retry (fifteen rows is fifteen error regions and the kit allows one);
/// * **no outlets** — an em dash and "No outlets to cover yet". The wire sends
///   `coverageRate: 0` here (`outletsTotal > 0 ? … : 0` in the service) and a
///   nought over an empty denominator is a verdict nobody reached.
///
/// Only the fourth prints a percentage, and a **measured 0%** prints `0%` and
/// keeps its place.
class TerritoriesScreen extends ConsumerWidget {
  const TerritoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final territories = ref.watch(territoriesListProvider);
    final role = ref.watch(sessionControllerProvider).value?.role;
    // Creating territories and assigning agents are manager/admin actions.
    final canManage = role == 'manager' || role == 'admin';

    Widget frame({required String phase, required List<Widget> children}) {
      return ConsoleFrame(
        phase: phase,
        active: ConsoleSlot.menu,
        header: TorchAppHeader(
          title: l10n.territoriesTitle,
          facts: <String>[l10n.territoriesFact],
          // The header allows exactly one trailing control, and on a console
          // worklist the one worth having is the refetch — the same choice
          // Alerts made, for the same reason.
          trailing: TorchIconButton(
            key: const ValueKey<String>('territories-refresh'),
            icon: Icons.refresh,
            semanticLabel: l10n.territoriesRefresh,
            onPressed: () => ref.invalidate(territoriesListProvider),
          ),
        ),
        children: children,
      );
    }

    return territories.when(
      loading: () => frame(
        phase: 'loading',
        children: <Widget>[
          Skeleton(
            label: l10n.territoriesTitle,
            slowLine: l10n.torchStillFetching,
            child: const SkeletonRows(count: 4, rowHeight: 80),
          ),
        ],
      ),
      error: (error, stack) => frame(
        phase: 'error',
        children: <Widget>[
          TorchErrorRegion(
            name: 'territories',
            child: ErrorState(
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('territories-retry'),
                label: l10n.torchTryAgain,
                onPressed: () => ref.invalidate(territoriesListProvider),
              ),
            ),
          ),
        ],
      ),
      data: (list) {
        if (list.isEmpty) {
          return frame(
            phase: 'empty',
            children: <Widget>[
              EmptyState(
                drawing: EmptyDrawing.pin,
                headline: l10n.territoriesEmptyHeadline,
                body: l10n.territoriesEmptyBody,
                action: canManage
                    ? TorchSecondaryButton(
                        key: const ValueKey<String>('territory-create'),
                        label: l10n.territoriesNew,
                        onPressed: () => context.push('/territories/new'),
                      )
                    : null,
              ),
            ],
          );
        }

        final gutter = context.skin.space.gutter;
        return frame(
          phase: 'loaded',
          children: <Widget>[
            SectionRule(
              l10n.territoriesSectionAll,
              count: list.length,
              action: canManage
                  ? SectionRuleAction(
                      l10n.territoriesNew,
                      key: const ValueKey<String>('territory-create'),
                      onTap: () => context.push('/territories/new'),
                    )
                  : null,
            ),
            const SizedBox(height: TiqSpace.s5),
            TorchBleed(
              extra: gutter * 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (var i = 0; i < list.length; i++)
                    _TerritoryRowView(
                      key: ValueKey<String>('territory-${list[i].id}'),
                      territory: list[i],
                      canManage: canManage,
                      last: i == list.length - 1,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One territory, as a row.
///
/// The row is the whole target: a thumb aims at the place, not at a 40dp verb
/// beside it. Tapping opens the detail sheet, which is where the coverage
/// breakdown, the map and the assignment live — the old screen put those in an
/// `AlertDialog` and two `RowAction` buttons, and the dialog is deleted.
class _TerritoryRowView extends ConsumerWidget {
  const _TerritoryRowView({
    super.key,
    required this.territory,
    required this.canManage,
    required this.last,
  });

  final Territory territory;
  final bool canManage;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final skin = context.skin;
    final row = TerritoryRow.from(
      territory,
      ref.watch(territoryCoverageProvider(territory.id)),
    );

    final meta = <String>[
      territory.code,
      if (territory.region != null) territory.region!,
    ].join(' · ');

    final counts = switch (row.state) {
      TerritoryCoverageState.loading => l10n.territoryCoverageLoading,
      TerritoryCoverageState.failed => l10n.territoryCoverageFailed,
      _ => <String>[
        l10n.territoryOutlets(row.coverage!.outletCount),
        l10n.territoryAgents(row.coverage!.agentCount),
      ].join(' · '),
    };

    return SoftRow(
      density: SoftRowDensity.tall,
      title: territory.name,
      titleTruncation: SoftRowTruncation.middle,
      subtitle: counts,
      meta: Text(
        meta,
        style: skin.text.monoIdent.style(color: skin.palette.ink3),
      ),
      trailing: _CoverageFigure(row: row),
      onTap: () => showTerritoryDetailSheet(
        context,
        territory: territory,
        canManage: canManage,
      ),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: <String>[
        territory.name,
        meta,
        counts,
        _coverageSentence(context, row),
        if (row.unassigned ?? false) l10n.territoryUnassigned,
      ].join('. '),
    );
  }
}

String _coverageSentence(BuildContext context, TerritoryRow row) {
  final l10n = context.l10n;
  return switch (row.state) {
    TerritoryCoverageState.loading => l10n.territoryCoverageLoading,
    TerritoryCoverageState.failed => l10n.territoryCoverageFailed,
    TerritoryCoverageState.noOutlets => l10n.territoryCoverageNoOutlets,
    TerritoryCoverageState.measured => l10n.territoryCoveredPercent(
      row.coverageRate!.round(),
    ),
  };
}

/// The figure at the trailing edge, in whichever of its four states it is in.
class _CoverageFigure extends StatelessWidget {
  const _CoverageFigure({required this.row});

  final TerritoryRow row;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;

    if (row.state == TerritoryCoverageState.loading) {
      // A skeleton line the width of "100%" — never a nought standing in for
      // a figure that has not arrived.
      return SizedBox(
        width: 48,
        child: SkeletonLine(role: skin.text.figureS, widthFactor: 1),
      );
    }

    final measured = row.state == TerritoryCoverageState.measured;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FigureSlot(
          value: measured ? row.coverageRate!.round() : null,
          role: skin.text.figureS,
          // "— %" is a unit measuring nothing.
          unit: measured ? TiqUnit.percent : TiqUnit.none,
          state: measured ? FigureState.measured : FigureState.missing,
          textAlign: TextAlign.end,
          semanticsLabel: measured ? null : _coverageSentence(context, row),
        ),
        Text(
          measured
              ? l10n.territoryCoveredWord
              : row.state == TerritoryCoverageState.failed
              ? l10n.territoryCoverageFailed
              : l10n.territoryCoverageNoOutlets,
          textAlign: TextAlign.end,
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
      ],
    );
  }
}
