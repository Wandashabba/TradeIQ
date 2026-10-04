import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/agent_skin.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/agent_location_banners.dart';
import '../../../core/widgets/torchlight/agent_wash.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/card.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
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
///   │ 4  of 11 stores                   7 left  │
///   │ ▬▬▬▬▬▬▬▬▬░░░░░░░░░░░░░░░░                 │
///   └───────────────────────────────────────────┘
///   ── Next up ─────────────────────────────────
///   ┌───────────────────────────────────────────┐
///   │ ▢3  Kasi Corner Spaza                     │
///   │     KC-0412 · 1,2 km                      │
///   │ ███████ Check in here ████████            │
///   └───────────────────────────────────────────┘
///   ── The rest of the day ─────────────────────
///   ▢4  Sunrise Spaza      KC-0413 · 2,1 km
///   ▢5  Khumalo Superette  KS-0014 · 3,4 km
///   [ nav pill ] ( + )
/// ```
///
/// ## The composition is the mockup's, since 29 September 2026
///
/// The owner, looking at the running screen: *"Literally you didnt change
/// anything"*, and then, re-sending the approved mockup, *"please focus"*.
/// Three things moved, and none of them is a radius — the point of the note
/// was that fixing corners inside the wrong layout does not answer it:
///
/// * **The figure leads its card.** The `ROUTE` eyebrow is gone; the mockup
///   opens on the count, on a screen whose header already says Today and
///   whose date line already names the plan. "Distances are off — this phone
///   will not say where it is" is a real state the mockup never had to show
///   and it stays, but on its own line under the meter at meta/ink-3 rather
///   than joined to "7 left" by a middot on the figure's own baseline.
/// * **A stop is a tile and a name on one row.** Next-up stacked a bare
///   numeral, a `title.l` name, the code and the button — a heading block.
///   It is now the same anatomy as the rows under it, at row scale.
/// * **One tile object for every stop number**, filled, at the radius the
///   state glyph and the row marks took the same day.
///
/// ## The two ambers, counted — and the mockup's four
///
/// A tab root, so the nav pill's active tab is object 1 whenever the nav
/// renders and the content has exactly one grant left. It goes to
/// **"Check in here"** — the one thing the agent is about to do, and since 29
/// September a *filled* amber block rather than a rimmed dark one
/// (`TorchPrimaryButton.filled`). The nav circle declares rung 4 honestly and
/// the allocator denies it outright (`circleWithPrimary`), so the light never
/// moves while a thumb scrolls.
///
/// The mockup lights **four** objects here: that CTA, the nav circle, the next
/// stop's glyph tile (`rgba(255,177,98,0.16)` under a `#FFCB94` numeral, which
/// is flame-700 and inside the census's flame box) and the progress fill
/// (`#FFB162`). The law came later and is stricter, and it is not a matter of
/// taste which two survive: the allocator's rungs decide it. The tile and the
/// bar declare no claim at all, so they take their neutral forms — `raised`
/// and `chartNeutral` — and the circle is denied by rank, not by budget.
///
/// When the route is done there is no next stop and therefore no primary, and
/// the circle takes the grant instead: *start a visit somewhere else* is then
/// genuinely the expected next move. On Day the ladder has one rung and the
/// circle is denied there too, so a finished route carries **zero** amber —
/// which is correct, because nothing is armed.
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
                // gets its own HEADLINE and not only its own sentence. The
                // two used to share "No route planned for today", which is
                // untrue of a plan that exists and has no stops on it, and
                // which at the top of the display ladder, under the fitting
                // rule, ran to two lines and took the fold with it. Both headlines here are the ones
                // the agent surface names for these two states.
                headline: route == null
                    ? l10n.todayNoRouteTitle
                    : l10n.todayEmptyPlanTitle,
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
    final wash = ref.watch(agentWashDirectionProvider);

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
        // THE BACK SHADE, and the flag that lets the fade coexist with it.
        // See `agent_wash.dart`: top-anchored Dawn reaches zero alpha at
        // t = 0.3248 of the screen, and the scrim band begins at t ≥ 0.831.
        // The direction and the flag come from one place so they cannot
        // disagree; the provider is constant in the app.
        backdrop: agentWashFor(skin, wash),
        backdropClearsScrim: agentWashClearsScrim(wash),
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
          // NO TRAILING ICON BUTTON — 4 October 2026. The skin cycle was the
          // one object in this slot on all four tab roots, and it moved into
          // Me's `THIS APP` block (`my_record_screen.dart`), which is where
          // the manager's own theme control lives. An appearance preference is
          // a setting, and a setting on four title rows is a setting nobody
          // has a home for.
          //
          // The sync chip is not an icon button and never competed for the
          // slot — it is pinned right of the title on the title row, which is
          // the shell's own anatomy. It used to go in the flag-chip wrap,
          // where it took a 48dp row plus a 16dp gap of its own under the
          // date: 64dp of a 640dp fold, every session, to say "All sent".
          status: const TorchSyncChip(),
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
        SizedBox(height: skin.space.blockGap),

        // NEXT UP. The section disappears when the route is done rather than
        // showing an empty card — there is no next store, and a card that
        // says so is a card about nothing.
        if (next != null) ...<Widget>[
          SectionRule(l10n.todayNextUpHeading),
          const SizedBox(height: TiqSpace.s5),
          _NextUpCard(stop: next, hasLocation: route.hasLocation),
          SizedBox(height: skin.space.blockGap),
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
          SizedBox(height: skin.space.blockGap),
        ],

        // The plan is a plan, not a cage. A store can be shut, or a manager
        // can phone with something urgent. This row deliberately duplicates
        // the nav circle, because a circle is not discoverable.
        TorchBleed(
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
/// **A card, since 26 September 2026.** It was a hand-built radius-14 panel
/// with an `edgeStructure` rim and `skin.depth.shadows`, and it stacked six
/// things: the eyebrow, the figure, the unit, a status chip, a meter and a
/// distances-off line. The Floor's grammar gives a figure block **one card and
/// at most four elements** — eyebrow, figure, one meta line, one visual — so
/// the chip and the note fold into the meta line and the track is the visual.
///
/// Nothing is lost by the fold. The chip carried a word and a silhouette; the
/// word is still here, in the same sentence as the distance note, and the
/// silhouette was saying what the track beneath it already draws. What goes is
/// the third and fourth *reads* of the same fact.
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
      child: TorchCard(
        key: const ValueKey<String>('day-block'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // NO EYEBROW, since 29 September 2026. The approved mockup's
            // route card opens on the figure — `4` at 30/700 with "of 9
            // stores" on its baseline — and puts no kick label above it. The
            // owner re-sent that mockup with the word "focus", and a card
            // whose first line is the word ROUTE on a screen whose header
            // already says Today and whose date line already names the plan
            // is the third statement of a fact made twice above it. The
            // figure leads.
            //
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
                // The nearest declared figure is `figure.l` at 32, and it
                // steps down to `figure.m` at 22 under the measured fit
                // rather than shrinking optically. (Both are figure roles and
                // neither moved in the 1 October 2026 prose reduction.)
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
                // THE ONE META LINE, ON THE FIGURE'S OWN BASELINE — which is
                // where The Floor puts its hero's delta, and what the chip
                // occupied here before. It says what the chip said and what
                // the distances note said, in one sentence: how much of the
                // day is left, and — only when it is true — that no row will
                // carry a distance.
                //
                // On the baseline and not on a line of its own, and that is
                // arithmetic rather than taste: a line of its own cost 25dp,
                // which on a 360×640 phone is the difference between the next
                // section marker being on the first fold and being under it.
                //
                Padding(
                  padding: const EdgeInsets.only(bottom: TiqSpace.s1),
                  child: Text(
                    complete
                        ? l10n.todayRouteDone
                        : l10n.todayStoresLeft(route.remaining),
                    style: skin.text.meta.style(color: skin.palette.ink2),
                  ),
                ),
              ],
            ),
            SizedBox(height: skin.space.intraBlock),
            // THE ONE VISUAL. `chartNeutral`, and not the mockup's amber
            // fill: the progress bar declares no claim, so under the ladder
            // it takes its neutral form — see the amber note on [TodayScreen].
            Meter(
              value: route.total == 0 ? 0 : done / route.total * 100,
              semanticsValue: l10n.todayRouteSemantics(
                done,
                route.total,
                route.remaining,
              ),
            ),
            // THE SENTENCE THE MOCKUP NEVER HAD TO SHOW.
            //
            // "Distances are off — this phone will not say where it is" is a
            // real state and it belongs on the screen, but it was joined to
            // "6 left" by a middot and run along the figure's own baseline,
            // where a 46-character sentence wrapped and swamped the count it
            // was standing beside. It is supporting text about the ROWS
            // BELOW — why none of them carries a distance — so it goes under
            // the card's visual, at meta, in ink-3, on its own line. The
            // 25dp that earlier arithmetic was protecting is bought back by
            // the eyebrow this card no longer carries.
            //
            // "Not location error": the agent turned it off, or the phone
            // cannot see the sky. Either way the route still works.
            if (!route.hasLocation) ...<Widget>[
              SizedBox(height: skin.space.intraBlock),
              Text(
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

/// THE NEXT STORE — the one store the agent is about to walk into, with the
/// screen's one commit on it.
///
/// **A card, since 29 September 2026.** It was the standalone row's material —
/// radius 14, `surface`, a 1px `edgeStructure` rim — and it sat between the day
/// block above it (a `TorchCard` since 26 September) and the stop rows below it
/// (radius-22 cards with no outline since the 25 September override). Three
/// grammars down one 390dp column, and the owner read the middle one as the
/// odd shape: *"the agent side is still rectangular"*.
///
/// It is a card and not a panel by the distinction [TiqRadii] draws: a panel is
/// a container and a card is an object. This is the same object as the rows
/// under it — a store on the plan — held one step apart by being the next one,
/// which is a difference in position and in what it carries, not in material.
class _NextUpCard extends StatelessWidget {
  const _NextUpCard({required this.stop, required this.hasLocation});

  final RouteStop stop;
  final bool hasLocation;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;

    return TorchCard(
      key: const ValueKey<String>('next-stop'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // THE STOP, ON ONE ROW. Tile, then name over identity — the same
          // anatomy as the rows beneath it, which is what makes this card
          // read as the first stop rather than as a heading block.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _SequenceTile(sequence: stop.sequence, done: false),
              const SizedBox(width: TiqSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      stop.outlet.name,
                      maxLines: 2,
                      style: skin.text.titleM.style(color: skin.palette.ink1),
                    ),
                    const SizedBox(height: TiqSpace.s1),
                    _StopIdentity(stop: stop),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: skin.space.intraBlock),
          // THE SCREEN'S AMBER. A primary on a tab root lives in the BODY,
          // never in a thumb zone the nav already occupies.
          //
          // FILLED and with no chevron, since 29 September 2026. The approved
          // mockup draws this control as a solid amber block with a centred
          // label — `background:#FFB162; color:#16202B; border-radius:16px`,
          // and 16 is `radii.control` already, so nothing about the geometry
          // moves. `filled` is scoped to this one call site and changes only
          // the Night granted form; see `TorchPrimaryButton.filled` for why
          // it is a parameter and not the new default.
          TorchPrimaryButton(
            key: const ValueKey<String>('check-in-next'),
            claimId: TodayScreen.checkInClaimId,
            label: l10n.todayCheckInHere,
            filled: true,
            onPressed: () => context.go('/audit/${stop.outlet.id}'),
          ),
        ],
      ),
    );
  }
}

