import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/agent_skin.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/agent_location_banners.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/skin_controls.dart';
import '../../../core/widgets/torchlight/sync_status.dart';
import '../../../l10n/l10n.dart';
import '../../contests/data/contests_repository.dart';
import '../data/today_route.dart';

/// TODAY — the agent's home, and the answer to the only question that matters
/// at 06:30: *where am I going, and how much is left.*
///
/// ```text
///   Today                       [ 12 held on this phone ]  [ ☾ ]
///   ┌───────────────────────────────────────────┐
///   │ ROUTE                                     │
///   │ 4  of 11 stores            ( 7 left )     │
///   │ ▬▬▬▬▬▬▬▬▬░░░░░░░░░░░░░░░░                 │
///   └───────────────────────────────────────────┘
///   ── Next up ─────────────────────────────────
///   ┌───────────────────────────────────────────┐
///   │ 03 · 1,2 km                               │
///   │ Kasi Corner Spaza                         │
///   │ KC-0412                                   │
///   │ [        Check in here         ]          │
///   └───────────────────────────────────────────┘
///   ── The rest of the day ─────────────────────
///   ▏04  Sunrise Spaza      KC-0413      2,1 km
///   ▏05  Khumalo Superette  KS-0014      3,4 km
///   [ nav pill ] ( + )
/// ```
///
/// ## The two ambers, counted
///
/// A tab root, so the nav pill's active tab is object 1 whenever the nav
/// renders and the content has exactly one grant left. It goes to
/// **"Check in here"** — the one thing the agent is about to do. The nav
/// circle declares rung 4 honestly and the allocator denies it outright
/// (`circleWithPrimary`), so the light never moves while a thumb scrolls.
///
/// When the route is done there is no next stop and therefore no primary, and
/// the circle takes the grant instead: *start a visit somewhere else* is then
/// genuinely the expected next move. On Day and Veld the ladder has one rung
/// and the circle is denied there too, so a finished route outdoors carries
/// **zero** amber — which is correct, because nothing is armed.
///
/// ## Distances are a figure or a sentence, never a guess
///
/// Every distance goes through `FigureSlot`, which owns the mono face, the
/// grouping and the decimal mark — so "1,2 km" in Afrikaans is the formatter's
/// job and not this file's. When the phone will not say where it is there are
/// no distances at all and one line of words says why. Half a list of
/// distances is worse than none, and a wrong one is worse than both.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  /// The id "Check in here" is declared under. Rung 1.
  static const String checkInClaimId = 'today-check-in';

  /// The nav circle's id. Declared on every phase and granted on exactly the
  /// phases where there is nothing else to do next.
  static const String navCircleClaimId = 'today-unplanned-visit';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TorchlightRoute(child: _Today());
  }
}

class _Today extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final routeAsync = ref.watch(todayRouteProvider);

    return routeAsync.when(
      loading: () => const TodayFrame(
        phase: 'loading',
        hasNextStop: false,
        children: <Widget>[_TodaySkeleton()],
      ),
      // A load failure is not an empty state and never an empty route. It
      // keeps the chrome, puts the failure in the body, says what survived,
      // and arms the circle — because picking a store yourself is still the
      // next physical action.
      error: (error, stack) => TodayFrame(
        phase: 'error',
        hasNextStop: false,
        children: <Widget>[
          _TodayMessage(
            headline: l10n.todayLoadErrorTitle,
            body: l10n.todayLoadErrorDetail,
            actionLabel: l10n.todayPickStore,
            onAction: () => context.go('/audit'),
            glyph: Icons.wifi_off_outlined,
          ),
        ],
      ),
      data: (route) {
        if (route == null || route.stops.isEmpty) {
          return TodayFrame(
            phase: route == null ? 'no-plan' : 'empty-plan',
            hasNextStop: false,
            children: <Widget>[
              _TodayMessage(
                // "No route today" is a fact about the plan, not about the
                // agent — and an empty plan is a different fact again, so it
                // gets its own sentence rather than the same one.
                headline: l10n.todayNoRouteTitle,
                body: route == null
                    ? l10n.todayNoPlanDetail
                    : l10n.todayEmptyPlanDetail,
                actionLabel: l10n.todayPickStore,
                onAction: () => context.go('/audit'),
                glyph: Icons.map_outlined,
              ),
            ],
          );
        }
        return _Route(route: route);
      },
    );
  }
}

