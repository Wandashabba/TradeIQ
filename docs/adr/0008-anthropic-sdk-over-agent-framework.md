# 0008. Drive the vendor SDK directly, not an agent framework

Date: 2026-08-02
Status: Accepted (amended same day — see *Amendment*)

## Context

The Conversational TradeIQ initiative needs an agent loop: take a manager's
prompt, call tools that wrap existing services, stream an answer back. The
obvious candidates were LangChain/LangGraph (the most production-mature agent
framework), Anthropic's Claude Agent SDK, Anthropic's Managed Agents, or driving
the plain SDK loop ourselves.

Public comparisons blur three distinct Anthropic products. Naming them
precisely mattered more than the framework question:

- **Claude Agent SDK** — Claude Code packaged as a library. Built-in
  Read/Write/Bash/Grep; filesystem-shaped. Wrong product for a data assistant.
- **Managed Agents** — Anthropic hosts the loop *and* a per-session sandbox.
  Right shape for scheduled, unattended work; not for a request/response chat.
- **Messages API + `tool_runner`** — we define tools, the SDK drives the loop
  and exposes per-turn hooks.

The decisive criteria, applied to this workload:

1. **Data residency?** No hard constraint today. Worth noting that Anthropic's
   *managed* features are unavailable through AWS Bedrock, so a future regional
   hosting requirement would close that path — the plain SDK stays portable.
2. **Multi-turn beyond one context window?** Eventually, but server-side
   compaction handles it without a graph framework.
3. **More than three conditional branches?** No. A tool loop is not branchy.

LangGraph's genuine wins — durable checkpoint resume, time-travel debugging,
multi-provider portability — none apply. Its costs do: 20–80ms of per-layer
overhead, the steepest learning curve of the major frameworks, and a debugging
story worse than a plain loop.

## Decision

Use **`@anthropic-ai/sdk` with `client.beta.messages.tool_runner`** in
`backend/src/modules/assistant/`. Claude Opus 5 orchestrates; Claude Haiku 4.5
handles cheap classification and the tool-less quarantine pass.

`orchestrator.ts` holds the loop and nothing else — no business logic. Tools are
closures over the authenticated user, wrapping existing `*.service.ts` functions.
Conversation state persists in Postgres from the first commit, not in memory.

## Consequences

- No new abstraction over an SDK we would be using anyway. The `tool_runner`
  per-turn hooks already provide the approval gates, error interception, and
  result modification that write actions need.
- ~~Committed to Claude. Model portability would mean rewriting the loop.~~
  **Superseded by the Amendment below.**
- **The known failure mode of this path is loop sprawl** — *"complexity
  accumulates fast; long-horizon workflows force you to rebuild LangGraph's
  checkpointing."* Mitigated by keeping the loop logic-free and state in
  Postgres.
- **Tripwire, recorded so it is not forgotten:** if we ever need durable
  multi-day resume, or the loop grows past three conditional branches, re-open
  this decision. Write the tripwire into `orchestrator.ts`'s file header so the
  next engineer sees it without reading this ADR.
- Managed Agents remains the right tool for Phase 5 scheduled digests. Choosing
  the plain SDK here does not preclude it there.

## Amendment (2026-08-02, same day)

**Context.** The Anthropic key was expected later in the week; a Gemini key was
already available. Rather than idle, we build against Gemini now and switch when
the Anthropic key lands.

**What changes.** The "committed to Claude" consequence above no longer holds.
The loop sits behind a two-method `LlmProvider` interface with adapters for both
vendors. The Gemini adapter is built first.

**What does not change.** The framework decision stands. The portability prize
LangGraph offers is "you don't rewrite the loop" — but the loop behind this
interface is roughly a hundred lines, so the prize is small while the costs
(per-layer overhead, learning curve, worse debugging) are unchanged. Two
providers behind a two-method interface is not a framework-shaped problem.

**The tripwire gains a third condition.** Re-open this decision if we need:

1. durable multi-day resume, **or**
2. more than three conditional branches in the loop, **or**
3. **a third provider, or dynamic per-request routing.**

**Costs we are accepting, stated plainly:**

- Every eval, red-team case, and cost assertion now runs **twice**. The ≥90%
  tool-selection gate is *per provider* — a regression on one must not be masked
  by the other passing.
- Providers are pinned **per conversation**, not per turn. History carries
  vendor-specific artifacts (thinking blocks, tool-call shapes) that do not
  transfer, and switching invalidates the cached prefix. "Fallback" therefore
  means a development substitute and a deployment switch — not per-turn failover.
- A contract test running both adapters over the same scripted turn is
  mandatory; without it the second adapter drifts silently.

**One thing got easier.** Gemini caches implicitly by hashing recent inputs, so
the discipline this design already mandates — frozen system prompt,
deterministic tool order, volatile content last — earns the discount on both
providers. Only the mechanism and the usage field name differ, which
`normaliseUsage` hides.

## References

- Plan: `docs/superpowers/plans/2026-08-02-conversational-tradeiq.md`
- Spec: `docs/superpowers/specs/2026-08-02-conversational-tradeiq-design.md`
