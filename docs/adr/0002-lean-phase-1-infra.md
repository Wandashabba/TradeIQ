# 0002. Lean Phase 1 infrastructure

Date: 2026-07-02
Status: Accepted

## Context

The pitch deck's "Technical Foundation" slide shows Kafka, PostGIS, and Redis
as part of the platform's architecture, but that slide spans all four
roadmap phases (Foundation through Scale & Optimise), not just Phase 1.

## Decision

Build Phase 1 on plain PostgreSQL (haversine geofencing, no PostGIS), a
simple REST API (no Kafka), and no Redis cache. All Phase 2+ capabilities
(real CV/OCR/ML/fraud/dispatch, Kafka, PostGIS, Redis) sit behind narrow
service interfaces so they can be swapped in later without rewriting
callers.

## Consequences

- Faster path to a working Phase 1 demo; less ops surface for a small team
  to maintain before there's real load or real ML models to justify it.
- Some Phase 2+ work will require adding new infrastructure later — accepted
  because the interfaces are designed for that swap.