/// The frame every state of this route wears — so a skeleton, an error, an
/// empty plan and the real thing are one screen in four conditions rather than
/// four screens.
class TodayFrame extends ConsumerWidget {
  const TodayFrame({
    super.key,
    required this.phase,
    required this.hasNextStop,
    required this.children,
    this.routeName,
  });

  final String phase;

  /// The plan's own name — "Tembisa run" — which joins the date on the
  /// header's one fact line. Null on every state that has no plan to name.
  final String? routeName;

  /// Whether there is a store to check into. It decides both the claim set
  /// and whether the circle is the expected next move — one boolean, so the
  /// two can never disagree.
  final bool hasNextStop;

  final List<Widget> children;

  /// Today · My work · Map · Me. **The owner's four, exactly as approved.**
  ///
  /// ## The history, because it explains the set
  ///
  /// The owner approved Today · My work · Map · Me. The migration shipped
  /// three, because neither Map nor Me had a destination, and a tab that
  /// bounces the user back where they already are reads as a broken app — an
  /// agent taps it once and never trusts the bar again. Contests took the
  /// freed slot rather than the migration quietly *removing* a capability:
  /// the agent's standings used to hang off the Today app bar (#124), and the
  /// new header carries the skin cycle in its one trailing slot. Map came
  /// back when `/map` existed, in the position it was approved in.
  ///
  /// **Me now exists** — `/me`, the agent's own visits and what they have
  /// earned (#383/#384) — so the fourth slot is Me, and Contests moves
  /// *inside* it, next to the points and the reward it is part of. Four is
  /// the maximum ([TorchNavPill] asserts it), so this was a move, not an
  /// addition, and the capability goes with it rather than vanishing:
  ///
  /// * Me carries a Contests row that opens the agent's standings
  ///   (`/leaderboard/contests`), wearing the running count.
  /// * The Me slot here wears the same running-contests badge and says it in
  ///   words to a screen reader, so Today still tells an agent a contest is
  ///   on without their having to go and look.
  static List<TorchNavSlot> slotsIn(
    AppLocalizations l10n, {
    int runningContests = 0,
  }) => <TorchNavSlot>[
    TorchNavSlot(
      icon: Icons.today_outlined,
      activeIcon: Icons.today,
      label: l10n.navToday,
    ),
    TorchNavSlot(
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2,
      label: l10n.navMyWork,
    ),
    TorchNavSlot(
      icon: Icons.map_outlined,
      activeIcon: Icons.map,
      label: l10n.navMap,
    ),
    TorchNavSlot(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: l10n.navMe,
      // The count the old Contests action carried (#124), kept on the slot
      // that now leads to Contests. A zero is not a badge: nothing running is
      // not news.
      badgeCount: runningContests > 0 ? runningContests : null,
      // A badge is a digit floating beside a glyph, so the sentence the old
      // tooltip said moves here or it is lost.
      semanticLabel: runningContests > 0
          ? l10n.contestsRunningHint(runningContests)
          : null,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final skin = context.skin;

    return TorchScope(
      skin: skin,
      phase: phase,
      navRenders: TorchShell.navWillRender(context, hasNav: true),
      tabbedRoute: true,
      claims: <TorchClaim>[
        if (hasNextStop)
          const TorchClaim.primaryCommit(TodayScreen.checkInClaimId),
        // Declared on every phase, granted on none that has a primary. Naming
        // it anyway is what makes the denial visible in
        // `TorchAllocation.describe()` rather than invisible in a widget that
        // quietly never asked.
        const TorchClaim.navCircle(TodayScreen.navCircleClaimId),
      ],
      child: TorchShell(
        profile: TorchShellProfile.agent,
        header: TorchAppHeader(
          title: l10n.todayTitle,
          // ONE compact fact line: the date and the route's name, middot
          // joined and read as a sentence. "Donderdag 18 September · Tembisa
          // run" is what the approved header says, and the plan's name is the
          // second half of the only question this screen answers.
          facts: <String>[
            formatDayHeading(context, DateTime.now()),
            if (routeName != null && routeName!.isNotEmpty) routeName!,
          ],
          // Exactly one trailing icon button, and on a tab root that one is
          // the skin cycle (unify §1.2). The sync chip is not an icon button
          // and does not compete for the slot — it is pinned right of the
          // title on the title row, which is the shell's own anatomy. It used
          // to go in the flag-chip wrap, where it took a 48dp row plus a 16dp
          // gap of its own under the date: 64dp of a 640dp fold, every
          // session, to say "All sent".
          status: const TorchSyncChip(),
          trailing: skinCycleIconButton(context, ref),
        ),
        navPill: TorchNavPill(
          slots: slotsIn(
            l10n,
            runningContests: ref.watch(runningContestsCountProvider).value ?? 0,
          ),
          activeIndex: todaySlot,
          onSelect: (i) => go(context, i),
        ),
        navCircle: TorchNavCircle(
          claimId: TodayScreen.navCircleClaimId,
          // Honest: it is the expected next move exactly when there is no
          // store on the plan left to walk into.
          expected: !hasNextStop,
          icon: Icons.add,
          expectedIcon: Icons.arrow_forward,
          semanticLabel: l10n.todayVisitAnotherStore,
          expectedSemanticLabel: l10n.todayPickStore,
          onPressed: () => context.go('/audit'),
        ),
        // Whether the agent is being located has an answer on every agent
        // screen (#153, POPIA) — see AgentLocationBanners.
        children: <Widget>[const AgentLocationBanners(), ...children],
      ),
    );
  }

  /// The slot indices, named. Every agent tab root reads [slotsIn] and [go]
  /// from here, so the bar is one list in one place — two screens that each
  /// wrote their own `case 2:` is how a nav bar starts sending the same tab to
  /// two destinations.
  static const int todaySlot = 0;
  static const int myWorkSlot = 1;
  static const int mapSlot = 2;
  static const int meSlot = 3;

  /// Where each slot goes. `go`, never `push`: a tab is a destination, not a
  /// page on top of the one the agent was reading.
  static void go(BuildContext context, int index) {
    switch (index) {
      case todaySlot:
        context.go('/today');
      case myWorkSlot:
        context.go('/my-work');
      case mapSlot:
        context.go('/map');
      // The agent's own record (#383/#384), and inside it their contests
      // (#124). Self-scoped end to end: every endpoint behind it reads the
      // agent id off the token.
      case meSlot:
        context.go('/me');
    }
  }
}

/// The route itself.
class _Route extends ConsumerWidget {
  const _Route({required this.route});

