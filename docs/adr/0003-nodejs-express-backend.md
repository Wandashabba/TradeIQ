# 0003. Node.js + Express backend

Date: 2026-07-02
Status: Accepted

## Context

The detailed MVP prompt specified Node.js + Express. The pitch deck's
architecture slide shows "Node.js / FastAPI" ambiguously.

## Decision

Use Node.js + Express + TypeScript, matching the detailed MVP prompt.

## Consequences

- Consistent with the original detailed spec.
- If real ML/CV models are built in Python during Phase 2+, they'll likely
  run as a separate service called from this API rather than in-process.
