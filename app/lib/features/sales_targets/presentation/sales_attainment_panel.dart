import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/network/human_error.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../data/sales_targets_repository.dart';

/// "September 2026", in the reader's own language.
///
/// The repository's `salesMonthLabel` builds the same string out of a
/// hardcoded English month table, because it also has to work where there is
/// no `BuildContext` — the wire key. On screen the month is a word a person
/// reads, so it goes through `intl` like every other date in this app.
String salesMonthLabelIn(BuildContext context, DateTime month) {
  try {
    return DateFormat('MMMM y', context.l10n.localeName).format(month);
  } on Exception {
    // intl throws when a locale's date symbols were never loaded — a screen
    // pumped without the Material delegates has none. en_US is built in.
    return DateFormat('MMMM y', 'en_US').format(month);
  }
}

/// The same, from the wire's `YYYY-MM`. Returns the key itself when it is not
/// one — an unparsed key is still something a person can read back to support.
String salesMonthLabelFromKeyIn(BuildContext context, String key) {
  final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(key);
  if (match == null) return key;
  final month = int.parse(match.group(2)!);
  if (month < 1 || month > 12) return key;
  return salesMonthLabelIn(
    context,
    DateTime(int.parse(match.group(1)!), month),
  );
}

/// The metric's name: the server's own label where it sent one, otherwise the
/// translated default. A client that renamed the metric keeps its name.
String salesMetricLabel(AppLocalizations l10n, String? fromServer) =>
    fromServer == null || fromServer.isEmpty || fromServer == sellInLabel
    ? l10n.salesSellIn
    : fromServer;

/// "On target", "Close", "Behind" — or nothing at all when there is no target.
///
/// A level with no target has **no** attainment. It is not behind, and it is
/// certainly not on target: there is nothing to be on.
String? salesBandWord(AppLocalizations l10n, double? pct) {
  if (pct == null) return null;
  if (pct >= 100) return l10n.salesBandOnTarget;
  if (pct >= 80) return l10n.salesBandClose;
  return l10n.salesBandBehind;
}

/// On target at 100%, close from 80%, behind below that. **No target is not a
/// miss** — it is an absence, and it carries no severity at all.
SeverityMarkKind? salesSeverity(double? pct) {
  if (pct == null) return null;
  if (pct >= 100) return SeverityMarkKind.onTarget;
  if (pct >= 80) return SeverityMarkKind.watch;
  return SeverityMarkKind.critical;
}

/// THE THREE SCOPE LEVELS AS FIGURES: account-wide, territories, stores.
///
/// A level with **no targets** is not nought per cent attained. The old panel
/// left such a level out of the grid entirely, which is a different lie: a
/// manager who set no territory targets saw two tiles and had no way to know
/// the third existed. Every level renders; one with no targets renders an em
/// dash, the unit suppressed, no band word, and the reason in words (#396,
/// unify §4).
class AttainmentLevels extends StatelessWidget {
  const AttainmentLevels({super.key, required this.report});

  final SalesAttainmentReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final levels = <(String, AttainmentLevel)>[
      (l10n.salesLevelAccount, report.client),
      (l10n.salesLevelTerritories, report.territory),
      (l10n.salesLevelOutlets, report.outlet),
    ];

    final tiles = <StatTile>[
      for (final (label, level) in levels)
        _levelTile(context, label: label, level: level),
    ];

