# Territory Heatmap Design

**Issue:** #127 ("Territory heatmap still doesn't exist") — split off from #96, whose delivered
work (`90b2379`, `b3f184f`) covered the coverage *rate* half of the original gap but not the
geographic visualization half.

## Problem

`Outlet.lat`/`lng` exist and are populated (used today for the haversine geofence check-in
distance calculation), but nothing renders them geographically. `GET /territories/:id/coverage`
returns outlet and agent *lists* plus (since #96) an aggregate `coverage.coverageRate`, but a
manager has no way to see *where* the uncovered outlets are, or which specific outlets were
missed.

Separately — discovered while scoping this ticket, not part of the original ask — the app itself
never picked up #96's `coverageRate` field. `territories_screen.dart` still shows only raw
outlet/agent counts and its own copy still claims *"there is no coverage rate to report,"* which
has been false since #96 shipped. Bundling the fix in here: same file, same already-fetched data,
zero design risk, and it closes a gap #96 should have closed but didn't.

## Decisions made during brainstorming

- **Visualization style: status pins**, not a density heatmap or hybrid. Territories are outlet
  counts in the tens, not the thousands — a true density heatmap needs volume to read as
  anything but noise, and pins are tappable (open an outlet directly) where a blurred heat blob
  isn't. Two states only: `visited` (green) / `not visited` (red) — no third "stale" tier, matching
  the binary shape `coverageRate` already uses.
- **Map library: `flutter_map` + OpenStreetMap tiles.** The app has no map rendering dependency
  today. `flutter_map` is MIT-licensed, needs no API key, no billing account, no per-load cost —
  none of which exist in this codebase today and none of which are worth standing up for one
  screen. `google_maps_flutter`/`mapbox_gl` were both rejected on that basis, not on visual
  quality.
- **Placement: a dedicated map screen per territory**, reached via a new "Map" row action next to
  the existing "Assign" action on `territories_screen.dart`. The existing list-based screen is
  otherwise untouched — the map is an additional view, not a replacement, and avoids cramming
  every territory's outlets onto one shared map.

## Backend changes

`backend/src/modules/territories/territories.service.ts` — `getTerritoryCoverage` already queries
the visited-outlet set (`visitedOutlets`, currently `select: { outletId: true }, distinct:
['outletId']`) but only returns its `.length`. Turn that into a `Set<string>` and tag each row in
the returned `outlets` array with a `visited: boolean`, computed by membership in that set. No
schema change, no new migration, no new route — same `from`/`to` window params, same tenant
scoping (`territory.code` join, not `.id` — see the existing doc comment), same role guard (`any`,
unchanged).

Return type changes from `outlets: Outlet[]` to `outlets: (Outlet & { visited: boolean })[]`.

## App changes

**Dependency:** add `flutter_map` (and its `latlong2` transitive requirement) to
`app/pubspec.yaml`.

**`app/lib/features/territories/data/territories_repository.dart`:**
- Add an `Outlet` model: `id`, `name`, `code`, `lat`, `lng`, `visited` — parsed from the coverage
  response's `outlets` array.
- Extend `TerritoryCoverage` with `outlets: List<Outlet>`, `outletsVisited: int`,
  `outletsTotal: int`, `coverageRate: double` — reading the `coverage` object #96 already added
  to the response, alongside the existing `outlets`/`agents` list-length counts (kept for
  backward display compatibility with anything else reading `outletCount`/`agentCount`).

**New file `app/lib/features/territories/presentation/territory_map_screen.dart`:**
- `TerritoryMapScreen({required Territory territory})`, fetches `TerritoryCoverage` the same way
  the existing coverage dialog does.
- Renders a `FlutterMap` with an OSM `TileLayer` and a `MarkerLayer` — one marker per outlet in
  `coverage.outlets`, green if `visited`, red otherwise.
- Initial camera fits the bounds of the outlet set (or centers on the single outlet if there's
  exactly one; shows an empty state if there are none — no divide-by-zero on an empty bounds
  computation).
- Tapping a pin opens a small bottom sheet: outlet name, code, and visited/not-visited label.

**`app/lib/features/territories/presentation/territories_screen.dart`:**
- Add a `RowAction` "Map" next to the existing "Assign" action, navigating to
  `TerritoryMapScreen` via `Navigator.push`/`MaterialPageRoute` — matching how
  `TerritoryFormScreen` is already opened from this same screen (no `go_router` route needed).
  Unlike "Assign", "Map" is **not** gated behind `canManage` — it's read-only and the coverage
  endpoint itself has no role restriction (`any`), so every role that can see the territories list
  can open the map.
- Fix the stale coverage display: `_TerritoryRow`'s `figures` string and the `_showCoverage`
  dialog both currently show only `outletCount`/`agentCount`. Update both to also surface
  `coverageRate` (e.g. `"12 outlets · 3 agents · 67% covered"`), and delete the now-false "there
  is no coverage rate to report" subtitle/comment.

## Testing

**Backend** (`territories.routes.test.ts`): extend the existing coverage-rate/date-window tests
to assert each outlet in the response carries `visited` matching the submitted-visit window
logic — reusing the fixtures already in place for the coverageRate assertions (in-progress visits
don't count, date window narrows the set, etc.).

**App:**
- New `territory_map_screen_test.dart`: given a fixture `TerritoryCoverage` with a mix of
  visited/unvisited outlets, verify the correct marker count and color, and that tapping a marker
  shows its info sheet. Does **not** call `pumpAndSettle()` — `flutter_map`'s `TileLayer` will
  attempt a real network fetch for tile images that never resolves in a test environment, so
  `pumpAndSettle` would hang. Use a single `tester.pump()` and assert directly on the `Marker`
  widgets in the tree, never on rendered tile content.
- `territories_screen_test.dart`: add a test that tapping the new "Map" action navigates to
  `TerritoryMapScreen`, and a test that the row/dialog figures include the coverage rate.

## Out of scope

- PostGIS / spatial-query infrastructure (#63, Phase 4) — this uses the lat/lng data that already
  exists today via plain in-memory bounds/marker logic, not spatial queries.
- A third "stale" pin state based on visit recency — two states matches what `coverageRate`
  already computes; a recency tier would need its own design (what counts as stale?) that wasn't
  part of this ticket's scope.
- Showing all territories' outlets on one shared map — deferred by the "dedicated screen per
  territory" placement decision above.
