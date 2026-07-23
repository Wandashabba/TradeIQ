# Pagination Slice 0 — Helpers + Alerts Pattern-Setter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the shared pagination helpers (backend `parsePagination` + envelope builder, app `PaginatedResponse<T>`) and convert the `alerts` module end-to-end as the template every other module will copy.

**Architecture:** Every list endpoint returns `{ data, nextCursor }` — a keyset cursor reusing the pattern already shipped in the agents module. On the app, repositories return `PaginatedResponse<T>`; providers unwrap `.data` to a first-page list so existing screen consumers do not change. No back-compat bare arrays (there are no external API consumers — see the spec).

**Tech Stack:** Express + Prisma + Jest/supertest (backend); Flutter + Riverpod + Dio + flutter_test (app).

**Spec:** `docs/superpowers/specs/2026-07-23-list-pagination-design.md`

---

## Background you need before starting

Read the spec first. Two things drive every decision:

1. **No external API consumers.** The only client is the Flutter app in this repo. So the contract changes on both sides together, and there is no "keep returning an array for compatibility" phase — a capped bare array would silently lose data, an uncapped one would not fix the OOM this exists to fix.
2. **The keyset pattern already exists.** `backend/src/modules/agents/agents.service.ts` (`listAgentActivity`) already does keyset pagination: `orderBy` with a unique `id` tiebreaker, `take: limit + 1`, `cursor: { id }, skip: 1`, slice back to `limit`, `nextCursor = hasMore ? lastId : null`. This slice extracts that into a shared helper and applies it to alerts. Read that function before Task 1.

**Why alerts, not visits:** a pattern-setter must exercise the app side. The app never lists `GET /visits` (its `visits_repository` only checks in / submits). It *does* list `GET /alerts` via `alertsListProvider` → the dashboard "Needs attention" panel. Converting alerts proves the full stack.

## File structure

**Backend — create:**
- `backend/src/lib/pagination.ts` — `parsePagination(req)` + `buildPage(rows, limit)`. Pure, no Prisma, no Express response.
- `backend/src/lib/pagination.test.ts` — unit tests for both.

**Backend — modify:**
- `backend/src/modules/alerts/alerts.service.ts` — `listAlerts` takes `limit`/`cursor`, applies keyset, returns `{ data, nextCursor }`.
- `backend/src/modules/alerts/alerts.routes.ts` — `GET /alerts` calls `parsePagination`, returns the envelope.
- `backend/src/modules/alerts/alerts.routes.test.ts` — pagination tests.

**App — create:**
- `app/lib/core/network/paginated_response.dart` — `PaginatedResponse<T>`.
- `app/test/core/network/paginated_response_test.dart` — unit tests.

**App — modify:**
- `app/lib/features/alerts/data/alerts_repository.dart` — `listAlerts` returns `PaginatedResponse<AlertItem>`; `alertsListProvider` unwraps `.data`.
- `app/test/features/alerts/alerts_repository_test.dart` — envelope-parse test.

---

## Task 1: Backend pagination helper

**Files:**
- Create: `backend/src/lib/pagination.ts`
- Create: `backend/src/lib/pagination.test.ts`

- [ ] **Step 1: Write the failing test**

Create `backend/src/lib/pagination.test.ts`:

