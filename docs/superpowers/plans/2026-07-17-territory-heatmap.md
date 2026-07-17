# Territory Heatmap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a manager where a territory's outlets are and which have been visited, as a pin map, closing the heatmap half of #127 (the coverage-rate half already shipped in #96).

**Architecture:** Backend tags each outlet already returned by `GET /territories/:id/coverage` with a `visited: boolean` (no new route, no schema change). The app adds `flutter_map` (OpenStreetMap tiles, no API key) and a new `TerritoryMapScreen` that renders one colored pin per outlet, reached via a new "Map" action on the existing territories list. While touching that screen, it also starts reading the `coverageRate` field #96 added to the backend months ago but the app never consumed.

**Tech Stack:** Express + Prisma (backend), Flutter + Riverpod + `flutter_map`/`latlong2` (app).

**Spec:** `docs/superpowers/specs/2026-07-17-territory-heatmap-design.md`

---

### Task 1: Backend — tag each outlet with a `visited` boolean

**Files:**
- Modify: `backend/src/modules/territories/territories.service.ts:63-109`
- Test: `backend/src/modules/territories/territories.routes.test.ts`

- [ ] **Step 1: Write the failing test**

Add this test to `backend/src/modules/territories/territories.routes.test.ts`, right after the `'returns coverageRate computed from distinct visited outlets'` test (after line 271, before the `'rejects an invalid from date with 400'` test):

```ts
  it('tags each outlet in the response with a visited boolean', async () => {
    const territory = await prisma.territory.create({
      data: { clientId, name: 'TERR-Visited', code: 'TERR-VIS1' },
    });
    const visitedOutlet = await prisma.outlet.create({
      data: {
        name: 'TERR-Outlet-Visited',
        code: 'TERR-OUT-VISITED',
        channelType: 'general_trade',
        lat: -26.2,
        lng: 28.04,
        territoryId: territory.code,
        clientId,
      },
    });
    const unvisitedOutlet = await prisma.outlet.create({
      data: {
        name: 'TERR-Outlet-Unvisited',
        code: 'TERR-OUT-UNVISITED',
        channelType: 'general_trade',
        lat: -26.2,
        lng: 28.04,
        territoryId: territory.code,
        clientId,
      },
    });
    await prisma.visit.create({
      data: {
        outletId: visitedOutlet.id,
        agentId,
        clientId,
        checkinTs: new Date('2026-07-01T09:00:00.000Z'),
        checkinLat: -26.2,
        checkinLng: 28.04,
        geofencePass: true,
        status: 'submitted',
      },
    });

    const res = await request(app)
      .get(`/territories/${territory.id}/coverage`)
      .set('Authorization', `Bearer ${agentToken}`);
    expect(res.status).toBe(200);
    const byId = new Map(
      (res.body.outlets as Array<{ id: string; visited: boolean }>).map((o) => [o.id, o.visited]),
    );
    expect(byId.get(visitedOutlet.id)).toBe(true);
    expect(byId.get(unvisitedOutlet.id)).toBe(false);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && npx jest territories.routes --runInBand -t "tags each outlet"`
Expected: FAIL — `byId.get(visitedOutlet.id)` is `undefined`, not `true` (the response has no `visited` field yet).

- [ ] **Step 3: Implement**

In `backend/src/modules/territories/territories.service.ts`, replace the `getTerritoryCoverage` function's return-type annotation and its final block (lines 63-109) with:

