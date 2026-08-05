# TradeIQ — Project Status

**Last updated:** 2026-08-02
**Current initiative:** Conversational TradeIQ (dashboard → chatbot)
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
| 0 | [Read-only chat spine](../../issues/253) | ⬜ Not started | ≥90% tool-selection accuracy **per provider** · cache hit on turn 2 · both adapters pass the contract test |
| 1 | [Voice in + voice out](../../issues/254) | ⬜ Not started | Transcript fidelity set · TTS p95 budgeted on independent latency |
| 2 | [**Artifacts** — filterable, responsive, PDF](../../issues/255) | ⬜ Not started | UI/prompt round-trip converges · params tampering rejected · PDF golden file |
| 3 | [Write actions + audit](../../issues/256) | ⬜ Not started | **Zero** cross-tenant leaks · every write tool has tier + gate + audit + red-team test |
| 4 | [Shrink sidebar 21 → 5](../../issues/257) | ⬜ Not started | Every retired destination still deep-linkable |
| 5 | [Memory + digests](../../issues/258) | ⬜ Not started | Preferences injected late; cache hit still holds |

> **Tickets.** Each phase has a tracking issue carrying its gate and task list
> (#253–#258). The backlog below is filed as #244–#250; the open questions as
> #251. The plan remains the *what and why* — the issues are where progress is
> claimed, so a task is done when its checkbox is ticked *there*, not here.

**Started 2026-08-06.** The key-independent half of Phase 0 foundation has
landed: the provider interface, the roster security boundary and its matrix
test, the per-client feature flag and kill switch, and both chat rate limiters.
Everything that needs a provider key — the Gemini adapter, the contract test,
Langfuse tracing — is still untouched, as is every tool, the orchestrator and
the route.

**Prerequisites:** a Langfuse Cloud project, plus **either** provider key. Both
are now declared in `backend/.env.example`; neither is set in `backend/.env`.

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

### Pre-existing (not part of this initiative)
- [x] Backend: 38 route modules, JWT auth + RBAC, multi-tenant scoping
- [x] Backend: pagination standardised across all list endpoints (#194, PRs #235/#237)
- [x] App: premium UI pass — charts, maps, worklists, agent visit trail
- [x] App: release build, offline DB encryption, session handling (#137–#140)
- [x] Audit remediation plans 1–4 merged

---

## In progress

_Nothing currently in progress._

---

## Next up — Phase 0

**Exit gate:** unit green · integration green · ≥ 90% tool-selection accuracy on
25 golden questions · cache-hit assertion passing · `assistant-evals.yml` running
its cheap slice on every assistant PR.

**Suggested order** — security boundary before anything that uses it:

1. Foundation
   - [x] `providers/types.ts` — `LlmProvider`, `TurnInput`, `TurnEvent`, `Usage` ✅ 2026-08-06
   - [ ] `providers/gemini.ts` (`@google/genai`) — **first adapter**
   - [x] `LLM_PROVIDER`, `GEMINI_API_KEY`, `ANTHROPIC_API_KEY` in `.env.example` ✅ 2026-08-03 (Langfuse keys too)
   - [ ] Provider contract test — same scripted turn, same `TurnEvent` stream
   - [ ] Langfuse Cloud project, tracing wired in from the first request
   - [ ] `.github/workflows/assistant-evals.yml` — cheap slice on PR, full sweep
         nightly, gated behind `secrets.ANTHROPIC_API_KEY`
2. Security boundary **first**
   - [x] `roster.ts` — role → tool list ✅ 2026-08-06
   - [x] Roster matrix unit test: every `(role × tool)` pair, incl. the negative
         case that `field_agent` cannot reach a manager tool ✅ 2026-08-06
         (41 assertions; `field_agent` is empty in Phase 0 per the Audience
         decision, which is what makes the negative case meaningful)
3. One vertical slice
   - [ ] `prompt.ts` — frozen system prompt, no interpolation
   - [ ] First tool (agent scorecard) wrapping the existing service
   - [ ] `sanitize.ts` — spotlight-wrap tool results as untrusted
   - [ ] `quarantine.ts` — tool-less Haiku pass over free text (dual-LLM pattern)
   - [ ] `viewspec.ts` — `agent_scorecard` spec + Zod validation
   - [ ] `orchestrator.ts` — `tool_runner` loop, cache breakpoint after tools+system
   - [ ] `POST /assistant/chat` (SSE), reusing `requireAuth`
   - [ ] Flutter: chat screen + streaming text
   - [ ] Flutter: refactor the scorecard screen into a parameterised widget
   - [ ] Flutter: view-spec registry renders it inline
4. Widen and prove
   - [ ] Remaining 7 tools, grouped by the four pillars
   - [ ] `trend_chart` + `outlet_map` specs
   - [ ] Integration test: stubbed model → correct service, correct `clientId`
   - [ ] View-spec validation test (unknown types, malformed params)
   - [ ] 25-question eval harness scored on tool-selection accuracy
   - [ ] Cache-hit assertion (`cache_read_input_tokens > 0` on turn 2)
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
   - [ ] Client disconnect aborts the in-flight provider call rather than
         orphaning a paid request

**Exit demo:** *"How has Tumo been performing this month?"* returns narrative
plus the real scorecard widget, at manager scope, with a cache hit on turn 2.

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
| Testing | Five layers, every phase gated | API key available day one, so nothing defers to a hardening pass |
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
