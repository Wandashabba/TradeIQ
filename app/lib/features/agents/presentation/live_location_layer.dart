import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/agent_state_glyph.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../core/widgets/torchlight/section_rule.dart';
import '../../../l10n/l10n.dart';
import '../data/agent_locations_repository.dart';

/// The live layer (#153 T1), shared by the dashboard's "Where are my agents"
/// panel and the `/agents/activity` trail map so the two can never disagree
/// about what a live position looks like.
///
/// Honesty rules carried over from T0, sharper now that positions move:
/// - **Age first.** Every pin label and every row starts with how old the
///   position was at the last update, before the state or the name.
/// - **Shape and word, never colour alone** (#144). Each state has its own
///   glyph silhouette and its own label; colour is an extra.
/// - **A visible "last updated".** Ages are the server's measurement at
///   [AgentLocationsPage.serverTime], so the time they are true AT is shown.
/// - **Distinct from check-ins.** Live pins are rounded squares; the check-in
///   pins they sit beside are round discs.
///
/// ## Torchlight
///
/// Two things changed with the tokens and neither is cosmetic.
///
/// **In transit is no longer amber.** It borrowed the old palette's `warn`,
/// and Torchlight has no amber warning: Burning Flame is emitted light and
/// never a label (unify §4). It takes `chartNeutral` — the neutral data hue
/// that exists precisely because it is a fill nobody reads as a verdict — and
/// the road silhouette plus the word go on carrying the state, as they always
/// did.
///
/// **The map geometry reads the Night palette in every skin.** The basemap is
/// the same dark canvas whatever the console around it wears, so a pin paints
/// Palladian on near-black rather than Veld's near-black ink on a near-black
/// tile. `trail_map.dart` does the same, for the same reason.

/// The palette every pin on the basemap paints from, whatever skin the console
/// around it is wearing. See the class comment.
TiqPalette get basemapPalette => TiqSkin.night().palette;

/// Colour for a state — an extra, never the carrier.
///
/// Near store has its own look rather than borrowing in transit's hue: it
/// takes `ink2`, the strong neutral that clears text contrast in all three
/// skins, so it reads as a fresh reading that makes a weaker claim. In transit
/// takes `chartNeutral` (never amber — see the class comment). Stale and not
/// sharing both take `ink3`, told apart by the padlock and the words, and
/// offline takes `inkMute` because it is the state that claims least of all.
Color liveStateColor(LiveAgentState state, TiqPalette palette) =>
    switch (state) {
      LiveAgentState.atStore => palette.good,
      LiveAgentState.nearStore => palette.ink2,
      LiveAgentState.inTransit => palette.chartNeutral,
      LiveAgentState.stale => palette.ink3,
      LiveAgentState.offline => palette.inkMute,
      LiveAgentState.notSharing => palette.ink3,
    };

String _two(int n) => n.toString().padLeft(2, '0');

/// Wall-clock time in the manager's local zone, to the second.
String formatUpdatedAt(DateTime at) {
  final t = at.toLocal();
  return '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
}

/// Where the agent is or was last known to be, in words; empty if unknown.
/// Names the source, so a morning check-in never reads as a live reading.
String liveOutletPhrase(AppLocalizations l10n, AgentLocation agent) {
  if (agent.state == LiveAgentState.atStore &&
      agent.currentOutletName != null) {
    return l10n.liveAtOutlet(agent.currentOutletName!);
  }
  final last = agent.lastOutletName;
  if (last == null) return '';
  if (agent.state == LiveAgentState.nearStore && agent.lastOutletFromPing) {
    return l10n.liveNearOutlet(last);
  }
  return agent.lastOutletFromPing
      ? l10n.liveLastNear(last)
      : l10n.liveLastCheckIn(last);
}