```typescript
import { parsePagination, buildPage, DEFAULT_LIMIT, MAX_LIMIT } from './pagination';

describe('parsePagination', () => {
  const req = (query: Record<string, unknown>) => ({ query } as any);

  it('defaults to DEFAULT_LIMIT and no cursor when nothing is supplied', () => {
    expect(parsePagination(req({}))).toEqual({ limit: DEFAULT_LIMIT, cursor: undefined });
  });

  it('accepts a valid limit and cursor', () => {
    expect(parsePagination(req({ limit: '25', cursor: 'abc' }))).toEqual({ limit: 25, cursor: 'abc' });
  });

  it('clamps a limit above the max down to MAX_LIMIT', () => {
    expect(parsePagination(req({ limit: '9999' })).limit).toBe(MAX_LIMIT);
  });

  it('throws on a non-integer limit', () => {
    expect(() => parsePagination(req({ limit: '1.5' }))).toThrow();
  });

  it('throws on a non-positive limit', () => {
    expect(() => parsePagination(req({ limit: '0' }))).toThrow();
  });

  it('throws on a non-numeric limit', () => {
    expect(() => parsePagination(req({ limit: 'abc' }))).toThrow();
  });
});

describe('buildPage', () => {
  it('returns all rows and a null cursor when fewer than limit+1 were fetched', () => {
    const rows = [{ id: 'a' }, { id: 'b' }];
    expect(buildPage(rows, 5)).toEqual({ data: rows, nextCursor: null });
  });

  it('drops the probe row and returns its predecessor id as the cursor when more exist', () => {
    // limit 2, fetched 3 (limit+1) → more pages exist
    const rows = [{ id: 'a' }, { id: 'b' }, { id: 'c' }];
    expect(buildPage(rows, 2)).toEqual({ data: [{ id: 'a' }, { id: 'b' }], nextCursor: 'b' });
  });

  it('returns an empty page and null cursor for no rows', () => {
    expect(buildPage([], 50)).toEqual({ data: [], nextCursor: null });
  });
});
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd backend && npx jest src/lib/pagination.test.ts
```
Expected: FAIL — `Cannot find module './pagination'`.

- [ ] **Step 3: Write the helper**

Create `backend/src/lib/pagination.ts`:

```typescript
import { Request } from 'express';
import { ValidationError } from '../middleware/errorHandler';

/** Default page size when the caller does not ask for one. */
export const DEFAULT_LIMIT = 50;
/** Hard ceiling — a caller cannot ask for more than this in one page. */
export const MAX_LIMIT = 200;

export interface Pagination {
  limit: number;
  cursor: string | undefined;
}

/**
 * Reads `?limit=&cursor=` off a request.
 *
 * `limit` defaults to DEFAULT_LIMIT, is clamped up to MAX_LIMIT, and a
 * malformed value (non-integer, zero, negative, non-numeric) is a
 * ValidationError — the route layer turns that into a 400. Clamping the top
 * end but rejecting the bottom is deliberate: "give me 9999" is a reasonable
 * ask we can satisfy with 200, but "give me 0" or "give me abc" is a bug in
 * the caller we should surface, not paper over.
 */
export function parsePagination(req: Request): Pagination {
  const rawLimit = req.query.limit;
  const rawCursor = req.query.cursor;

  let limit = DEFAULT_LIMIT;
  if (rawLimit !== undefined) {
    if (typeof rawLimit !== 'string') {
      throw new ValidationError('limit must be a single positive integer');
    }
    const parsed = Number(rawLimit);
    if (!Number.isInteger(parsed) || parsed < 1) {
      throw new ValidationError('limit must be a positive integer');
    }
    limit = Math.min(parsed, MAX_LIMIT);
  }

  const cursor = typeof rawCursor === 'string' ? rawCursor : undefined;
  return { limit, cursor };
}

/**
 * Turns a keyset query's rows into a page envelope.
 *
 * The caller fetches `limit + 1` rows: if that probe row came back, there is
 * another page, so drop it and hand back the last KEPT row's id as the cursor.
 * The id must be a stable, unique sort tiebreaker — see the service query.
 */
export function buildPage<T extends { id: string }>(
  rows: T[],
  limit: number,
): { data: T[]; nextCursor: string | null } {
  const hasMore = rows.length > limit;
  const data = hasMore ? rows.slice(0, limit) : rows;
  const nextCursor = hasMore ? data[data.length - 1].id : null;
  return { data, nextCursor };
}
```

- [ ] **Step 4: Confirm `ValidationError` exists and maps to 400**

```bash
cd backend && grep -rn "class ValidationError\|ValidationError" src/lib/errors.ts src/middleware/errorHandler.ts | head
```
Expected: `ValidationError` is defined in `src/lib/errors.ts` and `errorHandler.ts` maps it to a 400. If it does NOT exist under that name, stop and report — do not invent an error class; find the codebase's existing 400-mapped error (grep `status(400)` handlers) and use that instead, updating the import.

- [ ] **Step 5: Run it and watch it pass**

```bash
cd backend && npx jest src/lib/pagination.test.ts
```
Expected: PASS, 9 tests.

- [ ] **Step 6: Commit**

```bash
git add backend/src/lib/pagination.ts backend/src/lib/pagination.test.ts
git commit -m "feat(backend): shared parsePagination + buildPage helpers (#141)"
```

