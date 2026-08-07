# TradeIQ — Project Status

**Last updated:** 2026-08-07
**Current initiative:** Conversational TradeIQ (dashboard → chatbot)
**Active branch:** `orchestration` — PR [#265](../../pull/265), stacked on the
foundation PR [#264](../../pull/264). Retarget to `main` once #264 lands.
**Plan:** [docs/superpowers/plans/2026-08-02-conversational-tradeiq.md](docs/superpowers/plans/2026-08-02-conversational-tradeiq.md) — sequencing and tasks
**Spec:** [docs/superpowers/specs/2026-08-02-conversational-tradeiq-design.md](docs/superpowers/specs/2026-08-02-conversational-tradeiq-design.md) — contracts, wire protocol, security model

> **How to use this file.** The plan is the *what and why*; this is the *where we
> are*. As work lands, move the line from **Next up** to **Done** with a date.
> When a choice is made, add a row to **Decisions** — that table is the record of
> *why*, which neither the plan nor the code carries. When something turns out to
> be wrong, correct it in place and say so; a status file that hides its own
> errors is worse than none.

---

## At a glance

| Phase | Scope | Status | Gate |
|---|---|---|---|
| 0 | [Read-only chat spine](../../issues/253) | 🟡 100% on Flash; unmeasured on Pro | ≥90% tool-selection accuracy **per provider** · cache hit on turn 2 · both adapters pass the contract test |
| 1 | [Voice in + voice out](../../issues/254) | ⬜ Not started | Transcript fidelity set · TTS p95 budgeted on independent latency |
| 2 | [**Artifacts** — filterable, responsive, PDF](../../issues/255) | ⬜ Not started | UI/prompt round-trip converges · params tampering rejected · PDF golden file |
| 3 | [Write actions + audit](../../issues/256) | ⬜ Not started | **Zero** cross-tenant leaks · every write tool has tier + gate + audit + red-team test |
| 4 | [Shrink sidebar 21 → 5](../../issues/257) | ⬜ Not started | Every retired destination still deep-linkable |
| 5 | [Memory + digests](../../issues/258) | ⬜ Not started | Preferences injected late; cache hit still holds |

> **Tickets.** Each phase has a tracking issue carrying its gate and task list
> (#253–#258). The backlog below is filed as #244–#250; the open questions as
> #251. The plan remains the *what and why* — the issues are where progress is
> claimed, so a task is done when its checkbox is ticked *there*, not here.

**Started 2026-08-06.** The key-independent half of Phase 0 foundation landed
first: the provider interface, the roster security boundary and its matrix test,
the per-client feature flag and kill switch, and both chat rate limiters.

> **Correction (2026-08-06, later the same day).** The paragraph above continued
> *"Everything that needs a provider key — the Gemini adapter, the contract
> test, Langfuse tracing — is still untouched, as is every tool, the
> orchestrator and the route."* That conflated two different things. Writing the
> adapter needs no key; only *exercising it against Google* does. The adapter,
> the contract suite, all nine tools, the orchestrator and the SSE route have
> since been built and are green, tested against a scripted provider. Langfuse
> tracing and the live accuracy sweep genuinely do still need credentials.

**Prerequisites:** a Langfuse Cloud project, plus **either** provider key. Both
are declared in `backend/.env.example`.

> **Update (2026-08-07). A `GEMINI_API_KEY` now exists on one developer
> machine**, in `backend/.env` (gitignored). It is *not* in CI: `secrets.GEMINI_API_KEY`
> is unset, so `assistant-evals.yml` still skips itself there. So the sweep is
> runnable by hand and the gate is still unenforced on every PR — which are
> different things, and only the first has changed. The Langfuse project still
> does not exist.

> **Correction (2026-08-03).** An earlier version of this line said
> `GEMINI_API_KEY` "is available now, so Phase 0 is **unblocked**". The key
> exists, but it is not in this repo's environment — `backend/.env` carries only
> `DATABASE_URL`, `JWT_SECRET` and `PORT`. Phase 0 splits either side of that:
> the provider **interface** and the `.env.example` declarations need no key and
> can proceed; `providers/gemini.ts`, the provider contract test, and Langfuse
> tracing cannot. Whoever holds the key needs to put it in `backend/.env` before
> the adapter is written, or it will be written against nothing.
>
> **Follow-up (2026-08-06).** That instruction had a trap in it. `make setup`
> generated `backend/.env` from the **root** `.env.example`, a 15-line fossil
> carrying only `DATABASE_URL`, `JWT_SECRET` and `PORT` — not from
> `backend/.env.example`, where the assistant variables were declared. So the
> file the correction above tells you to edit was being created without a single
> line to edit. The root copy is deleted and `setup` now copies the backend one.

---

## Success criteria for the initiative

Not phase gates — how we'll know the whole thing worked.

| Measure | Target |
|---|---|
| Manager can answer a stats question without touching the sidebar | The core bet |
| "Filter → export → re-filter → overlay in Excel" is gone | The workflow the practitioner asked us to kill |
| Fraud question answerable in seconds | Was *"two or three months"* to spot duplicate coordinates |
| Tool-selection accuracy | ≥ 90%, tracked per release |
| Cross-tenant leaks | Zero. Non-negotiable |
| Cost per conversation | Measured from Phase 0, not estimated |

---

## Done

### Planning & research — 2026-08-02
- [x] Audited current state: 21 sidebar destinations, 38 backend route modules,
      no LLM integration anywhere in the repo
- [x] Desk research: agent frameworks, memory layers, semantic-layer accuracy,
      generative UI, voice architecture, write-action safety, tool-selection
      limits, prompt-injection defence, eval reliability
- [x] Domain grounding from the 2026-07-29 practitioner interview (four pillars,
      period vocabulary, the Excel-overlay workflow, fraud latency)
- [x] Architecture decided — see Decisions
- [x] Implementation plan written (6 phases, gates, sequencing, cost model)
- [x] Design spec written — contracts, SSE wire protocol, turn lifecycle,
      security model
- [x] This tracker created

### Shipped — 2026-08-02
- [x] `backend-ci.yml` hardened: added `npm run typecheck` (covers `scripts/`,
      which `build` misses) and switched to `jest --runInBand` (#181 pool
      exhaustion on shared runners)

> **Correction:** an earlier version of this file and of the agent's memory
> claimed the backend had **no CI**. Wrong — `backend-ci.yml` existed and worked;
> the note predated the merge from `main`, and a plan was briefly written around
> a gap that did not exist. Both are fixed.

### Shipped — 2026-08-06 · Phase 0 foundation (PR [#264](../../pull/264), open)
- [x] `providers/types.ts` — the `LlmProvider` seam
- [x] `roster.ts` + a 41-assertion matrix test — the security boundary
- [x] `Client.assistantEnabled` rollout flag and 404 kill switch
- [x] Per-user **and** per-tenant chat rate limiters
- [x] `make setup` generated an `.env` missing every assistant variable — fixed

### Shipped — 2026-08-06/07 · Phase 0 spine (PR [#265](../../pull/265), open)

Everything in **In progress** below. Grouped here so the two PRs are legible as
separate units of review: #264 is the boundary and the flags, #265 is everything
that uses them.

Two repo-wide fixes that were not the point but blocked the work:

- [x] **`evals/` was invisible to `build` *and* `typecheck`** — reachable only
      from a `*.test.ts`, which `tsconfig.json` excludes. The golden set could
      have drifted out of sync with the tool registry and `tsc` would have
      reported success. The same gap the repo already fixed once for `scripts/`
- [x] **The lockfile was pruned by a Windows `npm install`**, dropping `sharp`'s
      optional `@emnapi` entries. `npm ci` then failed in the *first* step of
      all three CI jobs, so lint, typecheck, build and every test never
      reported — three red crosses and no test signal. Regenerated on
      `node:24-alpine`. **Anyone changing dependencies from Windows will hit
      this again:** check `git diff <base> -- backend/package-lock.json` for
      removed `node_modules/` keys before pushing; a dependency change should
      only ever *add* entries
- [x] A new high-severity `js-yaml` advisory (CVE-2026-59870) that landed
      against a dev transitive after #264 was authored

### Pre-existing (not part of this initiative)
- [x] Backend: 38 route modules, JWT auth + RBAC, multi-tenant scoping
- [x] Backend: pagination standardised across all list endpoints (#194, PRs #235/#237)
- [x] App: premium UI pass — charts, maps, worklists, agent visit trail
- [x] App: release build, offline DB encryption, session handling (#137–#140)
- [x] Audit remediation plans 1–4 merged

---

## In progress

**Phase 0 is built end to end and green on CI. It is not *done*, because its
gate has never been measured.**

The spine works: a question reaches a real service at the caller's tenant and
comes back as narrative plus a validated artifact the app renders. Backend and
app both. What it has never done is speak to a model — every test in the branch
runs against a scripted provider.

**Shipped on `orchestration` (8 commits, ~9,800 lines, all checks green):**

| | Landed |
|---|---|
| Provider | `gemini.ts` adapter · `geminiSchema.ts` · `contract.ts` suite · `LLM_PROVIDER` selector |
| Spine | `prompt.ts` · `sanitize.ts` · `quarantine.ts` · `viewspec.ts` · `period.ts` · `orchestrator.ts` · `POST /assistant/chat` (SSE) |
| Tools | All 9, across the four pillars + execution, over `pillars.service.ts` and `scorecards.service.ts` |
| Proof | 25 golden questions · scorer · cache-hit cost gate · `assistant-evals.yml` |
| App | Chat screen · SSE client · view-spec registry · `AgentScorecardCard` · rollout gate |
| Ops | `tracing.ts` (Langfuse, no-op unconfigured) |

### First live measurement — 2026-08-07

A key was provided. The sweep has now run against Gemini for real, three times.

| Run | Accuracy | What changed |
|---|---|---|
| 1 | 88.0% (22/25) — **fail** | baseline |
| 2 | 92.0% (23/25) — pass | fixed a harness bug + a tool-description overlap |
| 3 | **100.0% (25/25)** | added name → id resolution |

Model: `gemini-3.6-flash` (cheap tier, to conserve credits).

**What run 1 actually found — a missing tool, not a wording problem.**
`exec-1` is *"How has Tumo been performing this month?"*, the sentence the plan
names as the exit demo, and it routed to `getVisitHistory`. That was the model
being **right**: `getAgentPerformance` needed an `agentId`, nothing resolved a
name to one, and the visit list was the only tool returning agent identities. It
was doing a discovery hop because the roster left it no alternative.

Managers say names. Ids only come from tool results. `resolveAgent` now bridges
the two, `getAgentScorecard` takes `agent` (name, email or id), and the exit
demo is a single hop.

**Two bugs on the way there, one of them in the measurement itself:**

- A Gemini **503** on `comp-1` was being scored as the model choosing the wrong
  tool, so the headline was part accuracy and part Google's uptime. That single
  conflation was the whole difference between 88% (fail) and 92% (pass).
  Transient errors are now retried once, then excluded from the denominator
  **and reported** — a shrinking denominator flatters the percentage.
- `getVisitHistory`'s description ended *"…or whether an agent has been checking
  in"*, which a model reasonably reads as covering how an agent is *doing*.

> **The expected answers were never loosened to make this pass.** Adding
> `acceptable: ['getVisitHistory']` to `exec-1` would have produced a green
> number in run 1 without changing a thing about the product. An eval tuned to
> match current behaviour is a record, not a gate.

**Read 100% carefully.** It means *no misses on 25 questions we wrote ourselves,
once, on the cheap model*. It is not evidence of a solved problem:

- [ ] Re-measure on **Gemini 3.1 Pro** — the gate is stated per model
- [ ] The set is small and non-adversarial. Growing it is Phase 1 work, and a
      set that never fails is a set that has stopped measuring
- [ ] Single run. Selection is not deterministic; a re-run can differ
- [ ] `stock-4` passes on an `acceptable` alternative, not an exact match

> **The number was 88% before two fixes, and one of them was a measurement bug
> in my own harness.** A Gemini 503 on `comp-1` was being scored as the model
> choosing the wrong tool, so the headline was part accuracy and part Google's
> uptime. Transient provider errors are now retried once and then *excluded from
> the denominator and reported*, never counted as a miss. That single conflation
> was the difference between 88% (fail) and 92% (pass).
>
> The other fix was real: `getVisitHistory`'s description ended *"…or whether an
> agent has been checking in"*, which a model reasonably reads as covering how
> an agent is doing. Both descriptions now disambiguate in each direction. It
> recovered `comp-1` but not the two scorecard questions — because those are the
> missing-lookup problem above, not a wording problem.

**Also corrected:** the golden set has **25** questions. Earlier commits and all
three documents said 26. Miscounted, and now counted programmatically.

**What is still not done:**

- [ ] **Re-measure on the real model.** 92% is `gemini-3.6-flash`. The gate is
      stated per model, and the plan's target orchestrator is Gemini 3.1 Pro.
      This number is a floor, not the number
- [ ] **Langfuse Cloud project** — the client and the seam exist; there is no
      project, so tracing no-ops
- [ ] **`trend_chart` + `outlet_map`** — in the catalog and validated, but no
      tool emits them and no widget draws them. Deliberately unticked
- [ ] **Provider console spend caps** — the one ceiling this repo cannot provide
- [ ] **`anthropic.ts`** — waiting on its key. The contract suite is written so
      that adding it should be an adapter plus a flag; if it turns out to be
      more, the interface leaked and *that* is the bug

**Three defects found by tests during the build**, each invisible to review:

1. `z.discriminatedUnion` emits JSON Schema `oneOf`, which **Gemini's `Schema`
   does not have**. Every tool takes a period, so this was a 400 on *every
   turn* — caught by converting every registered tool's schema in a test.
2. The tracer's queue cap did nothing: `flush()` splices synchronously before
   its first `await`, so the queue drained every 50 events and never reached the
   bound — trading unbounded memory for unbounded concurrent requests.
3. The app resolved repeated calls to one tool **backwards** (`lastIndexWhere`),
   with a comment above it claiming the opposite.

> **A limitation worth knowing before it surprises someone.** Gemini's
> `abortSignal` is *client-side only*, per the SDK's own note: a client
> disconnect stops us reading the stream, it does not stop Google generating or
> billing it. The plan's "client disconnect must not orphan a paid request" is
> therefore only partly satisfiable in code, and the rest genuinely is the
> console cap.

> **`RATES` in `providers/gemini.ts` is a placeholder.** Google's published
> pricing has not been confirmed, so `costCents` is directionally right and
> not yet trustworthy. It is a visible wrong number rather than a `0`, because
> a zero would make a cost regression look like a saving.

---

## Next up — Phase 0

**Exit gate:** unit green · integration green · ≥ 90% tool-selection accuracy on
25 golden questions · cache-hit assertion passing · `assistant-evals.yml` running
its cheap slice on every assistant PR.

**Suggested order** — security boundary before anything that uses it:

1. Foundation
   - [x] `providers/types.ts` — `LlmProvider`, `TurnInput`, `TurnEvent`, `Usage` ✅ 2026-08-06
   - [x] `providers/gemini.ts` (`@google/genai`) — **first adapter** ✅ 2026-08-06.
         Absorbs the three vendor differences that bite: the system prompt is
         `config.systemInstruction` (prepending it as a `user` turn is the
         common migration bug — it works, and silently destroys the cache prefix
         and the instruction hierarchy); `FunctionCall.id` is optional on the
         wire so a deterministic one is synthesised; cache hits arrive as
         `cachedContentTokenCount`. `providers/geminiSchema.ts` is split out and
         **pure** — Gemini's `Schema` is not JSON Schema, and two of the
         differences (`anyOf: [T, null]`, `const`) fail *silently* by widening
         what the model believes it may send
   - [x] `LLM_PROVIDER`, `GEMINI_API_KEY`, `ANTHROPIC_API_KEY` in `.env.example` ✅ 2026-08-03 (Langfuse keys too)
   - [x] Provider contract test — same scripted turn, same `TurnEvent` stream ✅ 2026-08-06.
         `providers/contract.ts` is a suite *definition*: each adapter renders
         one abstract script into its own wire shape, and everything after that
         is asserted identically. **No key, no network** — a contract test that
         needs a live provider runs on one machine, which is how a contract
         stops being enforced
   - [~] Langfuse tracing wired in from the first request ✅ 2026-08-06 —
         **the seam and the client exist; the Cloud project does not.** No-op
         when unconfigured, which is this repo's state. Fire-and-forget behind a
         bounded, serialised queue: observability must never fail a turn, and
         the orchestrator guards the tracer as well as the tracer guarding
         itself. **Metadata only — conversation content is behind
         `LANGFUSE_TRACE_CONTENT`, default off**, because the retention policy
         for transcripts is still open (#251 Q3) and shipping capture would
         quietly decide it. Tool *results* are never sent at any setting
   - [x] `.github/workflows/assistant-evals.yml` — cheap slice on PR, full sweep
         nightly ✅ 2026-08-06. Matrix is **per provider and `fail-fast: false`**,
         because the ≥90% gate is per adapter and a mean is exactly what hides a
         one-provider regression. Skips cleanly on fork PRs and warns loudly on
         a missing key, since a 0% score and an absent secret are otherwise
         indistinguishable
2. Security boundary **first**
   - [x] `roster.ts` — role → tool list ✅ 2026-08-06
   - [x] Roster matrix unit test: every `(role × tool)` pair, incl. the negative
         case that `field_agent` cannot reach a manager tool ✅ 2026-08-06
         (41 assertions; `field_agent` is empty in Phase 0 per the Audience
         decision, which is what makes the negative case meaningful)
3. One vertical slice
   - [x] `prompt.ts` — frozen system prompt, no interpolation ✅ 2026-08-06.
         Exported as a `const`, not a builder, so there is no parameter to
         accidentally thread through
   - [x] First tool (agent scorecard) wrapping the existing service ✅ 2026-08-06.
         `getAgentPerformance` added to `scorecards.service.ts`; the team
         baseline **excludes the agent being scored**, because including them
         pulls the average toward their own figure and compresses the gap most
         for exactly the outliers a manager is looking for
   - [x] `sanitize.ts` — spotlight-wrap tool results as untrusted ✅ 2026-08-06.
         The fence is stripped from the payload before wrapping — a wrapper the
         payload can close is the classic spotlighting failure. Also strips
         Unicode tag characters and bidi overrides, which carry instructions no
         human reviewing the record can see
   - [x] `quarantine.ts` — tool-less pass over free text (dual-LLM) ✅ 2026-08-06.
         **Fails closed**: on error, timeout, or a quarantine turn that somehow
         emits a tool call, the text is omitted rather than passed through raw
   - [x] `viewspec.ts` — `agent_scorecard` spec + Zod validation ✅ 2026-08-06
   - [x] `orchestrator.ts` — loop, cache breakpoint after tools+system ✅ 2026-08-06.
         Bounded at four tool rounds; the last round *withdraws tools* rather
         than cutting the turn off, so the model still answers from what it
         retrieved instead of wasting every paid call already made
   - [x] `POST /assistant/chat` (SSE), reusing `requireAuth` ✅ 2026-08-06
   - [x] Flutter: chat screen + streaming text ✅ 2026-08-06. SSE over a POST
         read with a stream response, not `EventSource` — the message and
         history do not belong in a URL, and `EventSource` cannot send an
         `Authorization` header. `SseParser` is split from the transport and
         tested a character at a time, because framing bugs only appear under
         chunk boundaries a real server happens to produce
   - [x] Flutter: scorecard as a parameterised widget ✅ 2026-08-06 —
         `AgentScorecardCard`, deliberately minimal (the anti-crowding rule).
         Every payload read is type-**tested**, never cast: a field that changes
         type would otherwise throw and take the narrative down with it
   - [x] Flutter: view-spec registry renders it inline ✅ 2026-08-06. An unknown
         spec renders a note, never a blank card — including the *older-client*
         case, where the server has added a spec this build has not heard of
4. Widen and prove
   - [x] Remaining 8 tools, grouped by the four pillars ✅ 2026-08-06.
         `pillars.service.ts` holds the aggregates — a new service rather than
         additions to six existing pillar modules, which are being edited by
         other branches and are the semantic-conflict surface
   - [ ] `trend_chart` + `outlet_map` specs — catalog and validation exist; no
         tool emits them yet, because nothing renders them until the Flutter
         registry lands. **Deliberately not ticked**
   - [x] Integration test: stubbed model → correct service, correct `clientId` ✅ 2026-08-06,
         including the cross-tenant probe: the model names a real user id from
         another tenant and the closure returns nothing
   - [x] View-spec validation test (unknown types, malformed params) ✅ 2026-08-06
   - [x] 25-question eval harness scored on tool-selection accuracy ✅ 2026-08-06 —
         25 questions including two **refusal** cases, because a suite with no
         refusals rewards a model that always guesses
   - [x] Cache-hit assertion (`cache_read_input_tokens > 0` on turn 2) ✅ 2026-08-06,
         with a companion test proving the assertion has teeth by interpolating
         the system prompt and watching the prefix diverge
5. Rollout and spend controls — **stated in the plan, previously missing here**
   - [x] Per-client feature flag, from Phase 0 ✅ 2026-08-06 —
         `Client.assistantEnabled`, default **false**. Readable via
         `GET /clients/me` so the app can gate its entry point, deliberately
         **not** writable via `PATCH /clients/me`: it is a rollout lever, not a
         customer preference, and a client admin switching on a metered AI
         feature for their own tenant is the thing a rollout flag exists to
         prevent. Operators toggle it directly until a cross-tenant admin
         surface exists
   - [x] Kill switch ✅ 2026-08-06 — `requireAssistantEnabled` answers **404,
         not 403**: 403 concedes the feature exists and this tenant is merely
         not entitled, which invites probing. It fails closed on a DB error,
         because defaulting a metered feature *open* on an infrastructure blip
         is a spend incident
   - [~] Rate-limit `/assistant/chat` per-user **and** per-tenant — limiters
         **built and tested** ✅ 2026-08-06, **not yet mounted**: the route does
         not exist. `createAssistantUserRateLimiter` /
         `createAssistantTenantRateLimiter` key on the JWT, never the IP (a team
         behind one corporate NAT would otherwise throttle each other). Tick
         this fully when `POST /assistant/chat` lands with both mounted after
         `requireAuth`
   - [ ] Hard monthly cap in **both** provider consoles + Langfuse budget alerts
         at 50% / 80%. Rate limiting bounds *a user*; the console cap bounds
         *the account* — a leaked key is not rate-limited by anything in this repo
   - [~] Client disconnect aborts the in-flight provider call ✅ 2026-08-06 —
         the route aborts on `res.close`, the orchestrator checks between
         rounds and between tool calls, and the signal reaches the SDK.
         ⚠️ **Gemini's `abortSignal` is client-side only**, per the SDK's own
         note: it stops us reading, not Google generating or billing. So this
         is only *partly* satisfiable in code, and the rest is the console cap
         above

**Exit demo:** *"How has Tumo been performing this month?"* returns narrative
plus the real scorecard widget, at manager scope, with a cache hit on turn 2.

> **The demo passes as a test, against a scripted model.**
> `assistant.routes.test.ts` and `chat_screen_test.dart` both assert exactly
> that sentence end to end — tool call, real service at the caller's tenant,
> validated artifact, rendered widget. It has **never been run against Gemini.**
> Treat it as unproven until it has.

---

## Decisions

Grouped by area. Each row is a choice we should not re-litigate without new
information.

### Architecture

| Decision | Choice | Why |
|---|---|---|
| Orchestration | Anthropic SDK `tool_runner`, **no LangChain/LangGraph** | Single-model request/response workload; the SDK loop already gives approval hooks. LangGraph adds 20–80ms/layer, worst-in-class debugging, steepest learning curve — its wins (durable resume, multi-provider) don't apply. **Tripwire:** durable multi-day resume or >3 loop branches re-opens this |
| Anthropic surface | Messages API + `tool_runner` — **not** the Claude *Agent* SDK (Claude Code as a library), **not** Managed Agents (Phase 5 only) | Public comparisons blur these three; only the plain SDK fits a data assistant |
| **Providers** | **Two, behind a two-method `LlmProvider` interface.** Gemini built **first** (key available); Anthropic when its key lands | Amends ADR 0008's "committed to Claude". The SSE event vocabulary is the normalisation boundary, so orchestrator/routes/Flutter stay vendor-blind |
| Provider scope | Pinned **per conversation**, never per turn | History carries vendor-specific artifacts (thinking blocks, tool-call shapes) that don't transfer; switching also invalidates the cached prefix |
| Brains | **One** orchestrator, many single-purpose tools | Two brains on one manager's data = slower, costlier, no quality gain |
| Model | Gemini 3.1 Pro / Opus 5 orchestrating; Gemini 3.6 Flash / Haiku 4.5 for quarantine | Tier by task, not parallel brains |
| Data access | Tools wrap `*.service.ts`. **Never SQL/Prisma** | Semantic layer ≈ 98% vs ≈ 90% for text-to-SQL — and it fails by refusing rather than inventing a number |
| Tool exposure | Roster derived from JWT role | Selection accuracy collapses past 30–50 tools; role-scoping fixes accuracy *and* is the security boundary |
| Tool taxonomy | Grouped by the **four pillars** (sales, stock, visibility, competition) + execution | The practitioner's own mental model — *"those are your four pillars… your input KPIs"*. Not REST endpoints |
| Validation | **Zod**, added 2026-08-06 | The design spec already commits to it — tool `args`, view specs and artifact params are all "validated by the tool's Zod schema". Adding it with the provider types rather than later keeps `AssistantTool` expressible at the point it is first declared |
| `TurnEvent` scope | **Narrower than the SSE wire vocabulary.** Providers emit `token` · `tool_call` · `usage` · `error` · `done`; the orchestrator adds `tool_start`/`tool_end`/`artifact`/`confirm` | `artifact` is a validated spec from our closed catalog and `confirm` is our risk gate — no model stream can produce either, so including them would oblige every adapter to declare cases it can never emit. The mapping table lives in `providers/types.ts`. **Confirm against the design spec before the first adapter**: the spec calls the SSE table "the normalisation boundary", which is true for the client but sits one layer above where vendor differences actually live |
| Roster immutability | **Fresh `Set` per call**, not a shared frozen one | `Object.freeze` does not make a `Set` immutable — contents live in internal slots, not properties, so a "frozen" roster still accepts `.add()` and the mutation would persist for every later request in the process. At nine entries beside an LLM call, copying does not register |
| **Audience** | **Manager console only for Phase 0.** Revisit for field agents at Phase 5, and as a narrow non-chat surface rather than the full spine | Every piece of evidence behind this plan is manager-shaped — the interview, the Excel-overlay workflow, the 21 `managerDestinations`. Chat also contradicts the agent app's core promise: captures queue offline and sync later, but a chat turn has nothing sensible to queue, so an agent with no signal gets a spinner from an app built to keep working without one. Agents are mid-capture, not mid-enquiry; they also author the free text that is the injection vector (outlet names, visit notes), and they outnumber managers, so the rate-limit and red-team surface both widen for demand nobody has demonstrated. **Reopen if** agent-side questions show up — #52 (route screen) is the one real signal, and it wants a screen that works offline, not a turn that doesn't |

### Implementation — decided while building Phase 0

| Decision | Choice | Why |
|---|---|---|
| **`Period` on the wire** | **Flat `{kind, from?, to?}`**, narrowed back to a discriminated union by `transform` | `z.discriminatedUnion` emits JSON Schema `oneOf`, and **Gemini's `Schema` has no `oneOf`**. Every tool takes a period, so the obvious spelling was a 400 on *every turn* — caught by `tools.test.ts`, not by a request. Strictness is unchanged: `refine` still rejects a `custom` period with no dates, and dates supplied alongside a fixed period |
| Inexpressible tool schemas | `toGeminiSchema` **throws**, never drops | A silently discarded constraint is a schema that lies to the model. `anyOf: [T, null]` and `const` are the dangerous cases because Gemini *accepts* the truncated version |
| Who names a view spec | **The tool**, never the model | Makes the closed catalog a real constraint rather than a suggestion — there is no path by which a model could name a spec type at all |
| Artifact data vs model data | Artifact carries the **raw** result; the model gets the sanitized copy | Fencing would put `«untrusted» …` inside a chart label. The model is what an injection targets; a widget is not |
| Quarantine failure | **Fails closed** — text omitted, never passed through raw | Falling back to the original on failure switches the defence off exactly when something is already going wrong |
| Loop bound | 4 rounds; the last **withdraws tools** rather than cutting off | Every round is a paid request. Stopping dead would waste every call the turn already made, when the model can still answer from what it retrieved |
| Pillar aggregates | New `pillars.service.ts`, not additions to six existing modules | Those files are being edited by other branches and are the semantic-conflict surface — two green PRs, one red `main`. These are also a different shape: capture services read *one visit*, these summarise many |
| `eraseToolTypes` | One documented assertion, in one place | `AssistantTool` is contravariant in its args, so a heterogeneous roster cannot be typed without it. The cast is guarded by the orchestrator's `safeParse`, which runs before `run` is reached |

### Interface

| Decision | Choice | Why |
|---|---|---|
| Rendering | Typed view specs → registered Flutter widgets | Reuses existing chart/map/worklist widgets; the model never emits UI |
| GenUI SDK | Adopt the A2UI **pattern**, not the package | `flutter/genui` is "highly experimental", API churn expected, no streaming UI |
| Charts | Reuse `core/widgets/charts.dart` | `LineChart`/`ColumnChart`/`BarChart`/`Sparkline` already exist as hand-rolled `CustomPainter`; no new dep. A closed spec catalog protects the design rules |
| Artifact state | `params` is the single source of truth; one Zod schema written by **both** model and UI | Prevents the two control paths from drifting apart |
| Filter changes | `POST /artifacts/:id/refine` re-runs the **same tool closure** — no model call | A slider drag must not cost 3s and a paid request; reusing the closure means scope was never a tamperable parameter |
| Artifact navigation | Real route `/artifact/:id` | Back button, deep links, sharing come free from go_router instead of bespoke state machinery |
| Period vocabulary | `today · yesterday · previous_week · mtd · ytd · custom` | Taken verbatim from what they filter by daily — not invented |
| Comparison | First-class in artifacts, not an add-on | The workflow being killed is *"export, save, export again, overlay in Excel"* — comparison **is** the job |
| PDF | Client-side `pdf` + `printing`, hybrid vector text + rasterised chart | Vector-only means reimplementing every `CustomPainter`; raster-only gives a blurry, unsearchable report. Bundled Inter TTFs keep it on-brand |
| Scheduled PDF | **Out of scope** — separate from artifact export | `/reports` + `/report-schedules` are server-side and cannot reuse Flutter charts |
| Sidebar | 21 → 5 | Business conversation said *"29 down to five, six"*; code has 21 manager destinations. Same intent |

### Voice

| Decision | Choice | Why |
|---|---|---|
| Architecture | Cascaded STT → LLM → TTS | S2S is ~10× cost and leaves no auditable text boundary; TradeIQ needs deep tools + RBAC + confirmations |
| STT | `speech_to_text`, on-device | Free, no key, no audio upload. Its "short phrases" limitation *is* our use case |
| TTS | Backend-proxied, vendor behind an interface (Cartesia first) | Keeps the key server-side; SSM architecture holds P99 tail latency. Rejected the community Dart Deepgram package — individual maintainer + client-side key |
| Voice-out default | **Off**, per-user toggle | Open-plan offices |

### Safety & operations

| Decision | Choice | Why |
|---|---|---|
| Write actions | 3-tier risk gate | Gating everything causes confirmation fatigue — the named failure mode of approval UX |
| Recommendations | Allowed, but must cite tool-retrieved figures | Their dashboards give none, so it's the differentiator — but an ungrounded recommendation is the exact failure the semantic layer prevents |
| Prompt injection | Dual-LLM quarantine + spotlighting, layered | No single defence closes the gap; instruction-based defence is the weakest layer and never the only one |
| Observability | **Langfuse Cloud** (MIT, self-host escape hatch) | Self-hosting is a 6-service stack — real operational weight for a small team. Braintrust is nicer but $249/mo with no self-host |
| Memory | Postgres preferences now; defer mem0/Zep | Temporal truth already lives in Postgres — don't build a graph over it |
| Testing | Five layers, every phase gated | ~~API key available day one, so nothing defers to a hardening pass~~ — **the premise was wrong** (2026-08-07). No key ever arrived. Four of the five layers turned out not to need one and are green; the *live eval* layer is the exception, and it is the phase gate. The conclusion survives by accident rather than by design: nothing was deferred, but nothing was proven either |
| **Trace content** | **Metadata only. Conversation text behind `LANGFUSE_TRACE_CONTENT`, default off** | Transcripts carry outlet and agent PII, and retention (#251 Q3) plus POPIA residency (Q4) are both **open**. Shipping capture to a third-party cloud would answer them without anyone deciding. Tool *results* are never sent at any setting — they are simultaneously the untrusted surface and the richest PII source in the system |
| **Cost rates** | Placeholder, seeded from the plan's cost table, `costCents` never `0` | Google's pricing is unconfirmed. One set of numbers to correct rather than two that can disagree; a zero would make a cost regression look like a saving |
| Rollout | Per-client feature flag; additive until Phase 4 | Nothing is removed until the replacement is proven |

---

## Backlog — surfaced by the 2026-07-29 practitioner interview

Independent of the assistant. The chatbot can only report signals the backend
computes, so these are **backend** work items.

**Fraud signals described in the field but not implemented** (existing:
`failed_attempts`, `fast_completion`, `geofence_distance`, `no_capture`,
`photo_gps_divergence`):

- [ ] #244 — Duplicate photo reuse across outlets / visits
- [ ] #245 — Flat or repeating stock figures across periods (*"2-1, 2-1"*)
- [ ] #246 — Gap between stock-entry timestamp and photo timestamp
- [ ] #247 — Dwell time **above** benchmark; only `fast_completion` exists, and
      ~12 min is the practitioner's benchmark, so *both* tails are signals
- [ ] #248 — Stock scanned outside its assigned outlet

**Product direction, not yet scoped:**
- [ ] #249 — Macro overlay (interest rates, fuel, disposable income) →
      price/volume strategy advice. Needs external data feeds
- [ ] #250 — Decoder/serial lifecycle: warehouse → trade → sold → activated

**Roadmap conflict to resolve:**
- [ ] **#61 "ML route optimisation & next-best-action"** (Phase 4, ticketed) is
      half-contradicted by the interview: *"you don't want to be a fleet
      management tool."* Re-scope to next-best-action only, or close, before
      anyone starts it. Flagged in `docs/ROADMAP.md` and on the issue itself

---

## Open questions

Filed as **#251** so they are assignable.

| # | Question | Blocks | Owner |
|---|---|---|---|
| 2 | Risk-tier assignment for write actions — which are truly irreversible in *your* customers' eyes? Too loose is dangerous, too tight is confirmation fatigue | Phase 3 | — |
| 3 | Retention policy for conversation transcripts — they will contain outlet and agent PII | Phase 5 | — |
| 4 | Any POPIA / client-contract data-residency requirement? Anthropic's *managed* features are unavailable via Bedrock, so Phase 5 digests would be affected. The `tool_runner` choice stays portable either way | Phase 5 | — |

**Answered:** bot speaks back ✅ · bot can take actions ✅ · API key provided ✅ ·
period vocabulary ✅ (from the interview) · **audience — manager console only for
Phase 0 ✅** (2026-08-03; see Decisions → Architecture → Audience)

> **Q3 and Q4 are worth answering now, not at Phase 5.** Both are
> retention/residency questions, and Q3 is the same question as #178 about a
> different data type. Answering them late risks Phase 5 designing around a
> capability the contract may not permit — the specific trap is already known:
> Anthropic's *managed* features are unavailable via Bedrock, which is exactly
> what the scheduled-digest task depends on. Q2 can wait; it needs a customer in
> the room and Phase 3 is three phases out.

---

## Risks

| Risk | Mitigation |
|---|---|
| **Indirect prompt injection** via agent-authored visit notes, outlet names, messages | Dual-LLM quarantine — free text summarised by a **tool-less** Haiku call before reaching the orchestrator. Spotlight-wrap anything passing through verbatim. `sanitize.ts` scans for instruction patterns. Red-team eval set in Phase 3 |
| **Cross-tenant leak** if the model supplies `clientId` | Tools are closures over `req.user`; tenant is never a model argument, so it is enforced by the type signature rather than by validation. Roster matrix test is the regression guard |
| **Prompt cache silently invalidated** → cost blowout with no functional failure | Frozen system prompt, deterministic tool order, `cache_read_input_tokens > 0` asserted in CI as a *cost* regression test |
| **Unbounded chat endpoint = cost DoS.** `express-rate-limit` is a dependency but `middleware/rateLimit.ts` currently guards `/auth/login` **only** | Per-user *and* per-tenant limits on `/assistant/chat` in Phase 0. An authenticated user looping Opus turns has no ceiling otherwise |
| **No spend floor** if a key leaks or a loop runs away | Hard monthly cap in **both** provider consoles + Langfuse budget alerts at 50% / 80%. Client disconnect must abort the in-flight call, not orphan a paid request |
| **The second provider adapter drifts silently** — passes its own tests, behaves differently in production | Contract test runs both adapters over the same scripted turn and asserts an identical normalised `TurnEvent` stream. Interface stays two methods wide; anything broader is a contract that can't be held |
| **A regression on one provider masked by the other passing** | The ≥90% tool-selection gate is **per provider**, not an average. Nightly sweep runs both — and costs roughly double, which is budgeted rather than discovered |
| Provider abstraction leaks, making the Anthropic swap a rewrite instead of a config flag | If adding `anthropic.ts` turns out to be more than an adapter plus a flag, that is the bug — fix the interface, don't special-case the caller |
| **Eval suite becomes flaky and gets disabled** | Score-and-threshold, never equality. Measure grader self-agreement — `UNSTABLE` is a failing state. Most of the suite is deterministic tool-selection comparison needing no judge |
| **Confirmation fatigue** makes approvals meaningless | Gate on risk tier only; reads never prompt. Instrument the prompt rate — >1 in 10 turns in a routine session is a calibration bug |
| **`orchestrator.ts` accretes branches** until it's an unmaintainable while-loop — the named DIY failure mode | Loop stays logic-free; conversation state in Postgres from day one; explicit tripwire in the file header to re-open the LangGraph decision |
| **Artifact state desync** — user filters via UI, then asks a follow-up answered against stale params | UI changes append a compact `[artifact:id params → …]` note to history; a live-artifact manifest lets the model target an existing card. Round-trip convergence test in Phase 2 |
| Chat becomes a graveyard of near-identical charts | Model patches artifacts in place via the manifest; inline cards deliberately minimal, controls only in Expanded |
| Chat answers a question no widget can display | View-spec catalog is closed; an unknown spec falls back to a text answer, never a blank card |
| Semantic-layer scope gaps (*"I can't answer that"*) | Acceptable failure mode **by design** — track refusals in the eval harness and add tools where they cluster |
| PDF generation freezes the app on a large report | Generate in an Isolate; golden-file test on output bytes |
| Assistant implies fraud detection we don't have | Phase 0 scopes the fraud tool to the five implemented signals; the gap is tracked in the backlog above, not assumed |

---

## Glossary

Full definitions in the plan. Quick reference:

**Four pillars** — sales, stock, visibility, competition; the user's own framing.
**Roster** — per-request tool set derived from the JWT role; accuracy control *and* security boundary.
**View spec** — `{type, params}` from a closed catalog; the model never generates UI.
**Artifact** — a stateful view spec with an id, persisted params, history, and its own route.
**Quarantine** — a tool-less model call over untrusted text; an injection has no tool to reach.
**Risk tier** — read / reversible / irreversible; decides whether an action prompts.
