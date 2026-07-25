import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/human_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/agent_motion.dart' show reduceMotion;
import '../../../core/widgets/console.dart';
import '../../../core/widgets/evidence_thumb.dart';
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

/// Severity dropdown + Open/Acknowledged/All segmented control — deliberately
/// NOT restyled to the tasks screen's pill chips (sub-4 note): `_FilterChips`
/// is private to tasks_screen.dart and typed on its own enum, so "reuse"
/// would mean lifting it shared and re-touching the tasks screen — not the
/// trivial swap the plan gated this on. Revisit if the chips ever go shared.
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
            DropdownMenuItem<String?>(
              value: null,
              child: Text('All severities'),
            ),
            DropdownMenuItem<String?>(
              value: 'critical',
              child: Text('Critical'),
            ),
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
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colors.lineStrong),
        borderRadius: BorderRadius.circular(AppColors.radiusControl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < segments.length; i++)
            InkWell(
              key: ValueKey('tab-${segments[i].value}'),
              onTap: () => onChanged(segments[i].value),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: segments[i].value == selected
                      ? colors.surface3
                      : Colors.transparent,
                  border: Border(
                    right: BorderSide(
                      color: i == segments.length - 1
                          ? Colors.transparent
                          : colors.lineStrong,
                    ),
                  ),
                ),
                child: Text(
                  segments[i].label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: segments[i].value == selected
                        ? colors.ink1
                        : colors.ink2,
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
              hint:
                  'Alerts appear here when a rule fires on a submitted visit.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < alerts.length; i++)
                  WorklistCascade(
                    index: i,
                    // Keyed by id so a row's collapse State can never be
                    // adopted by a DIFFERENT alert sliding into its list
                    // position after a refresh removes the one above it.
                    child: _AlertRow(
                      key: ValueKey('alert-row-${alerts[i].id}'),
                      alert: alerts[i],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// One alert as a worklist card.
///
/// No `View visit` action, deliberately (2026-07-25 ruling): the manager
/// console has no visit-detail destination — the agent trail screen takes a
/// day/agent context, not a visit id — and a link with nowhere real to go is
/// exactly the dishonest chrome the spec bans. Acknowledge is the only row
/// action until a visit-detail screen exists.
///
/// Acknowledging collapses the row closed IMMEDIATELY (optimistic, ~200ms
/// SizeTransition; instant under reduced motion) so the receipt is the tap,
/// not the round trip — and if the PATCH fails, the row un-collapses and a
/// SnackBar names the failure. An unacked alert never silently vanishes.
class _AlertRow extends ConsumerStatefulWidget {
  const _AlertRow({super.key, required this.alert});

  final AlertItem alert;

  @override
  ConsumerState<_AlertRow> createState() => _AlertRowState();
}

class _AlertRowState extends ConsumerState<_AlertRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _height = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 200),
  );
  late final Animation<double> _sizeFactor = CurvedAnimation(
    parent: _height,
    curve: Curves.easeInOut,
  );

  @override
  void didUpdateWidget(_AlertRow old) {
    super.didUpdateWidget(old);
    // A refresh can re-deliver this same row as acknowledged (the All /
    // Acknowledged tabs keep it on the page). The collapse was the receipt
    // for the transition, not the state — the acked row stands back up,
    // faded and pilled, instead of living on as an invisible zero-height
    // card.
    if (widget.alert.acknowledged && !old.alert.acknowledged) {
      _height.value = 1;
    }
  }

  @override
  void dispose() {
    _height.dispose();
    super.dispose();
  }

  Future<void> _acknowledge() async {
    // Optimistic: the row starts closing on the tap itself.
    if (reduceMotion(context)) {
      _height.value = 0;
    } else {
      _height.reverse();
    }
    try {
      await ref.read(alertsRepositoryProvider).acknowledge(widget.alert.id);
      if (!mounted) return;
      ref.invalidate(alertsListProvider);
    } catch (err) {
      if (!mounted) return;
      // Honesty: the acknowledge did NOT happen, so the alert must come back
      // — a vanished-but-unacked alert is the worklist lying.
      if (reduceMotion(context)) {
        _height.value = 1;
      } else {
        _height.forward();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to acknowledge. ${humanErrorMessage(err)}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final level = alert.acknowledged
        ? StatusLevel.neutral
        : alert.severity == 'critical'
        ? StatusLevel.critical
        : StatusLevel.warning;

    return SizeTransition(
      key: ValueKey('collapse-${alert.id}'),
      sizeFactor: _sizeFactor,
      // Anchored top: the card slides shut upward, the list closes over it.
      alignment: Alignment.topCenter,
      child: WorklistRow(
        key: ValueKey('alert-${alert.id}'),
        title: alert.message,
        // The thumbnail IS the evidence — no photo, no thumb, no placeholder.
        // evidencePhotoId implies a linked visit, but the guard keeps a
        // malformed row honest rather than crashing.
        thumb: alert.evidencePhotoId != null && alert.visitId != null
            ? EvidenceThumb(
                photoId: alert.evidencePhotoId!,
                visitId: alert.visitId!,
              )
            : null,
        // The rule that fired is machine-facing, so it wears the mono token —
        // a manager can quote it straight back into Scoring config.
        meta: Row(
          children: [
            if (alert.acknowledged) ...[
              const _AckedPill(),
              const SizedBox(width: 8),
            ],
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
        // The fade: WorklistRow dims resolved rows to 0.6 — verified ≥4.5:1
        // for the composited title on BOTH palettes (alerts_screen_test.dart
        // holds the maths), so the shipped value stands and the row is not
        // double-faded here.
        resolved: alert.acknowledged,
        actions: [
          if (!alert.acknowledged)
            RowAction(
              key: ValueKey<String>('ack-${alert.id}'),
              label: 'Acknowledge',
              onPressed: _acknowledge,
            ),
        ],
      ),
    );
  }
}

/// The muted `✓ ACKED` state pill — [SlaPill]'s chrome family (surface2 under
/// ink2), NOT reused from it: an SLA verdict and an acknowledged state are
/// different semantics that happen to share a wash. Words always — the fade
/// alone would be colour-only state.
class _AckedPill extends StatelessWidget {
  const _AckedPill();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      key: const ValueKey('acked-pill'),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
      ),
      child: Text(
        '✓ ACKED',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: colors.ink2,
        ),
      ),
    );
  }
}