    // Veld takes two figures to a cluster by rule — "two figures is a reading
    // and four is analysis, which nobody does in the sun" — and there are
    // three scope levels. Under glare they become the figure list unify §4
    // asks for: the same three tiles, stacked, each one full width.
    if (context.skin.density == TiqDensity.veld) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < tiles.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: TiqSpace.s5),
            tiles[i],
          ],
        ],
      );
    }

    return StatCluster(semanticsLabel: l10n.salesLevelsHeading, tiles: tiles);
  }

  StatTile _levelTile(
    BuildContext context, {
    required String label,
    required AttainmentLevel level,
  }) {
    final l10n = context.l10n;
    final numbers = TiqNumber.of(context);
    // MEASURED MEANS THE SERVER WORKED A PERCENTAGE OUT, not that a row
    // exists. `attainmentPct` is null whenever `targetUnits <= 0`, and the API
    // accepts a target of nought units — this very screen's sheet can create
    // one on a delisted SKU. Reading "measured" off `targets > 0` handed
    // `StatTile` a null value with no sentence beside it, which is the assert
    // in debug and a bare em dash in release: the exact unknown-vs-zero law
    // this panel was rewritten to keep.
    final pct = level.attainmentPct;
    final noDataReason = pct != null
        ? null
        : level.targets == 0
        // No target at all. Not nought per cent — an absence.
        ? l10n.salesLevelNoTargets
        : level.targetUnits <= 0
        // A target exists and asks for nothing. There is no share of nothing.
        ? l10n.salesLevelZeroTarget
        // A level the server declined to score. Said as such rather than
        // guessed at from the units, which would be inventing a total.
        : l10n.salesLevelAttainmentUnknown;

    return StatTile(
      key: ValueKey<String>('attainment-level-$label'),
      eyebrow: label,
      value: pct,
      unit: TiqUnit.percent,
      decimals: pct == null || pct == pct.roundToDouble() ? 0 : 1,
      noDataReason: noDataReason,
      severity: salesSeverity(pct),
      meter: pct == null ? null : MeterData(value: pct, maximum: 100),
      stateLine: salesBandWord(l10n, pct),
      // The counts stand on their own: "4 of 0 units · 1 target" is true, and
      // it is how a manager finds the delisted SKU the reason is about.
      subordinates: level.targets > 0
          ? l10n.salesLevelSubordinates(
              numbers.format(level.actualUnits),
              numbers.format(level.targetUnits),
              level.targets,
            )
          : null,
    );
  }
}

/// THE DASHBOARD'S SELL-IN PANEL: the current month's attainment by scope
/// level, with a way through to the targets themselves.
///
/// *Which* month is current is the server's answer, not this device's (#339).
/// The panel names the month it was given, so a console sitting an hour either
/// side of midnight on the 1st never shows a figure for a month nobody chose.
class SalesAttainmentPanel extends ConsumerWidget {
  const SalesAttainmentPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final report = ref.watch(currentMonthAttainmentProvider);
    final month = report.value?.month;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionRule(
          l10n.salesPanelTitle,
          action: SectionRuleAction(
            l10n.salesPanelLink,
            onTap: () => context.go('/sales-targets'),
          ),
        ),
        const SizedBox(height: TiqSpace.s3),
        Text(
          l10n.salesPanelSubtitle(
            salesMetricLabel(l10n, report.value?.metricLabel),
            month == null
                ? l10n.salesPanelThisMonth
                : salesMonthLabelFromKeyIn(context, month),
          ),
          style: context.skin.text.meta.style(color: context.skin.palette.ink3),
        ),
        const SizedBox(height: TiqSpace.s5),
        report.when(
          loading: () => Skeleton(
            label: l10n.salesPanelTitle,
            child: const SkeletonRows(count: 3, rowHeight: 72),
          ),
          error: (error, stack) => ErrorState(
            scope: ErrorScope.inline,
            message: TorchErrorMessage(
              kind: TorchErrorKind.unknown,
              headline: l10n.salesTargetsLoadErrorHeadline,
              body: humanErrorMessage(error, l10n),
              offersRetry: true,
            ),
            action: TorchSecondaryButton(
              key: const ValueKey<String>('dashboard-sales-targets-retry'),
              label: l10n.salesTargetsRetry,
              onPressed: () => ref.invalidate(currentMonthAttainmentProvider),
            ),
          ),
          data: (data) => data.hasTargets
              ? AttainmentLevels(report: data)
              : EmptyState(
                  scope: EmptyScope.inPanel,
                  headline: l10n.salesNoTargetsHeadline(
                    salesMonthLabelFromKeyIn(context, data.month),
                  ),
                  body: l10n.salesPanelEmptyBody,
                ),
        ),
      ],
    );
  }
}
