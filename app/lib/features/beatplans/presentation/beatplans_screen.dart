import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/design/tiq_number.dart';
import '../../../core/design/torch_scope.dart';
import '../../../core/network/human_error.dart';
import '../../../core/network/paginated_response.dart';
import '../../../core/theme/torchlight/console_skin.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/console_frame.dart';
import '../../../core/widgets/torchlight/input.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../../outlets/data/outlets_repository.dart';
import '../data/beatplans_repository.dart';
import 'beat_plan_form_screen.dart';

/// BEAT PLANS — a day of store stops, in visit order.
///
/// ```text
///   Beat plans                                    [ ⟳ ]
///   A plan is a day of store stops, in visit order.
///   ── Plans  4 ─────────────────── New plan ──
///   ▏ North Route                            ›
///   ▏ In progress · Thu 18 Sep
///   ▌ South Route                            ›
///   ▌ Missed · Wed 17 Sep
/// ```
///
/// ## Missed is the only severity
///
/// The old list painted `cancelled` crimson-critical beside `missed`. A
/// cancelled plan is a decision somebody made; a missed one is a day of stores
/// nobody visited, and it is the only row here that costs anything. It takes
/// the critical bar plus the word; everything else carries its status in
/// words and no colour at all.
class BeatPlansScreen extends ConsumerWidget {
  const BeatPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ConsoleTorchlightRoute(child: _BeatPlans());
  }
}

String beatPlanStatusWord(AppLocalizations l10n, String status) =>
    switch (status) {
      'scheduled' => l10n.beatPlanStatusScheduled,
      'in_progress' => l10n.beatPlanStatusInProgress,
      'completed' => l10n.beatPlanStatusCompleted,
      'missed' => l10n.beatPlanStatusMissed,
      'cancelled' => l10n.beatPlanStatusCancelled,
      _ => l10n.beatPlanStatusOther(status),
    };

/// A missed plan is a day of stores nobody visited. Nothing else on this list
/// is a problem — a cancelled plan is a decision, and a completed one is done.
SoftRowSeverity beatPlanSeverity(String status) =>
    status == 'missed' ? SoftRowSeverity.critical : SoftRowSeverity.none;

class _BeatPlans extends ConsumerWidget {
  const _BeatPlans();

  void _refresh(WidgetRef ref) => ref.invalidate(beatPlansPageProvider);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final page = ref.watch(beatPlansPageProvider);

