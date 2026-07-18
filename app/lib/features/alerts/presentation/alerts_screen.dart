import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tiq_colors.dart';
import '../../../core/theme/tiq_geometry.dart';
import '../../../core/widgets/console.dart';
import '../../../core/widgets/manager_scaffold.dart';
import '../../../core/widgets/worklist.dart';
import '../data/alerts_repository.dart';

/// The reference worklist: triage counts, one filter row, then rows sorted by
/// consequence. Every other list screen copies this shape.
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

enum _Tab { open, acknowledged, all }

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  _Tab _tab = _Tab.open;
  String? _severity;

  @override
  Widget build(BuildContext context) {
    final alerts = ref.watch(alertsListProvider);

    return ManagerScaffold(
      title: 'Alerts',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // What raises these rows is one hop away — a manager reading "a rule
          // fired" should be able to go and see (or silence) the rule itself.
          Row(
            children: [
              Expanded(
                child: Text(
                  'Rules evaluate on every visit submit.',
                  style: TextStyle(fontSize: 12, color: context.colors.ink3),
                ),
              ),
              RowAction(
                key: const ValueKey<String>('manage-rules'),
                label: 'Manage rules',
                onPressed: () => context.go('/alert-rules'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AsyncSection<List<AlertItem>>(
            value: alerts,
            label: 'alerts',
            onRetry: () => ref.invalidate(alertsListProvider),
            builder: (list) {
              final open = list.where((a) => !a.acknowledged).toList();
              final acked = list.where((a) => a.acknowledged).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TriageStrip(
                    counts: [
                      (
                        label: 'Critical',
                        count: open
                            .where((a) => a.severity == 'critical')
                            .length,
                        level: StatusLevel.critical,
                      ),
                      (
                        label: 'Warning',
                        count: open
                            .where((a) => a.severity != 'critical')
                            .length,
                        level: StatusLevel.warning,
                      ),
                      (
                        label: 'Acknowledged',
                        count: acked.length,
                        level: StatusLevel.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Filters(
                    tab: _tab,
                    severity: _severity,
                    openCount: open.length,
                    onTab: (t) => setState(() => _tab = t),
                    onSeverity: (s) => setState(() => _severity = s),
                  ),
                  const SizedBox(height: 12),
                  _AlertList(alerts: _visible(list)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Sorted by consequence, then by state: unacknowledged criticals first,
  /// acknowledged rows last. The list should read top-down as a to-do order.
  List<AlertItem> _visible(List<AlertItem> all) {
    final filtered = all.where((a) {
      final byTab = switch (_tab) {
        _Tab.open => !a.acknowledged,
        _Tab.acknowledged => a.acknowledged,
        _Tab.all => true,
      };
      final bySeverity = _severity == null || a.severity == _severity;
      return byTab && bySeverity;
    }).toList();

    int rank(AlertItem a) => a.acknowledged
        ? 2
        : a.severity == 'critical'
            ? 0
            : 1;
    filtered.sort((a, b) => rank(a).compareTo(rank(b)));
    return filtered;
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.tab,
    required this.severity,
    required this.openCount,
    required this.onTab,
    required this.onSeverity,
  });

  final _Tab tab;
  final String? severity;
  final int openCount;
  final ValueChanged<_Tab> onTab;
  final ValueChanged<String?> onSeverity;

  @override
  Widget build(BuildContext context) {
    return FilterRow(
      children: [
        const SectionLabel('Severity'),
        DropdownButton<String?>(
          key: const ValueKey('filter-severity'),
          value: severity,
          hint: const Text('All severities'),
          underline: const SizedBox.shrink(),
          isDense: true,
          style: TextStyle(fontSize: 12.5, color: context.colors.ink1),
          dropdownColor: context.colors.surface2,
          items: const [
            DropdownMenuItem<String?>(value: null, child: Text('All severities')),
            DropdownMenuItem<String?>(value: 'critical', child: Text('Critical')),
            DropdownMenuItem<String?>(value: 'warning', child: Text('Warning')),
          ],
          onChanged: onSeverity,
        ),
        const SizedBox(width: 4),
        _Segmented(
          segments: [
            (label: 'Open · $openCount', value: _Tab.open),
            (label: 'Acknowledged', value: _Tab.acknowledged),
            (label: 'All', value: _Tab.all),
          ],
          selected: tab,
          onChanged: onTab,
        ),
      ],
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<({String label, T value})> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: c.lineStrong),
        borderRadius: BorderRadius.circular(TiqGeometry.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < segments.length; i++)
            InkWell(
              key: ValueKey('tab-${segments[i].value}'),
              onTap: () => onChanged(segments[i].value),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: segments[i].value == selected
                      ? c.surface3
                      : Colors.transparent,
                  border: Border(
                    right: BorderSide(
                      color: i == segments.length - 1
                          ? Colors.transparent
                          : c.lineStrong,
                    ),
                  ),
                ),
                child: Text(
                  segments[i].label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: segments[i].value == selected
                        ? c.ink1
                        : c.ink2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AlertList extends StatelessWidget {
  const _AlertList({required this.alerts});

  final List<AlertItem> alerts;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title: '${alerts.length} ${alerts.length == 1 ? 'alert' : 'alerts'}',
      subtitle: 'Sorted by severity, then state',
      padded: false,
      child: alerts.isEmpty
          ? const EmptyState(
              message: 'Nothing to triage',
              hint: 'Alerts appear here when a rule fires on a submitted visit.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [for (final a in alerts) _AlertRow(alert: a)],
            ),
    );
  }
}

class _AlertRow extends ConsumerWidget {
  const _AlertRow({required this.alert});

  final AlertItem alert;

  Future<void> _acknowledge(WidgetRef ref) async {
    await ref.read(alertsRepositoryProvider).acknowledge(alert.id);
    ref.invalidate(alertsListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = alert.acknowledged
        ? StatusLevel.neutral
        : alert.severity == 'critical'
            ? StatusLevel.critical
            : StatusLevel.warning;

    return WorklistRow(
      key: ValueKey('alert-${alert.id}'),
      title: alert.message,
      // The rule that fired is machine-facing, so it wears the mono token —
      // a manager can quote it straight back into Scoring config.
      meta: Row(
        children: [
          CodeToken(alert.metric),
          if (alert.outletId != null) ...[
            const SizedBox(width: 6),
            const Text('·'),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Outlet ${alert.outletId}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
      level: level,
      statusLabel: alert.acknowledged
          ? 'Acknowledged'
          : alert.severity == 'critical'
              ? 'Critical'
              : 'Warning',
      resolved: alert.acknowledged,
      actions: [
        if (!alert.acknowledged)
          RowAction(
            key: ValueKey<String>('ack-${alert.id}'),
            label: 'Acknowledge',
            onPressed: () => _acknowledge(ref),
          ),
      ],
    );
  }
}
