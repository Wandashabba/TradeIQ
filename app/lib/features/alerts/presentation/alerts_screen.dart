import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tiq_number.dart';
import '../../../core/widgets/agent_motion.dart' show Motion, reduceMotion;
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/evidence_thumb.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../data/alerts_repository.dart';
import '../data/alerts_view.dart';
import 'alert_detail_sheet.dart';

/// ALERTS — everything a rule fired on, in the order a manager should deal
/// with it.
///
/// ```text
///   Alerts                                        [ ⟳ ]
///   Rules evaluate on every visit submit.
///   Manage rules
///   ┌────────────────────────────────────────┐
///   │ ▲  OPEN CRITICAL                    7  │   ← the lead indicator,
///   │    9 warnings · 23 acknowledged        │     crimson-outlined
///   └────────────────────────────────────────┘
///   ( Open 7 )( Acknowledged )( All )  |  ( Critical )( Warning )
///   ── Open 7 ───────────────────────────────
///   ▌ Out of stock since Tuesday        [img]
///   ▌ Kasi Corner Spaza
///   ▌ OSA_BELOW_50
///   ▌ View visit   Acknowledge
///   …
///   Showing the 50 newest of 74 alerts.
///   The counts above are of these 50.
///   [ nav pill ]
/// ```
///
/// ## The one amber, counted
///
/// A tab root: the nav pill's active tab is slot 1, and this screen nominates
/// **no content amber at all**. Under the ruling that costs nothing — the
/// selected filter chip is `lifted` here exactly as it is everywhere else, the
/// severity bars are crimson at two commitment levels, and the lead figure
/// carries the urgency with an outline, a triangle and a word. Day and Veld
/// paint zero: the ladder has one rung on a light ground and it is the primary
/// commit block, which a worklist does not have.
///
/// ## Acknowledging is optimistic, and it is never silent
///
/// The row starts closing on the tap itself — the receipt is the tap, not the
/// round trip. If the PATCH fails the row stands back up and a toast names it.
/// An unacknowledged alert never silently vanishes.
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  AlertTab _tab = AlertTab.open;

  /// The wire's own word, or null for every severity.
  String? _severity;

  void _refresh() {
    ref.invalidate(alertsViewProvider);
    // The Floor reads the plain list; keeping the two in step means a manager
    // who refreshes here does not walk back to a stale board.
    ref.invalidate(alertsListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(alertsViewProvider);

    return view.when(
      loading: () => _frame(
        phase: 'loading',
        children: <Widget>[
          Skeleton(
            label: 'alerts',
            child: const SkeletonRows(count: 4, rowHeight: 76),
          ),
        ],
      ),
      error: (error, stack) => _frame(
        phase: 'error',
        children: <Widget>[
          TorchErrorRegion(
            name: 'alerts',
            child: ErrorState(
              message: TorchErrorMessage.sanitise(error),
              action: TorchSecondaryButton(
                key: const ValueKey<String>('alerts-retry'),
                label: 'Try again',
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
    return ConsoleFrame(
      phase: phase,
      active: ConsoleSlot.work,
      header: TorchAppHeader(
        title: 'Alerts',
        facts: const <String>['Rules evaluate on every visit submit.'],
        trailing: TorchIconButton(
          key: const ValueKey<String>('alerts-refresh'),
          icon: Icons.refresh,
          semanticLabel: 'Refresh the alerts list',
          onPressed: _refresh,
        ),
      ),
      children: children,
    );
  }

  Widget _loaded(AlertsView view) {
    final visible = view.visible(_tab, _severity);
    final gutter = context.skin.space.gutter;
    final numbers = TiqNumber.of(context);
    final footer = view.footer((n) => numbers.format(n));

    return _frame(
      phase: view.rows.isEmpty
          ? 'empty'
          : visible.isEmpty
          ? 'filtered-empty'
          : 'loaded',
      children: <Widget>[
        // What raises these rows is one hop away — a manager reading "a rule
        // fired" should be able to go and see, or silence, the rule itself.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TorchTertiaryButton(
            key: const ValueKey<String>('manage-rules'),
            label: 'Manage rules',
            onPressed: () => context.go('/alert-rules'),
          ),
        ),
        const SizedBox(height: TiqSpace.s6),

        // THE LEAD INDICATOR. Not three equal cells: critical and
        // acknowledged are not peers, and a rail that says so in its layout
        // says it before a word is read.
        _LeadIndicator(view: view),
        const SizedBox(height: TiqSpace.s6),

        // THE FILTER RAIL — never amber, on any screen, in any skin.
        TorchBleed(extra: gutter * 2, child: _Filters(
          tab: _tab,
          severity: _severity,
          view: view,
          onTab: (t) => setState(() => _tab = t),
          onSeverity: (s) => setState(() => _severity = s),
        )),
        const SizedBox(height: TiqSpace.s6),

        // THE SECTION RULE, with the count it is actually showing.
        // A section that vanishes when empty makes a manager think the feature
        // is gone, so the rule and its name render whatever the count is.
        SectionRule(
          _sectionName(),
          count: visible.isEmpty ? null : visible.length,
        ),
        const SizedBox(height: TiqSpace.s5),

        if (view.rows.isEmpty)
          const EmptyState(
            scope: EmptyScope.inPanel,
            headline: 'Nothing to triage.',
            body: 'Alerts appear here when a rule fires on a submitted visit.',
          )
        else if (visible.isEmpty)
          EmptyState(
            scope: EmptyScope.inPanel,
            headline: _filteredEmptyHeadline(),
            body: 'Clear the filter to see the rest.',
            action: TorchSecondaryButton(
              key: const ValueKey<String>('clear-filters'),
              label: 'Show all alerts',
              onPressed: () => setState(() {
                _tab = AlertTab.all;
                _severity = null;
              }),
            ),
          )
        else
          TorchBleed(
            extra: gutter * 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < visible.length; i++)
                  // Keyed by id so a row's collapse State can never be adopted
                  // by a DIFFERENT alert sliding into its list position after
                  // a refresh removes the one above it.
                  _AlertRow(
                    key: ValueKey<String>('alert-row-${visible[i].id}'),
                    alert: visible[i],
                    last: i == visible.length - 1,
                    onAcknowledged: _refresh,
                  ),
              ],
            ),
          ),

        // The footer only exists where the list was actually cut. It does
        // not offer to narrow: the filters are client-side over this page,
        // so narrowing could never bring the rest into view.
        if (footer != null) ...<Widget>[
          const SizedBox(height: TiqSpace.s6),
          TorchBleed(
            extra: gutter * 2,
            child: PaginationFooter(
              key: const ValueKey<String>('alerts-footer'),
              summary: footer.summary,
              narrowLine: footer.scope,
            ),
          ),
        ],
      ],
    );
  }

  String _sectionName() => switch (_tab) {
    AlertTab.open => 'Open',
    AlertTab.acknowledged => 'Acknowledged',
    AlertTab.all => 'All alerts',
  };

  String _filteredEmptyHeadline() {
    final severity = _severity;
    if (severity != null) {
      return 'No ${severity.toLowerCase()} alerts in ${_sectionName().toLowerCase()}.';
    }
    return switch (_tab) {
      AlertTab.open => 'Nothing open.',
      AlertTab.acknowledged => 'Nothing acknowledged yet.',
      AlertTab.all => 'Nothing to triage.',
    };
  }
}

/// The open-critical count, as the one figure that sends somebody somewhere.
///
/// Three channels, none of them working alone: the crimson `bad` outline, the
/// filled triangle beside it, and the word in the eyebrow. Never amber — a
/// count of problems is the least lit thing on this screen, and the ladder's
/// first rung is a commit action that this route does not have.
class _LeadIndicator extends StatelessWidget {
  const _LeadIndicator({required this.view});

  final AlertsView view;

  @override
  Widget build(BuildContext context) {
    final critical = view.openCritical;
    final kind = critical > 0
        ? SeverityMarkKind.critical
        : SeverityMarkKind.onTarget;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: TiqSpace.s5),
          child: SeverityMark(kind: kind),
        ),
        const SizedBox(width: TiqSpace.s3),
        Expanded(
          child: StatTile(
            eyebrow: 'Open critical',
            // A measured zero renders 0 and keeps its place. Nought open
            // criticals is a fact worth reading, not an absence.
            value: critical,
            lead: true,
            severity: critical > 0 ? SeverityMarkKind.critical : null,
            subordinates:
                '${view.openWarning} warnings · ${view.acknowledged} '
                'acknowledged',
          ),
        ),
      ],
    );
  }
}

