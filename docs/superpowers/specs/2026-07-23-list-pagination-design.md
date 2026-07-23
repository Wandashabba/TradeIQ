# List Pagination Design (#141, H4)

**Issue:** #141 (Plan 2b of the 2026-07-17 audit), H4 half only.

#141 bundled two things: H4 (no list endpoint is bounded) and N7 (`User.email` should be
per-tenant unique). This spec covers **H4 alone**. N7 was split into #188 because it is a
login-identity redesign, not a migration — `findUnique({ where: { email } })` cannot survive
per-tenant email, so login needs a tenant discriminator, and that is a separate decision.

## Problem

`take:` appears exactly once in 72 non-test `findMany` calls, and that one
(`scorecards.service.ts:197`) is not reachable from a route. Every list endpoint returns the
tenant's entire history: `GET /visits`, `/tasks`, `/alerts`, `/orders`, `/photos` (8MB base64
rows), `/messages`, and ~25 more. Worst case, `GET /dashboard` with no `from`/`to` hydrates
every visit plus five relations into the Node heap — at ~190k visits/year that is millions of
objects and an OOM.

Roughly **30 list endpoints** are affected (31 service files under `backend/src/modules/` call
`findMany`; a few are single-row lookups rather than lists, and the exact list will be pinned per
slice during implementation), with roughly the same number of Flutter list repositories consuming
them.

## The decision that shapes everything: there are no external consumers

The only client of this API is the Flutter app, which lives in this repo and deploys with the
backend. There is no OpenAPI surface, no partner API (that is Phase 4, #59), and CORS is only a
frontend origin allowlist. "Contract-breaking" therefore has no external victim — the app and
backend change together, in the same repo, on the same branch.

This kills the back-compat option #141 floated ("accept `?limit` but keep returning an array").
A bare array that is capped silently truncates callers (data loss); a bare array left uncapped
does not fix the OOM this issue exists to fix. Back-compat machinery would protect nobody while
delivering neither goal. So: **every list endpoint returns the envelope, always.**

## Contract

Every list endpoint returns exactly one shape:

```json
{ "data": [ ...items ], "nextCursor": "<opaque id>" | null }
```

- `nextCursor` is the `id` of the last row in `data` when more rows exist beyond this page,
  otherwise `null`. It is opaque to the client — a cursor to hand back, not a value to interpret.

### Pagination parameters

A shared `parsePagination(req)` in `backend/src/lib/` returns `{ limit, cursor }`:

- `limit` — default **50**, hard maximum **200**. A non-integer or non-positive `limit` is a
  `400` (mirrors the guard already on `/agents/activity`).
- `cursor` — optional string; the `id` of the last row the client already has.

### Keyset cursor, not offset

Cursor pagination reuses the exact pattern already shipped and reviewed in the agents module
(`agents.service.ts`):

- `orderBy` includes a **unique tiebreaker** (`id`) so ties in the primary sort key are
  deterministic — the same tie-break bug already fixed there.
- `take: limit + 1` fetches one extra row to detect whether a next page exists.
- when a cursor is supplied: `cursor: { id: cursor }, skip: 1`.
- slice back to `limit`, and `nextCursor = hasMore ? lastRow.id : null`.

Offset pagination (`skip: n`) is rejected: it drifts and double-serves rows under the concurrent
writes these tables see.

### Align the agents module

`listAgentActivity` already returns this shape but with the key `agents` instead of `data`
(`{ agents, nextCursor }`). It is changed to `{ data, nextCursor }` so the app has exactly one
`PaginatedResponse.fromJson`, not one plus a special case. It is in-repo with no external
consumer; unifying now is cheaper than carrying two envelopes forever.

## Backend components

- `backend/src/lib/pagination.ts` — `parsePagination(req): { limit, cursor }` (validation +
  clamp) and a small helper that, given the `limit + 1` rows, returns `{ data, nextCursor }`.
  One place owns the arithmetic so no route re-derives the off-by-one.
- Each list **service** gains `limit`/`cursor` params and applies the keyset query.
- Each list **route** calls `parsePagination(req)`, passes the params through, and returns the
  envelope.

Endpoints that are already bounded by a different shape are left alone and noted: `/agents/activity`
(paged agent list + 48h range cap — only the envelope key changes), and `GET /dashboard`, whose
unboundedness is a `from`/`to` range concern rather than a list-length concern and is out of scope
here unless a list within it is the offender.

## App components

- `app/lib/core/network/paginated_response.dart` — `PaginatedResponse<T>` holding
  `List<T> data` and `String? nextCursor`, with a `fromJson` that takes an element parser. One
  model, one parser, used by every list repository.
- Each list **repository** returns `PaginatedResponse<T>` instead of `List<T>`.
- Each list **screen/provider** renders `response.data` (the first page).

### Deliberate scope limit: no "load more" UI in this sweep

Screens render the first page and stop. Infinite-scroll / "load more" is a per-screen UX
enhancement, and wiring it into ~30 screens would turn a mechanical bounding job into a UI
project. The server is bounded now; `nextCursor` is plumbed through and available, so any screen
that genuinely needs paging can adopt it later without a contract change.

The tradeoff, accepted knowingly: a screen that used to show *all* of something now shows the
most recent 50. For tasks, alerts, visits and the like this is invisible. If any single screen is
genuinely unusable capped at 50, "load more" is wired for **that** screen and called out — it is
not a reason to build the UI everywhere.

## Rollout — vertical slices, helpers first

1. **Slice 0 — helpers + pattern-setter.** Land `pagination.ts` and `PaginatedResponse<T>`,
   then convert one representative module end to end (backend + app + tests) as the template the
   rest copy. `visits` is a good candidate — it has the highest-volume table.
2. **Slices 1..N — one module per PR.** Each converts a module's list endpoints, its repositories,
   and its tests together, stays green, and ships independently. No slice leaves the app and
   backend disagreeing about a shape.
3. **Slice final — align agents** to `{ data, nextCursor }` and remove the last bespoke envelope.

Each slice is a small, reviewable PR. The sweep lands incrementally rather than as one 60-file
diff, and a slice can be paused between without leaving the tree half-converted.

## Testing

Per endpoint (backend): default-limit page, explicit `limit`, `limit` above the cap clamps to
200, a cursor returns the next page and eventually `nextCursor: null`, a bad `limit` returns
400, tenant isolation still holds.

Per repository (app): `PaginatedResponse.fromJson` parses `data` + `nextCursor`; a repository
returns the parsed page. Existing screen tests adapt to the envelope without weakening
assertions.

## Out of scope

- N7 per-tenant email uniqueness and the login-discriminator question (#188).
- "Load more" / infinite-scroll UI on list screens.
- `GET /dashboard` range-bounding, except where a nested list is the specific offender.
- Any change to a non-list endpoint.
