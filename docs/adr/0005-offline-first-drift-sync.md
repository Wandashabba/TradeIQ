# 0005. Offline-first with Drift + a sync queue

Date: 2026-07-02
Status: Accepted

## Context

Field agents in low-connectivity outlets need to complete a full audit visit
and see their score before leaving, without a network connection.

## Decision

Persist visit drafts locally via Drift (SQLite) and enqueue mutations in a
`SyncQueueItems` table, flushed by `SyncService` when connectivity returns.
Built into the scaffold now rather than retrofitted later.

## Consequences

- Every audit-section repository (once implemented) must write locally
  first, then enqueue a sync — this pattern needs to be followed
  consistently in the follow-up S1-S10 implementation plan.
- More upfront complexity than an online-only MVP, justified because
  retrofitting offline support after screens assume always-online is much
  more expensive.
