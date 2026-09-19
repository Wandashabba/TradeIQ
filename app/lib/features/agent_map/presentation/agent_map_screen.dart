import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/agent_skin.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/bleed.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/marks.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../core/widgets/torchlight/sheet.dart';
import '../../../core/widgets/torchlight/skin_controls.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../core/widgets/torchlight/sync_status.dart';
import '../../../l10n/l10n.dart';
import '../../beatplans/data/today_route.dart' show RouteDistance;
import '../../beatplans/presentation/today_screen.dart' show TodayFrame;
import '../../contests/data/contests_repository.dart';
import '../data/agent_map.dart';
import 'outlet_map.dart';
import 'outlet_sheet.dart';

/// MAP — where the agent's stores are.
///
/// ```text
///   Map                         [ 12 held on this phone ]  [ ☾ ]
///   3 stores on today's route · 14 in your patch
///   ┌───────────────────────────────────────────┐
///   │                  ◎ you                    │
///   │        ✓            ▲                     │   ← the basemap
///   │              □           □                │
///   └───────────────────────────────────────────┘
///   ✓ Visited today  ▲ Next up  ○ On today's route  □ In your patch
///   ── Today's route 3 ─────────────────────────
///   ▏✓ Kasi Corner Spaza   KC-0412    Visited today   420 m
///   ▏▲ Sunrise Spaza       SS-0221    Next up         1,2 km
///   ── The rest of your patch 14 ───────────────
///   ▏□ Khumalo Superette   KS-0014    In your patch   3,4 km
///   [ nav pill ] ( + )
/// ```
///
/// ## Why the list is not a second-class citizen
///
/// The list under the map is not a fallback. It is the same set of stores in
/// the same order, and it is what the screen becomes in the three conditions
/// that are ordinary rather than exceptional in this product: **Veld** (maps
/// do not render outdoors — unify §4), **offline** (the tiles never arrive on
/// a rural forecourt), and **a short screen at 2.0× text** (the map's fold
/// budget goes to zero before the list does). Everything a marker can do, a
/// row can do — including opening the sheet — so none of those three is a
/// degraded screen.
///
/// ## The two ambers, counted
///
/// A tab root, so the nav pill's active tab is object 1 whenever the nav
/// renders and the content has exactly one grant left. There is **no primary
/// commit on this screen** — checking in happens in a store's sheet, which is
/// an untabbed surface that extinguishes everything beneath it — so the one
/// content grant is declared by the **nav circle** and painted only when the
/// circle is the expected next move: when the phone says the agent is standing
/// inside one of their own stores' check-in fences. Night is therefore 1 or 2;
/// Day and Veld are 0, because on a light ground only a primary commit block
/// may be amber and this screen has none.
///
/// The claim set does not depend on the fix. It is declared on every phase, so
/// a GPS fix arriving can change which *glyph* the circle wears but never
/// which objects are allocated — a grant that moved when a satellite appeared
/// is a grant that blinks.
///
/// ## Scope is the server's job
///
/// The stores are `GET /outlets?mine=true`: the server narrows to the
/// territories assigned to the caller's own user id. The app never takes a
/// tenant-wide list and filters it. See `myTerritoryOutletsProvider`, and the
/// PR for what that endpoint still cannot do.
class AgentMapScreen extends ConsumerWidget {
  const AgentMapScreen({super.key});

  /// The nav circle's id. Declared on every phase; painted only when the agent
  /// is standing in one of their stores.
  static const String navCircleClaimId = 'map-check-in-here';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const TorchlightRoute(child: _AgentMap());
  }
}

class _AgentMap extends ConsumerWidget {
  const _AgentMap();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mapAsync = ref.watch(agentMapProvider);

    return mapAsync.when(
      loading: () => const AgentMapFrame(
        phase: 'loading',
        atDoor: null,
        storeCount: null,
        children: <Widget>[_MapSkeleton()],
      ),
      // A load failure keeps the chrome and says what still works. Picking a
      // store by name needs neither this screen's data nor a map.
      error: (error, stack) => AgentMapFrame(
        phase: 'error',
        atDoor: null,
        storeCount: null,
        children: <Widget>[
          ErrorState(
            message: TorchErrorMessage(
              kind: TorchErrorKind.network,
              headline: l10n.mapLoadErrorTitle,
              body: l10n.mapLoadErrorDetail,
              offersRetry: false,
            ),
            action: TorchSecondaryButton(
              label: l10n.todayPickStore,
              onPressed: () => context.go('/audit'),
            ),
          ),
        ],
      ),
      data: (view) {
        if (view.pins.isEmpty) {
          return AgentMapFrame(
            phase: 'empty',
            atDoor: null,
            storeCount: 0,
            children: <Widget>[
              EmptyState(
                headline: l10n.mapEmptyTitle,
                drawing: EmptyDrawing.pin,
                body: l10n.mapEmptyBody,
                action: TorchSecondaryButton(
                  label: l10n.todayPickStore,
                  onPressed: () => context.go('/audit'),
                ),
              ),
            ],
          );
        }
        return _Stores(view: view);
      },
    );
  }
}

