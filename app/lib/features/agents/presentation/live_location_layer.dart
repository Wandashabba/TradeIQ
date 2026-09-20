import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/tiq_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../core/widgets/agent_state_glyph.dart';
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

/// Colour for a state — an extra, never the carrier.
///
/// Near store has its own look rather than borrowing in transit's amber: amber
/// would say "on the road", which a ping inside a store fence is not, and
/// green would claim the store. It takes `ink2`, the strong neutral that
/// clears text contrast in both themes, so it reads as a fresh reading that
/// makes a weaker claim. Not sharing takes `ink3` — muted like stale, told
/// apart from it by the padlock and the words.
Color liveStateColor(LiveAgentState state, TiqColors colors) => switch (state) {
  LiveAgentState.atStore => colors.good,
  LiveAgentState.nearStore => colors.ink2,
  LiveAgentState.inTransit => colors.warn,
  LiveAgentState.stale => colors.ink3,
  LiveAgentState.offline => colors.ink4,
  LiveAgentState.notSharing => colors.ink3,
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

/// One live position: a navy rounded-square badge with the state glyph, and a
/// label that starts with the age.
///
/// Fixed literal colours, not theme tokens — like the trail pins, this sits on
/// the dark basemap in both app themes. White on the badge's navy is well
/// above 4.5:1.
class LiveAgentPin extends StatelessWidget {
  const LiveAgentPin({super.key, required this.agent});

  final AgentLocation agent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final description = liveAgentDescription(l10n, agent);
    return Semantics(
      label: l10n.liveLocationOf(description),
      excludeSemantics: true,
      child: Tooltip(
        message: description,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _badgeSize,
              height: _badgeSize,
              decoration: BoxDecoration(
                color: const Color(0xFF0B1426),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: LiveAgentStateGlyph(
                state: agent.state,
                color: Colors.white,
                size: 15,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xE6050A16),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                '${formatAgeSeconds(l10n, agent.ageSeconds)} · '
                '${livePinStateText(l10n, agent)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE6EEFF),
                ),
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

  /// Drawn over the map's dark chrome rather than the console surface.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textColor = onDark ? const Color(0xFFD9E6FF) : colors.ink2;
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
                color: onDark ? textColor : liveStateColor(state, colors),
                size: 14,
              ),
              const SizedBox(width: 5),
              Text(
                liveStateLabel(l10n, state),
                style: TextStyle(fontSize: 12, color: textColor),
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
    final value = ref.watch(liveAgentLocationsProvider);
    final page = value.value;
    final colors = context.colors;
    final small = TextStyle(fontSize: 12, color: colors.ink3);

    // Nothing to explain yet: one line, no legend. The legend describes pins,
    // and there are none until the first page lands.
    if (page == null) {
      return Text(
        value.hasError
            ? l10n.liveLocationFailed
            : l10n.liveLocationLoading,
        key: const ValueKey('live-locations-status'),
        style: small,
      );
    }

    return Column(
      key: const ValueKey('live-locations-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 2,
          children: [
            Text(
              l10n.liveLocationHeading,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colors.ink1,
              ),
            ),
            Text(
              l10n.liveLastUpdated(formatUpdatedAt(page.serverTime)),
              key: const ValueKey('live-last-updated'),
              style: small,
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(l10n.liveLocationNote, style: small),
        const SizedBox(height: 6),
        const LiveStateLegend(),
        const SizedBox(height: 6),
        if (value.hasError)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              l10n.liveCouldNotRefresh,
              key: const ValueKey('live-refresh-failed'),
              style: small,
            ),
          ),
        for (final agent in page.agents) LiveAgentRow(agent: agent),
        if (page.truncated)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(l10n.liveFirst200, style: small),
          ),
      ],
    );
  }
}

/// One agent: age, then state (glyph + word), then name and place.
class LiveAgentRow extends StatelessWidget {
  const LiveAgentRow({super.key, required this.agent});

  final AgentLocation agent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final place = liveOutletPhrase(l10n, agent);
    return Semantics(
      key: ValueKey('live-row-${agent.agentId}'),
      label: liveAgentDescription(l10n, agent),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: 76,
              child: Text(
                liveAgeText(l10n, agent),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.ink1,
                ),
              ),
            ),
            LiveAgentStateGlyph(
              state: agent.state,
              color: liveStateColor(agent.state, colors),
              size: 16,
            ),
            const SizedBox(width: 6),
            SizedBox(
              // Wide enough for the longest label, "Not sharing", on one line.
              width: 84,
              child: Text(
                liveStateLabel(l10n, agent.state),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: colors.ink2),
              ),
            ),
            Expanded(
              child: Text(
                place.isEmpty ? agent.name : '${agent.name} · $place',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: colors.ink2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