---

## Task 2: App PaginatedResponse model

**Files:**
- Create: `app/lib/core/network/paginated_response.dart`
- Create: `app/test/core/network/paginated_response_test.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/core/network/paginated_response_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';

void main() {
  group('PaginatedResponse.fromJson', () {
    test('parses data and a nextCursor', () {
      final page = PaginatedResponse.fromJson(
        const {'data': [1, 2, 3], 'nextCursor': 'abc'},
        (e) => e as int,
      );
      expect(page.data, [1, 2, 3]);
      expect(page.nextCursor, 'abc');
    });

    test('parses a null nextCursor as null', () {
      final page = PaginatedResponse.fromJson(
        const {'data': [], 'nextCursor': null},
        (e) => e as int,
      );
      expect(page.data, isEmpty);
      expect(page.nextCursor, isNull);
    });

    test('treats a missing data key as an empty list', () {
      final page = PaginatedResponse.fromJson(
        const {'nextCursor': null},
        (e) => e as int,
      );
      expect(page.data, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd app && flutter test test/core/network/paginated_response_test.dart
```
Expected: FAIL — `Target of URI doesn't exist`.

- [ ] **Step 3: Write the model**

Create `app/lib/core/network/paginated_response.dart`:

```dart
/// One page of a list endpoint's response: the rows plus an opaque cursor to
/// the next page, or null when this is the last page.
///
/// Every list repository returns this. The matching backend envelope is
/// `{ "data": [...], "nextCursor": "<id>" | null }` — see
/// `docs/superpowers/specs/2026-07-23-list-pagination-design.md`.
class PaginatedResponse<T> {
  const PaginatedResponse({required this.data, required this.nextCursor});

  final List<T> data;
  final String? nextCursor;

  /// [parse] converts one raw JSON element into a `T`.
  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? element) parse,
  ) {
    final raw = (json['data'] as List?) ?? const [];
    return PaginatedResponse(
      data: raw.map(parse).toList(),
      nextCursor: json['nextCursor'] as String?,
    );
  }
}
```

- [ ] **Step 4: Run it and watch it pass**

```bash
cd app && flutter test test/core/network/paginated_response_test.dart
```
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/network/paginated_response.dart app/test/core/network/paginated_response_test.dart
git commit -m "feat(app): PaginatedResponse<T> envelope model (#141)"
```

---

## Task 3: Convert the alerts backend to the envelope

**Files:**
- Modify: `backend/src/modules/alerts/alerts.service.ts`
- Modify: `backend/src/modules/alerts/alerts.routes.ts`
- Modify: `backend/src/modules/alerts/alerts.routes.test.ts`

- [ ] **Step 1: Write the failing test**

Append to `backend/src/modules/alerts/alerts.routes.test.ts`, inside the existing
`describe('alerts routes', ...)`. The suite already creates a `client`, a `manager`, and
`managerToken` in `beforeAll` — reuse them. Add a nested block that seeds enough alerts to page:

```typescript
  describe('GET /alerts pagination', () => {
    beforeAll(async () => {
      // Three alerts for this client, distinct createdAt so ordering is stable.
      await prisma.alert.createMany({
        data: [0, 1, 2].map((i) => ({
          clientId,
          metric: 'oos',
          message: `page-alert-${i}`,
          severity: 'warning',
          acknowledged: false,
          createdAt: new Date(`2026-07-20T0${i}:00:00.000Z`),
        })),
      });
    });

    it('returns an envelope with data and nextCursor, newest first', async () => {
      const res = await request(app)
        .get('/alerts')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body).toHaveProperty('nextCursor');
      const times = res.body.data.map((a: { message: string }) => a.message);
      // newest first — page-alert-2 (02:00) before page-alert-0 (00:00)
      expect(times.indexOf('page-alert-2')).toBeLessThan(times.indexOf('page-alert-0'));
    });

    it('caps the page at limit and returns a cursor to the next page', async () => {
      const first = await request(app)
        .get('/alerts?limit=2')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(first.status).toBe(200);
      expect(first.body.data).toHaveLength(2);
      expect(first.body.nextCursor).not.toBeNull();

      const second = await request(app)
        .get(`/alerts?limit=2&cursor=${first.body.nextCursor}`)
        .set('Authorization', `Bearer ${managerToken}`);
      expect(second.status).toBe(200);
      // No id from the first page reappears on the second.
      const firstIds = first.body.data.map((a: { id: string }) => a.id);
      const secondIds = second.body.data.map((a: { id: string }) => a.id);
      expect(secondIds.some((id: string) => firstIds.includes(id))).toBe(false);
    });

    it('clamps limit above the max to 200', async () => {
      const res = await request(app)
        .get('/alerts?limit=9999')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);
      // Fewer than 200 alerts exist, so this just proves it did not error.
      expect(Array.isArray(res.body.data)).toBe(true);
    });

    it('rejects a non-positive limit with 400', async () => {
      const res = await request(app)
        .get('/alerts?limit=0')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(400);
    });
  });
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd backend && npx jest src/modules/alerts/alerts.routes.test.ts -t "GET /alerts pagination"
```
Expected: FAIL — `res.body.data` is undefined (the route still returns a bare array).

- [ ] **Step 3: Convert the service**

In `backend/src/modules/alerts/alerts.service.ts`, extend `ListAlertsInput` and `listAlerts`:

```typescript
export interface ListAlertsInput {
  clientId: string;
  acknowledged?: boolean;
  severity?: string;
  limit: number;
  cursor?: string;
}

