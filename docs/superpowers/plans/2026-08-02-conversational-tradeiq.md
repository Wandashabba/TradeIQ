# Conversational TradeIQ — Implementation Plan

> **For agentic workers:** Steps use checkbox (`- [ ]`) syntax for tracking.
> Live progress lives in `STATUS.md` at the repo root — update it as tasks land.

**Goal:** Turn the manager console from a 21-destination dashboard into a
conversation. A manager types or speaks a prompt; one orchestrator resolves who
they are, picks from a role-scoped tool roster, calls the existing service layer,
and answers with narrative text plus the *same* charts, maps, and worklists the
dashboard already renders. The bot can also speak back, and can take actions —
under an explicit risk gate.

**Architecture:** One brain, many single-purpose tools. A new
`backend/src/modules/assistant/` owns an SSE chat endpoint driving the Anthropic
TypeScript SDK's `tool_runner` loop. Tools are thin wrappers over existing
`*.service.ts` functions — never raw Prisma, never raw SQL. The tool roster
handed to the model is derived per-request from the caller's JWT role. Responses
carry text plus typed **view specs**; the Flutter client maps each spec to a
widget already built for the equivalent screen.

**Tech Stack:** TypeScript, Express, Postgres/Prisma, Flutter + Riverpod 3,
SSE over the existing `ApiClient`. Two LLM providers behind one interface:

| Provider | Orchestrator | Quarantine | Status |
|---|---|---|---|
| **Gemini** | `gemini-3.1-pro` | `gemini-3.6-flash` | Key available — **build against this first** |
| **Anthropic** | `claude-opus-5` | `claude-haiku-4-5` | Key expected later this week |

See *Provider abstraction* below. The provider is selected per conversation, not
per turn.

**Sources:** (1) a 2026-07-29 interview with a trade-marketing practitioner —
domain grounding below; (2) 2026-08-02 desk research on agent frameworks, memory,
semantic-layer accuracy, generative UI, voice, and prompt-injection defence,
summarised in the Decisions table in `STATUS.md`; (3) the codebase itself.

**Spec:** `docs/superpowers/specs/2026-08-02-conversational-tradeiq-design.md` —
the contract authority. It pins the TypeScript shapes (tool closure, roster,
view spec, artifact, risk tier), the SSE wire protocol, the turn lifecycle, and
the security model. Where this plan and the spec disagree about a *shape*, the
spec wins; this plan owns sequencing and tasks.

**Status tracking:** `STATUS.md` at the repo root. Phase status, decisions with
rationale, the backend backlog, open questions, and the risk register live there,
not here. This document is the *what and why*; `STATUS.md` is the *where we are*.

---

## Contents

