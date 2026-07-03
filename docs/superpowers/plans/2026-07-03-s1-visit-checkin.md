# S1 Outlet Check-in / Visit Creation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the `visits` backend module (geofenced check-in) and wire the Flutter S1 screen so a field agent can pick an outlet, check in (offline-first, via the already-scaffolded Drift/sync-queue tables), and reach the S1-S10 audit stepper.

**Architecture:** Backend: a `visits.service.ts`/`visits.routes.ts` pair mirroring the existing `outlets` module, adding a `NotFoundError` (404) alongside the already-scaffolded `GeofenceRejectedError` (422). Flutter: a `LocationService` (wrapping `geolocator` behind a small testable gateway), a Dart port of the backend's haversine geofence check, a `VisitsRepository` that writes a `VisitDrafts` row + a `SyncQueueItems` outbox entry then attempts one best-effort sync flush, a new `VisitOutletPickerScreen` at `/audit`, and `AuditShellScreen` (now at `/audit/:outletId`) driving the check-in and rendering the existing Stepper on success.

**Tech Stack:** Node.js/Express/TypeScript/Prisma (backend), Flutter/Riverpod/go_router/Drift/Dio (app), `geolocator` + `uuid` (new Flutter dependencies), Jest+Supertest (backend tests), flutter_test (app tests).

**Spec:** `docs/superpowers/specs/2026-07-03-s1-visit-checkin-design.md`

---

## Task 1: Backend — `NotFoundError` error class

**Files:**
- Modify: `backend/src/middleware/errorHandler.ts`
- Test: `backend/src/middleware/errorHandler.test.ts`

- [ ] **Step 1: Write the failing test**

Append to `backend/src/middleware/errorHandler.test.ts` (inside the existing `describe(...)`, after the two existing `it(...)` blocks), and add `NotFoundError` to the import:

```ts
import { errorHandler, GeofenceRejectedError, NotFoundError, NotImplementedError } from './errorHandler';
```

```ts
  it('maps NotFoundError to 404', async () => {
    const app = express();
    app.get('/boom', () => {
      throw new NotFoundError('missing thing');
    });
    app.use(errorHandler);

    const res = await request(app).get('/boom');
    expect(res.status).toBe(404);
    expect(res.body).toEqual({ error: 'missing thing' });
  });
```