/// The frame every state of this route wears.
class AgentMapFrame extends ConsumerWidget {
  const AgentMapFrame({
    super.key,
    required this.phase,
    required this.atDoor,
    required this.storeCount,
    required this.children,
  });

  final String phase;

  /// The store the agent is standing inside, if any. It decides the circle's
  /// glyph, its label and its destination — one value, so the three cannot
  /// disagree.
  final MapOutlet? atDoor;

  /// How many of the agent's stores this screen is about. Null while unknown —
  /// and a header fact that is unknown is absent, never a zero.
  final int? storeCount;

  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final skin = context.skin;
    final door = atDoor;

    return TorchSheetAware(
      builder: (context, beneathSheet) => TorchScope(
        skin: skin,
        phase: phase,
        navRenders: TorchShell.navWillRender(context, hasNav: true),
        tabbedRoute: true,
        // While a store's sheet is up, every amber on this route goes out —
        // the nav tab included — so the sheet's own "Check in here" is the
        // only lit object on the screen.
        beneathSheet: beneathSheet,
        claims: const <TorchClaim>[
          TorchClaim.navCircle(AgentMapScreen.navCircleClaimId),
        ],
        child: TorchShell(
          profile: TorchShellProfile.agent,
          header: TorchAppHeader(
            title: l10n.mapTitle,
            facts: <String>[
              if (storeCount != null) l10n.mapStoresFact(storeCount!),
            ],
            trailing: skinCycleIconButton(context, ref),
            flagChips: const <Widget>[TorchSyncChip()],
          ),
          navPill: TorchNavPill(
            slots: TodayFrame.slotsIn(
              l10n,
              runningContests: ref.watch(runningContestsCountProvider).value ?? 0,
            ),
            activeIndex: TodayFrame.mapSlot,
            onSelect: (i) => TodayFrame.go(context, i),
          ),
          navCircle: TorchNavCircle(
            claimId: AgentMapScreen.navCircleClaimId,
            // Honest: standing inside a store's own check-in fence is the one
            // condition under which "check in" is the move rather than an
            // offer.
            expected: door != null,
            icon: Icons.add,
            expectedIcon: Icons.arrow_forward,
            semanticLabel: l10n.todayPickStore,
            expectedSemanticLabel: door == null
                ? l10n.todayPickStore
                : l10n.mapCircleAtDoor(door.outlet.name),
            onPressed: () => context.go(
              door == null ? '/audit' : '/audit/${door.outlet.id}',
            ),
          ),
          children: children,
        ),
      ),
    );
  }
}

/// The stores: the map, the legend, and the two lists.
class _Stores extends ConsumerWidget {
  const _Stores({required this.view});

  final AgentMapView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final skin = context.skin;
    final drawn = view.drawn;
    final planned = <MapOutlet>[
      for (final pin in drawn) if (pin.state != MapPinState.territory) pin,
    ];
    final rest = <MapOutlet>[
      for (final pin in drawn) if (pin.state == MapPinState.territory) pin,
    ];
    final bleed = skin.space.gutter * 2;