/// Two axes in one rail: the state, then the severity.
///
/// Selected is `lifted` + a 1px ink-1 border + a tick + weight 700 — three
/// channels, and never amber on any screen (unify §1.6). A disabled filter
/// stays visible with its count at zero: hiding a filter because it is empty
/// hides the fact that it is empty.
class _Filters extends StatelessWidget {
  const _Filters({
    required this.tab,
    required this.severity,
    required this.view,
    required this.onTab,
    required this.onSeverity,
  });

  final AlertTab tab;
  final String? severity;
  final AlertsView view;
  final ValueChanged<AlertTab> onTab;
  final ValueChanged<String?> onSeverity;

  @override
  Widget build(BuildContext context) {
    return TorchFilterRail(
      semanticsLabel: 'Filters',
      chips: <Widget>[
        TorchFilterChip(
          key: const ValueKey<String>('tab-open'),
          label: 'Open',
          count: view.open,
          selected: tab == AlertTab.open,
          onSelected: () => onTab(AlertTab.open),
        ),
        TorchFilterChip(
          key: const ValueKey<String>('tab-acknowledged'),
          label: 'Acknowledged',
          count: view.acknowledged,
          selected: tab == AlertTab.acknowledged,
          onSelected: () => onTab(AlertTab.acknowledged),
        ),
        TorchFilterChip(
          key: const ValueKey<String>('tab-all'),
          label: 'All',
          count: view.rows.length,
          selected: tab == AlertTab.all,
          onSelected: () => onTab(AlertTab.all),
        ),
        TorchFilterChip(
          key: const ValueKey<String>('filter-critical'),
          label: 'Critical',
          selected: severity == 'critical',
          onSelected: () => onSeverity(severity == 'critical' ? null : 'critical'),
        ),
        TorchFilterChip(
          key: const ValueKey<String>('filter-warning'),
          label: 'Warning',
          selected: severity == 'warning',
          onSelected: () => onSeverity(severity == 'warning' ? null : 'warning'),
        ),
      ],
    );
  }
}