/// The state as a pin shows it: "Near Sandton Spar" when the store is known,
/// otherwise the state's own label.
String livePinStateText(AppLocalizations l10n, AgentLocation agent) {
  final near = agent.lastOutletName;
  if (agent.state == LiveAgentState.nearStore &&
      agent.lastOutletFromPing &&
      near != null) {
    return l10n.liveNear(near);
  }
  return liveStateLabel(l10n, agent.state);
}

/// The age column: how old the position is, or a dash when the agent declined
/// and there is deliberately no position to age.
String liveAgeText(AppLocalizations l10n, AgentLocation agent) =>
    agent.state == LiveAgentState.notSharing
    ? '—'
    : formatAgeSeconds(l10n, agent.ageSeconds);

/// Age · state · name · place — the order a screen reader hears it in, too.
/// Not sharing has no age to lead with, so it leads with the state.
String liveAgentDescription(AppLocalizations l10n, AgentLocation agent) {
  final place = liveOutletPhrase(l10n, agent);
  return [
    if (agent.state != LiveAgentState.notSharing)
      agent.ageSeconds == null
          ? l10n.liveNeverShared
          : l10n.liveAgeOld(formatAgeSeconds(l10n, agent.ageSeconds)),
    liveStateLabel(l10n, agent.state),
    agent.name,
    if (place.isNotEmpty) place,
  ].join(' · ');
}

const _markerWidth = 124.0;
const _markerHeight = 54.0;
const _badgeSize = 26.0;

/// The point sits at the centre of the square badge, with the label hanging
/// below — computed with flutter_map's helper because its named alignments
/// are inverted relative to Flutter's (see agent_trail_screen.dart).
final _markerAlignment = Marker.computePixelAlignment(
  width: _markerWidth,
  height: _markerHeight,
  left: _markerWidth / 2,
  top: _badgeSize / 2,
);

/// Markers for every agent in [agents] that has a position. Callers place
/// them LAST in their marker layer so a live square is never hidden under a
/// check-in disc or an outlet dot.
List<Marker> liveAgentMarkers(List<AgentLocation> agents) => [
  for (final a in agents)
    if (a.hasPosition)
      Marker(
        point: LatLng(a.lat!, a.lng!),
        width: _markerWidth,
        height: _markerHeight,
        alignment: _markerAlignment,
        child: LiveAgentPin(
          key: ValueKey('live-agent-pin-${a.agentId}'),
          agent: a,
        ),
      ),
];

/// One live position: a rounded-square badge with the state glyph, and a
/// label that starts with the age.
///
/// Night tokens in every skin, not the ambient ones — like the trail pins,
/// this sits on the dark basemap whatever the console is wearing.
class LiveAgentPin extends StatelessWidget {
  const LiveAgentPin({super.key, required this.agent});

  final AgentLocation agent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final night = TiqSkin.night();
    final p = night.palette;
    final description = liveAgentDescription(l10n, agent);
    return Semantics(
      label: l10n.liveLocationOf(description),
      excludeSemantics: true,
      // The hover tooltip is a real affordance on the web console this panel
      // is read on, and it is the only way to get the full sentence off a pin
      // whose caption is one ellipsised line.
      child: Tooltip(
        message: description,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _badgeSize,
              height: _badgeSize,
              decoration: BoxDecoration(
                color: p.ground,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: p.ink1, width: 1.5),
              ),
              alignment: Alignment.center,
              child: LiveAgentStateGlyph(
                state: agent.state,
                color: p.ink1,
                size: 15,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: p.well,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                '${formatAgeSeconds(l10n, agent.ageSeconds)} · '
                '${livePinStateText(l10n, agent)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: night.text.meta.style(color: p.ink1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The six states, each as glyph + word.
class LiveStateLegend extends StatelessWidget {
  const LiveStateLegend({super.key, this.onDark = false});

  /// Drawn over the map's dark chrome rather than the console surface. The
  /// legend then reads the basemap's own palette, exactly as the pins it
  /// describes do.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = onDark ? TiqSkin.night() : context.skin;
    final palette = skin.palette;
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        for (final state in LiveAgentState.values)
          Row(
            key: ValueKey('live-legend-${state.name}'),
            mainAxisSize: MainAxisSize.min,
            children: [
              LiveAgentStateGlyph(
                state: state,
                color: liveStateColor(state, palette),
                size: 14,
              ),
              const SizedBox(width: 5),
              Text(
                liveStateLabel(l10n, state),
                style: skin.text.meta.style(color: palette.ink2),
              ),
            ],
          ),
      ],
    );
  }
}