  final TodayRoute route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final skin = context.skin;
    final next = route.next;
    final rest = <RouteStop>[
      for (final stop in route.stops)
        if (next == null || stop.outlet.id != next.outlet.id) stop,
    ];

    return TodayFrame(
      phase: route.isComplete ? 'route-done' : 'loaded',
      hasNextStop: next != null,
      routeName: route.planName,
      children: <Widget>[
        _DayBlock(route: route),
        const SizedBox(height: TiqSpace.s7),

        // NEXT UP. The section disappears when the route is done rather than
        // showing an empty card — there is no next store, and a card that
        // says so is a card about nothing.
        if (next != null) ...<Widget>[
          SectionRule(l10n.todayNextUpHeading),
          const SizedBox(height: TiqSpace.s5),
          _NextUpCard(stop: next, hasLocation: route.hasLocation),
          const SizedBox(height: TiqSpace.s7),
        ],

        if (rest.isNotEmpty) ...<Widget>[
          SectionRule(
            next == null
                ? l10n.todayYourRouteHeading
                : l10n.todayRestOfDayHeading,
          ),
          const SizedBox(height: TiqSpace.s5),
          // A row owns its own gutter and draws its rule inset to the text
          // edge, so the list goes out to the screen's edges.
          TorchBleed(
            extra: skin.space.gutter * 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final (i, stop) in rest.indexed)
                  _StopRow(
                    stop: stop,
                    hasLocation: route.hasLocation,
                    last: i == rest.length - 1,
                  ),
              ],
            ),
          ),
          const SizedBox(height: TiqSpace.s5),
        ],

        // The plan is a plan, not a cage. A store can be shut, or a manager
        // can phone with something urgent. This row deliberately duplicates
        // the nav circle, because a circle is not discoverable.
        TorchBleed(
          extra: skin.space.gutter * 2,
          child: SoftRow(
            key: const ValueKey<String>('visit-another'),
            title: l10n.todayVisitAnotherStore,
            leading: const Icon(Icons.add, size: 20),
            trailing: const SoftRowChevron(),
            separator: SoftRowSeparator.none,
            onTap: () => context.go('/audit'),
          ),
        ),
      ],
    );
  }
}