```ts
export async function getTerritoryCoverage(
  territoryId: string,
  clientId: string,
  from?: Date,
  to?: Date,
): Promise<{
  territory: Territory;
  outlets: (Outlet & { visited: boolean })[];
  agents: User[];
  coverage: { outletsVisited: number; outletsTotal: number; coverageRate: number };
}> {
  const territory = await findTerritoryForClient(territoryId, clientId);

  // Outlets link to a territory by the free-text Outlet.territoryId equalling
  // Territory.code, still scoped to the caller's client.
  const outlets = await prisma.outlet.findMany({
    where: { territoryId: territory.code, clientId },
  });

  const assignments = await prisma.userTerritory.findMany({
    where: { territoryId: territory.id },
    include: { user: true },
  });
  const agents = assignments.map((assignment) => assignment.user);

  const outletIds = outlets.map((outlet) => outlet.id);
  const visitWhere: Prisma.VisitWhereInput = {
    clientId,
    outletId: { in: outletIds },
    status: 'submitted',
  };
  if (from || to) {
    visitWhere.checkinTs = {
      ...(from ? { gte: from } : {}),
      ...(to ? { lte: to } : {}),
    };
  }
  const visitedOutlets = outletIds.length
    ? await prisma.visit.findMany({ where: visitWhere, select: { outletId: true }, distinct: ['outletId'] })
    : [];

  const outletsTotal = outlets.length;
  const outletsVisited = visitedOutlets.length;
  const coverageRate = outletsTotal > 0 ? Math.round((100 * outletsVisited / outletsTotal) * 100) / 100 : 0;

  // Tag each outlet with whether it was visited, so a map view can color
  // individual pins instead of only knowing the aggregate rate above.
  const visitedOutletIds = new Set(visitedOutlets.map((visit) => visit.outletId));
  const outletsWithVisited = outlets.map((outlet) => ({
    ...outlet,
    visited: visitedOutletIds.has(outlet.id),
  }));

  return {
    territory,
    outlets: outletsWithVisited,
    agents,
    coverage: { outletsVisited, outletsTotal, coverageRate },
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && npx jest territories.routes --runInBand`
Expected: PASS — all tests in the file, including the new one and the pre-existing `'returns coverage with matching outlets and assigned agents'` test (which only asserts on outlet `id`s, unaffected by the new field).

- [ ] **Step 5: Commit**

```bash
git add backend/src/modules/territories/territories.service.ts backend/src/modules/territories/territories.routes.test.ts
git commit -m "feat(backend): tag territory-coverage outlets with visited status (#127)"
```

---

### Task 2: App — extend `Outlet` and `TerritoryCoverage` to carry per-outlet visited status

**Files:**
- Modify: `app/lib/features/outlets/data/outlets_repository.dart:4-25`
- Modify: `app/lib/features/territories/data/territories_repository.dart:1-39`
- Test: `app/test/features/territories/territories_repository_test.dart`

The app already has an `Outlet` model at `app/lib/features/outlets/data/outlets_repository.dart` (`id`, `name`, `code`, `lat`, `lng`) used by the outlets list screen. Reuse it here — with a new optional `visited` field — instead of creating a second, colliding `Outlet` class in the territories feature.

- [ ] **Step 1: Write the failing test**

Replace both existing tests in `app/test/features/territories/territories_repository_test.dart` (currently lines 29-55, the `'TerritoryCoverage.fromJson counts...'` and `'TerritoryCoverage.fromJson defaults missing lists to zero'` tests) with:

```dart
  test(
      'TerritoryCoverage.fromJson counts outlets and agents, and parses each outlet',
      () {
    final coverage = TerritoryCoverage.fromJson(const {
      'territory': {'id': 't1'},
      'outlets': [
        {'id': 'o1', 'name': 'Outlet One', 'code': 'OUT-1', 'lat': -26.1, 'lng': 28.0, 'visited': true},
        {'id': 'o2', 'name': 'Outlet Two', 'code': 'OUT-2', 'lat': -26.2, 'lng': 28.1, 'visited': false},
        {'id': 'o3', 'name': 'Outlet Three', 'code': 'OUT-3', 'lat': -26.3, 'lng': 28.2, 'visited': false},
      ],
      'agents': [
        {'id': 'a1'},
        {'id': 'a2'},
      ],
      'coverage': {'outletsVisited': 1, 'outletsTotal': 3, 'coverageRate': 33.33},
    });

    expect(coverage.outletCount, 3);
    expect(coverage.agentCount, 2);
    expect(coverage.outlets.length, 3);
    expect(coverage.outlets.first.visited, true);
    expect(coverage.outlets[1].visited, false);
    expect(coverage.outletsVisited, 1);
    expect(coverage.outletsTotal, 3);
    expect(coverage.coverageRate, 33.33);
  });

  test('TerritoryCoverage.fromJson defaults missing lists and coverage to zero',
      () {
    final coverage = TerritoryCoverage.fromJson(const {
      'territory': {'id': 't1'},
    });

    expect(coverage.outletCount, 0);
    expect(coverage.agentCount, 0);
    expect(coverage.outlets, isEmpty);
    expect(coverage.outletsVisited, 0);
    expect(coverage.outletsTotal, 0);
    expect(coverage.coverageRate, 0);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/territories/territories_repository_test.dart`
