# Conversational TradeIQ — design

**Date:** 2026-08-02
**Status:** approved, not yet implemented
**Plan:** `docs/superpowers/plans/2026-08-02-conversational-tradeiq.md`
**Tracker:** `STATUS.md`

This document is the **contract authority**: the shapes, the wire protocol, and
the security model. The plan owns sequencing and tasks; `STATUS.md` owns
progress. Where this document and the plan disagree about a *shape*, this one
wins.

## Why

The manager console has 21 sidebar destinations across three groups. A manager
answering "how is this agent doing" navigates to a screen, filters it, reads it,
then repeats for the next question. A trade-marketing practitioner described the
resulting workflow precisely:

> *"You have to filter… you get an output. Save the output. And then if you want
> another, you do your own analysis… then you go back to something else and you
> try and overlay what you've saved there with what you have here. So… we are
> trying to kill all of that."*

Two things follow. The interface should be a conversation, not a menu. And
**comparison is the product**, not a feature — the thing being replaced is
manual overlay in Excel.

A second finding sets the accuracy bar. Their fraud incident — agents reusing
GPS coordinates — took *two to three months* to surface. Any answer this system
gives about agent performance may end a contract, so a confidently wrong number
is the worst failure mode available to us. That single constraint drives the
data-access design below.

## Purpose and scope

| Question | Decision |
|---|---|
| Replace the dashboard, or add to it? | **Add**, until Phase 4. Chat ships behind a per-client flag alongside the existing 21 destinations. Nothing is removed before its replacement is proven |
| Who is the user? | The **manager console**. The field app is offline-first and chat needs connectivity (open question #1) |
| Can the model write? | Yes, from Phase 3, under a three-tier risk gate |
| Can the model reach the database? | **No.** Tools wrap existing service functions. The model never sees SQL, Prisma, or a table name |
| Can the model generate UI? | **No.** It emits a spec from a closed catalog; Flutter renders a registered widget |
| Who decides which tools exist for a turn? | The caller's JWT role, resolved server-side before the turn starts |
| One agent or many? | **One** orchestrator; many single-purpose tools. Specialisation lives in the tool layer, not in extra models |

## Core contracts

### 1. Tool — a closure, not a function with a tenant argument

The single most important shape in the system. A tool is **constructed per
request**, closing over the authenticated user. There is no parameter through
which the model could widen scope, so isolation is enforced by the type
signature rather than by validation somebody might forget to write.

```ts
// The model supplies ONLY business arguments. Never identity.
type ToolArgs = Record<string, unknown>;   // validated by the tool's Zod schema

interface AssistantTool<A extends ToolArgs, R> {
  readonly name: string;                    // stable; part of the cache prefix
  readonly pillar: Pillar;                  // sales | stock | visibility | competition | execution
  readonly description: string;             // states WHEN to call it, not just what it does
  readonly args: z.ZodType<A>;
  readonly run: (args: A) => Promise<R>;    // already bound to the caller
}

type Pillar = 'sales' | 'stock' | 'visibility' | 'competition' | 'execution';

// Construction — the only place identity enters.
function buildTools(user: AuthUser): AssistantTool<never, unknown>[];
```

**Rule:** if a tool's `args` schema ever contains `clientId`, `tenantId`, or
`userId`, that is a defect, not a feature. The roster test asserts it.

Descriptions are **prescriptive** — "Call this when the user asks about stock
levels or availability", not "Returns stock levels". Trigger conditions in the
description measurably improve should-call rate.

### 2. Roster — the security boundary

```ts
function rosterFor(role: Role): ReadonlySet<string>;   // tool names
type Role = 'field_agent' | 'manager' | 'admin';
```

Pure, exhaustively tested, and deliberately **not** derived from a hierarchy —
`admin ⊇ manager ⊇ field_agent` is *asserted* by test, never assumed by code.
An inherited-permissions bug is silent; an explicit table is auditable.

Rosters are also the accuracy control: tool-selection quality degrades past
~30–50 visible tools, so no role sees the union.

### 3. View spec — what the model may draw

```ts
type ViewSpec =
  | { type: 'agent_scorecard';  params: { agentId: string;  period: Period } }
  | { type: 'trend_chart';      params: { metric: Metric; period: Period; groupBy?: GroupBy } }
  | { type: 'outlet_map';       params: { territoryId?: string; outletIds?: string[] } };
  // …catalog grows per phase; it is CLOSED at every point in time.
```

The catalog being closed is a feature: the model cannot invent a chart type that
violates `charts.dart`'s design rules (one series one hue, recessive chrome,
selective labels). An unrecognised spec renders as text, never as a blank card.