(`GeofenceRejectedError` is added to the import list only because it's already exported and unused-import lint would otherwise flag the line if you copy it verbatim — keep the import list exactly as shown.)

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && npx jest errorHandler.test.ts`
Expected: FAIL — `Module '"./errorHandler"' has no exported member 'NotFoundError'`

- [ ] **Step 3: Implement `NotFoundError`**

Replace the full contents of `backend/src/middleware/errorHandler.ts`:

```ts
import { NextFunction, Request, Response } from 'express';

export class NotImplementedError extends Error {}
export class GeofenceRejectedError extends Error {}
export class NotFoundError extends Error {}

// eslint-disable-next-line @typescript-eslint/no-unused-vars
export function errorHandler(err: Error, _req: Request, res: Response, _next: NextFunction): void {
  if (err instanceof NotImplementedError) {
    res.status(501).json({ error: err.message });
    return;
  }
  if (err instanceof GeofenceRejectedError) {
    res.status(422).json({ error: err.message });
    return;
  }
  if (err instanceof NotFoundError) {
    res.status(404).json({ error: err.message });
    return;
  }
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && npx jest errorHandler.test.ts`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add backend/src/middleware/errorHandler.ts backend/src/middleware/errorHandler.test.ts
git commit -m "feat(backend): add NotFoundError (404) to the shared error handler"
```

---

## Task 2: Backend — `POST /visits` check-in endpoint

**Files:**
- Create: `backend/src/modules/visits/visits.service.ts`
- Modify: `backend/src/modules/visits/visits.routes.ts`
- Test: `backend/src/modules/visits/visits.routes.test.ts` (new)

- [ ] **Step 1: Write the failing test**

Create `backend/src/modules/visits/visits.routes.test.ts`:

```ts
import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

describe('visits routes', () => {
  let clientId: string;
  let token: string;
  let outletId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'Test Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const agent = await prisma.user.create({
      data: {
        email: 'visit-test-agent@example.com',
        passwordHash: 'unused-in-this-test',
        role: 'field_agent',
        clientId,
      },
    });
    token = issueToken({ userId: agent.id, role: 'field_agent', clientId });

    const outlet = await prisma.outlet.create({
      data: {
        name: 'Test Outlet',
        code: 'VISIT-TEST-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 'territory-1',
        clientId,
      },
    });
    outletId = outlet.id;
  });

  afterAll(async () => {
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  it('creates a Visit when the check-in is within the outlet geofence', async () => {
    const res = await request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${token}`)
      .send({ outletId, lat: -26.20400, lng: 28.0473 }); // ~11m north, within 50m

    expect(res.status).toBe(201);
    expect(res.body.outletId).toBe(outletId);
    expect(res.body.geofencePass).toBe(true);
    expect(res.body.status).toBe('in_progress');
  });

  it('rejects a check-in outside the outlet geofence with 422', async () => {
    const res = await request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${token}`)
      .send({ outletId, lat: -26.2100, lng: 28.0473 }); // ~650m away

    expect(res.status).toBe(422);

    const visits = await prisma.visit.findMany({ where: { outletId } });
    expect(visits).toHaveLength(0);
  });

  it('returns 404 when the outlet belongs to another client', async () => {
    const otherClient = await prisma.client.create({
      data: { name: 'Other Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    const otherAgent = await prisma.user.create({
      data: {
        email: 'visit-test-agent-b@example.com',
        passwordHash: 'unused-in-this-test',
        role: 'field_agent',
        clientId: otherClient.id,
      },
    });
    const otherToken = issueToken({ userId: otherAgent.id, role: 'field_agent', clientId: otherClient.id });

    try {
      const res = await request(app)
        .post('/visits')
        .set('Authorization', `Bearer ${otherToken}`)
        .send({ outletId, lat: -26.2041, lng: 28.0473 });

      expect(res.status).toBe(404);
    } finally {
      await prisma.user.deleteMany({ where: { clientId: otherClient.id } });
      await prisma.client.delete({ where: { id: otherClient.id } });
    }
  });

  it('rejects a check-in with a missing required field', async () => {
    const res = await request(app)
      .post('/visits')
      .set('Authorization', `Bearer ${token}`)
      .send({ outletId });

    expect(res.status).toBe(400);
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).post('/visits').send({ outletId, lat: -26.2041, lng: 28.0473 });
    expect(res.status).toBe(401);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && npx jest visits.routes.test.ts`
Expected: FAIL — the first test gets `501` (current `GET`-only skeleton has no `POST` handler, so Express falls through to the existing `GET '/'` skeleton's `NotImplementedError` only for `GET`; a `POST` with no matching route returns Express's default 404 handler, not the `201` expected) — in any case, all assertions fail against the current skeleton.

- [ ] **Step 3: Implement `visits.service.ts`**

Create `backend/src/modules/visits/visits.service.ts`:

```ts
import { prisma } from '../../lib/prisma';
import { isWithinGeofence } from '../../lib/geofence';
import { GeofenceRejectedError, NotFoundError } from '../../middleware/errorHandler';

export interface CheckInInput {
  outletId: string;
  lat: number;
  lng: number;
  clientId: string;
  agentId: string;
}

export async function checkIn(input: CheckInInput) {
  const outlet = await prisma.outlet.findFirst({
    where: { id: input.outletId, clientId: input.clientId },
  });
  if (!outlet) {
    throw new NotFoundError('Outlet not found');
  }

  const geofencePass = isWithinGeofence(
    { lat: outlet.lat, lng: outlet.lng },
    { lat: input.lat, lng: input.lng },
  );
  if (!geofencePass) {
    throw new GeofenceRejectedError('Check-in location is outside the outlet geofence');
  }

  return prisma.visit.create({
    data: {
      outletId: input.outletId,
      agentId: input.agentId,
      clientId: input.clientId,
      checkinTs: new Date(),
      checkinLat: input.lat,
      checkinLng: input.lng,
      geofencePass: true,
      status: 'in_progress',
    },
  });
}
```

- [ ] **Step 4: Implement `visits.routes.ts`**

Replace the full contents of `backend/src/modules/visits/visits.routes.ts`:

```ts
import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { NotImplementedError } from '../../middleware/errorHandler';
import { checkIn } from './visits.service';

export const visitsRouter = Router();
visitsRouter.use(requireAuth);

visitsRouter.post('/', async (req: AuthedRequest, res) => {
  const { outletId, lat, lng } = req.body as { outletId?: string; lat?: number; lng?: number };

  if (!outletId || lat === undefined || lng === undefined) {
    res.status(400).json({ error: 'outletId, lat, and lng are required' });
    return;
  }

  const visit = await checkIn({
    outletId,
    lat,
    lng,
    clientId: req.user!.clientId,
    agentId: req.user!.userId,
  });
  res.status(201).json(visit);
});

visitsRouter.get('/', () => {
  throw new NotImplementedError('Visit listing is not implemented yet');
});
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd backend && npx jest visits.routes.test.ts`
Expected: PASS (5 tests)

- [ ] **Step 6: Commit**

```bash
git add backend/src/modules/visits/visits.service.ts backend/src/modules/visits/visits.routes.ts backend/src/modules/visits/visits.routes.test.ts
git commit -m "feat(backend): implement POST /visits geofenced check-in"
```

---

## Task 3: Backend — retire `/visits` from the module-skeleton test and verify

**Files:**
- Modify: `backend/src/modules/moduleSkeletons.test.ts`

- [ ] **Step 1: Update the skeleton route list**

In `backend/src/modules/moduleSkeletons.test.ts`, remove `'/visits'` from the array:

```ts
const skeletonRoutes = [
  '/stock', '/visibility', '/pricing', '/competitive',
  '/capability', '/risks', '/tasks', '/scorecards', '/dashboard',
];
```

- [ ] **Step 2: Run the full backend suite and lint**

Run: `cd backend && npm run lint && npm test`
Expected: PASS — all suites green (11 suites now, `/visits` no longer in the generic 501 list but covered by its own `visits.routes.test.ts`)

- [ ] **Step 3: Commit**

```bash
git add backend/src/modules/moduleSkeletons.test.ts
git commit -m "test(backend): drop /visits from the generic 501 skeleton coverage"
```

---

## Task 4: Flutter — add `geolocator` and `uuid` dependencies

**Files:**
- Modify: `app/pubspec.yaml` (via `flutter pub add`)
- Modify: `app/android/app/src/main/AndroidManifest.xml`
- Modify: `app/ios/Runner/Info.plist`

- [ ] **Step 1: Add the packages**

Run:
```bash
cd app && flutter pub add geolocator && flutter pub add uuid
```
Expected: `pubspec.yaml` gains `geolocator: ^14.0.2` (or whatever the current resolved version is) under `dependencies`, and `uuid: ^4.5.3` alongside it. `flutter pub get` runs automatically as part of `pub add`.

- [ ] **Step 2: Add the Android location permissions**

In `app/android/app/src/main/AndroidManifest.xml`, add these two lines directly after the opening `<manifest ...>` tag, before `<application ...>`:

```xml
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

- [ ] **Step 3: Add the iOS location usage description**

In `app/ios/Runner/Info.plist`, add this key/value pair just before the final `</dict>` (line 69, right after the closing `</array>` of `UISupportedInterfaceOrientations~ipad`):

```xml
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>TradeIQ needs your location to confirm you're at the outlet you're checking into.</string>
```

- [ ] **Step 4: Verify the app still analyzes cleanly**

Run: `cd app && flutter analyze`
Expected: PASS — no new warnings/errors (the packages aren't used by any code yet, so this just confirms dependency resolution didn't break anything)

- [ ] **Step 5: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock app/android/app/src/main/AndroidManifest.xml app/ios/Runner/Info.plist
git commit -m "chore(app): add geolocator and uuid dependencies"
```

---

## Task 5: Flutter — port the geofence haversine check to Dart

**Files:**
- Create: `app/lib/core/geo/geofence.dart`
- Test: `app/test/core/geo/geofence_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Create `app/test/core/geo/geofence_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/geo/geofence.dart';

void main() {
  group('isWithinGeofence', () {
    test('returns true when within 50m of the outlet', () {
      const outlet = Coordinates(lat: -26.2041, lng: 28.0473);
      const checkin = Coordinates(lat: -26.20400, lng: 28.0473); // ~11m north
      expect(isWithinGeofence(outlet, checkin), isTrue);
    });

    test('returns false when more than 50m from the outlet', () {
      const outlet = Coordinates(lat: -26.2041, lng: 28.0473);
      const checkin = Coordinates(lat: -26.2100, lng: 28.0473); // ~650m away
      expect(isWithinGeofence(outlet, checkin), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/geo/geofence_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'tradeiq_app' in 'package:tradeiq_app/core/geo/geofence.dart'` (file doesn't exist yet)

- [ ] **Step 3: Implement `geofence.dart`**

Create `app/lib/core/geo/geofence.dart`:

```dart
import 'dart:math';

class Coordinates {
  const Coordinates({required this.lat, required this.lng});
  final double lat;
  final double lng;
}

const _earthRadiusMeters = 6371000.0;

double _toRadians(double degrees) => degrees * pi / 180;

double haversineDistanceMeters(Coordinates a, Coordinates b) {
  final dLat = _toRadians(b.lat - a.lat);
  final dLng = _toRadians(b.lng - a.lng);
  final lat1 = _toRadians(a.lat);
  final lat2 = _toRadians(b.lat);

  final h = pow(sin(dLat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dLng / 2), 2);

  return 2 * _earthRadiusMeters * asin(sqrt(h));
}

bool isWithinGeofence(Coordinates outlet, Coordinates checkin, {double radiusMeters = 50}) {
  return haversineDistanceMeters(outlet, checkin) <= radiusMeters;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/core/geo/geofence_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/geo/geofence.dart app/test/core/geo/geofence_test.dart
git commit -m "feat(app): port the backend haversine geofence check to Dart"
```

---

## Task 6: Flutter — `LocationService`

**Files:**
- Create: `app/lib/core/location/geolocator_gateway.dart`
- Create: `app/lib/core/location/location_service.dart`
- Test: `app/test/core/location/location_service_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Create `app/test/core/location/location_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tradeiq_app/core/location/geolocator_gateway.dart';
import 'package:tradeiq_app/core/location/location_service.dart';

Position _fakePosition(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026, 1, 1),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

class _FakeGateway implements GeolocatorGateway {
  _FakeGateway({
    this.initialPermission = LocationPermission.always,
    this.requestedPermission,
    this.serviceEnabled = true,
    this.position,
  });

  final LocationPermission initialPermission;
  final LocationPermission? requestedPermission;
  final bool serviceEnabled;
  final Position? position;

  @override
  Future<LocationPermission> checkPermission() async => initialPermission;

  @override
  Future<LocationPermission> requestPermission() async => requestedPermission ?? initialPermission;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<Position> getCurrentPosition() async {
    if (position == null) throw Exception('no fake position provided');
    return position!;
  }
}

void main() {
  test('returns LocationGranted with the device coordinates when permission is already granted', () async {
    final service = LocationService(
      gateway: _FakeGateway(
        initialPermission: LocationPermission.whileInUse,
        position: _fakePosition(-26.1076, 28.0567),
      ),
    );

    final result = await service.getCurrentPosition();

    expect(result, isA<LocationGranted>());
    expect((result as LocationGranted).lat, -26.1076);
    expect(result.lng, 28.0567);
  });

  test('requests permission when initially denied, then succeeds if granted', () async {
    final service = LocationService(
      gateway: _FakeGateway(
        initialPermission: LocationPermission.denied,
        requestedPermission: LocationPermission.whileInUse,
        position: _fakePosition(-26.1076, 28.0567),
      ),
    );

    final result = await service.getCurrentPosition();

    expect(result, isA<LocationGranted>());
  });

  test('returns LocationDenied when permission is denied even after requesting', () async {
    final service = LocationService(
      gateway: _FakeGateway(
        initialPermission: LocationPermission.denied,
        requestedPermission: LocationPermission.denied,
      ),
    );

    final result = await service.getCurrentPosition();

    expect(result, isA<LocationDenied>());
  });

  test('returns LocationDenied when permission is permanently denied', () async {
    final service = LocationService(
      gateway: _FakeGateway(initialPermission: LocationPermission.deniedForever),
    );

    final result = await service.getCurrentPosition();

    expect(result, isA<LocationDenied>());
  });

  test('returns LocationError when location services are disabled', () async {
    final service = LocationService(
      gateway: _FakeGateway(initialPermission: LocationPermission.whileInUse, serviceEnabled: false),
    );

    final result = await service.getCurrentPosition();

    expect(result, isA<LocationError>());
  });

  test('returns LocationError when fetching the position throws', () async {
    final service = LocationService(
      gateway: _FakeGateway(initialPermission: LocationPermission.whileInUse),
    );

    final result = await service.getCurrentPosition();

    expect(result, isA<LocationError>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/location/location_service_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'tradeiq_app' in 'package:tradeiq_app/core/location/geolocator_gateway.dart'` (files don't exist yet)

- [ ] **Step 3: Implement `geolocator_gateway.dart`**

Create `app/lib/core/location/geolocator_gateway.dart`:

```dart
import 'package:geolocator/geolocator.dart';

/// Thin wrapper around the static [Geolocator] calls this app needs, so
/// [LocationService] can be unit-tested with a fake instead of mocking
/// geolocator's platform-channel internals.
abstract class GeolocatorGateway {
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<bool> isLocationServiceEnabled();
  Future<Position> getCurrentPosition();
}

class RealGeolocatorGateway implements GeolocatorGateway {
  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() => Geolocator.requestPermission();

  @override
  Future<bool> isLocationServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<Position> getCurrentPosition() => Geolocator.getCurrentPosition();
}
```

- [ ] **Step 4: Implement `location_service.dart`**

Create `app/lib/core/location/location_service.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'geolocator_gateway.dart';

sealed class LocationResult {}

class LocationGranted extends LocationResult {
  LocationGranted(this.lat, this.lng);
  final double lat;
  final double lng;
}

class LocationDenied extends LocationResult {}

class LocationError extends LocationResult {
  LocationError(this.message);
  final String message;
}

class LocationService {
  LocationService({GeolocatorGateway? gateway}) : _gateway = gateway ?? RealGeolocatorGateway();

  final GeolocatorGateway _gateway;

  Future<LocationResult> getCurrentPosition() async {
    var permission = await _gateway.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _gateway.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return LocationDenied();
    }

    if (!await _gateway.isLocationServiceEnabled()) {
      return LocationError('Location services are disabled');
    }

    try {
      final position = await _gateway.getCurrentPosition();
      return LocationGranted(position.latitude, position.longitude);
    } catch (e) {
      return LocationError('Failed to get current location: $e');
    }
  }
}

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/core/location/location_service_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 6: Commit**

```bash
git add app/lib/core/location/geolocator_gateway.dart app/lib/core/location/location_service.dart app/test/core/location/location_service_test.dart
git commit -m "feat(app): add LocationService wrapping geolocator for check-in GPS"
```

---

## Task 7: Flutter — wire `HttpQueueFlusher`'s `'visit'` case

**Files:**
- Modify: `app/lib/core/storage/local_db.dart`
- Modify: `app/lib/core/sync/sync_service.dart`
- Modify: `app/test/core/sync/sync_service_test.dart`

- [ ] **Step 1: Write the failing test**

Replace the full contents of `app/test/core/sync/sync_service_test.dart`:

```dart
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';

class NoopFlusher implements QueueFlusher {
  int callCount = 0;

  @override
  Future<void> flush(SyncQueueItem item) async {
    callCount += 1;
  }
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.statusCode);
  final int statusCode;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{}',
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

SyncQueueItem _visitQueueItem(String payloadJson) => SyncQueueItem(
      id: 1,
      entityType: 'visit',
      entityId: 'visit-1',
      payloadJson: payloadJson,
      queuedAt: DateTime(2026, 1, 1),
      synced: false,
    );

void main() {
  test('flushPending marks queued items as synced', () async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
      entityType: 'visit',
      entityId: 'visit-1',
      payloadJson: '{}',
    ));

    final flusher = NoopFlusher();
    final service = SyncService(db: db, flusher: flusher);
    await service.flushPending();

    expect(flusher.callCount, 1);
    final rows = await db.select(db.syncQueueItems).get();
    expect(rows.first.synced, isTrue);
  });

  group('HttpQueueFlusher', () {
    test('posts the visit payload to /visits and succeeds on 2xx', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))..httpClientAdapter = _FakeAdapter(201);
      final flusher = HttpQueueFlusher(dio: dio);

      await flusher.flush(_visitQueueItem('{"outletId":"o1","lat":1.0,"lng":2.0}'));
    });

    test('throws when the backend rejects the check-in with 422', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'))..httpClientAdapter = _FakeAdapter(422);
      final flusher = HttpQueueFlusher(dio: dio);

      await expectLater(
        flusher.flush(_visitQueueItem('{"outletId":"o1","lat":1.0,"lng":2.0}')),
        throwsA(isA<DioException>()),
      );
    });

    test('throws UnimplementedError for an unhandled entity type', () async {
      final flusher = HttpQueueFlusher(dio: Dio());
      await expectLater(
        flusher.flush(_visitQueueItem('{}').copyWith(entityType: 'stock')),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/sync/sync_service_test.dart`
Expected: FAIL — `The named parameter 'dio' isn't defined` (current `HttpQueueFlusher` has no constructor)

- [ ] **Step 3: Add `localDbProvider`**

In `app/lib/core/storage/local_db.dart`, add the import and provider. The file becomes:

```dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'local_db.g.dart';

/// The app's offline-first local database.
///
/// Holds in-progress visit drafts ([VisitDrafts]) and the generic outbox of
/// pending mutations ([SyncQueueItems]) that the sync service flushes to the
/// backend once connectivity returns.
@DriftDatabase(tables: [VisitDrafts, SyncQueueItems])
class LocalDb extends _$LocalDb {
  LocalDb([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'tradeiq_local.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}

final localDbProvider = Provider<LocalDb>((ref) => LocalDb());
```

- [ ] **Step 4: Implement the `'visit'` flush case**

Replace the full contents of `app/lib/core/sync/sync_service.dart`:

```dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart' as api_client;
import '../storage/local_db.dart';

abstract class QueueFlusher {
  Future<void> flush(SyncQueueItem item);
}

/// Posts queued entities to their matching backend endpoint. Only 'visit'
/// is wired so far (POST /visits) — other entity types get their own case
/// as their S2-S10 modules land.
class HttpQueueFlusher implements QueueFlusher {
  HttpQueueFlusher({Dio? dio}) : _dio = dio ?? api_client.dio;

  final Dio _dio;

  @override
  Future<void> flush(SyncQueueItem item) async {
    switch (item.entityType) {
      case 'visit':
        await _dio.post('/visits', data: jsonDecode(item.payloadJson));
        return;
      default:
        throw UnimplementedError('HTTP sync for ${item.entityType} not wired yet');
    }
  }
}

class SyncService {
  SyncService({required this.db, required this.flusher});

  final LocalDb db;
  final QueueFlusher flusher;

  Future<void> flushPending() async {
    final pending = await (db.select(db.syncQueueItems)
          ..where((tbl) => tbl.synced.equals(false)))
        .get();

    for (final item in pending) {
      await flusher.flush(item);
      await (db.update(db.syncQueueItems)..where((tbl) => tbl.id.equals(item.id)))
          .write(const SyncQueueItemsCompanion(synced: Value(true)));
    }
  }
}

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(db: ref.read(localDbProvider), flusher: HttpQueueFlusher()),
);
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/core/sync/sync_service_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 6: Run the full app test suite and analyzer to confirm no regressions**

Run: `cd app && flutter analyze && flutter test`
Expected: PASS, no analyzer warnings

- [ ] **Step 7: Commit**

```bash
git add app/lib/core/storage/local_db.dart app/lib/core/sync/sync_service.dart app/test/core/sync/sync_service_test.dart
git commit -m "feat(app): wire HttpQueueFlusher's visit case to POST /visits"
```

---

## Task 8: Flutter — `Outlet` lat/lng + `VisitsRepository`

**Files:**
- Modify: `app/lib/features/outlets/data/outlets_repository.dart`
- Modify: `app/test/features/outlets/outlets_list_screen_test.dart`
- Create: `app/lib/features/audit/data/visits_repository.dart`
- Test: `app/test/features/audit/visits_repository_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Create `app/test/features/audit/visits_repository_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/location/location_service.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';
import 'package:tradeiq_app/features/audit/data/visits_repository.dart';

class _FakeLocationService extends LocationService {
  _FakeLocationService(this._result);
  final LocationResult _result;

  @override
  Future<LocationResult> getCurrentPosition() async => _result;
}

class _NoopFlusher implements QueueFlusher {
  @override
  Future<void> flush(SyncQueueItem item) async {}
}

class _ThrowingFlusher implements QueueFlusher {
  @override
  Future<void> flush(SyncQueueItem item) async {
    throw Exception('network error');
  }
}

void main() {
  late LocalDb db;

  setUp(() {
    db = LocalDb(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('a check-in within the geofence writes a VisitDraft and enqueues a sync item', () async {
    final repository = DriftVisitsRepository(
      db: db,
      locationService: _FakeLocationService(LocationGranted(-26.20400, 28.0473)),
      syncService: SyncService(db: db, flusher: _NoopFlusher()),
    );

    final result = await repository.checkIn(outletId: 'outlet-1', outletLat: -26.2041, outletLng: 28.0473);

    expect(result, isA<CheckInSucceeded>());

    final drafts = await db.select(db.visitDrafts).get();
    expect(drafts, hasLength(1));
    expect(drafts.first.outletId, 'outlet-1');
    expect(drafts.first.geofencePass, isTrue);

    final queued = await db.select(db.syncQueueItems).get();
    expect(queued, hasLength(1));
    expect(queued.first.entityType, 'visit');
  });

  test('a check-in outside the geofence writes nothing and returns the distance', () async {
    final repository = DriftVisitsRepository(
      db: db,
      locationService: _FakeLocationService(LocationGranted(-26.2100, 28.0473)),
      syncService: SyncService(db: db, flusher: _NoopFlusher()),
    );

    final result = await repository.checkIn(outletId: 'outlet-1', outletLat: -26.2041, outletLng: 28.0473);

    expect(result, isA<CheckInGeofenceFailed>());
    expect((result as CheckInGeofenceFailed).distanceMeters, greaterThan(50));
    expect(await db.select(db.visitDrafts).get(), isEmpty);
    expect(await db.select(db.syncQueueItems).get(), isEmpty);
  });

  test('a denied location permission returns CheckInLocationUnavailable and writes nothing', () async {
    final repository = DriftVisitsRepository(
      db: db,
      locationService: _FakeLocationService(LocationDenied()),
      syncService: SyncService(db: db, flusher: _NoopFlusher()),
    );

    final result = await repository.checkIn(outletId: 'outlet-1', outletLat: -26.2041, outletLng: 28.0473);

    expect(result, isA<CheckInLocationUnavailable>());
    expect(await db.select(db.visitDrafts).get(), isEmpty);
  });

  test('a failing sync flush does not fail the check-in', () async {
    final repository = DriftVisitsRepository(
      db: db,
      locationService: _FakeLocationService(LocationGranted(-26.20400, 28.0473)),
      syncService: SyncService(db: db, flusher: _ThrowingFlusher()),
    );

    final result = await repository.checkIn(outletId: 'outlet-1', outletLat: -26.2041, outletLng: 28.0473);

    expect(result, isA<CheckInSucceeded>());
    final queued = await db.select(db.syncQueueItems).get();
    expect(queued.first.synced, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/audit/visits_repository_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'tradeiq_app' in 'package:tradeiq_app/features/audit/data/visits_repository.dart'` (file doesn't exist yet)

- [ ] **Step 3: Add lat/lng to the `Outlet` model**

Replace the full contents of `app/lib/features/outlets/data/outlets_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class Outlet {
  const Outlet({
    required this.id,
    required this.name,
    required this.code,
    required this.lat,
    required this.lng,
  });
  final String id;
  final String name;
  final String code;
  final double lat;
  final double lng;

  factory Outlet.fromJson(Map<String, dynamic> json) => Outlet(
        id: json['id'] as String,
        name: json['name'] as String,
        code: json['code'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      );
}

abstract class OutletsRepository {
  Future<List<Outlet>> listOutlets();
}

class DioOutletsRepository implements OutletsRepository {
  @override
  Future<List<Outlet>> listOutlets() async {
    final response = await dio.get('/outlets');
    return (response.data as List)
        .map((json) => Outlet.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

final outletsRepositoryProvider = Provider<OutletsRepository>((ref) => DioOutletsRepository());

final outletsListProvider = FutureProvider<List<Outlet>>((ref) {
  return ref.read(outletsRepositoryProvider).listOutlets();
});
```

- [ ] **Step 4: Fix the now-broken `Outlet(...)` call in `outlets_list_screen_test.dart`**

In `app/test/features/outlets/outlets_list_screen_test.dart`, update the `FakeOutletsRepository`:

```dart
class FakeOutletsRepository implements OutletsRepository {
  @override
  Future<List<Outlet>> listOutlets() async => const [
        Outlet(id: 'o1', name: 'Test Hypermarket', code: 'TH-001', lat: -26.2041, lng: 28.0473),
      ];
}
```

- [ ] **Step 5: Run the outlets screen test to confirm it still passes**

Run: `cd app && flutter test test/features/outlets/outlets_list_screen_test.dart`
Expected: PASS (1 test)

- [ ] **Step 6: Implement `VisitsRepository`**

Create `app/lib/features/audit/data/visits_repository.dart`:

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/geo/geofence.dart';
import '../../../core/location/location_service.dart';
import '../../../core/storage/local_db.dart';
import '../../../core/sync/sync_service.dart';

sealed class CheckInResult {}

class CheckInSucceeded extends CheckInResult {
  CheckInSucceeded(this.visitId);
  final String visitId;
}

class CheckInGeofenceFailed extends CheckInResult {
  CheckInGeofenceFailed(this.distanceMeters);
  final double distanceMeters;
}

class CheckInLocationUnavailable extends CheckInResult {
  CheckInLocationUnavailable(this.message);
  final String message;
}

abstract class VisitsRepository {
  Future<CheckInResult> checkIn({
    required String outletId,
    required double outletLat,
    required double outletLng,
  });
}

class DriftVisitsRepository implements VisitsRepository {
  DriftVisitsRepository({required this.db, required this.locationService, required this.syncService});

  final LocalDb db;
  final LocationService locationService;
  final SyncService syncService;

  static const _uuid = Uuid();

  @override
  Future<CheckInResult> checkIn({
    required String outletId,
    required double outletLat,
    required double outletLng,
  }) async {
    final locationResult = await locationService.getCurrentPosition();

    return switch (locationResult) {
      LocationDenied() => CheckInLocationUnavailable('Location permission denied'),
      LocationError(:final message) => CheckInLocationUnavailable(message),
      LocationGranted(:final lat, :final lng) => await _checkInAt(outletId, outletLat, outletLng, lat, lng),
    };
  }

  Future<CheckInResult> _checkInAt(
    String outletId,
    double outletLat,
    double outletLng,
    double lat,
    double lng,
  ) async {
    final distance = haversineDistanceMeters(
      Coordinates(lat: outletLat, lng: outletLng),
      Coordinates(lat: lat, lng: lng),
    );
    if (distance > 50) {
      return CheckInGeofenceFailed(distance);
    }

    final id = _uuid.v4();
    await db.into(db.visitDrafts).insert(VisitDraftsCompanion.insert(
          id: id,
          outletId: outletId,
          checkinTs: DateTime.now(),
          checkinLat: lat,
          checkinLng: lng,
          geofencePass: true,
        ));
    await db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
          entityType: 'visit',
          entityId: id,
          payloadJson: jsonEncode({'outletId': outletId, 'lat': lat, 'lng': lng}),
        ));

    try {
      await syncService.flushPending();
    } catch (_) {
      // Best-effort: the visit is already saved locally and queued; a
      // failed flush just means it stays queued for the next attempt.
    }

    return CheckInSucceeded(id);
  }
}

final visitsRepositoryProvider = Provider<VisitsRepository>((ref) => DriftVisitsRepository(
      db: ref.read(localDbProvider),
      locationService: ref.read(locationServiceProvider),
      syncService: ref.read(syncServiceProvider),
    ));
```

- [ ] **Step 7: Run test to verify it passes**

Run: `cd app && flutter test test/features/audit/visits_repository_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 8: Commit**

```bash
git add app/lib/features/outlets/data/outlets_repository.dart app/test/features/outlets/outlets_list_screen_test.dart app/lib/features/audit/data/visits_repository.dart app/test/features/audit/visits_repository_test.dart
git commit -m "feat(app): add VisitsRepository for offline-first geofenced check-in"
```

---

## Task 9: Flutter — `VisitOutletPickerScreen`

**Files:**
- Create: `app/lib/features/audit/presentation/visit_outlet_picker_screen.dart`
- Test: `app/test/features/audit/visit_outlet_picker_screen_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Create `app/test/features/audit/visit_outlet_picker_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/features/audit/presentation/visit_outlet_picker_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

class FakeOutletsRepository implements OutletsRepository {
  @override
  Future<List<Outlet>> listOutlets() async => const [
        Outlet(id: 'o1', name: 'Test Outlet', code: 'TO-001', lat: -26.2041, lng: 28.0473),
      ];
}

void main() {
  testWidgets('renders outlets and navigates to the audit shell on Start Visit', (tester) async {
    final router = GoRouter(
      initialLocation: '/audit',
      routes: [
        GoRoute(path: '/audit', builder: (context, state) => const VisitOutletPickerScreen()),
        GoRoute(
          path: '/audit/:outletId',
          builder: (context, state) => Text('Visit ${state.pathParameters['outletId']}'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [outletsRepositoryProvider.overrideWithValue(FakeOutletsRepository())],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Outlet'), findsOneWidget);

    await tester.tap(find.text('Start Visit'));
    await tester.pumpAndSettle();

    expect(find.text('Visit o1'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/audit/visit_outlet_picker_screen_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'tradeiq_app' in 'package:tradeiq_app/features/audit/presentation/visit_outlet_picker_screen.dart'` (file doesn't exist yet)

- [ ] **Step 3: Implement `VisitOutletPickerScreen`**

Create `app/lib/features/audit/presentation/visit_outlet_picker_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../outlets/data/outlets_repository.dart';

class VisitOutletPickerScreen extends ConsumerWidget {
  const VisitOutletPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outlets = ref.watch(outletsListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Select an Outlet')),
      body: outlets.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final outlet = list[index];
            return ListTile(
              title: Text(outlet.name),
              subtitle: Text(outlet.code),
              trailing: ElevatedButton(
                onPressed: () => context.go('/audit/${outlet.id}'),
                child: const Text('Start Visit'),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Failed to load outlets: $err')),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/audit/visit_outlet_picker_screen_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/audit/presentation/visit_outlet_picker_screen.dart app/test/features/audit/visit_outlet_picker_screen_test.dart
git commit -m "feat(app): add VisitOutletPickerScreen for agent-facing outlet selection"
```

---

## Task 10: Flutter — `AuditShellScreen` check-in wiring

**Files:**
- Modify: `app/lib/features/audit/presentation/audit_shell_screen.dart`
- Modify: `app/lib/features/audit/presentation/sections/s1_outlet_info_screen.dart`
- Modify: `app/test/features/audit/audit_shell_screen_test.dart`

- [ ] **Step 1: Replace the test file with the failing test**

Replace the full contents of `app/test/features/audit/audit_shell_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/features/audit/data/visits_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/audit_shell_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

class _FakeOutletsRepository implements OutletsRepository {
  @override
  Future<List<Outlet>> listOutlets() async => const [
        Outlet(id: 'o1', name: 'Test Outlet', code: 'TO-001', lat: -26.2041, lng: 28.0473),
      ];
}

class _SucceedingVisitsRepository implements VisitsRepository {
  @override
  Future<CheckInResult> checkIn({
    required String outletId,
    required double outletLat,
    required double outletLng,
  }) async =>
      CheckInSucceeded('visit-1');
}

class _GeofenceFailingVisitsRepository implements VisitsRepository {
  @override
  Future<CheckInResult> checkIn({
    required String outletId,
    required double outletLat,
    required double outletLng,
  }) async =>
      CheckInGeofenceFailed(650);
}

class _LocationUnavailableVisitsRepository implements VisitsRepository {
  @override
  Future<CheckInResult> checkIn({
    required String outletId,
    required double outletLat,
    required double outletLng,
  }) async =>
      CheckInLocationUnavailable('Location permission denied');
}

Widget _appWith(VisitsRepository visitsRepository) {
  return ProviderScope(
    overrides: [
      outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
      visitsRepositoryProvider.overrideWithValue(visitsRepository),
    ],
    child: const MaterialApp(home: AuditShellScreen(outletId: 'o1')),
  );
}

void main() {
  testWidgets('shows a stepper with all 10 audit sections after a successful check-in', (tester) async {
    await tester.pumpWidget(_appWith(_SucceedingVisitsRepository()));
    await tester.pumpAndSettle();

    expect(find.text('S1 Outlet Information'), findsOneWidget);
    expect(find.text('S10 Execution Scorecard'), findsOneWidget);
  });

  testWidgets('shows a blocking error when the check-in fails the geofence', (tester) async {
    await tester.pumpWidget(_appWith(_GeofenceFailingVisitsRepository()));
    await tester.pumpAndSettle();

    expect(find.textContaining('650'), findsOneWidget);
    expect(find.text('S1 Outlet Information'), findsNothing);
  });

  testWidgets('shows a retry action when location is unavailable', (tester) async {
    await tester.pumpWidget(_appWith(_LocationUnavailableVisitsRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Location permission denied'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('tapping logout clears the session', (tester) async {
    await tester.pumpWidget(_appWith(_SucceedingVisitsRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pump();

    final context = tester.element(find.byType(AuditShellScreen));
    final container = ProviderScope.containerOf(context);
    expect(container.read(sessionControllerProvider).value?.role, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/audit/audit_shell_screen_test.dart`
Expected: FAIL — `The named parameter 'outletId' isn't defined` (current `AuditShellScreen` takes no constructor params)

- [ ] **Step 3: Update the S1 screen**

Replace the full contents of `app/lib/features/audit/presentation/sections/s1_outlet_info_screen.dart`:

```dart
import 'package:flutter/material.dart';

class S1OutletInfoScreen extends StatelessWidget {
  const S1OutletInfoScreen({super.key, this.checkinTs});

  final DateTime? checkinTs;

  @override
  Widget build(BuildContext context) {
    final ts = checkinTs;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('S1 Outlet Information'),
          const SizedBox(height: 8),
          if (ts != null) Text('Checked in at $ts — Geofence: passed'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Implement `AuditShellScreen` check-in wiring**

Replace the full contents of `app/lib/features/audit/presentation/audit_shell_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../data/visits_repository.dart';
import '../../outlets/data/outlets_repository.dart';
import 'sections/s1_outlet_info_screen.dart';
import 'sections/s2_stock_screen.dart';
import 'sections/s3_4_visibility_display_screen.dart';
import 'sections/s5_pricing_promotions_screen.dart';
import 'sections/s6_competitive_screen.dart';
import 'sections/s7_capability_screen.dart';
import 'sections/s8_risks_screen.dart';
import 'sections/s9_action_plan_screen.dart';
import 'sections/s10_scorecard_screen.dart';

class AuditShellScreen extends ConsumerStatefulWidget {
  const AuditShellScreen({super.key, required this.outletId});

  final String outletId;

  @override
  ConsumerState<AuditShellScreen> createState() => _AuditShellScreenState();
}

class _AuditShellScreenState extends ConsumerState<AuditShellScreen> {
  int _step = 0;
  bool _checkInStarted = false;
  CheckInResult? _checkInResult;

  Future<void> _startCheckIn(double outletLat, double outletLng) async {
    final result = await ref.read(visitsRepositoryProvider).checkIn(
          outletId: widget.outletId,
          outletLat: outletLat,
          outletLng: outletLng,
        );
    if (!mounted) return;
    setState(() => _checkInResult = result);
  }

  Outlet? _findOutlet(List<Outlet> outlets) {
    for (final outlet in outlets) {
      if (outlet.id == widget.outletId) return outlet;
    }
    return null;
  }

  // Only ever called from _buildStepper(), which only renders once
  // _checkInResult is CheckInSucceeded — so check-in has just completed.
  List<Widget> _sections() => [
        S1OutletInfoScreen(checkinTs: DateTime.now()),
        const S2StockScreen(),
        const S3S4VisibilityDisplayScreen(),
        const S5PricingPromotionsScreen(),
        const S6CompetitiveScreen(),
        const S7CapabilityScreen(),
        const S8RisksScreen(),
        const S9ActionPlanScreen(),
        const S10ScorecardScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    final outletsAsync = ref.watch(outletsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Visit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: outletsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Failed to load outlet: $err')),
        data: (outlets) {
          final outlet = _findOutlet(outlets);
          if (outlet == null) {
            return const Center(child: Text('Outlet not found'));
          }
          if (!_checkInStarted) {
            _checkInStarted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => _startCheckIn(outlet.lat, outlet.lng));
            return const Center(child: CircularProgressIndicator());
          }
          return switch (_checkInResult) {
            null => const Center(child: CircularProgressIndicator()),
            CheckInSucceeded() => _buildStepper(),
            CheckInGeofenceFailed(:final distanceMeters) => _buildError(
                'You are ${distanceMeters.round()}m from this outlet. Move within 50m to check in.',
              ),
            CheckInLocationUnavailable(:final message) => _buildError(
                message,
                onRetry: () => setState(() => _checkInStarted = false),
              ),
          };
        },
      ),
    );
  }

  Widget _buildStepper() {
    final sections = _sections();
    return SingleChildScrollView(
      child: Stepper(
        physics: const NeverScrollableScrollPhysics(),
        currentStep: _step,
        onStepContinue: () {
          if (_step < sections.length - 1) setState(() => _step += 1);
        },
        onStepTapped: (index) => setState(() => _step = index),
        steps: sections.map((screen) => Step(title: const SizedBox.shrink(), content: screen)).toList(),
      ),
    );
  }

  Widget _buildError(String message, {VoidCallback? onRetry}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (onRetry != null)
            ElevatedButton(onPressed: onRetry, child: const Text('Retry'))
          else
            ElevatedButton(onPressed: () => context.go('/audit'), child: const Text('Back to outlets')),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/features/audit/audit_shell_screen_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/audit/presentation/audit_shell_screen.dart app/lib/features/audit/presentation/sections/s1_outlet_info_screen.dart app/test/features/audit/audit_shell_screen_test.dart
git commit -m "feat(app): wire AuditShellScreen to drive the S1 check-in flow"
```

---

## Task 11: Flutter — router: outlet picker at `/audit`, stepper at `/audit/:outletId`

**Files:**
- Modify: `app/lib/core/router/app_router.dart`
- Modify: `app/test/core/router/app_router_test.dart`

- [ ] **Step 1: Replace `app_router_test.dart` wholesale with the failing test**

Replace the full contents of `app/test/core/router/app_router_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/router/app_router.dart';
import 'package:tradeiq_app/features/audit/data/visits_repository.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

class _FixedSessionController extends SessionController {
  _FixedSessionController(this._initial);
  final SessionState _initial;

  @override
  Future<SessionState> build() async => _initial;
}

class _FakeOutletsRepository implements OutletsRepository {
  @override
  Future<List<Outlet>> listOutlets() async => const [
        Outlet(id: 'o1', name: 'Test Outlet', code: 'TO-001', lat: -26.2041, lng: 28.0473),
      ];
}

class _FakeSucceedingVisitsRepository implements VisitsRepository {
  @override
  Future<CheckInResult> checkIn({
    required String outletId,
    required double outletLat,
    required double outletLng,
  }) async =>
      CheckInSucceeded('visit-1');
}

Widget _appWithOverrides(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: Consumer(
      builder: (context, ref, _) => MaterialApp.router(routerConfig: ref.watch(routerProvider)),
    ),
  );
}

void main() {
  testWidgets('unauthenticated root route shows the login screen', (tester) async {
    await tester.pumpWidget(_appWithOverrides([]));
    await tester.pumpAndSettle();
    expect(find.text('TradeIQ Login'), findsOneWidget);
  });

  testWidgets('unauthenticated request for /dashboard redirects to login', (tester) async {
    await tester.pumpWidget(_appWithOverrides([]));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    container.read(routerProvider).go('/dashboard');
    await tester.pumpAndSettle();

    expect(find.text('TradeIQ Login'), findsOneWidget);
  });

  testWidgets('authenticated field_agent starting at /login lands on the outlet picker', (tester) async {
    await tester.pumpWidget(_appWithOverrides([
      sessionControllerProvider.overrideWith(
        () => _FixedSessionController(const SessionState(role: 'field_agent')),
      ),
      outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Select an Outlet'), findsOneWidget);
  });

  testWidgets('/audit/:outletId renders the audit shell for that outlet', (tester) async {
    await tester.pumpWidget(_appWithOverrides([
      sessionControllerProvider.overrideWith(
        () => _FixedSessionController(const SessionState(role: 'field_agent')),
      ),
      outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
      visitsRepositoryProvider.overrideWithValue(_FakeSucceedingVisitsRepository()),
    ]));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    container.read(routerProvider).go('/audit/o1');
    await tester.pumpAndSettle();

    expect(find.text('Audit Visit'), findsOneWidget);
    expect(find.text('S1 Outlet Information'), findsOneWidget);
  });

  testWidgets('authenticated manager starting at /login lands on /dashboard', (tester) async {
    await tester.pumpWidget(_appWithOverrides([
      sessionControllerProvider.overrideWith(
        () => _FixedSessionController(const SessionState(role: 'manager')),
      ),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Numeric Distribution'), findsOneWidget);
  });

  testWidgets('logging out from a protected route redirects back to login', (tester) async {
    await tester.pumpWidget(_appWithOverrides([
      sessionControllerProvider.overrideWith(
        () => _FixedSessionController(const SessionState(role: 'manager')),
      ),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Numeric Distribution'), findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    container.read(sessionControllerProvider.notifier).logout();
    await tester.pumpAndSettle();

    expect(find.text('TradeIQ Login'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/router/app_router_test.dart`
Expected: FAIL — `authenticated field_agent starting at /login lands on the outlet picker` fails because `/audit` still renders the old `AuditShellScreen` (which now itself fails to construct without `outletId`), and `/audit/:outletId` isn't a registered route yet

- [ ] **Step 3: Implement the router changes**

Replace the full contents of `app/lib/core/router/app_router.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/audit/presentation/audit_shell_screen.dart';
import '../../features/audit/presentation/visit_outlet_picker_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_shell_screen.dart';
import '../../features/outlets/presentation/outlets_list_screen.dart';
import '../auth/session_controller.dart';
import 'session_refresh_listenable.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: ref.read(sessionRefreshListenableProvider),
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider).value;
      final isLoggedIn = session?.role != null;
      final isOnLoginScreen = state.matchedLocation == '/login';

      if (!isLoggedIn) {
        return isOnLoginScreen ? null : '/login';
      }
      if (isOnLoginScreen) {
        return session!.role == 'field_agent' ? '/audit' : '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/dashboard', builder: (context, state) => const DashboardShellScreen()),
      GoRoute(path: '/audit', builder: (context, state) => const VisitOutletPickerScreen()),
      GoRoute(
        path: '/audit/:outletId',
        builder: (context, state) => AuditShellScreen(outletId: state.pathParameters['outletId']!),
      ),
      GoRoute(path: '/outlets', builder: (context, state) => const OutletsListScreen()),
    ],
  );
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/core/router/app_router_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/router/app_router.dart app/test/core/router/app_router_test.dart
git commit -m "feat(app): route /audit to the outlet picker, /audit/:outletId to the stepper"
```

---

## Task 12: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full backend suite**

Run: `cd backend && npm run lint && npm test`
Expected: PASS, all suites green

- [ ] **Step 2: Run the full app suite and analyzer**

Run: `cd app && flutter analyze && flutter test`
Expected: PASS, no analyzer warnings

- [ ] **Step 3: Manual end-to-end verification against the real backend**

1. `make dev` (or `cd backend && npm run dev` if Postgres is already up)
2. `cd app && flutter run -d chrome`
3. Log in as `agent@demo-fmcg.tradeiq.com` / `demo-password-123`
4. Confirm you land on "Select an Outlet" showing Sandton Hypermarket, Rosebank Supermarket, Fourways Convenience
5. Tap "Start Visit" on any outlet
6. Approve the browser's location permission prompt if shown
7. If Chrome's reported location doesn't happen to be within 50m of the outlet (likely, since Chrome will report your real location, not Gauteng), open Chrome DevTools → the "⋮" menu → More tools → Sensors → set "Location" to a custom value matching the outlet's coordinates (Sandton Hypermarket: `-26.1076, 28.0567`) and reload
8. Confirm the S1 stepper renders with "Checked in at ... — Geofence: passed"
9. Query Postgres to confirm the Visit row landed: `docker exec -it tradeiq-postgres-1 psql -U tradeiq -d tradeiq -c "select outlet_id, geofence_pass, status from visits order by checkin_ts desc limit 1;"`
10. Also test the geofence-fail path: leave Chrome's sensor override at your real (non-Gauteng) location, tap "Start Visit" on a different outlet, confirm the blocking "You are Nm from this outlet" error renders instead of the stepper

- [ ] **Step 4: No commit for this task** — it's verification only; if any step fails, return to the relevant task above and fix it there (with its own commit), don't fix it here.