/// One alert, as a row.
///
/// Acknowledging collapses the row closed IMMEDIATELY (optimistic, a
/// [Motion.base] `SizeTransition` — "a row settling"; instant under reduced
/// motion) so the receipt is the tap rather than the round trip. If the PATCH
/// fails the row un-collapses and a toast names the failure.
class _AlertRow extends ConsumerStatefulWidget {
  const _AlertRow({
    super.key,
    required this.alert,
    required this.last,
    required this.onAcknowledged,
  });

  final AlertRow alert;
  final bool last;
  final VoidCallback onAcknowledged;

  @override
  ConsumerState<_AlertRow> createState() => _AlertRowState();
}

class _AlertRowState extends ConsumerState<_AlertRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _height = AnimationController(
    vsync: this,
    value: 1,
    duration: Motion.base,
  );
  late final CurvedAnimation _sizeFactor = CurvedAnimation(
    parent: _height,
    curve: Curves.easeInOut,
  );

  /// True from the Acknowledge tap until the PATCH resolves. A second tap
  /// mid-collapse must not fire a duplicate request: the server's ack is
  /// idempotent, so the repeat would be benign there, but a repeated FAILURE
  /// would stack toasts — one tap, one receipt, one outcome.
  bool _acking = false;

  @override
  void didUpdateWidget(_AlertRow old) {
    super.didUpdateWidget(old);
    // A refresh can re-deliver this same row as acknowledged (the All and
    // Acknowledged tabs keep it on the page). The collapse was the receipt for
    // the transition, not the state — the acked row stands back up, at `ink2`
    // with its mark intact, instead of living on as a zero-height ghost.
    if (widget.alert.acknowledged && !old.alert.acknowledged) {
      _height.value = 1;
    }
  }

  @override
  void dispose() {
    _sizeFactor.dispose();
    _height.dispose();
    super.dispose();
  }

  Future<void> _acknowledge() async {
    if (_acking) return;
    _acking = true;
    // Optimistic: the row starts closing on the tap itself.
    if (reduceMotion(context)) {
      _height.value = 0;
    } else {
      _height.reverse();
    }
    try {
      await ref.read(alertsRepositoryProvider).acknowledge(widget.alert.id);
      // The row may have been disposed under the pending PATCH (a tab switch
      // filters it out of the list): a dead ref cannot invalidate, and the
      // refresh it wanted is moot — whoever rebuilt the list already refetched
      // or will.
      if (!mounted) return;
      widget.onAcknowledged();
    } catch (error) {
      // Same dispose race, failure arm: no controller to un-collapse, no
      // element to hang a toast off — and no row left to be honest about.
      if (!mounted) return;
      // Honesty: the acknowledge did NOT happen, so the alert must come back.
      // A vanished-but-unacked alert is the worklist lying.
      _acking = false;
      if (reduceMotion(context)) {
        _height.value = 1;
      } else {
        _height.forward();
      }
      showTorchToast(
        context,
        message: 'That alert was not acknowledged. It is still open.',
        kind: ToastKind.failure,
        // A second toast replaces the first rather than stacking, so a retry
        // that fails again reports once.
        action: TorchTertiaryButton(
          label: 'Try again',
          onPressed: _acknowledge,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final alert = widget.alert;

    return SizeTransition(
      key: ValueKey<String>('collapse-${alert.id}'),
      sizeFactor: _sizeFactor,
      // Anchored top: the row slides shut upward and the list closes over it.
      alignment: Alignment.topCenter,
      child: SoftRow(
        key: ValueKey<String>('alert-${alert.id}'),
        density: SoftRowDensity.tall,
        title: alert.message,
        subtitle: alert.acknowledged
            ? '${alert.outletName} · acknowledged'
            : alert.outletName,
        severity: alert.severity,
        severityLabel: alert.severityLabel,
        // The thumbnail IS the evidence — no photo, no thumb, no placeholder.
        // `evidencePhotoId` implies a linked visit, but the guard keeps a
        // malformed row honest rather than crashing.
        trailing: alert.evidencePhotoId != null && alert.visitId != null
            ? TorchEvidenceThumb(
                photoId: alert.evidencePhotoId!,
                semanticLabel:
                    'Shelf photograph from ${alert.outletName} for '
                    '${alert.message}',
              )
            : null,
        meta: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // The rule that fired is machine-facing, so it wears the
            // identifier face — a manager can quote it straight back into the
            // rules screen.
            Text(
              alert.rule,
              style: skin.text.monoIdent.style(color: skin.palette.ink3),
            ),
            Wrap(
              spacing: TiqSpace.s4,
              children: <Widget>[
                // A link with nowhere to go is dishonest chrome: an alert with
                // no visit gets no action at all, not a disabled one.
                if (alert.visitId != null)
                  TorchTertiaryButton(
                    key: ValueKey<String>('view-visit-${alert.id}'),
                    label: 'View visit',
                    // push, not go: back returns to this worklist with its tab
                    // and filter intact.
                    onPressed: () => context.push('/visits/${alert.visitId}'),
                  ),
                if (!alert.acknowledged)
                  TorchTertiaryButton(
                    key: ValueKey<String>('ack-${alert.id}'),
                    label: 'Acknowledge',
                    onPressed: _acknowledge,
                  ),
              ],
            ),
          ],
        ),
        onTap: () => showAlertDetailSheet(
          context,
          alert: alert,
          onAcknowledge: _acknowledge,
        ),
        separator: widget.last
            ? SoftRowSeparator.none
            : SoftRowSeparator.auto,
        semanticsLabel: <String>[
          alert.severityLabel,
          alert.message,
          alert.rule,
          alert.outletName,
          if (alert.acknowledged) 'acknowledged',
        ].join('. '),
      ),
    );
  }
}
