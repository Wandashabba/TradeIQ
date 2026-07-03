# 0001. Flutter for mobile and web

Date: 2026-07-02
Status: Accepted

## Context

The deck's original architecture specified React Native for the field-agent
mobile app and implied a separate web stack for the manager dashboard. The
team wants one codebase and one skillset across both surfaces.

## Decision

Build both the field-agent mobile app and the manager/admin dashboard as a
single Flutter codebase (`app/`), using responsive layouts to adapt between
mobile and web/desktop form factors.

## Consequences

- One team, one skillset, maximum code reuse between mobile and web.
- Flutter Web dashboards are less "native web" than a dedicated web
  framework — acceptable tradeoff for a small team's velocity.