export async function listAlerts(input: ListAlertsInput) {
  const rows = await prisma.alert.findMany({
    where: {
      clientId: input.clientId,
      ...(input.acknowledged !== undefined ? { acknowledged: input.acknowledged } : {}),
      ...(input.severity !== undefined ? { severity: input.severity } : {}),
    },
    // `id` is the unique tiebreaker that makes the cursor deterministic when
    // two alerts share a createdAt — same reasoning as agents.service.ts.
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
  });
  return buildPage(rows, input.limit);
}
```

Add the import at the top of the file:

```typescript
import { buildPage } from '../../lib/pagination';
```

- [ ] **Step 4: Convert the route**

In `backend/src/modules/alerts/alerts.routes.ts`, add the import:

```typescript
import { parsePagination } from '../../lib/pagination';
```

and change the `GET /` handler's `listAlerts` call + response. Replace:

```typescript
  const alerts = await listAlerts({
    clientId: req.user!.clientId,
    acknowledged: acknowledged === undefined ? undefined : acknowledged === 'true',
    severity: severity as string | undefined,
  });
  res.status(200).json(alerts);
```

with:

```typescript
  const { limit, cursor } = parsePagination(req);
  const page = await listAlerts({
    clientId: req.user!.clientId,
    acknowledged: acknowledged === undefined ? undefined : acknowledged === 'true',
    severity: severity as string | undefined,
    limit,
    cursor,
  });
  res.status(200).json(page);
```

`parsePagination` throws `ValidationError` on a bad limit; the router's existing async error
handling forwards it to `errorHandler`, which returns 400. Confirm this router does not swallow
errors in a try/catch that would turn it into a 500 — if it has its own try/catch around the
handler body, let `ValidationError` propagate (re-throw it) rather than mapping it to 500.

- [ ] **Step 5: Run the alerts tests and watch them pass**

```bash
cd backend && npx jest src/modules/alerts/
```
Expected: PASS — the four new pagination tests plus the pre-existing alerts tests. Note: the
pre-existing `GET /alerts` test (if any) asserted on a bare array and will now fail against the
envelope — update it to read `res.body.data`, and say so in your report. Do not weaken it beyond
that mechanical change.

- [ ] **Step 6: Full backend suite for regressions**

```bash
cd backend && npx jest --maxWorkers=4
```
Expected: PASS. `--maxWorkers=4` avoids the connection-exhaustion failures (#181). If a single
*unrelated* suite flakes, that is the known #186 flake — re-run to confirm, do not chase it.

- [ ] **Step 7: Commit**

```bash
git add backend/src/modules/alerts/
git commit -m "feat(backend): paginate GET /alerts with the shared envelope (#141)"
```

---

## Task 4: Convert the alerts app repository

**Files:**
- Modify: `app/lib/features/alerts/data/alerts_repository.dart`
- Modify: `app/test/features/alerts/alerts_repository_test.dart`

- [ ] **Step 1: Write the failing test**

Read `app/test/features/alerts/alerts_repository_test.dart` first to match its Dio-mocking
style (it likely swaps `dio.httpClientAdapter` or uses an interceptor — follow whatever it
already does). Add a test asserting the repository parses the envelope:

```dart
  test('listAlerts parses the {data, nextCursor} envelope', () async {
    // Arrange the mock so GET /alerts returns an envelope, not a bare array.
    // (Match the file's existing mock-response mechanism.)
    final page = await repository.listAlerts();
    expect(page, isA<PaginatedResponse<AlertItem>>());
    expect(page.data, isNotEmpty);
    expect(page.nextCursor, isNotNull);
  });