/// THE DAY BLOCK — a standalone soft surface carrying the whole day.
///
/// Radius 14, `surface` fill, a 1px `edgeStructure` rim: it is a standalone
/// row's material, built here rather than through `SoftRow` because its
/// content is a figure cluster and a track, not a title over a subtitle.
class _DayBlock extends StatelessWidget {
  const _DayBlock({required this.route});

  final TodayRoute route;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final done = route.doneCount;
    final complete = route.isComplete;

    return Semantics(
      container: true,
      label: l10n.todayRouteSemantics(done, route.total, route.remaining),
      excludeSemantics: true,
      child: Container(
        key: const ValueKey<String>('day-block'),
        padding: const EdgeInsets.all(TiqSpace.s4),
        decoration: BoxDecoration(
          color: skin.palette.surface,
          borderRadius: BorderRadius.circular(skin.radii.panel),
          border: Border.all(
            color: skin.palette.edgeStructure,
            width: skin.depth.borderWidth,
          ),
          boxShadow: skin.depth.shadows,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Eyebrow(l10n.todayRouteEyebrow),
            const SizedBox(height: TiqSpace.s3),
            // One baseline in a Wrap: at 2.0× the figure and its unit stack
            // instead of the figure shrinking or the unit truncating.
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: TiqSpace.s2,
              runSpacing: TiqSpace.s2,
              children: <Widget>[
                // `figure.l` and not `display`: the design calls for "mono
                // display 40/600" and there is no declared FIGURE role at 40 —
                // display is a prose role, and `FigureSlot` asserts on one.
                // The nearest declared figure is 32, and it steps down to 24
                // under the measured fit rather than shrinking optically.
                FigureSlot(
                  value: done,
                  role: skin.text.figureL,
                  fit: <TiqTypeToken>[skin.text.figureL, skin.text.figureM],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: TiqSpace.s1),
                  child: Text(
                    l10n.todayStoresOfTotal(route.total),
                    style: skin.text.titleM.style(color: skin.palette.ink2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: TiqSpace.s1),
                  // Never the bar alone: the state is a word on a chip with a
                  // silhouette, which is what survives greyscale and glare.
                  child: StatusChip(
                    level: complete ? StatusLevel.onTarget : StatusLevel.held,
                    label: complete
                        ? l10n.todayRouteDone
                        : l10n.todayStoresLeft(route.remaining),
                  ),
                ),
              ],
            ),
            const SizedBox(height: TiqSpace.s4),
            Meter(
              value: route.total == 0 ? 0 : done / route.total * 100,
              semanticsValue: l10n.todayRouteSemantics(
                done,
                route.total,
                route.remaining,
              ),
            ),
            if (!route.hasLocation) ...<Widget>[
              const SizedBox(height: TiqSpace.s3),
              Text(
                // Not "location error". The agent turned it off, or the phone
                // cannot see the sky. Either way the route still works — and
                // no row on it will show a distance.
                l10n.todayDistancesOff,
                style: skin.text.meta.style(color: skin.palette.ink3),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// THE NEXT STORE — a standalone row with the screen's one commit on it.
class _NextUpCard extends StatelessWidget {
  const _NextUpCard({required this.stop, required this.hasLocation});

  final RouteStop stop;
  final bool hasLocation;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;

    return Container(
      key: const ValueKey<String>('next-stop'),
      padding: const EdgeInsets.all(TiqSpace.s4),
      decoration: BoxDecoration(
        color: skin.palette.surface,
        borderRadius: BorderRadius.circular(skin.radii.panel),
        border: Border.all(
          color: skin.palette.edgeStructure,
          width: skin.depth.borderWidth,
        ),
        boxShadow: skin.depth.shadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // The meta line, at the sizes the surface declares: the sequence in
          // mono 16 and the distance in the small mono role beside it. It was
          // `figure.m` (22) over `figure.s` (16) — a sequence number set
          // larger than the day block's unit and nearly as large as the store
          // name it belongs to.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: TiqSpace.s2,
            runSpacing: TiqSpace.s1,
            children: <Widget>[
              _SequenceFigure(sequence: stop.sequence),
              _DistanceFigure(stop: stop, role: skin.text.axisLabel),
            ],
          ),
          const SizedBox(height: TiqSpace.s3),
          Text(
            stop.outlet.name,
            maxLines: 2,
            style: skin.text.titleL.style(color: skin.palette.ink1),
          ),
          const SizedBox(height: TiqSpace.s1),
          Text(
            stop.outlet.code,
            style: skin.text.monoIdent.style(color: skin.palette.ink3),
          ),
          const SizedBox(height: TiqSpace.s4),
          // THE SCREEN'S AMBER. A primary on a tab root lives in the BODY,
          // never in a thumb zone the nav already occupies.
          TorchPrimaryButton(
            key: const ValueKey<String>('check-in-next'),
            claimId: TodayScreen.checkInClaimId,
            label: l10n.todayCheckInHere,
            icon: Icons.chevron_right,
            onPressed: () => context.go('/audit/${stop.outlet.id}'),
          ),
        ],
      ),
    );
  }
}

/// One later stop.
class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.stop,
    required this.hasLocation,
    required this.last,
  });

  final RouteStop stop;
  final bool hasLocation;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final done = stop.visited;

    return SoftRow(
      key: ValueKey<String>('stop-${stop.outlet.id}'),
      title: stop.outlet.name,
      // An outlet name middle-truncates, so the branch survives when the
      // chain does not: "Pick n Pay …Vosloorus" beats "Pick n Pay Liber…".
      titleTruncation: SoftRowTruncation.middle,
      subtitle: stop.outlet.code,
      leading: _SequenceTile(sequence: stop.sequence, done: done),
      trailing: _StopTrailing(stop: stop, done: done),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: l10n.todayStopSemantics(
        stop.outlet.name,
        stop.outlet.code,
        done ? l10n.todayStopDoneTag : l10n.todayStopUpcoming,
      ),
      // Tapping a later stop starts a check-in there too. The plan is a plan,
      // not a cage.
      onTap: () => context.go('/audit/${stop.outlet.id}'),
    );
  }
}