Expected: FAIL — `TerritoryCoverage` has no `outlets`/`outletsVisited`/`outletsTotal`/`coverageRate` getters (compile error).

- [ ] **Step 3: Implement**

In `app/lib/features/outlets/data/outlets_repository.dart`, replace the `Outlet` class (lines 4-25) with:

```dart
class Outlet {
  const Outlet({
    required this.id,
    required this.name,
    required this.code,
    required this.lat,
    required this.lng,
    this.visited = false,
  });
  final String id;
  final String name;
  final String code;
  final double lat;
  final double lng;

  /// Whether this outlet had at least one submitted visit within the
  /// coverage query's date window. Only meaningful on an `Outlet` that came
  /// from `GET /territories/:id/coverage` — plain `/outlets` responses leave
  /// this at its default of `false`.
  final bool visited;

  factory Outlet.fromJson(Map<String, dynamic> json) => Outlet(
        id: json['id'] as String,
        name: json['name'] as String,
        code: json['code'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        visited: json['visited'] as bool? ?? false,
      );
}
```

In `app/lib/features/territories/data/territories_repository.dart`, replace lines 1-39 (the imports and the `Territory`/`TerritoryCoverage` classes down to the old `TerritoryCoverage.fromJson`) with:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../outlets/data/outlets_repository.dart' show Outlet;

/// A sales territory returned by GET /territories.
class Territory {
  const Territory({
    required this.id,
    required this.name,
    required this.code,
    this.region,
  });
  final String id;
  final String name;
  final String code;
  final String? region;

  factory Territory.fromJson(Map<String, dynamic> json) => Territory(
        id: json['id'] as String,
        name: json['name'] as String,
        code: json['code'] as String,
        region: json['region'] as String?,
      );
}

/// Coverage summary for one territory returned by GET /territories/:id/coverage.
class TerritoryCoverage {
  const TerritoryCoverage({
    required this.outletCount,
    required this.agentCount,
    this.outlets = const [],
    this.outletsVisited = 0,
    this.outletsTotal = 0,
    this.coverageRate = 0,
  });
  final int outletCount;
  final int agentCount;

  /// The outlets themselves, each tagged with whether it was visited — the
  /// data the territory map screen renders as pins.
  final List<Outlet> outlets;
  final int outletsVisited;
  final int outletsTotal;
  final double coverageRate;

  factory TerritoryCoverage.fromJson(Map<String, dynamic> json) {
    final coverage = json['coverage'] as Map<String, dynamic>?;
    return TerritoryCoverage(
      outletCount: (json['outlets'] as List?)?.length ?? 0,
      agentCount: (json['agents'] as List?)?.length ?? 0,
      outlets: (json['outlets'] as List?)
              ?.map((o) => Outlet.fromJson(o as Map<String, dynamic>))
              .toList() ??
          const [],
      outletsVisited: coverage?['outletsVisited'] as int? ?? 0,
      outletsTotal: coverage?['outletsTotal'] as int? ?? 0,
      coverageRate: (coverage?['coverageRate'] as num?)?.toDouble() ?? 0,
    );
  }
}
```

Leave the rest of the file (`TerritoriesRepository`, `DioTerritoriesRepository`, the providers) unchanged — only the imports and the two class definitions above them move.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/territories/territories_repository_test.dart`
Expected: PASS.

Then run the full app test suite to confirm the `Outlet` field addition didn't break its existing consumers:

