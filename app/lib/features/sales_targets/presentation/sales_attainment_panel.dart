import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/worklist.dart';
import '../data/sales_targets_repository.dart';

/// "54%", "33.3%", or an em dash when there is no target to attain.
String formatAttainment(double? pct) {
  if (pct == null) return '—';
  final whole = pct == pct.roundToDouble();
  return '${pct.toStringAsFixed(whole ? 0 : 1)}%';
}

/// On target at 100%, close from 80%, behind below that. No target is
/// neutral, not a miss.
StatusLevel attainmentLevel(double? pct) {
  if (pct == null) return StatusLevel.neutral;
  if (pct >= 100) return StatusLevel.good;
  if (pct >= 80) return StatusLevel.warning;
  return StatusLevel.critical;
}

/// The three scope levels as figures: account-wide, territories, outlets. A
/// level with no targets is left out rather than drawn as a zero.
class AttainmentLevels extends StatelessWidget {
  const AttainmentLevels({super.key, required this.report});

  final SalesAttainmentReport report;

  @override
  Widget build(BuildContext context) {
    final levels = [
      ('Account-wide', report.client),
      ('Territories', report.territory),
      ('Outlets', report.outlet),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (label, level) in levels)
          if (level.targets > 0) _LevelFigure(label: label, level: level),
      ],
    );
  }
}

class _LevelFigure extends StatelessWidget {
  const _LevelFigure({required this.label, required this.level});

  final String label;
  final AttainmentLevel level;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final glass = colors.glass;
    final ink = glass ? context.lumen.ink : colors.ink1;
    final muted = glass ? context.lumen.inkMuted : colors.ink3;
    final pct = level.attainmentPct;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180),
      child: GlassPane(
        key: ValueKey<String>('attainment-level-$label'),
        kind: GlassKind.tile,
        // Several of these sit side by side: no blur, like any repeated pane.
        blur: false,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 11.5, color: muted)),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatAttainment(pct),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: ink,
                    fontFamily: glass ? LumenGlass.mono : null,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                StatusChip(
                  label: pct == null
                      ? 'No target'
                      : pct >= 100
                      ? 'On target'
                      : pct >= 80
                      ? 'Close'
                      : 'Behind',
                  level: attainmentLevel(pct),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${level.actualUnits} of ${level.targetUnits} units · '
              '${level.targets} ${level.targets == 1 ? 'target' : 'targets'}',
              style: TextStyle(fontSize: 11.5, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// The dashboard's sell-in panel: the current month's attainment by scope
/// level, with a way through to the targets themselves.
///
/// *Which* month is current is the server's answer, not this device's (#339).
/// The panel names the month it was given, so a console sitting an hour either
/// side of midnight on the 1st never shows a figure for a month nobody chose.
class SalesAttainmentPanel extends ConsumerWidget {
  const SalesAttainmentPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(currentMonthAttainmentProvider);
    final month = report.value?.month;
    return PanelCard(
      title: 'Sell-in vs target',
      subtitle:
          '$sellInLabel · '
          '${month == null ? 'this month' : salesMonthLabelFromKey(month)}'
          ' — not consumer sales',
      trailing: TextButton(
        key: const ValueKey<String>('dashboard-sales-targets-link'),
        onPressed: () => context.go('/sales-targets'),
        child: const Text('Targets'),
      ),
      child: AsyncSection<SalesAttainmentReport>(
        value: report,
        label: 'sell-in attainment',
        onRetry: () => ref.invalidate(currentMonthAttainmentProvider),
        builder: (data) => data.hasTargets
            ? AttainmentLevels(report: data)
            : EmptyState(
                message:
                    'No sales targets for '
                    '${salesMonthLabelFromKey(data.month)}',
                hint:
                    'Set monthly SKU targets under Sales targets to track '
                    'sell-in against them.',
              ),
      ),
    );
  }
}
