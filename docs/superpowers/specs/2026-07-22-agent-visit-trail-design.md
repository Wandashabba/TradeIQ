# Agent Visit Trail Design (T0)

**Issue:** #153 ("Live agent location on the manager dashboard"), tier T0 only.

#153 defines three tiers. This spec covers **T0 alone** — the visit trail built from data the
system already captures. T1 (foreground heartbeat) and T2 (background tracking) stay out of
scope and out of this document; T2 in particular is gated on a POPIA position that has not been
taken.

## Problem

A manager cannot answer "where are my agents, and which store is each one at?" — not
approximately, not with a delay, not at all. The data to answer it approximately has been
sitting in `Visit` rows since check-in shipped.

Every `Visit` already records `agentId`, `outletId`, `checkinTs`, `checkinLat`/`checkinLng`,
and `status`. In sequence, per agent, per day, those rows *are* a route: a confirmed list of
which stores an agent stood inside and when. Nothing renders them.

## What T0 is and is not

T0 shows **where an agent has been confirmed present**. It does not show live movement, and it
must not imply that it does. Between two check-ins the agent's position is unknown — they may
be driving to the next store, sitting in traffic, or stopped for lunch. A UI that renders that
gap as motion is inventing data.

This is the single most important constraint in this design and it drives three decisions
below: the three-state model, the dashed polyline, and leading every row with data age.

## Decisions made during brainstorming

- **Placement: dashboard panel + drill-in map.** A compact "Where are my agents" panel joins
  the existing panels on `dashboard_shell_screen.dart`, with a `[View map →]` action opening a
  full-screen trail map. The panel is list-only — no tile layer on the dashboard, so the
  manager's morning screen does not pay OSM tile loads to answer a question the list already
  answers. The map gets its own screen and its own real estate.

  > **Reversed 2026-07-22, after T0 shipped for review.** The panel now carries a map
  > alongside the list. The tile-load objection above was real but was the wrong thing to
  > optimise for: geography is the point of the question "where are my agents", and a
  > manager reading a list of store names has to reconstruct the map in their head.
  >
  > It is **map + list, not map alone.** Idle agents have no coordinates — an agent who has
  > not checked in cannot be plotted — so a map-only panel would silently drop the single
  > most actionable row on the whole feature ("Sipho has not checked in today"). The list
  > keeps them visible and keeps the per-agent staleness age, which is the thing that stops
  > the panel reading as live. The map is the hero; the list is what makes it honest.
  >
  > Plotting idle agents at a *previous* day's position was considered and rejected: it
  > would show an agent at a store they are not at, which is precisely the
  > stale-reads-as-live failure this whole feature is built to avoid.