Run: `cd app && flutter test test/features/outlets/ test/features/audit/visit_outlet_picker_screen_test.dart`
Expected: PASS — both fixture files construct `Outlet(...)` without `visited`, which now defaults to `false`.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/outlets/data/outlets_repository.dart app/lib/features/territories/data/territories_repository.dart app/test/features/territories/territories_repository_test.dart
git commit -m "feat(app): parse per-outlet visited status and coverage rate (#127)"
```

---

### Task 3: App — `TerritoryMapScreen`

**Files:**
- Modify: `app/pubspec.yaml` (add `flutter_map`, `latlong2`)
- Create: `app/lib/features/territories/presentation/territory_map_screen.dart`
- Test: `app/test/features/territories/territory_map_screen_test.dart`

**Context on the map library:** `flutter_map` renders OpenStreetMap tiles with no API key. Its `TileLayer` fetches real tiles over the network, which never resolves in a widget test — **never call `tester.pumpAndSettle()` on a screen containing `FlutterMap`**, it will hang. Use bounded `tester.pump()` calls instead, and assert on the `Marker` pins' `child` widgets directly (each pin's `child` gets its own `ValueKey`), never on rendered tile imagery.

- [ ] **Step 1: Add the dependency**

Run: `cd app && flutter pub add flutter_map latlong2`

(Idempotent if already present in `pubspec.yaml`.)

- [ ] **Step 2: Write the failing test**

Create `app/test/features/territories/territory_map_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';
import 'package:tradeiq_app/features/territories/presentation/territory_map_screen.dart';

import '../../helpers/routed_app.dart';

const _territory = Territory(id: 'ter-1', name: 'Gauteng North', code: 'GP-N');

const _visited = Outlet(
  id: 'o1',
  name: 'Sandton Spar',
  code: 'OUT-1',
  lat: -26.10,
  lng: 28.05,
  visited: true,
);
const _unvisited = Outlet(
  id: 'o2',
  name: 'Rosebank Pick n Pay',
  code: 'OUT-2',
  lat: -26.14,
  lng: 28.04,
  visited: false,
);

class _FakeTerritoriesRepository implements TerritoriesRepository {
  const _FakeTerritoriesRepository(this.coverage);
  final TerritoryCoverage coverage;

  @override
  Future<List<Territory>> listTerritories() async => const [_territory];

  @override
  Future<TerritoryCoverage> getCoverage(String id) async => coverage;