/// `KC-0412 · 1,2 km` — the identity line under a stop's name.
///
/// The code is its own `Text` and the distance is its own [FigureSlot], joined
/// by a middot: a distance is a figure or it is nothing, so it cannot be
/// interpolated into a string here. Where the phone will not say where it is
/// there is no distance and no middot, and the day block has already said in
/// one sentence why.
class _StopIdentity extends StatelessWidget {
  const _StopIdentity({required this.stop});

  final RouteStop stop;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ink = skin.palette.ink3;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: TiqSpace.s2,
      runSpacing: TiqSpace.s1,
      children: <Widget>[
        Text(
          stop.outlet.code,
          style: skin.text.monoIdent.style(color: ink),
        ),
        if (stop.distance != null) ...<Widget>[
          Text('·', style: skin.text.meta.style(color: ink)),
          _DistanceFigure(stop: stop, role: skin.text.axisLabel),
        ],
      ],
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
      // THE IDENTITY LINE, and nothing in the trailing lane. It was the code
      // as a subtitle with a two-line trailing column beside it — the
      // distance over the word "To do" — and the mockup carries neither: the
      // ordinal tile and the row's position in the list already say a stop is
      // still to come, and the distance belongs next to the code it qualifies
      // rather than in a column of its own. The words are not lost; they are
      // in `semanticsLabel`, which is where a screen reader was always going
      // to hear them.
      meta: _StopIdentity(stop: stop),
      leading: _SequenceTile(sequence: stop.sequence, done: done),
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

/// THE STOP NUMBER — one object, on every stop on the screen.
///
/// **Filled, since 29 September 2026.** There were two of these and neither
/// was the mockup's: a bare mono numeral inside the Next-up card, and an
/// outlined `radii.chip` square down the leading lane of the rest of the day.
/// The mockup has one object for both — `.glyph`, 30 × 30, `border-radius:
/// 11px`, a filled tint and no border — and the owner re-sent it saying
/// "focus". So it is the same tile [SectionStateGlyph] and [RowMarkTile]
/// became on the same day: [MarkScale.tile] square, [torchGlyphTileRadius],
/// `raised`, no outline, the numeral in ink-2.
///
/// ## It is NOT amber, and the mockup's is
///
/// The mockup tints the next stop's tile `rgba(255,177,98,0.16)` with a
/// `#FFCB94` numeral. `#FFCB94` was flame-700 — hue 30.8°, value 1.00; the
/// token is `#FFC180` at hue 30.7° and the same value since the ramp gained
/// chroma on 1 October 2026, and either way it is a flame-700 — which
/// is inside the census's flame box, so that numeral is a **lit object**, and
/// it is the fourth on a screen the law allows two. It declares no claim, so
/// it takes its neutral form; see the amber note on [TodayScreen] for the
/// whole allocation. The next stop is told apart from the rest by being in a
/// card of its own with the screen's one commit under it, which is a stronger
/// signal than a 16% tint.
class _SequenceTile extends StatelessWidget {
  const _SequenceTile({required this.sequence, required this.done});