/// The sequence badge: the number in mono, or a tick once the stop is done.
class _SequenceTile extends StatelessWidget {
  const _SequenceTile({required this.sequence, required this.done});

  final int sequence;
  final bool done;

  @override
  Widget build(BuildContext context) {
    if (done) {
      return const SectionStateGlyph(state: SectionState.done);
    }
    final skin = context.skin;
    final tile = MarkScale.tile(context);
    return Container(
      width: tile,
      height: tile,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(skin.radii.chip),
        border: Border.all(
          color: skin.palette.edgeControl,
          width: skin.depth.borderWidth,
        ),
      ),
      child: FigureSlot(
        value: sequence,
        role: skin.text.figureS,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// `03` in mono 16, for the next-up card's meta line. The surface says 16/500
/// here; it is the card's smallest voice, not its loudest.
class _SequenceFigure extends StatelessWidget {
  const _SequenceFigure({required this.sequence});

  final int sequence;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return FigureSlot(
      value: sequence,
      role: skin.text.figureS,
      semanticsLabel: context.l10n.todayStopNumber('$sequence'),
    );
  }
}

/// The trailing column of a stop row: the distance over a state word.
class _StopTrailing extends StatelessWidget {
  const _StopTrailing({required this.stop, required this.done});

  final RouteStop stop;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _DistanceFigure(stop: stop, role: skin.text.figureS),
        Text(
          done ? l10n.todayStopDoneTag : l10n.todayStopUpcoming,
          style: skin.text.meta.style(color: skin.palette.ink3),
        ),
      ],
    );
  }
}

/// A distance, or nothing at all.
///
/// There is no third case. The formatter owns the digits, the grouping and
/// the decimal mark; this widget owns only the choice of unit word — and the
/// decision that an unknown distance renders **nothing here** rather than an
/// em dash, because the day block has already said in one sentence why every
/// distance on the screen is missing and repeating it eleven times as a dash
/// is noise.
class _DistanceFigure extends StatelessWidget {
  const _DistanceFigure({required this.stop, required this.role});

  final RouteStop stop;
  final TiqTypeToken role;

