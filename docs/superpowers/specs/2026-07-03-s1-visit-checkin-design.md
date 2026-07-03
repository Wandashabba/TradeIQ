# S1 — Outlet Check-in / Visit Creation — Design Spec

Date: 2026-07-03
Status: Approved

## 1. Purpose

Close [issue #7](https://github.com/Wandashabba/TradeIQ/issues/7): implement
the `visits` backend module (currently a 501 skeleton) and wire the Flutter
S1 screen so a field agent can check into an outlet, creating the root
`Visit` record that all of S2–S10's audit data hangs off. This is the first
of the ten follow-up specs referenced by
`docs/architecture/stubs-and-interfaces.md`'s "route skeleton" table.

## 2. Scope

In scope:
- `POST /visits` — geofenced check-in, creating a `Visit`
- An outlet-picker screen so the agent has something to check into
- Offline-first check-in: local Drift write + sync-queue outbox + a
  best-effort flush, per ADR 0005
- Client-side geofence pre-check (device GPS via `geolocator`)

Explicitly out of scope (deferred, not part of this change):
- `GET /visits` (listing/resuming visits) — stays the 501 skeleton. Nothing
  in this pass needs it; it lands naturally when a manager-facing visits
  view or "resume in-progress visit" flow is built.
- Connectivity-triggered auto-retry of the sync queue — this pass attempts
  one best-effort flush right after enqueueing. A background/connectivity
  listener retry is separate follow-up scope.
- S2–S10 section data entry — this spec only gets the agent from "outlet
  picker" through a successful S1 check-in to the top of the existing
  Stepper; the S2–S9 screens remain their current placeholders.
- Soft/warn-and-allow geofence failure — check-in outside the 50m radius is
  a hard 422 reject, matching the `GeofenceRejectedError` class already
  scaffolded in `errorHandler.ts`.

## 3. Backend: `visits` module

`backend/src/modules/visits/visits.service.ts` (new, mirrors
`outlets.service.ts`):

```ts
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
  if (!outlet) throw new NotFoundError('Outlet not found');

  const geofencePass = isWithinGeofence(
    { lat: outlet.lat, lng: outlet.lng },
    { lat: input.lat, lng: input.lng },
  );
  if (!geofencePass) throw new GeofenceRejectedError('Check-in location is outside the outlet geofence');

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

`NotFoundError` is a new error class in `errorHandler.ts` (404), following
the existing `NotImplementedError`/`GeofenceRejectedError` pattern —
scoping the outlet lookup by `clientId` gives tenant isolation and a 404
(not a 403) for cross-tenant access, consistent with how a nonexistent
resource is already handled elsewhere in this codebase.

`backend/src/modules/visits/visits.routes.ts` (rewritten):

```ts
visitsRouter.post('/', async (req: AuthedRequest, res) => {
  const { outletId, lat, lng } = req.body as { outletId?: string; lat?: number; lng?: number };
  if (!outletId || lat === undefined || lng === undefined) {
    res.status(400).json({ error: 'outletId, lat, and lng are required' });
    return;
  }
  const visit = await checkIn({ outletId, lat, lng, clientId: req.user!.clientId, agentId: req.user!.userId });
  res.status(201).json(visit);
});

visitsRouter.get('/', () => {
  throw new NotImplementedError('Visit listing is not implemented yet');
});
```

`moduleSkeletons.test.ts` drops `/visits` from `skeletonRoutes` (GET
`/visits` still individually asserts 501 via the new `visits.routes.test.ts`
instead).

## 4. Flutter: data/sync layer

**Location:** `app/lib/core/location/location_service.dart` (new), wrapping
the new `geolocator` dependency:

```dart
sealed class LocationResult {}
class LocationGranted extends LocationResult { final double lat, lng; ... }
class LocationDenied extends LocationResult {}
class LocationError extends LocationResult { final String message; ... }

class LocationService {
  Future<LocationResult> getCurrentPosition() async { ... }
}
```

Handles the `checkPermission`/`requestPermission`/`getCurrentPosition` flow
and maps every failure mode to a typed result rather than letting
`geolocator`'s exceptions surface to the UI.

**Repository:** `app/lib/features/audit/data/visits_repository.dart` (new):

```dart
abstract class VisitsRepository {
  Future<CheckInResult> checkIn(String outletId, {required double outletLat, required double outletLng});
}

sealed class CheckInResult {}
class CheckInSucceeded extends CheckInResult { final String visitId; }
class CheckInGeofenceFailed extends CheckInResult { final double distanceMeters; }
class CheckInLocationUnavailable extends CheckInResult { final String message; }
```

`DriftVisitsRepository.checkIn`:
1. `LocationService.getCurrentPosition()` — on `LocationDenied`/`LocationError`, return `CheckInLocationUnavailable`.
2. Compute `haversineDistanceMeters` (ported to Dart, `app/lib/core/geo/geofence.dart`, ~15 lines mirroring `backend/src/lib/geofence.ts` — no shared package between the two runtimes, consistent with `slaClock`/`forecast` logic also not being shared cross-language).
3. Distance > 50m → return `CheckInGeofenceFailed` without touching Drift (no local draft or queue entry for a rejected check-in).
4. Otherwise: insert a `VisitDrafts` row (`id`: generated uuid, `outletId`, `status: in_progress`, `checkinTs: now`, lat/lng, `geofencePass: true`), enqueue a `SyncQueueItems` row (`entityType: 'visit'`, `entityId`: the draft id, `payloadJson`: `{outletId, lat, lng}`), call `SyncService.flushPending()` once (best-effort — errors from the flush don't fail the check-in; the visit is already saved locally), and return `CheckInSucceeded(visitId: draftId)`.

**`HttpQueueFlusher`** (`app/lib/core/sync/sync_service.dart`, modified):
add the `'visit'` branch — `POST /visits` with the decoded `payloadJson`.
A `422` response (backend geofence reject — shouldn't normally happen since
the client already checked, but the server is the source of truth) is
treated as a terminal failure: log it and leave the item unsynced rather
than retrying indefinitely, since retrying an inherently-rejected payload
would never succeed. Network errors remain retryable (item stays queued,
picked up by the next `flushPending()` call).

## 5. Flutter: UI/routing

- **New route:** `/audit/:outletId` (`GoRoute` in `app_router.dart`) renders
  `AuditShellScreen(outletId: ...)`.
- **`/audit`** becomes `VisitOutletPickerScreen` (new,
  `app/lib/features/audit/presentation/visit_outlet_picker_screen.dart`):
  reuses `outletsListProvider` (already fetches the client's outlets) but is
  a distinct widget from `OutletsListScreen` — each row has a "Start Visit"
  button; tapping it does `context.go('/audit/${outlet.id}')`. Kept separate
  from the manager-facing `OutletsListScreen` because the two are expected
  to diverge (visit-status badges, route ordering, etc. are natural
  follow-ups for the agent view; nothing analogous applies to the manager's
  CRUD list) — sharing one widget now would mean threading a mode flag
  through it for no present benefit.
- **Router redirect change:** field_agent post-login target stays `/audit`
  (now the picker, not the stepper) — no change needed to the redirect
  logic itself, only to what `/audit` renders.
- **`Outlet` model** (`outlets_repository.dart`, modified): currently only
  parses `id`/`name`/`code`. Add `lat`/`lng` (the backend already returns
  them; the Flutter model just hasn't needed them until now).
- **`AuditShellScreen`** gains a required `outletId` constructor param (and
  `outletLat`/`outletLng`, passed through from the picker's already-fetched
  outlet data — avoids an extra `GET /outlets/:id` round-trip). On
  `initState`, calls `VisitsRepository.checkIn(...)` and holds the result in
  local state:
  - `CheckInSucceeded` → renders the existing `Stepper` (unchanged); S1's
    screen (`s1_outlet_info_screen.dart`, replacing its placeholder) shows
    the check-in confirmation (timestamp, "Geofence: passed").
  - `CheckInGeofenceFailed` → blocking error view: distance from the
    outlet, a "Back to outlets" button (`context.go('/audit')`), no
    `Stepper` rendered.
  - `CheckInLocationUnavailable` → blocking error view with the message and
    a "Retry" button that re-invokes `checkIn`.

## 6. Testing

Backend (Jest + Supertest):
- `visits.routes.test.ts` (new, mirrors `outlets.routes.test.ts`): 201 +
  persisted `Visit` on valid check-in; 422 on out-of-geofence check-in
  (assert no `Visit` row was created); 404 when `outletId` belongs to
  another client; 400 on missing `outletId`/`lat`/`lng`; 401 unauthenticated.
- `moduleSkeletons.test.ts` (modified): remove `/visits` from
  `skeletonRoutes`.

Flutter (`flutter_test`):
- `location_service_test.dart`: maps each `geolocator` outcome (granted,
  denied, error) to the correct `LocationResult`.
- `visits_repository_test.dart`: fake `LocationService` + in-memory Drift —
  successful check-in writes one `VisitDrafts` row and one `SyncQueueItems`
  row; geofence-fail writes neither; asserts the returned `CheckInResult`
  variant in each case.
- `sync_service_test.dart` (modified): new `HttpQueueFlusher` case for
  `entityType: 'visit'` — success marks synced; simulated network failure
  leaves it queued; simulated 422 leaves it queued but doesn't retry-loop
  (single flush attempt behaves identically either way at this layer — the
  "don't retry a 422" distinction matters once auto-retry exists, noted
  here so the follow-up issue has a test to extend).
- `visit_outlet_picker_screen_test.dart` (new): renders the outlet list;
  tapping "Start Visit" navigates to `/audit/<id>`.
- `audit_shell_screen_test.dart` (modified): fake `VisitsRepository`
  returning each `CheckInResult` variant renders the corresponding state
  (stepper / geofence-fail view / location-unavailable view).
- `app_router_test.dart` (modified): add a reachability case for
  `/audit/:outletId`; existing field_agent → `/audit` assertion is
  unchanged (still correct, `/audit` now resolves to the picker).
- Full `flutter test` suite stays green; `flutter analyze` clean.

## 7. Explicitly out of scope for this spec

- `GET /visits` (see §2)
- Connectivity-triggered sync retry (see §2)
- S2–S10 section screens (see §2)
- Soft geofence override (see §2)