  final int sequence;
  final bool done;

  @override
  Widget build(BuildContext context) {
    // A done stop is the section glyph's tick disc — already this exact tile
    // in `good`'s own wash, at this exact radius, since 29 September 2026.
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
        color: skin.palette.raised,
        borderRadius: BorderRadius.circular(torchGlyphTileRadius),
      ),
      child: FigureSlot(
        value: sequence,
        role: skin.text.figureS,
        textAlign: TextAlign.center,
        semanticsLabel: context.l10n.todayStopNumber('$sequence'),
      ),
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
        SizedBox(height: skin.space.blockGap),
        ExcludeSemantics(
          child: Icon(glyph, size: 64, color: skin.palette.edgeControl),
        ),
        SizedBox(height: skin.space.blockGap),
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
        SizedBox(height: skin.space.intraBlock),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            body,
            style: skin.text.body.style(color: skin.palette.ink2),
          ),
        ),
        SizedBox(height: skin.space.blockGap),
        // LEFT-ALIGNED AT ITS NATURAL WIDTH.
        //
        // The empty-state grammar says "one secondary button, 56dp,
        // left-aligned at its natural width". It was full width everywhere: a
        // ghost action stretched across the screen reads as the commit this
        // state deliberately does not have.
        //
        // `IntrinsicWidth` and not `Align(widthFactor:)`: the button's label
        // sits in a `Center`, which expands to whatever width it is offered,
        // so an Align around it still yields a full-width button. This is one
        // button in a state with nothing else in it, not a row in a list.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: IntrinsicWidth(
            child: TorchSecondaryButton(
              label: actionLabel,
              onPressed: onAction,
            ),
          ),
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
    // THE SKELETON KEEPS THE OUTLINE, and it is the one place on this screen
    // that still does. unify §1.11 is explicit — "rows and panels are their
    // real outline at their real geometry, empty" — and the reason is the
    // device floor: a `surface` block on the Night ground is 1.49:1, which is
    // one quantisation level on a 6-bit panel at 40% backlight, so a filled
    // card with no edge is a skeleton nobody can see. The blocks arriving are
    // cards; their placeholder is drawn at the edge you can actually find.
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
        SizedBox(height: skin.space.blockGap),
        block(176),
        SizedBox(height: skin.space.blockGap),
        for (var i = 0; i < 3; i++) ...<Widget>[
          SizedBox(
            height: TiqSpace.s5,
            child: ColoredBox(color: skin.palette.edgeStructure),
          ),
          SizedBox(height: skin.space.blockGap),
        ],
      ],
    );
  }
}