```

You will need `import 'package:tradeiq_app/core/network/paginated_response.dart';` at the top,
and the mock's response body must be `{'data': [ ...one alert json... ], 'nextCursor': 'x'}`.
If the existing tests assert `listAlerts` returns a `List<AlertItem>`, update those to read
`.data` — that is the contract change, not a weakening.

- [ ] **Step 2: Run it and watch it fail**

```bash
cd app && flutter test test/features/alerts/alerts_repository_test.dart
```
Expected: FAIL — `listAlerts` still returns `List<AlertItem>` / return type mismatch.

- [ ] **Step 3: Convert the repository**

In `app/lib/features/alerts/data/alerts_repository.dart`:

Add the import:

```dart
import '../../../core/network/paginated_response.dart';
```

Change the abstract signature and the Dio implementation. Replace:

```dart
  Future<List<AlertItem>> listAlerts({bool? acknowledged, String? severity});
```

in the abstract class with:

```dart
  Future<PaginatedResponse<AlertItem>> listAlerts({bool? acknowledged, String? severity});
```

and replace the implementation body:

```dart
  Future<List<AlertItem>> listAlerts({
    bool? acknowledged,
    String? severity,
  }) async {
    final query = <String, dynamic>{};
    if (acknowledged != null) query['acknowledged'] = acknowledged ? 'true' : 'false';
    if (severity != null) query['severity'] = severity;
    final response = await dio.get('/alerts', queryParameters: query);
    return (response.data as List)
        .map((json) => AlertItem.fromJson(json as Map<String, dynamic>))
        .toList();
  }
```

with:

```dart
  Future<PaginatedResponse<AlertItem>> listAlerts({
    bool? acknowledged,
    String? severity,
  }) async {
    final query = <String, dynamic>{};
    if (acknowledged != null) query['acknowledged'] = acknowledged ? 'true' : 'false';
    if (severity != null) query['severity'] = severity;
    final response = await dio.get('/alerts', queryParameters: query);
    return PaginatedResponse<AlertItem>.fromJson(
      response.data as Map<String, dynamic>,
      (e) => AlertItem.fromJson(e as Map<String, dynamic>),
    );
  }
```

- [ ] **Step 4: Keep the provider's consumers working by unwrapping `.data`**

`alertsListProvider` currently returns `Future<List<AlertItem>>` and feeds the dashboard "Needs
attention" panel (`dashboard_shell_screen.dart:250`). Keep that contract so no screen changes.
Replace:

```dart
final alertsListProvider = FutureProvider<List<AlertItem>>((ref) {
  return ref.read(alertsRepositoryProvider).listAlerts();
});
```

with:

```dart
// The provider exposes the FIRST PAGE as a plain list: the "Needs attention"
// panel wants the most recent alerts, not the whole history, and "load more"
// UI is deliberately out of scope for the pagination sweep (see the spec).
// `nextCursor` is available on the repository for any screen that later needs
// to page; this provider intentionally drops it.
final alertsListProvider = FutureProvider<List<AlertItem>>((ref) async {
  final page = await ref.read(alertsRepositoryProvider).listAlerts();
  return page.data;
});
```

- [ ] **Step 5: Run the alerts app tests and watch them pass**

```bash
cd app && flutter test test/features/alerts/
```
Expected: PASS. `alert_rules_screen_test.dart` and `alerts_screen_test.dart` should be
unaffected because the provider still yields `List<AlertItem>`. If a screen test used a fake
repository whose `listAlerts` returned a `List`, update that fake to return a
`PaginatedResponse` — a mechanical change, report it.

- [ ] **Step 6: Analyze**

```bash
cd app && flutter analyze
```
Expected: "No issues found!". Fix any type error the signature change surfaced in a consumer you
did not expect — every consumer of `listAlerts` directly (not via the provider) must now read
`.data`.

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/alerts/ app/test/features/alerts/
git commit -m "feat(app): alerts repository returns PaginatedResponse, provider unwraps first page (#141)"
```