### 4. Period and comparison — taken from practitioner usage

```ts
type Period =
  | { kind: 'today' | 'yesterday' | 'previous_week' | 'mtd' | 'ytd' }
  | { kind: 'custom'; from: IsoDate; to: IsoDate };

type CompareTo =
  | { kind: 'previous_period' }
  | { kind: 'same_period_last_year' }
  | { kind: 'territory' | 'agent' | 'sku'; id: string };
```

Not invented — this mirrors the drop-down a practitioner uses daily
(*"day-to-day, previous day, previous week, month-to-date and year-to-date… and
then a drop-down for a specific period"*). `compareTo` is what kills the Excel
overlay.

### 5. Artifact — a stateful view spec

```ts
interface Artifact {
  id: string;
  conversationId: string;
  type: ViewSpec['type'];
  toolName: string;               // which tool refreshes it
  params: unknown;                // validated by the type's params schema
  paramsHistory: unknown[];       // undo stack, capped at 20
  createdAt: Date;
  updatedAt: Date;
}
```

`params` is the **single source of truth**, and exactly one Zod schema per
artifact type governs it. The model writes through that schema; the UI writes
through the same schema. Neither can express something the other cannot — which
is what keeps the two control paths from drifting.

### 6. Risk tier

```ts
type RiskTier = 'read' | 'reversible' | 'irreversible';
function tierOf(toolName: string): RiskTier;   // pure, table-driven
```

Reads never prompt. Gating everything is how approval UX dies.

### 7. Provider — the only vendor-aware seam

Two providers, one interface. The **SSE event vocabulary below is the
normalisation boundary**: an adapter's entire job is vendor stream →
`TurnEvent`. Everything above it — orchestrator, routes, Flutter client — is
vendor-blind.

```ts
interface LlmProvider {
  readonly name: 'anthropic' | 'gemini';
  readonly models: { orchestrator: string; quarantine: string };

  runTurn(input: TurnInput, signal: AbortSignal): AsyncIterable<TurnEvent>;
  normaliseUsage(raw: unknown): Usage;
}

interface TurnInput {
  system: string;                          // frozen; cached prefix
  tools: AssistantTool<never, unknown>[];  // our shape; adapter converts
  messages: Message[];
  toolChoice?: 'auto' | 'none';
}

interface Usage {
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens: number;   // hides cache_read_input_tokens vs cachedContentTokenCount
  costCents: number;
}
```

What each adapter absorbs, and must not leak upward:

| Concern | Anthropic | Gemini |
|---|---|---|
| Tool call shape | `tool_use` content blocks | `function_call` steps |
| System prompt | Top-level `system` parameter | Handled differently — **the most common migration bug** |
| Caching | Explicit `cache_control` breakpoint | Implicit by default; explicit `CachedContent` + TTL optional |
| Usage field | `cache_read_input_tokens` | `cachedContentTokenCount` |

**Provider is pinned per conversation**, recorded on the conversation row. It
cannot change mid-thread: history carries vendor-specific artifacts that do not
transfer, and switching would invalidate the cached prefix regardless.

**Contract test.** Both adapters run the same scripted turn and must emit the
same normalised `TurnEvent` sequence. That test is what stops the second adapter
from silently diverging, and it is why the interface stays two methods wide —
anything broader is a contract that cannot be held.

## The SSE wire protocol

`POST /assistant/chat` streams `text/event-stream`. Event names are stable; the
client must ignore unknown event types rather than erroring, so the server can
add events without a lockstep app release.

| Event | Payload | Meaning |
|---|---|---|
| `token` | `{ text }` | Incremental narrative text |
| `tool_start` | `{ name, pillar }` | Drives the "checking stock levels…" affordance |
| `tool_end` | `{ name, ok }` | Tool finished; no result payload — data reaches the client via `artifact` |
| `artifact` | `{ id, type, params, data }` | Render or patch. **Same `id` = patch in place**, never append |
| `confirm` | `{ actionId, tool, args, reasoning, impact, rollback, expiresAt }` | Tier-3 gate; stream pauses pending `POST /assistant/confirm` |
| `usage` | `{ inputTokens, outputTokens, cacheReadTokens, costCents }` | Final; feeds the cost dashboard |
| `error` | `{ code, message }` | Terminal; `message` is user-safe, never a stack trace |
| `done` | `{}` | Stream complete |

### Figure artifacts — `stat_tiles` and `ranked_bars`

Added 2026-09-17 with the answer design ("livelier Ask TradeIQ"). They travel
as ordinary `artifact` events, with `params: {}` and the figures in `data`, and
are built **deterministically on the server** from the tool result the model
also reads (`backend/src/modules/assistant/figures.ts`). The model never
supplies a tile or bar number. They are turn-local — not persisted, not
refinable — with ids of the form `<toolName>-<type>-<n>`, so they can never
patch the tool's view artifact. For each tool they follow `tool_end` and the
tool's own view artifact, and precede the next `tool_start` or `token`.

```ts
// type: 'stat_tiles'
{ tiles: Array<{
    label: string;                                   // "Sell-in, units"
    value: number;
    unit: 'units' | 'pct' | 'pts' | 'count';
    delta?: { value: number /* magnitude */; unit: 'pct' | 'pts' | 'count';
              direction: 'up' | 'down'; sentiment: 'good' | 'bad' | 'warn' | 'neutral' };
    comparedTo?: string;                             // "vs 55,034 · Aug '25", pre-formatted
    meter?: number;                                  // 0–100
}> }

// type: 'ranked_bars' — items ordered worst first, signs preserved
{ title: string; comparedTo: string; unit: 'units' | 'pct' | 'pts' | 'count';
  items: Array<{ label: string; value: number }> }
```

| Tool | Figures |
|---|---|
| `getRateOfSale` | tiles: sell-in units (Δ% vs comparison), target attainment with `meter` — **whole months with a target only**, outlets ordering |
| `getStockLevels` | tiles: on-shelf availability (Δpts), outlets with a stock-out (Δcount); bars: out-of-stock lines by outlet |
| `getShareOfShelf` | tile: share of shelf |
| `getVisibilityCompliance` | tiles: planogram compliance, high-traffic placement |
| `getCompetitorActivity` | tiles: competitor promoter presence, competitor SKUs seen; bars: competitor facings by SKU |
| `getAgentScorecard` | tiles: execution score (Δ vs team), visits, outlets visited |
| `getTerritoryRanking` | tile: combined sell-in units of the territories in scope (Δ% vs comparison); bars: "Change by territory" — signed sell-in % change per territory, worst first, ties by name. Territories with no comparison-window sell-in are left out of the bars (listed in the result's `excludedNoComparison`) |

Sentiment comes from the `SENTIMENT` table in `figures.ts`, never from the
model. A figure with no observations behind it is omitted rather than shown as
0. `trend_chart` data may carry `comparison: { label, basis, points }` — the
prior-period series — only when the tool was asked for a comparison.

### Answer markdown conventions

The app renders `token` text as markdown: the first paragraph as a one-sentence
headline, a blockquote opening `**What explains it**` as the insight callout,
and a fenced block tagged `followups` (at most three questions, one per line) as
tappable follow-ups. It does so for **any** model text, whether or not the
prompt asks for these constructs. Tool results are therefore neutralised before
they reach the model (`neutraliseAnswerMarkup` in `sanitize.ts`, applied to
every tool-result string, to quarantine summaries, and to tool-facing error
messages) so text written by field agents or outlet owners cannot smuggle a
fence or a callout through the model.

From prompt v3 (`SYSTEM_PROMPT_VERSION = 'v3-2026-09-17'`, rules 10–14) the
model is asked to produce these constructs: a one-sentence headline with the
key figure, at most one `**What explains it**` callout backed by retrieved
figures, no restating of tile/bar/chart numbers, and up to three follow-ups.

**Why `artifact` carries `data`:** the alternative — client re-fetches after the
event — doubles latency on the visible path and re-runs the tool for no benefit.
Refreshes after a *filter change* go through `refine`, which is a different path
with different economics.

**Why `tool_end` carries no result:** tool output can be large and is the
untrusted surface. It reaches the model through the quarantine path and reaches
the client only as validated artifact data.

## Turn lifecycle

```
POST /assistant/chat
  │
  ├─ requireAuth → req.user {userId, role, clientId}
  ├─ buildTools(user)          ← identity bound here, once
  ├─ rosterFor(user.role)      ← filter to the allowed set
  ├─ assemble prompt:
  │     [tools][system]  ← FROZEN, cache breakpoint here
  │     [history][artifact manifest][user message]  ← volatile, after the breakpoint
  │
  ├─ tool_runner loop
  │     ├─ tool call → run(args)
  │     ├─ result → sanitize() → spotlight-wrap
  │     ├─ free-text fields → quarantine() → tool-less Haiku → structured
  │     └─ structured result → back to orchestrator
  │
  └─ stream events → client
```

The ordering of the prompt is load-bearing. Caching is a prefix match, so
anything volatile — timestamps, the user's name, the artifact manifest — must
sit *after* the breakpoint. A single interpolated value in the system prompt
turns every turn into a cache miss, which is a cost regression no functional
test would catch. Hence the CI assertion on `cache_read_input_tokens`.

## Security model

Three layers, in decreasing order of strength.

**1. Structural — identity is not a parameter.** Tools close over `req.user`.
The model has no argument through which to request another tenant's data. This
is the layer that actually holds; the rest are defence in depth.

**2. Quarantine — untrusted text never reaches a tool-capable model.** Field
agents author visit notes, outlet names, and messages. That text flows into tool
results and therefore into context. Prompt injection is #1 on the OWASP LLM Top
10 and no single defence closes the gap, so:

- Structured fields (numbers, dates, enums) pass through directly — no injection
  surface.
- Free-text fields go through a **tool-less** Haiku call that returns structured
  output. An injected instruction has no tool to reach.
- Anything passing through verbatim is spotlight-wrapped as data, not
  instruction.

**3. Instructional — the weakest layer, never the only one.** The system prompt
says to treat tool output as data. This is stated last deliberately: a design
that relies on it is a design that fails.

**Excessive agency** (OWASP LLM06) is handled by the roster (least privilege,
per request) plus the risk tiers (human-in-the-loop for irreversible actions),
not by asking the model to be careful.

## Verification approach

| Layer | Runs | Asserts |
|---|---|---|
| Unit | Every commit | Roster matrix — every `(role × tool)` pair, incl. negatives. Spec/params validation rejects unknown types and malformed input. Tier table is total |
| Integration | Every commit | Stubbed model → scripted `tool_use` → correct service called with the caller's `clientId`; result serialises to a valid spec |
| Live evals | PR (cheap slice) · nightly (full) | Tool-selection accuracy ≥ 90% against a versioned golden set |
| Red-team | Nightly, from Phase 3 | Injection payloads in outlet names / visit notes / messages; cross-tenant probe. **Zero tolerance** |
| Cost | Every commit | `cache_read_input_tokens > 0` on turn 2 |

**Non-determinism is handled by scoring, not equality.** Assert tool choice and
spec type, never prose. Thresholds, not exact matches. And measure the grader's
own self-agreement — a 95% pass rate from a grader that disagrees with itself is
noise, so `UNSTABLE` is a failing state.

Tool-selection accuracy is the primary metric precisely because it is
*deterministic*: did it call `getAgentScorecard`? No judge required for most of
the suite.

## Out of scope

| Excluded | Why |
|---|---|
| Text-to-SQL / model-authored queries | Fails by inventing plausible numbers. The failure mode, not the accuracy delta, is disqualifying |
| LangChain / LangGraph | Wrong shape for a single-model request/response loop. Tripwire: durable multi-day resume or >3 loop branches re-opens it |
| Multi-orchestrator | Two brains on one manager's data — slower, costlier, no quality gain |
| `flutter/genui` package | Adopt the A2UI *pattern*; the SDK is highly experimental with no streaming UI |
| Speech-to-speech voice | ~10× cost and no auditable text boundary |
| Route optimisation | Ruled out by the practitioner: *"you don't want to be a fleet management tool"* |
| Server-side PDF for scheduled reports | Different problem from on-demand export; `/report-schedules` cannot reuse Flutter charts |
| New fraud signals | The assistant surfaces what `fraud.service.ts` computes. Five described-but-missing signals are backend work, tracked in `STATUS.md` |
| Macro-economic overlay | Needs external data feeds that do not exist |