  @override
  Widget build(BuildContext context) {
    final distance = stop.distance;
    if (distance == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    return FigureSlot(
      value: distance.value,
      role: role,
      decimals: distance.decimals,
      unit: TiqUnit.worded(
        distance.kilometres ? l10n.unitKilometres : l10n.unitMetres,
      ),
      semanticsLabel: distance.kilometres
          ? l10n.todayDistanceKmSemantics(distance.value)
          : l10n.todayDistanceMetresSemantics(distance.value.round()),
    );
  }
}

/// A headline, a sentence and one real next step.
///
/// The empty-state grammar: left-aligned to the gutter and never centred, a
/// 64px line drawing from the closed enum, display type under the line-count
/// fitting rule, and a button that is the actual next action rather than
/// "Refresh". No animation — an empty screen that animates is asking for
/// attention it has not earned.
class _TodayMessage extends StatelessWidget {
  const _TodayMessage({
    required this.headline,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    required this.glyph,
  });

  final String headline;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;
  final IconData glyph;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: TiqSpace.s6),
        ExcludeSemantics(
          child: Icon(glyph, size: 64, color: skin.palette.edgeControl),
        ),
        const SizedBox(height: TiqSpace.s6),
        Semantics(
          header: true,
          child: Text(
            headline,
            style: displayFor(
              context,
              headline,
            ).style(color: skin.palette.ink1),
          ),
        ),
        const SizedBox(height: TiqSpace.s3),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            body,
            style: skin.text.body.style(color: skin.palette.ink2),
          ),
        ),
        const SizedBox(height: TiqSpace.s6),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TorchSecondaryButton(label: actionLabel, onPressed: onAction),
        ),
      ],
    );
  }
}

/// The display fitting rule, keyed to LINE COUNT after layout.
///
/// unify §1.12 and the agent surface's empty-state grammar: **1–2 lines stay
/// at 40, 3 lines step to 32, 4 or more to 26, floor 26.** Display prose was
/// the one type role with no fitting rule while `hero.figure` had one keyed to
/// glyph count, and an Afrikaans headline at 2.0× ate the screen.
///
/// ## What this used to do, and why it was not the rule
///
/// It stepped *display → title.l → title.m*, returning the first role that
/// laid out in two lines or fewer. Two things were wrong with that. The scale
/// it stepped through was 40 → 24 → 16, not the declared 40 → 32 → 26: a
/// three-line Afrikaans headline landed at `title.l`, which is the role an
/// outlet name wears inside a card, so the screen's one headline was set
/// smaller than the store name two blocks under it. And it was keyed to "does
/// this role fit in two lines", which is a search, not the rule — the rule
/// counts the lines the *display* role takes and picks the step from that
/// count, so the same string always resolves to the same size no matter which
/// roles happen to exist between them.
///
/// The measurement is against the body's own width at the live scaler, and it
/// lives here rather than in the type scale because only whole-screen states
/// use it.
TiqTypeToken displayFor(BuildContext context, String headline) {
  final skin = context.skin;
  final width = MediaQuery.sizeOf(context).width - skin.space.gutter * 2;
  final scaler = MediaQuery.textScalerOf(context);
  final painter = TextPainter(
    text: TextSpan(text: headline, style: skin.text.display.style()),
    textDirection: Directionality.of(context),
    textScaler: scaler,
  )..layout(maxWidth: width);
  final lines = painter.computeLineMetrics().length;
  painter.dispose();
  return switch (lines) {
    <= 2 => skin.text.display,
    3 => skin.text.displayM,
    _ => skin.text.displayS,
  };
}

/// The skeleton: the real geometry, empty. Not a spinner, and not a `well`
/// block at 1.12:1 that nobody can see.
class _TodaySkeleton extends StatelessWidget {
  const _TodaySkeleton();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    Widget block(double height) => Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(skin.radii.panel),
        border: Border.all(
          color: skin.palette.edgeStructure,
          width: skin.depth.borderWidth,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        block(128),
        const SizedBox(height: TiqSpace.s7),
        block(176),
        const SizedBox(height: TiqSpace.s7),
        for (var i = 0; i < 3; i++) ...<Widget>[
          SizedBox(
            height: TiqSpace.s5,
            child: ColoredBox(color: skin.palette.edgeStructure),
          ),
          const SizedBox(height: TiqSpace.s6),
        ],
      ],
    );
  }
}