    return page.when(
      loading: () => _frame(
        context,
        ref,
        phase: 'loading',
        children: <Widget>[
          Skeleton(
            label: l10n.beatPlansTitle,
            child: const SkeletonRows(count: 5, rowHeight: 72),
          ),
        ],
      ),
      error: (error, stack) => _frame(
        context,
        ref,
        phase: 'error',
        children: <Widget>[
          TorchErrorRegion(
            name: 'beat-plans',
            child: ErrorState(
              message: TorchErrorMessage(
                kind: TorchErrorKind.unknown,
                headline: l10n.beatPlansLoadErrorHeadline,
                body: humanErrorMessage(error, l10n),
                offersRetry: true,
              ),
              drawing: EmptyDrawing.pin,
              action: TorchSecondaryButton(
                key: const ValueKey<String>('beatplans-retry'),
                label: l10n.beatPlansRetry,
                onPressed: () => _refresh(ref),
              ),
            ),
          ),
        ],
      ),
      data: (data) => _loaded(context, ref, data),
    );
  }

  Widget _loaded(
    BuildContext context,
    WidgetRef ref,
    PaginatedResponse<BeatPlan> page,
  ) {
    final l10n = context.l10n;
    final numbers = TiqNumber.of(context);
    final gutter = context.skin.space.gutterFor(
      MediaQuery.sizeOf(context).width,
    );
    final plans = page.data;
    final cut = page.nextCursor != null;
    final shown = numbers.format(plans.length);

    // Planning is a manager/admin action; a field agent only executes plans.
    final role = ref.watch(sessionControllerProvider).value?.role;
    final canBuild = role == 'manager' || role == 'admin';

    return _frame(
      context,
      ref,
      phase: plans.isEmpty ? 'empty' : 'loaded',
      children: <Widget>[
        SectionRule(
          l10n.beatPlansSectionHeading,
          count: plans.isEmpty ? null : plans.length,
          action: canBuild
              ? SectionRuleAction(
                  l10n.beatPlansNewPlan,
                  onTap: () => _openForm(context, ref),
                )
              : null,
        ),
        const SizedBox(height: TiqSpace.s5),
        if (plans.isEmpty)
          EmptyState(
            headline: l10n.beatPlansEmptyHeadline,
            drawing: EmptyDrawing.pin,
            body: l10n.beatPlansEmptyBody,
            action: canBuild
                ? TorchSecondaryButton(
                    key: const ValueKey<String>('beatplan-create'),
                    label: l10n.beatPlansNewPlan,
                    icon: Icons.add,
                    onPressed: () => _openForm(context, ref),
                  )
                : null,
          )
        else
          TorchBleed(
            extra: gutter.left * 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < plans.length; i++)
                  _BeatPlanRow(plan: plans[i], last: i == plans.length - 1),
              ],
            ),
          ),
        if (cut) ...<Widget>[
          const SizedBox(height: TiqSpace.s6),
          TorchBleed(
            extra: gutter.left * 2,
            child: PaginationFooter(
              key: const ValueKey<String>('beatplans-footer'),
              summary: page.total == null || page.total! <= plans.length
                  ? l10n.beatPlansFooterMore(shown)
                  : l10n.beatPlansFooterOf(shown, numbers.format(page.total!)),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, _, _) => const BeatPlanFormScreen(),
        transitionsBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    ref.invalidate(beatPlansPageProvider);
  }

  Widget _frame(
    BuildContext context,
    WidgetRef ref, {
    required String phase,
    required List<Widget> children,
  }) {
    final l10n = context.l10n;
    return ConsoleFrame(
      phase: phase,
      active: ConsoleSlot.menu,
      header: TorchAppHeader(
        title: l10n.beatPlansTitle,
        facts: <String>[l10n.beatPlansSubtitle],
        trailing: TorchIconButton(
          key: const ValueKey<String>('beatplans-refresh'),
          icon: Icons.refresh,
          semanticLabel: l10n.beatPlansRefresh,
          onPressed: () => _refresh(ref),
        ),
      ),
      children: children,
    );
  }
}

class _BeatPlanRow extends StatelessWidget {
  const _BeatPlanRow({required this.plan, required this.last});

  final BeatPlan plan;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final status = beatPlanStatusWord(l10n, plan.status);
    final severity = beatPlanSeverity(plan.status);
    final date = beatPlanDateLabel(context, plan.scheduledDate);