  @override
  Future<Territory> createTerritory({
    required String name,
    required String code,
    String? region,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> assignAgent(String territoryId, String userId) async =>
      throw UnimplementedError();
}

Widget _app(TerritoryCoverage coverage) => routedApp(
      const TerritoryMapScreen(territory: _territory),
      overrides: [
        territoriesRepositoryProvider
            .overrideWithValue(_FakeTerritoriesRepository(coverage)),
      ],
    );

void main() {
  testWidgets('renders a green pin for visited and red for unvisited outlets',
      (tester) async {
    const coverage = TerritoryCoverage(
      outletCount: 2,
      agentCount: 0,
      outlets: [_visited, _unvisited],
      outletsVisited: 1,
      outletsTotal: 2,
      coverageRate: 50,
    );
    await tester.pumpWidget(_app(coverage));
    await tester.pump();
    await tester.pump();

    final visitedPin = tester.widget<Icon>(
      find.byKey(const ValueKey<String>('outlet-pin-icon-o1')),
    );
    final unvisitedPin = tester.widget<Icon>(
      find.byKey(const ValueKey<String>('outlet-pin-icon-o2')),
    );
    expect(visitedPin.color, Colors.green);
    expect(unvisitedPin.color, Colors.red);
  });

  testWidgets('tapping a pin shows the outlet info sheet', (tester) async {
    const coverage = TerritoryCoverage(
      outletCount: 1,
      agentCount: 0,
      outlets: [_visited],
      outletsVisited: 1,
      outletsTotal: 1,
      coverageRate: 100,
    );
    await tester.pumpWidget(_app(coverage));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey<String>('outlet-pin-icon-o1')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Sandton Spar'), findsOneWidget);
    expect(find.text('Visited'), findsOneWidget);
  });

  testWidgets('shows an empty state when the territory has no outlets',
      (tester) async {
    const coverage = TerritoryCoverage(outletCount: 0, agentCount: 0);
    await tester.pumpWidget(_app(coverage));
    await tester.pump();
    await tester.pump();

    expect(find.text('No outlets in this territory yet.'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd app && flutter test test/features/territories/territory_map_screen_test.dart`
Expected: FAIL — `territory_map_screen.dart` does not exist (import error).

- [ ] **Step 4: Implement**

Create `app/lib/features/territories/presentation/territory_map_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../outlets/data/outlets_repository.dart';
import '../data/territories_repository.dart';

/// A pin map of one territory's outlets — green if visited, red if not,
/// within the coverage query's default window. Reached from a "Map" action
/// on [TerritoriesScreen]; every role that can see the territories list can
/// open it, since the underlying coverage endpoint has no role restriction.
class TerritoryMapScreen extends ConsumerWidget {
  const TerritoryMapScreen({super.key, required this.territory});

  final Territory territory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('${territory.name} — Map')),
      body: FutureBuilder<TerritoryCoverage>(
        future: ref.read(territoriesRepositoryProvider).getCoverage(territory.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load coverage: ${snapshot.error}'),
            );
          }
          final outlets = snapshot.data!.outlets;
          if (outlets.isEmpty) {
            return const Center(
              child: Text('No outlets in this territory yet.'),
            );
          }

          final points = [for (final o in outlets) LatLng(o.lat, o.lng)];
          // A single-outlet bounds box has zero area, so center on it
          // directly instead of asking flutter_map to "fit" a point.
          final cameraFit = outlets.length > 1
              ? CameraFit.bounds(
                  bounds: LatLngBounds.fromPoints(points),
                  padding: const EdgeInsets.all(40),
                )
              : null;

          return FlutterMap(
            options: MapOptions(
              initialCenter: points.first,
              initialZoom: 14,
              initialCameraFit: cameraFit,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tradeiq.tradeiq_app',
              ),
              MarkerLayer(
                markers: [
                  for (final outlet in outlets)
                    Marker(
                      point: LatLng(outlet.lat, outlet.lng),
                      width: 32,
                      height: 32,
                      child: GestureDetector(
                        onTap: () => _showOutletSheet(context, outlet),
                        child: Icon(
                          Icons.location_on,
                          key: ValueKey<String>('outlet-pin-icon-${outlet.id}'),
                          color: outlet.visited ? Colors.green : Colors.red,
                          size: 32,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _showOutletSheet(BuildContext context, Outlet outlet) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              outlet.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(outlet.code),
            const SizedBox(height: 8),
            Text(outlet.visited ? 'Visited' : 'Not visited'),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/features/territories/territory_map_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock app/lib/features/territories/presentation/territory_map_screen.dart app/test/features/territories/territory_map_screen_test.dart
git commit -m "feat(app): territory map screen with visited/unvisited pins (#127)"
```

---

### Task 4: App — wire the "Map" action and the coverage-rate display fix into `TerritoriesScreen`

**Files:**
- Modify: `app/lib/features/territories/presentation/territories_screen.dart`
- Test: `app/test/features/territories/territories_screen_test.dart`

- [ ] **Step 1: Write the failing test**

In `app/test/features/territories/territories_screen_test.dart`, update `_FakeTerritoriesRepository.getCoverage` (currently lines 30-32) to return a realistic coverage rate:

```dart
  @override
  Future<TerritoryCoverage> getCoverage(String id) async => const TerritoryCoverage(
        outletCount: 3,
        agentCount: 2,
        outletsVisited: 2,
        outletsTotal: 3,
        coverageRate: 66.67,
      );
```

Then add these two tests at the end of `main()`, before the closing `}`:

```dart
  testWidgets('shows the coverage rate in the row figures', (tester) async {
    await tester.pumpWidget(_app(_FakeTerritoriesRepository()));
    await tester.pumpAndSettle();

    expect(find.textContaining('67% covered'), findsOneWidget);
  });

  testWidgets('the "Map" action opens the territory map screen', (tester) async {
    await tester.pumpWidget(_app(_FakeTerritoriesRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('territory-map-ter-1')));
    // A screen containing FlutterMap: pump a bounded number of frames rather
    // than pumpAndSettle, which never settles while flutter_map's TileLayer
    // keeps retrying its (test-environment-blocked) network tile fetch.
    await tester.pump();
    await tester.pump();

    expect(find.text('Gauteng North — Map'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/territories/territories_screen_test.dart`
Expected: FAIL — no widget with key `territory-map-ter-1`, and the row figures don't contain `%`.

- [ ] **Step 3: Implement**

In `app/lib/features/territories/presentation/territories_screen.dart`:

Add the import (alongside the existing `territory_form_screen.dart` import at line 11):

```dart
import 'territory_form_screen.dart';
import 'territory_map_screen.dart';
```

Replace the `_coverageProvider` doc comment (lines 13-16) — it's now false since #96 shipped `coverageRate`:

```dart
/// Coverage for one territory. Kept per-id and cached by Riverpod so a row
/// that rebuilds does not re-fetch.
final _coverageProvider =
    FutureProvider.family<TerritoryCoverage, String>((ref, id) {
  return ref.read(territoriesRepositoryProvider).getCoverage(id);
});
```

Replace the `PanelCard`'s `subtitle` (line 62) — drop the stale claim:

```dart
              subtitle: 'Outlet and agent counts, plus coverage rate',
```

In `_TerritoryRow._showCoverage`, replace the coverage `Text` (lines 110-113):

```dart
            final coverage = snapshot.data!;
            return Text(
              'Outlets: ${coverage.outletCount}   Agents: ${coverage.agentCount}\n'
              'Coverage: ${coverage.coverageRate.round()}%',
            );
```

In `_TerritoryRow.build`, replace the `figures` switch (lines 148-153):

```dart
    final figures = switch (coverage) {
      AsyncData(:final value) =>
        '${value.outletCount} outlets · ${value.agentCount} agents · '
            '${value.coverageRate.round()}% covered',
      AsyncError() => 'Coverage unavailable',
      _ => 'Loading coverage…',
    };
```

And add the "Map" action to the `actions` list (lines 177-184), ahead of the existing conditional "Assign" action so it's always present:

```dart
      actions: [
        RowAction(
          key: ValueKey<String>('territory-map-${territory.id}'),
          label: 'Map',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => TerritoryMapScreen(territory: territory),
            ),
          ),
        ),
        if (canManage)
          RowAction(
            key: ValueKey<String>('territory-assign-${territory.id}'),
            label: 'Assign',
            onPressed: () => _assignAgent(context),
          ),
      ],
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/territories/`
Expected: PASS — all tests in the `territories` test directory.

Then run the full app suite, since `TerritoryCoverage`'s constructor signature changed and other feature tests construct it:

Run: `cd app && flutter test`
Expected: PASS. If `test/features/territories/territory_form_screen_test.dart`, `test/features/beatplans/beat_plan_form_screen_test.dart`, or `test/features/dashboard/dashboard_shell_screen_test.dart` fail, it means one of their `TerritoryCoverage(...)` fixtures relies on positional/required-field assumptions this plan didn't anticipate — re-check against the final constructor in Task 2 and adjust the fixture's named arguments to match (the new fields are all optional with defaults, so no existing fixture should need to change).

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/territories/presentation/territories_screen.dart app/test/features/territories/territories_screen_test.dart
git commit -m "feat(app): wire territory map + coverage rate into TerritoriesScreen (#127)"
```

---

### Task 5: Final verification and issue closeout

**Files:** none (verification only)

- [ ] **Step 1: Full backend suite**

Run: `cd backend && npm run lint && npm run build && npx jest --runInBand`
Expected: all pass, 0 failures.

- [ ] **Step 2: Full app suite**

Run: `cd app && flutter analyze && flutter test`
Expected: all pass, 0 failures, 0 analyzer issues.

- [ ] **Step 3: Push and close #127**

```bash
git push origin main
gh issue close 127 --comment "Fixed — territory map screen ships with visited/unvisited pins, plus the app now surfaces the coverageRate #96 already computed. See commits from docs/superpowers/plans/2026-07-17-territory-heatmap.md."
```

(Fill in the actual commit SHAs from `git log --oneline -6` before posting the closing comment.)

---

## Out of scope (unchanged from the spec)

- PostGIS / spatial-query infrastructure (#63, Phase 4).
- A third "stale" pin state based on visit recency.
- Showing all territories' outlets on one shared map.