/// The live half of the "Where are my agents" panel: last updated, legend,
/// and one row per agent, age first.
///
/// Reads [liveAgentLocationsProvider] with `.value`, which keeps the last page
/// while a poll is in flight or has failed — so the list never flashes empty
/// every thirty seconds, and a failed poll says so instead of hiding the data.
class LiveLocationsSection extends ConsumerWidget {
  const LiveLocationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final skin = context.skin;
    final value = ref.watch(liveAgentLocationsProvider);
    final page = value.value;

    TextStyle meta() => skin.text.meta.style(color: skin.palette.ink3);

    // Nothing to explain yet: one line, no legend. The legend describes pins,
    // and there are none until the first page lands.
    if (page == null) {
      return Text(
        value.hasError ? l10n.liveLocationFailed : l10n.liveLocationLoading,
        key: const ValueKey('live-locations-status'),
        style: meta(),
      );
    }

    return Column(
      key: const ValueKey('live-locations-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionRule(l10n.liveLocationHeading),
        const SizedBox(height: TiqSpace.s3),
        Text(
          l10n.liveLastUpdated(formatUpdatedAt(page.serverTime)),
          key: const ValueKey('live-last-updated'),
          style: meta(),
        ),
        const SizedBox(height: TiqSpace.s1),
        Text(l10n.liveLocationNote, style: meta()),
        const SizedBox(height: TiqSpace.s3),
        const LiveStateLegend(),
        const SizedBox(height: TiqSpace.s3),
        if (value.hasError)
          Padding(
            padding: const EdgeInsets.only(bottom: TiqSpace.s2),
            child: Text(
              l10n.liveCouldNotRefresh,
              key: const ValueKey('live-refresh-failed'),
              style: meta(),
            ),
          ),
        for (var i = 0; i < page.agents.length; i++)
          LiveAgentRow(
            agent: page.agents[i],
            last: i == page.agents.length - 1,
          ),
        if (page.truncated)
          Padding(
            padding: const EdgeInsets.only(top: TiqSpace.s2),
            child: Text(l10n.liveFirst200, style: meta()),
          ),
      ],
    );
  }
}

/// One agent: age, then state (glyph + word), then name and place.
///
/// A `SoftRow` in its compact density, which is what a console list row is.
/// It is **not tappable** — there is no per-agent live destination to open —
/// and the row's whole utterance is [liveAgentDescription], age first.
class LiveAgentRow extends StatelessWidget {
  const LiveAgentRow({super.key, required this.agent, this.last = false});

  final AgentLocation agent;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = context.skin;
    final place = liveOutletPhrase(l10n, agent);
    return SoftRow(
      key: ValueKey('live-row-${agent.agentId}'),
      density: SoftRowDensity.compact,
      leading: LiveAgentStateGlyph(
        state: agent.state,
        color: liveStateColor(agent.state, skin.palette),
        size: 16,
      ),
      title: place.isEmpty ? agent.name : '${agent.name} · $place',
      titleTruncation: SoftRowTruncation.middle,
      subtitle: liveStateLabel(l10n, agent.state),
      trailing: Text(
        liveAgeText(l10n, agent),
        style: skin.text.label.style(color: skin.palette.ink1),
      ),
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
      semanticsLabel: liveAgentDescription(l10n, agent),
    );
  }
}