    return SoftRow(
      key: ValueKey<String>('beatplan-${plan.id}'),
      density: SoftRowDensity.tall,
      title: plan.name,
      titleTruncation: SoftRowTruncation.middle,
      subtitle: '$status · $date',
      severity: severity,
      severityLabel: severity == SoftRowSeverity.none ? null : status,
      // The plan id is what the stops endpoint keys on, so a manager can quote
      // it straight back at the API or a support ticket.
      meta: Text(
        plan.id,
        style: skin.text.monoIdent.style(color: skin.palette.ink3),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const SoftRowChevron(),
      onTap: () => Navigator.of(context).push(
        PageRouteBuilder<void>(
          pageBuilder: (context, _, _) => BeatPlanDetailScreen(planId: plan.id),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: <String>[plan.name, status, date].join('. '),
    );
  }
}

/// `scheduledDate` is a calendar date stored as UTC midnight. It is rendered
/// in the locale's own short form, and left exactly as the wire sent it when
/// it is not a date this app can parse — an unparsed string is still something
/// a person can read back to support.
String beatPlanDateLabel(BuildContext context, String scheduledDate) {
  final parsed = DateTime.tryParse(scheduledDate);
  if (parsed == null) return scheduledDate;
  return formatDayShort(context, parsed.toLocal());
}

/// ONE BEAT PLAN — its stops, and how much of the day was worked.
///
/// ```text
///   ← Beat plans
///   North Route
///   Thu 18 Sep
///   ┌────────────────────────────────────┐
///   │ STOPS WORKED                   50% │
///   │ ▓▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒                   │
///   │ 1 of 2 stops                       │
///   └────────────────────────────────────┘
///   ── Stops  2 ────────────────────────────
///   ▏ Kasi Corner Spaza          [✓] Worked
///   ▏ Stop 1
///   [ ☾ ]
/// ```
///
/// ## A plan with no stops is not nought per cent adherent
///
/// `adherenceRate` is `visited / total`, and the old screen ran it through
/// `toStringAsFixed(0)` unconditionally — so an empty plan read "0% adherence"
/// and accused an agent of not working stops that were never there. A plan
/// with no stops has **no** adherence: an em dash, with the reason in words
/// (unify §4).
///
/// ## The amber, counted
///
/// Not a tab root, and nothing here is a commit: ticking a stop is a row's own
/// control, not the screen's next move. The thumb zone carries the skin cycle
/// alone and this route paints **zero** amber objects in every skin.
class BeatPlanDetailScreen extends ConsumerWidget {
  const BeatPlanDetailScreen({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConsoleTorchlightRoute(child: _BeatPlanDetail(planId: planId));
  }
}

class _BeatPlanDetail extends ConsumerWidget {
  const _BeatPlanDetail({required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final detail = ref.watch(beatPlanDetailProvider(planId));

    return detail.when(
      loading: () => _DetailFrame(
        phase: 'loading',
        title: l10n.beatPlanDetailTitle,
        children: <Widget>[
          Skeleton(
            label: l10n.beatPlanDetailTitle,
            child: const SkeletonRows(count: 4, rowHeight: 64),
          ),
        ],
      ),
      error: (error, stack) => _DetailFrame(
        phase: 'error',
        title: l10n.beatPlanDetailTitle,
        children: <Widget>[
          TorchErrorRegion(
            name: 'beat-plan-detail',
            child: ErrorState(
              message: TorchErrorMessage(
                kind: TorchErrorKind.unknown,
                headline: l10n.beatPlanDetailLoadErrorHeadline,
                body: humanErrorMessage(error, l10n),
                offersRetry: true,
              ),
              drawing: EmptyDrawing.pin,
              action: TorchSecondaryButton(
                key: const ValueKey<String>('beatplan-detail-retry'),
                label: l10n.beatPlansRetry,
                onPressed: () => ref.invalidate(beatPlanDetailProvider(planId)),
              ),
            ),
          ),
        ],
      ),
      data: (data) => _DetailFrame(
        phase: 'loaded',
        title: data.plan.name,
        facts: <String>[
          '${beatPlanStatusWord(l10n, data.plan.status)} · '
              '${beatPlanDateLabel(context, data.plan.scheduledDate)}',
        ],
        children: <Widget>[
          _Adherence(detail: data),
          const SizedBox(height: TiqSpace.s7),
          _Stops(planId: planId, detail: data),
        ],
      ),
    );
  }
}

class _DetailFrame extends StatelessWidget {
  const _DetailFrame({
    required this.phase,
    required this.title,
    required this.children,
    this.facts = const <String>[],
  });

  final String phase;
  final String title;
  final List<String> facts;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TorchScope(
      skin: context.skin,
      phase: phase,
      navRenders: false,
      tabbedRoute: false,
      // Nothing on this route is a commit: a stop's tick is the row's own
      // control and it takes effect on the tap.
      claims: const <TorchClaim>[],
      child: TorchShell(
        profile: TorchShellProfile.console,
        header: TorchAppHeader(
          title: title,
          facts: facts,
          back: TorchIconButton(
            icon: Icons.arrow_back,
            semanticLabel: l10n.beatPlanDetailBack,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        skinCycle: const ConsoleSkinCycle(),
        children: children,
      ),
    );
  }
}

/// How much of the planned day was worked.
class _Adherence extends StatelessWidget {
  const _Adherence({required this.detail});

  final BeatPlanDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final numbers = TiqNumber.of(context);
    // A plan with no stops has no adherence. Nought per cent is a claim that
    // somebody failed to work stops that do not exist.
    final measured = detail.stopsTotal > 0;

    return StatTile(
      key: const ValueKey<String>('adherence'),
      eyebrow: l10n.beatPlanAdherenceEyebrow,
      value: measured ? detail.adherenceRate * 100 : null,
      unit: TiqUnit.percent,
      decimals: 0,
      noDataReason: measured ? null : l10n.beatPlanAdherenceNoStops,
      meter: measured
          ? MeterData(value: detail.adherenceRate * 100, maximum: 100)
          : null,
      subordinates: measured
          ? l10n.beatPlanAdherenceOf(
              numbers.format(detail.stopsVisited),
              numbers.format(detail.stopsTotal),
            )
          : null,
    );
  }
}

class _Stops extends ConsumerStatefulWidget {
  const _Stops({required this.planId, required this.detail});

  final String planId;
  final BeatPlanDetail detail;

  @override
  ConsumerState<_Stops> createState() => _StopsState();
}

class _StopsState extends ConsumerState<_Stops> {
  /// Stops with a request in flight. A second tap must not fire a duplicate,
  /// and a failure must be reported once.
  final Set<String> _busy = <String>{};

  Future<void> _mark(BeatPlanStop stop, bool visited) async {
    if (_busy.contains(stop.id)) return;
    setState(() => _busy.add(stop.id));
    try {
      await ref
          .read(beatPlansRepositoryProvider)
          .markStopVisited(widget.planId, stop.id, visited);
      ref.invalidate(beatPlanDetailProvider(widget.planId));
      ref.invalidate(beatPlansPageProvider);
    } catch (error) {
      if (!mounted) return;
      showTorchToast(
        context,
        message: context.l10n.beatPlanStopFailed,
        kind: ToastKind.failure,
      );
    } finally {
      if (mounted) setState(() => _busy.remove(stop.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final gutter = skin.space.gutterFor(MediaQuery.sizeOf(context).width);
    final stops = widget.detail.stops;
    // The branch is on the `AsyncValue`, not on `.value`: null is both "still
    // walking the pages of GET /outlets" and "that request failed", and a
    // fallback that reads the sequence back gave a row titled "Stop 1" over a
    // subtitle reading "Stop 1" — the duplicated row title §1.15 lists as a
    // defect this system removed.
    final outlets = ref.watch(outletsListProvider);

    String nameFor(BeatPlanStop stop) =>
        outlets.value
            ?.where((o) => o.id == stop.outletId)
            .map((o) => o.name)
            .firstOrNull ??
        (outlets.isLoading
            ? l10n.beatPlanStopStoreLoading
            : outlets.hasError
            ? l10n.beatPlanStopStoreUnavailable
            : l10n.beatPlanStopUnknownStore);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionRule(
          l10n.beatPlanStopsHeading,
          count: stops.isEmpty ? null : stops.length,
        ),
        const SizedBox(height: TiqSpace.s4),
        if (stops.isEmpty)
          EmptyState(
            scope: EmptyScope.inPanel,
            headline: l10n.beatPlanStopsEmptyHeadline,
            body: l10n.beatPlanStopsEmptyBody,
          )
        else
          TorchBleed(
            extra: gutter.left * 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < stops.length; i++)
                  SoftRow(
                    key: ValueKey<String>('stop-${stops[i].id}'),
                    density: SoftRowDensity.standard,
                    title: nameFor(stops[i]),
                    titleTruncation: SoftRowTruncation.middle,
                    subtitle: l10n.beatPlanStopLabel(
                      TiqNumber.of(context).format(stops[i].sequence),
                    ),
                    // The tick is operated, not read: without this the row's
                    // own semantics node would swallow it and a screen-reader
                    // user could not work a stop at all.
                    trailingIsControl: true,
                    trailing: TorchCheckbox(
                      key: ValueKey<String>('stop-tick-${stops[i].id}'),
                      label: stops[i].visited
                          ? l10n.beatPlanStopVisited
                          : l10n.beatPlanStopNotVisited,
                      value: stops[i].visited,
                      onChanged: _busy.contains(stops[i].id)
                          ? null
                          : (value) => _mark(stops[i], value),
                    ),
                    separator: i == stops.length - 1
                        ? SoftRowSeparator.none
                        : SoftRowSeparator.auto,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