- **Data source: `Visit` rows only.** `CheckInAttempt` (which records failed geofence attempts,
  #44) was considered and rejected for T0. It would show "tried and failed" — genuinely useful
  for spotting bad outlet coordinates — but it doubles the query, introduces a second marker
  vocabulary, and retry spam from one spot clutters the map badly. Worth revisiting as its own
  ticket; not worth carrying in the first slice.

- **Time range: today by default, arbitrary day on the map.** The panel is always today. The
  map screen takes a date picker so a manager can review a past day's route.

- **Three states, not four.** `at_store` (an `in_progress` visit), `in_transit` (last visit
  `submitted`), `idle` (no check-in that day). #153's UI sketch proposes a fourth, `offline`.
  T0 has no heartbeat, so it has no way to distinguish "offline" from "between stores" — a
  marker claiming offline status would be asserting something we cannot observe.

- **Map library: `flutter_map` + OpenStreetMap.** Not a new decision — inherited from the
  territory heatmap design (2026-07-17). Already a dependency.

- **Basemap: CARTO `dark_all` / `light_all`, switched on theme brightness.** Stock OSM tiles
  are cream and read as a bright rectangle pasted into a dark console — visibly wrong against
  this app's chrome. CARTO's basemaps are free, need no API key and no billing account, which
  is the same constraint that ruled out Google and Mapbox for the territory map.

  Switched on `Theme.of(context).brightness` rather than hardcoded: the console has a
  working light/dark toggle, and dark tiles in light mode is the same mismatch in reverse.

  CARTO's terms require attributing **both** OpenStreetMap and CARTO, so the attribution
  string changes from "OpenStreetMap contributors" to "OpenStreetMap contributors © CARTO"
  wherever these tiles are used.

## Decision surfaced while writing this spec: the day boundary

The design discussion assumed a date is resolved in "the tenant's timezone". **No such thing
exists.** `Client` has no timezone column and the backend has no timezone handling anywhere.

Resolving a `date=YYYY-MM-DD` param server-side would therefore mean either UTC — which cuts
the day at 02:00 SAST, splitting a South African field team's morning across two "days" — or
inventing a timezone column and a default, which is a larger change than this feature earns.

**Decision: the endpoint takes `from` and `to` as ISO-8601 instants, not a date.** The Flutter
client computes local midnight-to-midnight for the day the manager selected and sends explicit
instants. The server does no timezone reasoning at all. It validates that the range is
well-formed and no wider than 48 hours.

This is honest about where the timezone knowledge actually lives (the client, which knows the
manager's locale) and adds no schema change. If per-tenant timezones are needed later — for
scheduled reports, say — that is a separate concern and this endpoint is unaffected.

## Backend

New module `backend/src/modules/agents/`, following the shape of the existing modules
(`agents.routes.ts`, `agents.service.ts`, `agents.routes.test.ts`).

```
GET /agents/activity?from=<iso>&to=<iso>[&territoryId=<code>][&limit=&cursor=]
```

Manager and admin only. Tenant-scoped from the authenticated user's `clientId` — never from a
parameter.

Response, per agent:

```
{ agentId, name, state, currentOutlet: { id, name } | null, lastSeenAt, stops: [...] }
```

where each stop is `{ visitId, outletId, outletName, lat, lng, checkinTs, status }`, ordered by
`checkinTs`.

**State derivation** (in `agents.service.ts`, unit-tested directly):

| Condition | State |
|---|---|
| Agent has a visit with `status = in_progress` in range | `at_store`, `currentOutlet` = that outlet |
| Agent's latest visit in range is `submitted` | `in_transit`, `currentOutlet` = null |
| Agent has no visits in range | `idle` |

`lastSeenAt` is the latest `checkinTs` in range, or null. It is deliberately **not**
`User.lastSeenAt` — that field is written only on successful check-in and is not scoped to the
requested range, so using it would report a timestamp from a different day than the one on
screen.

**Bounding (#141).** #153 requires this endpoint be bounded from day one. It is bounded by
*shape* rather than a blanket `take:`: one day of one tenant's agents is inherently finite.
Truncating an agent's day mid-route would draw a *wrong* line rather than a short one, which is
worse than no line. So the **agent list** is paged (`limit`/`cursor`, default 50, max 200) and
each included agent's day is returned whole. The 48-hour range cap is the second bound.

Note that this codebase has no shared pagination helper today — #141 covers introducing one
across 92 `findMany` calls. This endpoint should not wait for it, but should be written so it
can adopt the helper without an API change.

**Territory filter.** When `territoryId` is supplied, restrict to agents assigned to that
territory via `UserTerritory`. Reuse the `UserTerritory` → `territory.code` resolution from
`outlets.service.ts`, which exists precisely because `Outlet.territoryId` stores a code and not
an id — the #97 trap.

## App

**`GET`/repository:** new `agents_repository.dart` under `app/lib/features/agents/data/`,
mirroring `territories_repository.dart`.

**Panel:** `_AgentActivityPanel` in `dashboard_shell_screen.dart`, a `PanelCard` matching the
existing panels. One row per agent: name, state (shape + label + colour), current-or-last
outlet, and last-seen age. Added to `_refresh`'s invalidation set so it refreshes with every
other panel — the file's own comment explains why panels must not refresh independently.

It reads `dashboardFilterProvider` for the territory filter rather than introducing its own
scoping, so it agrees with the rest of the dashboard by construction.

**Map screen:** `agent_trail_screen.dart` under `app/lib/features/agents/presentation/`.
Outlet pins reusing the existing `_OutletPin` silhouette vocabulary, numbered stop markers per
agent, dashed polylines between consecutive stops, a date picker in the app bar, and an agent
filter. `AsyncSection` for load/error/retry, `SimpleAttributionWidget` for the OSM licence —
both as `territory_map_screen.dart` does them.

**Dashed polylines, deliberately.** A solid line between two check-ins asserts a route we did
not observe. Dashes read as inference. The map legend says so in words too.

**Accessibility.** Agent state is carried by shape and text label, not colour alone, and every
marker gets a `Semantics` label naming the agent and state — the rule `territory_map_screen.dart`
already follows and #144 enforced. #144 is now closed, but the rule outlives the ticket.

## Testing

**Backend** (`agents.routes.test.ts`): each of the three states derived correctly; an agent with
two `in_progress` visits (data anomaly) does not crash; tenant isolation — another client's
visits never appear; territory filter restricts by `UserTerritory`; malformed and inverted
`from`/`to`; a range wider than 48h is rejected; empty result for a day with no visits;
non-manager roles are refused.

**App:** panel renders each state; panel respects `dashboardFilterProvider`; panel appears in
`_refresh`; map screen renders stops and polylines; date picker refetches; empty state for a day
with no visits; error state offers retry.

## Out of scope

- T1 heartbeat, `AgentLocationPing`, and any new location capture. No new permissions are
  requested and no new location data is collected by this work.
- T2 background tracking and the POPIA position that must precede it.
- `CheckInAttempt` overlay.
- Per-tenant timezone support.
- A retention policy — T0 stores nothing new, so there is nothing new to retain. Retention
  becomes real at T1 and is tracked separately.