**Why this shape**
- [Domain grounding](#domain-grounding--from-the-2026-07-29-practitioner-interview) — what the practitioner actually said
- [The five decisions this plan rests on](#the-five-decisions-this-plan-rests-on)
- [Which Anthropic surface](#which-anthropic-surface--a-distinction-the-comparison-articles-blur)
- [Platform choices — pros, cons, mitigation](#platform-choices--pros-cons-and-the-mitigation)
- [Explicitly not doing](#explicitly-not-doing)

**How it works**
- [How the hard parts actually get built](#how-the-hard-parts-actually-get-built) — injection, isolation, evals, fatigue
- [Artifact architecture](#artifact-architecture--two-writers-one-source-of-truth)
- [Action risk tiers](#action-risk-tiers)
- [File structure](#file-structure)
- [Background the engineer needs](#background-the-engineer-needs)

**How we build it**
- [Testing strategy](#testing-strategy)
- [Phase 0 — Read-only spine](#phase-0--read-only-spine)
- [Phase 1 — Voice, both directions](#phase-1--voice-both-directions)
- [Phase 2 — Artifacts](#phase-2--artifacts-interactive-filterable-exportable)
- [Phase 3 — Actions](#phase-3--actions)
- [Phase 4 — Shrink the console](#phase-4--shrink-the-console)
- [Phase 5 — Memory and proactivity](#phase-5--memory-and-proactivity)
- [Sequencing and dependencies](#sequencing-and-dependencies)
- [Cost model](#cost-model) · [Rollout](#rollout) · [Glossary](#glossary)

---

## Domain grounding — from the 2026-07-29 practitioner interview

A trade-marketing practitioner (MultiChoice, runs the FSS field app) walked
through how this job actually works. Four things from that conversation change
this plan; they are not inferences, they are what the user of this product said.

### The four pillars are the semantic layer

> *"Sales, stock, visibility, and competition. Those are your four pillars…
> that's all related to your **input KPIs**. That's what is feeding to the
> business."*

Tools must be grouped by **pillar**, not by REST endpoint. A manager thinks
"how's my visibility in Western Cape", not "GET /visibility?territory=". The
existing modules already map: `stock` · `visibility` · `competitive` ·
sales (`orders`/`scorecards`), with execution quality (`visits`, `fraud`,
`scorecards`) as the fifth, cross-cutting group.

### The exact workflow we are replacing

> *"It all fits into a report… you have to filter… you get an output. Save the
> output. And then if you want another, you do your own analysis… then you go
> back to something else and you try and **overlay what you've saved there with
> what you have here**. So… **we are trying to kill all of that.**"*

The pain is not "charts are hard to find." It is **filter → export → save →
re-filter → export → manually overlay in Excel.** So *comparison is the job*,
not a nice-to-have. Phase 2 artifacts must support a comparison series natively
(vs last period, vs last year, vs another territory) — otherwise we have
rebuilt the dashboard they already have.

### The period vocabulary, from the practitioner

> *"Day-to-day data, previous day, previous week, month-to-date and
> year-to-date… and then you can always go and do a drop-down if you want to
> study a specific period."*

That answers the open question from earlier planning. The artifact `period`
param is: `today` · `yesterday` · `previous_week` · `mtd` · `ytd` ·
`custom(from, to)`. Not invented — this is the vocabulary in daily use.

### The gap that is our actual differentiator

> *"Does it give you recommendations?"* — **"No."**

Their dashboards are descriptive only. But this cuts both ways: a recommendation
that isn't grounded in retrieved numbers is exactly the confidently-wrong
failure the semantic layer exists to prevent. **Rule: every recommendation must
cite the figures it came from, and those figures must come from a tool call.**
No recommendation may be produced from the model's priors.

### Fraud: the highest-value question we can ask — within limits

The practitioner's worst case was a detection-latency problem, not a
detection-capability one:

> *"The guys were bullshitting using the same coordinate… that was something we
> found **two or three months later**."*

"Which agents look off this week?" is therefore one of the strongest Phase 0
demos: months collapse to seconds. **But the assistant can only surface signals
the backend already computes.** `fraud.service.ts` currently emits
`failed_attempts`, `fast_completion`, `geofence_distance`, `no_capture`, and
`photo_gps_divergence`.

Signals the practitioner described that are **not** implemented — tracked
separately, not silently assumed by this plan:

| Signal | Their words |
|---|---|
| Duplicate photo reuse across outlets | *"I give you the same information I gave from point A"* |
| Flat/repeating stock figures | *"they'd be consistent — 2-1, 2-1… you see the data set, something is wrong"* |
| Gap between stock-entry time and photo time | *"there's a gap between stock taking and taking a picture, a massive one"* |
| Dwell **above** the benchmark, not just below | *"below that range, or too high that range — it rings a bell"* (~12 min benchmark) |
| Stock scanned outside its assigned outlet | *"you can't scan this because this stock doesn't belong to this shop"* |

Phase 0 scopes the fraud tool to the five signals that exist. Closing the gap is
a **backend** work item, independent of the assistant.

### Scale and roles

~1,000 field submissions per week against a 20–24 question audit template.
Role hierarchy confirmed as administrator → regional manager → sales force,
matching `admin` / `manager` / `field_agent`. Sidebar target from the business
conversation was *"29 items down to five, six"* — this plan says 5, close enough
to be the same intent.

---

## The five decisions this plan rests on

**1. No LangChain / LangGraph.** The workload is single-model, request/response
tool-calling — not a durable state graph. LangGraph's real wins (checkpoint
resume, time-travel, multi-provider portability) don't apply here, and it costs
20–80ms of per-layer overhead, the steepest learning curve of the major
frameworks, and a debugging story worse than a plain loop. The Anthropic SDK's
`tool_runner` already supplies the loop *plus* per-turn hooks for approval gates,
error interception, and result modification — which is exactly what write actions
need. Revisit only if approval workflows become multi-day and need durable
resume.

**2. The tools *are* the semantic layer.** Benchmarks put Claude at 90.0%
accuracy on raw text-to-SQL versus 98.2% through a semantic layer — but the
decisive difference is the failure mode. Text-to-SQL fails by returning a
confident wrong number; a semantic layer fails by saying it can't answer. A
manager acting on a fabricated scorecard is the worst outcome this system can
produce, so the model never sees SQL or Prisma. TradeIQ already has its semantic
layer: `kpiMath.ts`, `scorecards.service.ts`, `dashboard.service.ts`,
`trends.service.ts`. Tools call those.

**3. The tool roster is scoped by role — for accuracy *and* security.** Tool
selection degrades badly past 30–50 visible tools; retrieval-filtered rosters
have been measured tripling selection accuracy while halving prompt tokens. The
same mechanism is the security control: grant per request the *intersection* of
what this user may do and what the tool needs. `field_agent`, `manager`, and
`admin` get different rosters, assembled from the JWT. The model is never handed
the union, and never supplies `clientId` itself.

**4. View specs, not generated UI.** The model emits
`{type, params}` from a fixed catalog; Flutter renders the registered widget.
This is the same shape as Google's A2UI protocol, but `flutter/genui` is
explicitly "highly experimental," warns its API will change "drastically," and
does not yet support streaming UI — too much risk for a core surface. Adopt the
pattern, hand-roll the renderer (~200 lines), keep specs A2UI-shaped so adopting
the SDK later is cheap.

**5. Cascaded voice, not speech-to-speech.** S2S is faster (250–350ms vs
400–600ms) but costs roughly 10× and produces no text artifact to log, redact, or
audit. TradeIQ has a deep tool surface, RBAC filtering, and write confirmations
that must be auditable — all of which need the text boundary. Cascade:
device STT → orchestrator → TTS.

---

## Which Anthropic surface — a distinction the comparison articles blur

Public write-ups compare "Claude Agent SDK vs LangGraph." That is **not** the
choice in front of us. There are three separate Anthropic products:

| Surface | What it is | Fit here |
|---|---|---|
| **Claude Agent SDK** (`@anthropic-ai/claude-agent-sdk`) | Claude Code packaged as a library — built-in Read/Write/Bash/Grep, filesystem-shaped | ❌ Wrong shape. We're not a coding agent. |
| **Managed Agents** | Anthropic hosts the loop *and* a per-session sandbox; REST + SSE | ⏳ Phase 5 only, for scheduled digests |
| **Messages API + `tool_runner`** | Plain SDK. We define tools, SDK drives the loop, per-turn hooks for approval | ✅ **This one.** |

In the Developers Digest taxonomy our choice is closest to the "DIY while-loop"
path — whose verdict is *"do not add framework complexity before you need it. A
40-line while-loop beats LangGraph for customer support classifiers or document
Q&A."*

Their three decision questions, answered for TradeIQ:

1. **Data residency constraints?** None hard today. Worth noting: Anthropic's
   *managed* features do not work through AWS Bedrock, so if POPIA or a client
   contract ever forces regional hosting, the managed path is closed — our
   `tool_runner` approach stays portable. Logged as an open question.
2. **Multi-turn beyond one context window?** Eventually yes — handled by
   server-side compaction, not by a graph framework.
3. **More than three conditional branches?** No. A tool loop is not branchy.

Three for three toward the plain SDK.

**The named DIY failure mode is real, so mitigate it up front:** *"complexity
accumulates fast; long-horizon workflows force you to rebuild LangGraph's
checkpointing."* Mitigations: keep `orchestrator.ts` thin (loop only — no
business logic), persist conversation state in Postgres from day one rather than
in memory, and set an explicit tripwire — **if we ever need durable multi-day
resume or more than three branches in the loop, re-open the LangGraph decision.**
Write that tripwire into the file header so the next engineer sees it.

---

## Provider abstraction — Gemini as the fallback

**Added 2026-08-02, after the initial design.** The Anthropic key may arrive
later in the week, and a Gemini key is available now. Rather than idle, we build
behind a **narrow provider interface** and develop against Gemini until the
Anthropic key lands.

This partially reverses ADR 0008's *"committed to Claude"*. That ADR has been
amended rather than left to ship a claim we no longer hold.

### What was already portable, and what wasn't

The expensive layer — tools wrapping services, the roster, view specs, artifacts
— was **never provider-specific**. What is:

| Provider-specific | Why |
|---|---|
| Loop driver | `tool_runner` is an Anthropic SDK helper |
| Tool schema envelope | Anthropic returns `tool_use` content blocks; Gemini returns `function_call` steps |
| System prompt placement | Anthropic takes `system` as a top-level parameter; Gemini handles it differently. This is the single most common source of migration bugs |
| Caching mechanism | Anthropic: explicit `cache_control` breakpoints. Gemini: implicit caching on by default, plus opt-in `CachedContent` with a TTL |
| Usage field names | `cache_read_input_tokens` vs `cachedContentTokenCount` |
| Thinking / reasoning config | Different parameters, different defaults |

### The interface

The normalisation boundary already exists: **the SSE event vocabulary in the
spec**. An adapter's whole job is vendor stream → our `TurnEvent` union. The
orchestrator, the SSE layer, and the entire Flutter client stay unchanged.

```ts
interface LlmProvider {
  readonly name: 'anthropic' | 'gemini';
  readonly models: { orchestrator: string; quarantine: string };
  runTurn(input: TurnInput, signal: AbortSignal): AsyncIterable<TurnEvent>;
  normaliseUsage(raw: unknown): Usage;   // hides the field-name difference
}
```

Tools are declared **once** in our own shape (`AssistantTool` with a Zod schema);
each adapter converts to the vendor envelope. Zod → JSON Schema is solved, and
both vendors accept JSON-Schema-shaped declarations.

### The caching discipline is portable even though the API is not

A useful accident: Gemini's *implicit* caching hashes recent inputs and applies
the cached rate automatically when prefixes overlap. So the discipline this plan
already mandates — **frozen system prompt, deterministic tool order, volatile
content last** — earns the discount on *both* providers. Only the mechanism and
the assertion differ:

| | Anthropic | Gemini |
|---|---|---|
| Mechanism | Explicit `cache_control` breakpoint after tools+system | Implicit by default; explicit `CachedContent` + TTL available |
| Discount | ~0.1× on cached reads | ~90% on repeated input |
| CI assertion reads | `cache_read_input_tokens` | `cachedContentTokenCount` |

Hence `normaliseUsage` — the cost-regression test asserts against one normalised
number and runs identically on either provider.

### Provider is pinned per conversation, not per turn

**You cannot cleanly switch providers mid-conversation.** History carries
vendor-specific artifacts (thinking blocks, tool-call block shapes) that do not
transfer, and switching would invalidate the cached prefix anyway. So:

- The provider is chosen at conversation start and recorded on the conversation
  row.
- "Fallback" here means **a development substitute and a deployment switch** —
  not per-turn runtime failover.
- If runtime failover is ever wanted, it is *per conversation* (start a new one
  on the healthy provider), never mid-thread.

### Does this re-open LangGraph?

Fair question, since multi-provider portability is part of its pitch. **No —
but the tripwire gains a condition.**

Our loop behind this interface is roughly a hundred lines; the framework's
portability win is "you don't rewrite the loop," which is a small prize here.
Its costs are unchanged: per-layer overhead, the steepest learning curve of the
major frameworks, and worse debugging than a plain loop. Two providers behind a
two-method interface is not a framework-shaped problem.

**Re-open the decision if** we need a *third* provider, dynamic per-request
routing, or durable multi-day resume.

### Evals become a matrix

Tool-calling fidelity differs by vendor, so **the ≥90% tool-selection gate is
per provider**, not global. A regression on one provider must not be masked by
the other passing. The nightly sweep runs both; the cheap PR slice runs whichever
provider that branch targets.

This is the real ongoing cost of the decision, and it is worth stating plainly:
**every eval, every red-team case, and every cost assertion now runs twice.**

---

## Platform choices — pros, cons, and the mitigation

| Layer | Choice | Pro | Con | Mitigation |
|---|---|---|---|---|
| **Orchestration** | Vendor SDK behind a two-method `LlmProvider` interface — Gemini adapter first, Anthropic second | No framework abstraction; per-turn approval hooks; caching discipline pays off on both vendors | Loop can sprawl; every eval and cost assertion now runs twice | Loop stays logic-free; contract test across both adapters; 3-condition tripwire above |
| **Observability / evals** | **Langfuse Cloud** (hobby → $29/mo) | MIT-licensed, so self-hosting is always an escape hatch; tracing + prompt versioning + datasets + LLM-as-judge in one tool | Self-hosted stack is 6 services (web, worker, ClickHouse, MinIO, Redis, Postgres) — real operational weight for a small team | **Start on cloud, not self-hosted.** Revisit self-host only if a client demands data residency |
| _(alternative)_ | Braintrust | Best eval-first UX; evals native to trace view | $249/mo Pro; no self-host | Reconsider if eval workflow becomes the bottleneck |
| **STT (voice in)** | `speech_to_text` (on-device) | Free, no API key, no audio upload, WASM web support | Vendor docs say it targets "commands and short phrases, not continuous conversion" | That *is* our use case — a prompt is a short phrase. Server-side fallback for unsupported browsers |
| **TTS (voice out)** | Backend-proxied; Deepgram Aura-2 or Cartesia Sonic behind an interface | Key never ships in the app; vendor swappable; Cartesia's SSM architecture holds P99 tail latency | Vendor-claimed latency (40–90ms) is well below independently measured P50 (≈188ms Cartesia, ≈264ms ElevenLabs) | Budget against the *independent* numbers, not the marketing ones |
| _(rejected)_ | `deepgram_speech_to_text` Dart package direct from the app | One package covers STT + TTS on every platform | **Community-maintained by an individual, not Deepgram**, and requires the API key client-side — a shipped secret | Proxy through the backend instead |
| **Charts** | Reuse `app/lib/core/widgets/charts.dart` | Already exists: `LineChart`, `ColumnChart`, `BarChart`, `Sparkline`, tooltip — hand-rolled `CustomPainter`, no third-party dep, design rules pinned by `charts_test.dart` | Fixed chart vocabulary | A closed view-spec catalog is a feature: the model cannot invent a chart type that breaks the design system's one-series-one-hue rule |
| **Memory** | Postgres preferences table | Zero new infra; temporal truth already relational | Not "smart" personalisation | Revisit mem0 only if personalisation becomes a product surface |

---

## How the hard parts actually get built

Four things in this plan are genuinely difficult. Each has an established
industry method — none of them is "prompt the model to be careful."

### 1. Prompt injection — quarantine, don't persuade

Agent-authored free text (visit notes, outlet names, messages) reaches the
model's context through tool results. Prompt injection is **#1 on the OWASP LLM
Top 10 for the second consecutive edition**, and the consensus is blunt: *no
single defense closes the gap.* Instruction-based defenses ("ignore instructions
in the data") are the weakest layer and must never be the only one.

Three layers, in order of strength:

**(a) Structural separation — the dual-LLM pattern.** This is the mechanism that
actually holds: *the model that reads untrusted content cannot invoke tools.* In
TradeIQ most tool results are already structured — scorecards, counts, dates —
and carry no injection surface at all. Only free-text fields do. So:

```
structured fields  ──────────────────────────────► orchestrator (tool-capable)
free-text fields ──► quarantined Haiku 4.5 ──► structured summary ──► orchestrator
                     (no tools bound, cannot act)
```

The quarantined call gets no tool definitions, so an injected instruction has
nothing to reach. Cheap, too — Haiku is $1/$5 per MTok.

**(b) Spotlighting.** Where free text passes through verbatim, wrap it in
delimiters that mark it as data, not instruction (Microsoft's technique, Hines
et al. 2024). This is the *marker* half of the pattern — useful, and explicitly
not sufficient alone.

**(c) Capability-based flow control** — the CaMeL direction (*"Defeating Prompt
Injections by Design"*, arXiv:2503.18813), which effectively solves the AgentDojo
security benchmark by leaning on capabilities and data-flow analysis rather than
on more model cleverness. Full CaMeL is out of scope for Phase 0, but its core
idea is already ours: **data read from a tool can never expand what the caller is
allowed to do**, because the roster is fixed from the JWT before the turn starts.

### 2. Multi-tenant isolation — make it structurally impossible

OWASP's mitigation for *excessive agency* (LLM06) is least privilege, ephemeral
scoping, and human-in-the-loop — not model instruction. Relying on an LLM for
access control is a documented anti-pattern.

The implementation rule: **a tool function signature physically cannot accept a
tenant or user identifier.** Tools are constructed per request as closures over
`req.user`. There is no argument the model could supply to widen scope, so this
isn't enforced by validation that could be forgotten — it's enforced by the type
signature. The roster matrix test is the regression guard.

### 3. Evals that don't flake — score, don't compare

The failure everyone hits: equality assertions against non-deterministic output.
The industry fix is to replace them with a scored evaluator and a **threshold**.

Two rules worth stating explicitly, because they're the ones teams skip:

- **Measure the grader's self-agreement.** *"A 95% pass rate at 0.6 judge
  agreement is noise."* If the grader can't agree with itself across samples,
  `UNSTABLE` must be a **failing** CI state — otherwise the gate is theatre.
- **Aggregate across runs.** A single sample per question can't distinguish a
  real regression from sampling variance. Report a confidence interval.

We get a large head start: the highest-signal metric here is **tool-selection
accuracy**, which is a *deterministic* comparison (did it call
`getAgentScorecard`?). No LLM judge needed for the majority of the suite —
reserve judging for answer quality only.

### 4. Confirmation fatigue — measure it, don't guess

Named as *the* primary obstacle to effective human oversight at scale: prompt
people constantly and they stop reading and click Approve. The mitigation is to
trigger approvals on **risk signals, not broad action categories** — which is
exactly what the three-tier model does, with reads never prompting.

Make it measurable: instrument the prompt rate and treat **>1 approval per 10
turns in a routine session as a calibration bug**, not as user error.

---

## Artifact architecture — two writers, one source of truth

A stats answer is not a static picture. The user asks for Jan–Dec 2026, then
wants Q3, then wants it weekly. They must be able to do that **either** by
touching the artifact's own controls **or** by saying so in chat — and the two
must never drift apart.

The failure this design exists to prevent: user drags the range to Q3 via the
UI, then types *"now break that down by territory."* If the UI change never
reached the model, it answers about Jan–Dec — confidently, and wrongly.

### The contract

```
Artifact = { id, type, toolName, params, paramsHistory[] }
```

`params` is the **single source of truth**, and each artifact type owns one Zod
schema for it. The model writes through that schema. The UI writes through that
same schema. Neither can express something the other cannot.

### Path A — the user moves a control

```
control change → POST /assistant/artifacts/:id/refine { params }
              → validate against the type's Zod schema
              → re-invoke the SAME tool closure (same RBAC, same clientId)
              → fresh data → re-render
              → append "[artifact:abc params → period=2026-Q3]" to history
```

**No model call.** Dragging a date slider must not cost three seconds and a
paid request. It re-runs the same tool the model would have called, so the
security path is identical — a hand-edited `refine` payload cannot widen scope,
because scope was never a parameter.

The trailing history note is what keeps the model honest. It is compact — a few
tokens, not a re-render of the whole dataset — and it sits *after* the cached
prefix, so it costs nothing in cache terms.

### Path B — the user asks in chat

The context carries a **live-artifact manifest**: `[{id, type, params}]`. So
*"make that last quarter"* resolves to an update targeting `artifact:abc`,
not a brand-new card appended below. The model emits the same artifact id with
new params; the client patches in place.

Without the manifest, every follow-up spawns a duplicate chart and the
conversation becomes a graveyard of near-identical cards.

### Memory, and going back

`paramsHistory` (capped at 20) gives a real undo stack per chart, and the
artifact row persists, so reopening restores the last state rather than
resetting to whatever the model first guessed.

Navigation "back" is deliberately **not** custom state machinery: artifacts get
a real route, `/artifact/:id`. The browser back button, deep links, and sharing
then all work for free — and go_router is already the app's router.

### Not crowding the conversation

Anti-crowding is a *layout* rule, enforced by having three modes rather than one:

| Mode | Contains | Where |
|---|---|---|
| **Inline** | Headline figure, `Sparkline`, one-line caption, Expand | In the chat stream |
| **Expanded** | Full chart, filter controls, table twin, export | Side panel (web/tablet) · full-screen sheet (phone) |
| **Print** | Paginated, controls stripped | PDF only |

The inline card is intentionally impoverished. Filter controls live in Expanded
only — putting a date picker in every chat bubble is exactly the crowding to
avoid. `charts.dart` already mandates a "table-view twin" so no value is gated
behind a hover; Expanded is where that twin lives, and it doubles as the
vector-text half of the PDF.

---

## Testing strategy

The API key is available from day one, so **every phase ships with tests** —
nothing is deferred to a hardening pass. Five layers:

**1. Unit (no network, no DB).** `roster.ts`, `viewspec.ts`, `params.ts`,
`risk.ts`, `sanitize.ts`, `prompt.ts` are all pure. Jest, fast, every commit.
The load-bearing one: a table-driven test asserting that for every
`(role × tool)` pair, the roster grants exactly the intended set — with an
explicit negative case that `field_agent` cannot reach a manager-only tool.

**2. Integration (real Postgres, mocked model).** The orchestrator loop with a
stubbed Anthropic client: given a scripted `tool_use` response, does the right
service get called, with the caller's `clientId`, and does the result serialise
into a valid view spec? Follows the existing `--runInBand` convention.

**3. Live-model evals (real API, recorded).** A golden set of questions with an
expected tool call and expected view-spec type. Scored on **tool-selection
accuracy** — the metric that predicts agent failure better than answer text.
Runs nightly and pre-merge on assistant changes, traced to Langfuse.
Start at 25 questions; grow to 100+.
**Rule: every production regression becomes a permanent eval case.**

**4. Red-team (adversarial).** Injection payloads planted in the fields agents
actually control — outlet names, visit notes, message bodies — asserting the
model neither leaks cross-tenant data nor executes an injected instruction. Plus
a cross-tenant probe: user from client A asking directly for client B's data.

**5. Cost & latency regression.** Assert `cache_read_input_tokens > 0` on turn 2
of a conversation — a silent prefix invalidation is a cost blowout that no
functional test catches. Track p50/p95 time-to-first-token per phase.

**Non-determinism.** Model output varies run to run, so evals assert on
*tool choice and spec type*, never on exact prose. Score thresholds, not
equality: a suite passes at ≥ 90% tool-selection accuracy, and any drop below
the previous run's score fails the build.

**CI reality check.** `backend-ci.yml` **already exists** and works — postgres
service, `prisma migrate deploy`, `npm audit --audit-level=high`, lint, build,
jest. It was hardened on 2026-08-02 with a `typecheck` step (so `scripts/` is
covered, not just `src/`) and `--runInBand` (the suite's documented-safe mode;
`maxWorkers: 4` still exhausts the Prisma pool on a shared runner, #181).

What Phase 0 adds is **not** a pipeline — it's a second workflow,
`assistant-evals.yml`, gated behind `secrets.ANTHROPIC_API_KEY` so forked PRs
cannot burn the key:

| Trigger | Runs | Gate |
|---|---|---|
| PR touching `backend/src/modules/assistant/**` | Unit + integration (already in `backend-ci`) + the cheap deterministic eval slice | Blocking |
| Nightly | Full live-model eval sweep against the versioned dataset | Reported, not blocking |

The split follows the industry pattern: *cheap deterministic checks on every PR;
the full LLM-judge sweep nightly against a versioned dataset.* Putting a slow,
paid, non-deterministic sweep in the PR path is how teams end up disabling it.

---

## Background the engineer needs

**Auth context already exists.** `requireAuth`
(`backend/src/middleware/auth.ts`) attaches `req.user` = `{userId, role,
clientId}`. Every tool closes over that object. A tool signature never accepts a
tenant or user id as a model-supplied argument — if the model can pass
`clientId`, a crafted outlet name becomes a cross-tenant read.

**Indirect prompt injection is a live risk here, not a theoretical one.** Field
agents type free text into visit notes, outlet names, and messages. That text
flows into tool results and therefore into the model's context. Tool results must
be wrapped as untrusted data and scanned for instruction-like patterns before
they reach the model.

**Nav is single-source.** `app/lib/core/widgets/nav_destinations.dart` feeds the
rail, the bottom-sheet menu, and the router guard. Shrinking the sidebar is one
edit there; the router keeps its full route table so deep links survive.

**Prompt caching is the cost lever.** Caching is a prefix match — render order is
`tools` → `system` → `messages`. Keep the system prompt byte-frozen (no
interpolated timestamps or user names), sort tools deterministically, and place
the cache breakpoint after the tool+system block. Inject per-user context as a
later message. Verify with `usage.cache_read_input_tokens`; if it is zero across
turns, something is silently invalidating the prefix.

**Commands** (all from `backend/`):
- Single suite: `npx jest src/modules/assistant --runInBand`
- Typecheck: `npx tsc --noEmit`
- Lint: `npm run lint`

App changes verify only via GitHub Actions `app-ci` (analyze infos are fatal);
Flutter is not installed locally.

---

## File structure

| File | Responsibility |
|---|---|
| File | Responsibility | Phase | Pure? |
|---|---|---|---|
| `backend/src/modules/assistant/assistant.routes.ts` | `POST /assistant/chat` (SSE), `/confirm`, `/artifacts/*` | 0 | ✗ |
| `backend/src/modules/assistant/providers/types.ts` | `LlmProvider`, `TurnInput`, `TurnEvent`, `Usage` | 0 | ✓ |
| `backend/src/modules/assistant/providers/gemini.ts` | Gemini adapter — **built first** | 0 | ✗ |
| `backend/src/modules/assistant/providers/anthropic.ts` | Anthropic adapter — added when the key lands | 0 | ✗ |
| `backend/src/modules/assistant/orchestrator.ts` | Loop, streaming, cache breakpoints — **provider-agnostic, loop only, no business logic** | 0 | ✗ |
| `backend/src/modules/assistant/roster.ts` | Role → tool list. **The security boundary** | 0 | ✓ |
| `backend/src/modules/assistant/prompt.ts` | Frozen system prompt. No interpolation, ever | 0 | ✓ |
| `backend/src/modules/assistant/tools/{sales,stock,visibility,competition,execution}.ts` | One file per pillar. Wrappers over `*.service.ts` | 0 | ✗ |
| `backend/src/modules/assistant/viewspec.ts` | View-spec catalog + Zod validation | 0 | ✓ |
| `backend/src/modules/assistant/sanitize.ts` | Spotlight-wrap tool results; scan for instruction patterns | 0 | ✓ |
| `backend/src/modules/assistant/quarantine.ts` | Tool-less Haiku pass over free text (dual-LLM pattern) | 0 | ✗ |
| `backend/src/modules/assistant/tts.ts` | TTS vendor behind an interface; key stays server-side | 1 | ✗ |
| `backend/src/modules/assistant/artifact.ts` | Artifact CRUD, `refine`, `undo`, params history | 2 | ✗ |
| `backend/src/modules/assistant/params.ts` | Per-artifact-type params schemas (incl. `period`, `compareTo`) | 2 | ✓ |
| `backend/src/modules/assistant/risk.ts` | Action tier classification + gate policy | 3 | ✓ |
| `backend/src/modules/assistant/audit.ts` | Writes `AssistantAction` rows | 3 | ✗ |
| `app/lib/features/assistant/` | Chat screen, composer, voice capture, TTS playback | 0–1 | — |
| `app/lib/features/assistant/view_specs/` | Spec → widget registry | 0 | — |
| `app/lib/features/assistant/artifacts/` | Inline / Expanded / Print modes, filter controls, PDF | 2 | — |
| `backend/evals/` | Golden-question dataset + scorer | 0 | ✗ |

**Design rule:** every file marked ✓ is pure — no Prisma, no network — and is
unit-testable with plain Jest. That is not an accident: the security boundary
(`roster.ts`), the output contract (`viewspec.ts`, `params.ts`), and the action
gate (`risk.ts`) are all pure precisely so they can be exhaustively tested
without infrastructure.

---

## Action risk tiers

Confirmation fatigue is the named failure mode of approval UX — when users are
prompted constantly they stop reading and click through. Gate on risk, not on
category.

| Tier | Examples | Gate |
|---|---|---|
| **Read** | scorecards, trends, outlet lookup, fraud review | None. Never prompt. |
| **Reversible** | create task, draft message, add note | Act, log with undo context, show an Undo affordance |
| **External / irreversible** | deactivate user, fire webhook, send announcement, approve incentive payout | Explicit confirm card: proposed action, params, reasoning, impact, rollback, expiry |

Every tier-2 and tier-3 call writes an `AssistantAction` row: user, role, tool,
arguments, the model's stated reasoning, and who authorized it. A changed record
without the "why" is not an audit trail.

---

## Phase 0 — Read-only spine

**Testing gate for this phase:** unit suite green · integration suite green ·
≥ 90% tool-selection accuracy on the 25-question eval set **per provider** ·
cache-hit assertion passing on the active provider · provider contract tests
green on both adapters · `assistant-evals.yml` running its cheap slice on every
assistant PR.

> **Gemini first.** The key is available now, so Phase 0 is built and proven
> against Gemini. When the Anthropic key arrives, adding `anthropic.ts` should
> be an adapter and a config flag — if it turns out to be more than that, the
> interface leaked and that is the bug to fix.

> **Status, 2026-08-07.** Everything below that does not need credentials is
> built, tested and green on CI, across PRs
> [#264](https://github.com/Wandashabba/TradeIQ/pull/264) and
> [#265](https://github.com/Wandashabba/TradeIQ/pull/265).
> **The phase is not complete**: its headline gate
> — ≥90% tool-selection accuracy — has never been measured, because no provider
> key exists in this environment. Every test in the branch runs against a
> scripted provider. `STATUS.md` is the live tracker; this list is ticked to
> match it, and the two unticked-on-purpose items say why.
>
> The note above says "the key is available now". It is not available *here* —
> see the 2026-08-03 correction in `STATUS.md`. That single sentence is the
> difference between this phase being finishable and not.
>
> `[~]` means **partly done, and the remainder is named** — borrowed from
> `STATUS.md`. A ticked box that overstates is how a plan stops being worth
> reading, and the two here are both cases where the gap is real and external.

- [x] `providers/` — `LlmProvider` interface + `gemini.ts` adapter first
      (`@google/genai`). `LLM_PROVIDER`, `GEMINI_API_KEY`, `ANTHROPIC_API_KEY`
      in `.env.example`. `anthropic.ts` still waits on its key, and
      `providerFor('anthropic')` throws a message saying so rather than being
      absent from the union
- [x] Contract test suite — same scripted turn, same normalised `TurnEvent`
      stream out. Runs with **no key and no network**: each adapter renders one
      abstract script into its own wire shape and everything after is asserted
      identically. A contract test needing a live provider runs on one machine,
      which is how a contract stops being enforced
- [x] ~~Add `backend-ci`~~ — **it already existed.** Hardened 2026-08-02 with a
      `typecheck` step and `--runInBand`
- [x] `.github/workflows/assistant-evals.yml` — cheap slice on PR, full sweep
      nightly. Matrix is **per provider, `fail-fast: false`**, because the gate
      is per adapter and a mean is exactly what hides a one-provider
      regression. Skips itself with a loud warning when no key is set: a 0%
      score and an absent secret are otherwise indistinguishable
- [~] Langfuse tracing wired into `orchestrator.ts` from the first request, not
      retrofitted — **the seam and the client exist; the Cloud project does
      not.** Fire-and-forget behind a bounded, serialised queue; no-op when
      unconfigured. **Metadata only** — content is behind
      `LANGFUSE_TRACE_CONTENT`, default off, because transcript retention is
      still an open question (#251 Q3). Tool *results* are never sent at any
      setting
- [x] `quarantine.ts` — free text summarised by a **tool-less** call before it
      reaches the orchestrator. **Fails closed**: on error, timeout, or a
      quarantine turn that somehow emits a tool call, the text is omitted
      rather than passed through raw
- [x] `prompt.ts`: frozen system prompt, exported as a `const` rather than a
      builder so there is no parameter to accidentally thread through
- [x] `roster.ts`: role → tool list, with the matrix test (landed in #264)
- [x] 8 read tools grouped by the four pillars, plus the agent scorecard — 9 in
      total, over `pillars.service.ts` and `scorecards.service.ts`
- [x] `sanitize.ts`: spotlight-wrap tool results as untrusted. The fence is
      stripped from the payload *before* wrapping — a wrapper the payload can
      close is the classic failure. Also strips Unicode tag characters and bidi
      overrides, which carry instructions no human reviewing the record can see
- [x] `viewspec.ts`: catalog + Zod validation for all 3 specs
- [x] `orchestrator.ts`: loop, cache breakpoint after tools+system. Bounded at
      four rounds; the last round **withdraws tools** rather than cutting the
      turn off, so the model still answers from what it retrieved
- [x] `POST /assistant/chat` as SSE; reuses `requireAuth`
- [x] **Rate-limit the chat endpoint** — per-user *and* per-tenant (landed in
      #264, mounted on the route in #265)
- [ ] **Spend ceiling + budget alarm.** Hard monthly cap in the provider
      console, plus a Langfuse alert at 50% / 80%. **Not doable from this
      repo** — it is a console setting, and it is the only real ceiling on a
      leaked key
- [~] Abort handling — the orchestrator and the route both abort, and the signal
      reaches the SDK. ⚠️ **Gemini's `abortSignal` is client-side only**, per the
      SDK's own note: it stops us reading, not Google generating or billing. So
      "must not orphan a paid request" is only *partly* satisfiable in code, and
      the remainder is the console cap above
- [x] Flutter: chat screen, text composer, streaming text render
- [x] Flutter: scorecard as a parameterised widget (`AgentScorecardCard`)
- [ ] Flutter: view-spec registry renders **all three** widgets inline — the
      registry exists and renders `agent_scorecard`; `trend_chart` and
      `outlet_map` are validated but no tool emits them and no widget draws
      them. **Deliberately unticked**
- [x] Unit: roster matrix test — every `(role × tool)` pair (landed in #264)
- [x] Unit: view-spec validation rejects unknown spec types and malformed params
- [x] Integration: stubbed model → scripted tool call → asserts the correct
      service ran with the caller's `clientId`, **including the cross-tenant
      probe** — the model names a real user id from another tenant and the
      closure returns nothing
- [x] Eval harness: 26 golden questions with expected tool, scored on
      tool-selection accuracy. Includes **two refusal cases**, because a suite
      with no refusals rewards a model that always guesses. ⚠️ **Written and
      unrun** — see the status note above
- [x] Cost regression: asserts `cacheReadTokens > 0` on turn 2, with a companion
      test that interpolates the system prompt and watches the prefix diverge —
      so the assertion is *shown* to have teeth rather than merely passing

**Exit:** "How has Tumo been performing this month?" returns narrative plus the
real scorecard widget, at manager scope, with a cache hit on turn 2.

> **The exit demo passes as a test, against a scripted model** — see
> `assistant.routes.test.ts` and `chat_screen_test.dart`, which assert exactly
> that sentence end to end. It has **not** been run against Gemini. Treat the
> demo as unproven until it has.

### What building it changed about the plan

Recorded here because a plan that is only ever read forward hides what the work
taught. Full reasoning in `STATUS.md` → Decisions → *Implementation*.

- **`Message` had to become a union.** A `tool_runner` loop cannot be expressed
  without a way to send results back, and `TurnEvent.tool_call.id` existed to
  "correlate the later result" with no message shape carrying one.
- **`Period` cannot be a discriminated union on the wire.** Zod emits one as
  JSON Schema `oneOf`, and Gemini's `Schema` has no `oneOf`. Every tool takes a
  period, so the obvious spelling was a 400 on every turn.
- **Tools declare their view spec; the model never names one.** The plan said
  "the model never emits UI"; this is the mechanism that makes the closed
  catalog a constraint rather than a suggestion.
- **The artifact carries raw data, the model gets the sanitized copy.** Fencing
  would put `«untrusted» …` inside a chart label.
- **Pillar aggregates live in a new `pillars.service.ts`**, not spread across
  six existing service files that other branches are editing.

## Phase 1 — Voice, both directions

**Testing gate:** transcript→prompt fidelity set (50 recorded utterances in SA
English, including outlet and agent names, asserting the transcript reaches the
model intact); TTS p95 time-to-first-audio budgeted against *independently
measured* latency, not vendor claims; eval set grown to 50 questions.

- [ ] Device STT via `speech_to_text`; server-side transcription fallback for web
- [ ] Voice composer UI: hold-to-record, live waveform, editable transcript
      before send
- [ ] TTS service behind an interface (Cartesia first — SSM architecture holds
      P99 tail latency; ElevenLabs swappable if expressiveness matters more)
- [ ] Speak the *narrative only*; never read out a chart. Charts render silently.
- [ ] Per-user voice-out toggle, persisted, default **off** (open-plan offices)
- [ ] Expand to 12 view specs (leaderboard, worklist, alert card, campaign ROI,
      beat plan, order summary)

## Phase 2 — Artifacts: interactive, filterable, exportable

An artifact is a **live, stateful view** the user can steer two ways — by
manipulating its own controls, or by continuing the conversation. Both paths
must work at all times and must never desync. Design detail is in the
*Artifact architecture* section above.

**Testing gate:** a round-trip test proving UI-driven and prompt-driven changes
converge on identical state; a params-tampering test proving a hand-edited
`refine` payload cannot widen scope; PDF golden-file test; responsive layout
tests at phone / tablet / desktop breakpoints.

### Comparison — the feature that kills the Excel overlay
- [ ] Every artifact params schema carries an optional `compareTo`:
      `previous_period` · `same_period_last_year` · `{territory|agent|sku}: id`
- [ ] Charts render the comparison as a second series; the table twin gains a
      delta column (absolute and %)
- [ ] "Compare X to Y" resolves in one turn — this is the workflow the
      practitioner explicitly asked us to kill, so it must not require the user
      to open two artifacts and read across them

### Backend
- [ ] `Artifact` Prisma model — `id`, `conversationId`, `type`, `toolName`,
      `params`, `paramsHistory[]` (capped at 20), `createdAt`, `updatedAt`
- [ ] `period` param enum straight from practitioner usage: `today` ·
      `yesterday` · `previous_week` · `mtd` · `ytd` · `custom(from, to)`
- [ ] Per-artifact-type Zod **params schema** — the single contract both the
      model and the UI write through
- [ ] `POST /assistant/artifacts/:id/refine` — validate params, re-invoke the
      **same tool closure** (same RBAC), return fresh data. **No model call.**
- [ ] Append a compact `[artifact:<id> params → …]` note to conversation history
      on every UI-driven change, so the model never reasons from stale params
- [ ] Inject a live-artifact manifest (`{id, type, params}`) into context so the
      model can target an existing artifact instead of emitting a duplicate
- [ ] `GET /assistant/artifacts/:id` — rehydrate on reopen
- [ ] `POST /assistant/artifacts/:id/undo` — pop `paramsHistory`

### Flutter — three render modes
- [ ] **Inline** (in the chat stream): headline figure + existing `Sparkline` +
      one-line caption + Expand. Deliberately minimal — this is the
      anti-crowding rule
- [ ] **Expanded**: full `LineChart`/`ColumnChart`/`BarChart`, filter controls,
      and the **table twin** `charts.dart` already mandates. Side panel on
      web/tablet (chat stays visible), full-screen sheet on phone
- [ ] **Print**: paginated, controls stripped
- [ ] Route `/artifact/:id` so the browser back button and deep links work —
      this is what makes "go back" free rather than bespoke state juggling
- [ ] Filter controls: date-range picker, period granularity, territory/agent
      scope. Labelled for screen readers (the a11y work in #144 set the bar)
- [ ] Optimistic UI on filter change with a rollback on server rejection

### PDF export
- [ ] `pdf` + `printing` packages; generate **in an Isolate** so the UI thread
      never blocks
- [ ] Embed the already-bundled **Inter** TTFs (`app/assets/fonts/`) so the
      report matches the product and renders identically across platforms
- [ ] **Hybrid fidelity:** text, headers, and the data table as *vector* (crisp,
      selectable, searchable); the chart itself rasterised via `RepaintBoundary`
      at ≥2× device pixel ratio. Vector-only would mean reimplementing every
      `CustomPainter`; raster-only would give a blurry, unsearchable report
- [ ] Report header: title, applied filters in words, generated-at, tenant.
      A chart with no visible date range is a support ticket waiting to happen
- [ ] Golden-file test on generated PDF bytes

> **Not this phase:** server-side PDF for *scheduled* reports. `/reports`
> (CSV + JSON) and `/report-schedules` already exist server-side and cannot
> reuse Flutter's `CustomPainter` charts. That is a separate problem — do not
> conflate on-demand export of what the user is looking at with unattended
> generation of something nobody is looking at.

## Phase 3 — Actions

**Testing gate — the strictest in the plan.** No write tool ships without:
a unit test proving its risk tier, an integration test proving the gate fires,
an audit-row assertion, and a red-team case. Plus a standing rule: **zero
tolerance on the cross-tenant probe** — one leak fails the phase outright.

- [ ] `AssistantAction` Prisma model + migration
- [ ] `risk.ts` tier classifier + policy table
- [ ] Tier-2 tools: create task, draft message, add outlet note
- [ ] Undo affordance for tier-2, driven by logged undo context
- [ ] Tier-3 confirm card spec + `POST /assistant/confirm` round trip
- [ ] Tier-3 tools: deactivate user, send announcement, toggle incentive scheme
- [ ] Audit view under Settings — filter by user, tool, tier, date
- [ ] Red-team eval set: injection payloads planted in outlet names, visit notes,
      and message bodies — the fields agents actually control
- [ ] Cross-tenant probe: client A user asking directly for client B data
- [ ] Confirmation-fatigue check: measure what fraction of turns prompt. If a
      routine session prompts more than ~1 in 10, the tiering is miscalibrated

## Phase 4 — Shrink the console

**Testing gate:** every retired destination still reachable by deep link
(route-table test); `app-ci` green; a navigation test proving the router guard
still blocks `field_agent` from manager routes after the roster shrinks.

**Do this phase last among the UI phases, not first.** Removing the sidebar
before chat can answer the questions those tabs served would strand users with
no path to their data. Shrink only once Phases 0–2 have replaced the capability.

- [ ] `nav_destinations.dart` down to 5: Chat, Alerts, Today, Outlets, Settings
      (the business conversation said *"29 down to five, six"* — same intent;
      the code's `managerDestinations` currently holds 21)
- [ ] Settings absorbs all 7 CONFIGURE destinations
- [ ] Router keeps every route for deep links; chat emits deep links
- [ ] Retire `/dashboard` as the landing route; chat becomes home
- [ ] Update `docs/architecture/overview.md`

## Phase 5 — Memory and proactivity

**Testing gate:** a preference-injection test proving user preferences land in a
*late* message and never mutate the cached system prefix (assert
`cache_read_input_tokens > 0` still holds with preferences applied).

- [ ] Postgres-backed user preferences (default period, favourite territories,
      verbosity, voice on/off) injected as a late message, never the system prompt
- [ ] Conversation persistence + server-side compaction for long threads
- [ ] **Pinned artifacts / morning digest** — the practitioner checks *"four or
      five dashboards every day"*. A standing set beats re-asking every morning
- [ ] Re-evaluate a dedicated memory layer **only if** personalisation becomes a
      product surface. mem0 fits "what did the user tell me"; Zep fits "what was
      true, and when" — but TradeIQ already has temporal truth in Postgres, so do
      not build a knowledge graph over data you can already query
- [ ] Scheduled digests via Managed Agents cron deployments — the one place a
      second, asynchronous brain genuinely earns its keep

---

## Sequencing and dependencies

Phases are ordered by *risk-adjusted value*, not by what is most fun to build.

```
Phase 0 (spine) ──┬──► Phase 1 (voice)      ──┐
                  │                            ├──► Phase 4 (shrink console)
                  └──► Phase 2 (artifacts)  ──┤
                                               └──► Phase 5 (memory, digests)
                       Phase 3 (actions) ───────────┘
```

- **Phase 0 blocks everything.** Nothing else is meaningful without the loop,
  the roster, and one rendered view spec.
- **Phases 1 and 2 are independent** and can run in parallel by different people:
  voice touches the composer and a TTS service; artifacts touch state and charts.
- **Phase 3 (actions) depends only on Phase 0**, but is deliberately scheduled
  after artifacts because it carries the most risk and the least novelty — get
  the read experience right before granting write access.
- **Phase 4 must come after 0–2.** Removing tabs before chat replaces them
  strands users.
- **Phase 5 depends on 0 and benefits from 2** (pinned artifacts need artifacts).

**Hard prerequisite for all of it:** a provider key and a Langfuse project.

> **Correction (2026-08-07). Neither has arrived, and this is now the binding
> constraint.** "Both are being provided" was written in expectation and read
> ever since as a settled fact. `backend/.env` carries only `DATABASE_URL`,
> `JWT_SECRET` and `PORT`; there is no `GEMINI_API_KEY`, no `ANTHROPIC_API_KEY`
> and no Langfuse project.
>
> Phase 0 turned out to split either side of that line far more favourably than
> anyone assumed — the adapter, the contract suite, all nine tools, the
> orchestrator, the route, the app, and the whole test suite needed no key, and
> are built and green. What needs one is *proving it works*: the ≥90%
> tool-selection gate, the live cost figure, and any trace at all.
>
> So the sequencing claim above holds with one amendment: **Phase 0 blocks
> everything, and a provider key blocks Phase 0's exit — not its
> construction.** Phases 1 and 2 could technically begin against an unproven
> spine; whether that is wise is a call for whoever holds the key.

---

## Cost model

This is a paid dependency, so the plan should not pretend otherwise. Orders of
magnitude, not a forecast — replace with measured numbers after Phase 0.

| Driver | Control |
|---|---|
| Orchestrator turns — Gemini 3.1 Pro ($2/$12) or Opus 5 ($5/$25) per MTok | Prompt caching on the tools+system prefix. ~0.1× on Anthropic cached reads, ~90% discount on Gemini — the single biggest lever on either |
| Quarantine passes — Gemini 3.6 Flash ($1.50/$7.50) or Haiku 4.5 ($1/$5) | Only free-text fields, only when present |
| **Running both providers in evals** | The nightly sweep costs roughly double. Bounded and predictable, but real — budget for it rather than discovering it |
| Filter changes | **Zero.** `refine` re-runs the tool with no model call — this is why that design matters commercially, not just for latency |
| Nightly eval sweep | Fixed, bounded by dataset size. Runs on schedule, not per PR |
| TTS | Per character, and only when voice-out is on — which defaults to **off** |

**Instrument before optimising.** Langfuse traces carry per-turn cost from the
first request, so Phase 0 exits with a real cost-per-conversation number rather
than a guess. The cache-hit assertion is a *cost* regression test as much as a
correctness one: a silently invalidated prefix multiplies spend without failing
any functional test.

> **Correction (2026-08-07).** The instrumentation exists; the number does not.
> Tracing emits `costCents` per turn from the first request as intended — but
> there is no Langfuse project receiving it, and the per-token rates in
> `providers/gemini.ts` are **placeholders**. So Phase 0 as it stands exits with
> a *computed* cost, not a *measured* one, and the distinction matters because
> the whole point of the paragraph above is not to guess.
>
> The rates in the table above are also unverified — the section says so, "orders
> of magnitude, not a forecast". `RATES` in `providers/gemini.ts` is now seeded
> from these same figures deliberately, so there is **one** set of numbers to
> correct against Google's pricing page rather than two that can disagree.
> `costCents` returns a visible wrong number rather than `0`, because a zero
> would make a cost regression look like a saving.

---

## Rollout

- **Feature-flagged from Phase 0.** The assistant ships behind a per-client flag
  (`clients.service.ts` already carries client config) so it can be enabled for
  one pilot tenant without touching everyone.
- **Additive until Phase 4.** Chat is a *new* destination alongside the existing
  21. Nothing is removed until the replacement is proven — which is also what
  makes Phase 4 safe to defer indefinitely if the pilot says otherwise.
- **Pilot with managers, not agents.** The manager console is the target; the
  field app is offline-first and chat needs connectivity (open question #1).
- **Kill switch.** Flag off must degrade to today's dashboard with no data loss,
  since nothing in Phases 0–2 mutates business data.

---

## Glossary

Terms used throughout this plan with specific meanings.

| Term | Meaning here |
|---|---|
| **Four pillars** | Sales, stock, visibility, competition — the practitioner's own framing of the "input KPIs" field agents collect. Tools are grouped by these |
| **Semantic layer** | The existing service functions (`kpiMath.ts`, `scorecards.service.ts`, …) that turn raw tables into business metrics. The model calls these, never SQL |
| **Roster** | The per-request set of tools handed to the model, derived from the caller's JWT role. Both the accuracy control and the security boundary |
| **View spec** | `{type, params}` from a closed catalog. The model emits it; Flutter renders a registered widget. The model never generates UI |
| **Artifact** | A *stateful, live* view spec — has an id, persisted params, a history stack, and its own route. Steerable from its own controls or from chat |
| **Quarantine** | A tool-less model call that reads untrusted free text and returns structured output. An injected instruction has no tool to reach |
| **Spotlighting** | Wrapping untrusted content in delimiters marking it as data, not instruction |
| **Risk tier** | Read / reversible / irreversible. Determines whether an action prompts for confirmation |
| **Tool-selection accuracy** | Did the model call the right tool? Deterministic, so it needs no LLM judge — the primary eval metric |

---

## Explicitly not doing

| Rejected | Why |
|---|---|
| LangChain / LangGraph | Overhead and abstraction for a workload a ~100-line loop behind a provider interface already covers. **Tripwire (3 conditions):** a *third* provider, dynamic per-request routing, or durable multi-day resume re-opens this |
| Per-turn runtime failover between providers | History carries vendor-specific artifacts (thinking blocks, tool-call shapes) that do not transfer, and switching invalidates the cached prefix. Provider is pinned **per conversation** |
| Claude **Agent** SDK | That's Claude Code as a library — filesystem/coding shaped, wrong product for a data assistant |
| Self-hosted Langfuse (for now) | 6-service stack (web, worker, ClickHouse, MinIO, Redis, Postgres) is real operational weight for a small team. MIT licence keeps it as an escape hatch |
| Braintrust | Better eval UX, but $249/mo Pro and no self-host option |
| `deepgram_speech_to_text` Dart package | Community-maintained by an individual, and would ship the API key inside the app |
| Multi-orchestrator | Two brains on one manager's data is slower and costlier with no quality gain |
| Text-to-SQL | Fails by inventing confident numbers — disqualifying for KPI data |
| `flutter/genui` SDK | Highly experimental, API churn expected, no streaming UI yet |
| Speech-to-speech voice | ~10× cost, no auditable text boundary, wants a shallow tool surface |
| Zep / Letta now | Building a temporal graph over data Postgres already holds |
| Tool search / `defer_loading` | Role-scoping is simpler and solves the same problem — adopt only if one role exceeds ~25 tools |
| **Route optimisation / fleet management** | Ruled out by the practitioner directly: *"you don't want to be a fleet management tool. There's fleet management companies that deal with your FMCGs."* Route planning is a solved, competitive market — not our differentiator |
| Macro-economic strategy overlay (interest rates → price/volume advice) | A genuine long-term ambition from the interview, but it needs external data feeds that do not exist in the system. Capture as direction, not scope |
| Decoder/serial lifecycle tracking (warehouse → trade → sold → activated) | Real ask, but it's a supply-chain feature, not a conversational one. Separate initiative |