---

## Task 5: Full verification and PR

- [ ] **Step 1: Both suites clean**

```bash
cd backend && npx jest --maxWorkers=4
cd ../app && flutter test && flutter analyze
```
Expected: all green. A single unrelated backend flake is the known #186 issue — re-run to
confirm it is not your change. Anything reproducible is a real regression; stop and fix it.

- [ ] **Step 2: Open the PR**

```bash
git push -u origin <this-branch>
gh pr create --title "feat: pagination Slice 0 — shared helpers + alerts pattern-setter (#141)" --body "$(cat <<'EOF'
First slice of the #141 pagination sweep (H4). Establishes the pattern every other module copies.

## What this lands
- **Backend `parsePagination` + `buildPage`** (`src/lib/pagination.ts`) — `?limit=&cursor=`, default 50, hard max 200, 400 on a bad limit, keyset `buildPage` that turns `limit+1` rows into `{ data, nextCursor }`. Extracted from the pattern already proven in the agents module.
- **App `PaginatedResponse<T>`** (`core/network/paginated_response.dart`) — one envelope model for every list repository.
- **Alerts converted end to end** as the pattern-setter: `GET /alerts` returns `{ data, nextCursor }`; the app repository returns `PaginatedResponse<AlertItem>`; `alertsListProvider` unwraps `.data` so the dashboard "Needs attention" panel is untouched.

## Why alerts, not visits
A pattern-setter must exercise the app side. The app never lists `GET /visits` (its repository only checks in / submits); it does list `GET /alerts`. See the spec.

## No back-compat bare arrays
There are no external API consumers — the Flutter app is the only client and ships from this repo. A capped bare array would silently lose data; an uncapped one would not fix the OOM. So the envelope is returned always. Full reasoning in `docs/superpowers/specs/2026-07-23-list-pagination-design.md`.

## The template for the remaining modules
Each later slice is one module: service takes `limit`/`cursor` + keyset query, route calls `parsePagination`, repository returns `PaginatedResponse`, provider unwraps `.data`. Small, reviewable, independently shippable.

## Out of scope (tracked)
- N7 per-tenant email uniqueness → #188 (forces a login-discriminator redesign).
- "Load more" UI — deferred; `nextCursor` is plumbed through for when a screen needs it.

## Verified
- Backend `--maxWorkers=4` green; app suite + analyze green.
EOF
)"
```

- [ ] **Step 3: Update #141**

Comment on #141 that Slice 0 has landed (helpers + alerts), the template is set, and list the
modules remaining for subsequent slices. Do not close #141 — it tracks the whole sweep.

---

## Self-review notes

Checked against the spec:

- Envelope `{ data, nextCursor }` always → Tasks 3, 4
- `parsePagination` default 50 / max 200 / 400 on bad limit → Task 1
- Keyset cursor with unique `id` tiebreaker, `take: limit+1` → Tasks 1 (buildPage), 3 (query)
- No offset pagination → Task 3 uses `cursor`/`skip:1`, never bare `skip:n`
- One `PaginatedResponse<T>` on the app → Task 2, used in Task 4
- Provider unwraps `.data`, screens unchanged → Task 4 Step 4
- No "load more" UI → not built; documented in the provider comment
- Testing per endpoint (default, explicit limit, cap clamp, cursor→page2, 400) → Task 3
- Testing per repository (envelope parse) → Task 4

Type consistency: `Pagination { limit, cursor }`, `buildPage<T extends {id}>` → `{ data, nextCursor }`, and `PaginatedResponse<T> { data, nextCursor }` are named identically everywhere they appear. `listAlerts` returns `PaginatedResponse<AlertItem>` in both the abstract class and the impl.

One thing left to the implementer's verification, not assumed: that `ValidationError` is the codebase's 400-mapped error class (Task 1 Step 4 checks this before relying on it). If the codebase names it differently, the implementer substitutes the real one rather than inventing it.