    return AgentMapFrame(
      phase: 'loaded',
      atDoor: view.atDoor,
      storeCount: view.pins.length,
      children: <Widget>[
        // THE MAP. Full-bleed, a fixed fold-budget height, and absent
        // altogether in Veld and on a screen too short to give it one.
        AgentOutletMap(view: view),
        const SizedBox(height: TiqSpace.s5),

        // Why the phone will not say where things are. One sentence, once —
        // not an em dash on every row.
        if (view.problem != null) ...<Widget>[
          Text(
            switch (view.problem!) {
              MapLocationProblem.denied => l10n.mapLocationDenied,
              MapLocationProblem.servicesOff => l10n.mapLocationServicesOff,
              MapLocationProblem.timedOut ||
              MapLocationProblem.failed => l10n.mapLocationNoFix,
            },
            style: skin.text.body.style(color: skin.palette.ink2),
          ),
          const SizedBox(height: TiqSpace.s5),
        ],

        SectionRule(
          l10n.mapRouteHeading,
          count: planned.isEmpty ? null : planned.length,
          emptyLine: planned.isEmpty ? l10n.mapRouteEmptyLine : null,
        ),
        if (planned.isNotEmpty) ...<Widget>[
          const SizedBox(height: TiqSpace.s5),
          TorchBleed(
            extra: bleed,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final (i, pin) in planned.indexed)
                  OutletRow(pin: pin, last: i == planned.length - 1),
              ],
            ),
          ),
        ],
        const SizedBox(height: TiqSpace.s7),

        if (rest.isNotEmpty) ...<Widget>[
          SectionRule(l10n.mapPatchHeading, count: rest.length),
          const SizedBox(height: TiqSpace.s5),
          TorchBleed(
            extra: bleed,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final (i, pin) in rest.indexed)
                  OutletRow(pin: pin, last: i == rest.length - 1),
              ],
            ),
          ),
        ],

        // The marker budget, said out loud. A capped list that does not say it
        // is capped is a list that has quietly lost stores.
        if (view.hidden > 0) ...<Widget>[
          const SizedBox(height: TiqSpace.s5),
          PaginationFooter(
            summary: view.hasLocation
                ? l10n.mapShowingNearest(drawn.length, view.pins.length)
                : l10n.mapShowingFirst(drawn.length, view.pins.length),
          ),
        ],
      ],
    );
  }
}

/// One store, as a list row. The same object the marker is, in the form that
/// survives Veld, glare, an empty battery and no signal.
class OutletRow extends StatelessWidget {
  const OutletRow({super.key, required this.pin, required this.last});

  final MapOutlet pin;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final state = mapStateWord(l10n, pin.state);

    return SoftRow(
      key: ValueKey<String>('map-store-${pin.outlet.id}'),
      title: pin.outlet.name,
      titleTruncation: SoftRowTruncation.middle,
      subtitle: pin.outlet.code,
      leading: MapPinGlyph(pin: pin),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          MapDistanceFigure(distance: pin.distance, role: skin.text.figureS),
          Text(
            state,
            style: skin.text.meta.style(color: skin.palette.ink3),
            textAlign: TextAlign.end,
          ),
        ],
      ),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: l10n.mapPinHint(
        '${pin.outlet.name}, ${pin.outlet.code}',
        pin.disputed ? '$state, ${l10n.mapStateDisputed}' : state,
      ),
      // A row opens the same sheet a marker does. One object, one affordance —
      // and the only way the sheet is reachable at all in Veld, where there is
      // no map to tap.
      onTap: () => showOutletSheet(context, pin),
    );
  }
}

/// A distance, or nothing at all.
///
/// The same rule as Today's: when the phone will not say where it is, the
/// screen says so once in words and shows no distances anywhere. An em dash on
/// every row of a long list is the same sentence repeated forty times.
class MapDistanceFigure extends StatelessWidget {
  const MapDistanceFigure({
    super.key,
    required this.distance,
    required this.role,
  });

  final RouteDistance? distance;
  final TiqTypeToken role;

  @override
  Widget build(BuildContext context) {
    final value = distance;
    if (value == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    return FigureSlot(
      value: value.value,
      role: role,
      decimals: value.decimals,
      unit: TiqUnit.worded(
        value.kilometres ? l10n.unitKilometres : l10n.unitMetres,
      ),
      semanticsLabel: value.kilometres
          ? l10n.todayDistanceKmSemantics(value.value)
          : l10n.todayDistanceMetresSemantics(value.value.round()),
    );
  }
}

/// The state word for a pin, in the agent's language.
String mapStateWord(AppLocalizations l10n, MapPinState state) =>
    switch (state) {
      MapPinState.doneToday => l10n.mapStateDone,
      MapPinState.nextUp => l10n.mapStateNext,
      MapPinState.plannedAhead => l10n.mapStatePlanned,
      MapPinState.territory => l10n.mapStateTerritory,
    };

/// The skeleton: the real geometry, empty.
class _MapSkeleton extends StatelessWidget {
  const _MapSkeleton();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    return Skeleton(
      label: l10n.mapTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (agentMapHeight(context) > 0)
            SkeletonShell(height: agentMapHeight(context), outlined: true),
          SizedBox(height: skin.space.blockGap),
          const SkeletonRows(count: 4),
        ],
      ),
    );
  }
}
