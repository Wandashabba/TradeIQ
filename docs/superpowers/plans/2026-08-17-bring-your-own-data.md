# Bring your own data — a customer's own systems behind TradeIQ

> **Status: decision note, not an implementation plan.** Nothing here is
> scheduled and nothing should be built from it yet — the last section says
> what has to happen first, and it is not a coding task.

**The question.** Today a customer's data gets into TradeIQ because *field
agents capture it in our app*. The question is whether a company can arrive
with an existing system — an ERP, a distributor feed, another field-force tool
— and have TradeIQ answer questions about **their** data instead of ours.

**Short answer: yes, and it is probably the difference between a product and a
pilot.** A large FMCG will not re-key what it already has. But "point the
assistant at their API" is the most expensive possible version of the idea and
the one that quietly destroys what makes the assistant trustworthy. The
recommendation below is a cheaper shape that keeps the guarantees.

---

## First: four different products are hiding in one sentence

Separating them is most of the work, because they have wildly different costs
and only one of them is what customers usually mean.

| | What it means | Cost | Who asks for it |
|---|---|---|---|
| **A. Import / sync** | Their system of record feeds TradeIQ on a schedule. We still own the schema and the metrics | Moderate | Almost everyone, whether they say so or not |
| **B. Live federation** | Tools call *their* API during the turn. We store nothing | High, and it degrades the assistant | People who say "just connect to our API" |
| **C. Their semantic layer** | They define the metrics; we map onto their definitions | High, and it ends the cross-customer benchmark | Enterprises with a BI team |
| **D. White-label** | Their front end, our brain | Separate product | Resellers |

**This note argues for A as the default, B only where a question genuinely
cannot be answered from a snapshot, and C as a per-metric exception rather than
a mode.** D is a different conversation.

---

## Why not simply point the tools at their API

Because **the tools are the semantic layer and the security boundary at the
same time**, and both properties come from the tool wrapping a service *we*
wrote:

- **Accuracy.** The plan's central bet is 98% through a semantic layer versus
  ~90% for text-to-SQL — and, more importantly, that it fails by *refusing*
  rather than by inventing a number. That holds because `getShareOfShelf` means
  exactly one thing. If it means whatever each customer's endpoint returns, the
  tool description the model reads — frozen, cached, and eval'd — stops being
  true, one customer at a time.
- **Isolation.** `clientId` is not a model-supplied argument; it is closed over
  from the JWT. A per-customer HTTP source adds a *second* thing that must be
  bound the same way (their credentials), and it must be equally impossible for
  a tool argument to reach.
- **Latency and failure.** A turn already spends seconds on the model. A tool
  that fans out to a customer API with unknown p95 turns "how's my stock" into
  a timeout — after the paid model call has been made. Their outage becomes our
  outage, mid-conversation.
- **Comparison doubles it.** `compareTo` re-runs the same tool over a second
  window. Every compared question becomes two outbound calls to a system whose
  rate limit is not ours to raise.
- **Aggregation.** The pillar tools aggregate across outlets and periods. Their
  API almost certainly does not expose the aggregate we need, so we would fetch
  rows and aggregate in memory, per question, live. That is a data warehouse
  with extra steps and no cache.

None of this says "never federate". It says federation is a per-question
exception, not an architecture.

---

## The shape to build (when it is time)

Three layers, and the discipline is that **only the middle one is per
customer**.

### 1. The canonical model stays ours

The four pillars plus execution — outlet, visit, SKU, facings, stockout, score
— is the vocabulary the tools speak, the tool descriptions promise, and the
eval set measures. **Do not let this become per-customer.** The moment it does,
there is no shared eval, no cross-customer benchmark, and no way to review the
tool declarations as one artifact.

### 2. A per-tenant source adapter

The same seam the repo already trusts for models. `LlmProvider` is two methods
wide, and the standing rule is: *if adding the second adapter turns out to be
more than an adapter plus a flag, the interface leaked and that is the bug.*
Apply it here — a narrow `DataSource` interface with `NativeSource` (today's
Prisma queries, the reference implementation) and `HttpSource` beside it.

The services keep their signatures. The tools do not change at all. That is the
test of whether this layer is in the right place.

### 3. A field mapping declared as data, not code

Different companies name things differently and count them at different
grains — store vs outlet, SKU vs article, "audit" vs "visit". The mapping
belongs in a per-tenant, versioned, Zod-validated config, so onboarding a
customer is configuration rather than a release. Anything that cannot be
expressed as mapping — a customer who has no concept of facings at all — is not
a mapping problem, it is a **coverage** problem, and coverage has its own answer
below.

### Sync, not federate, as the default

Pull on a schedule into the existing tenant-scoped tables, with provenance
columns (`source`, `sourceId`, `syncedAt`). The assistant keeps querying one
store, so latency, aggregation and cost stay where they are today, and a
customer outage delays freshness instead of breaking a conversation.

Federate only where the question is genuinely live — "is this order confirmed?"
— and even then behind a per-tool timeout, with the answer stating its own
recency.

---

## The five things that will actually bite

1. **Their number and our number will disagree, and they will trust theirs.**
   `kpiMath.ts` computes on-shelf availability our way. If a customer already
   publishes an OSA figure, ours will differ — different denominator, different
   treatment of a closed store. **Recommendation: recompute from their raw data
   where raw data exists, and when we accept a pre-computed metric, say whose
   it is in the answer.** Provenance in the response is what keeps the
   assistant honest; a figure with no stated origin is the beginning of a
   support ticket.

2. **A tenant with no visibility data must make the tool disappear, not return
   zeros.** Zero is a lie that looks like data. The roster is already derived
   per request from the caller's role — extend it to intersect with *what this
   tenant actually has*. This reuses the existing security machinery, and it
   shrinks the roster, which helps selection accuracy rather than hurting it.

3. **The eval gate has to survive per-customer data.** Do not run 27 golden
   questions per customer — that is a bill and a maintenance burden that grows
   linearly with sales. Instead copy `providers/contract.ts`: **one abstract
   fixture that every adapter must render into the same canonical rows.** The
   golden set stays against a reference tenant and keeps meaning what it means.

4. **Their feed is untrusted input, in bulk.** Today's injection surface is
   agent-authored free text. A customer feed is the same surface, arriving
   faster and unsupervised. Sanitise **once at ingest**, not per turn.

5. **Credentials become tenant state.** Per-tenant API keys or OAuth tokens
   need encrypted storage, rotation, and the same rule as `clientId`: no tool
   argument may ever name one. Plus a health signal — a sync that has been
   failing for two days must be something the assistant can *say*, because
   answering from a stale snapshot without mentioning it is the worst failure
   mode this system has.

---

## The cheapest first version is not an API at all

**It is a file.** Most customers will hand over a weekly CSV or Excel export
long before they will hand over API credentials and a security review. A file
import exercises the entire mapping layer — naming, grain, coverage,
provenance, the "their number vs our number" conversation — without touching
their infrastructure or waiting on their IT department.

Ship that for one customer, hand-mapped. Generalise on the second. The
generic connector framework, if it is ever justified, is what the third
customer pays for.

---

## What has to happen before any of this is scheduled

**One real customer's actual export or API documentation.** Designing a mapping
format against imagined schemas is how teams produce a config language that no
real customer can express their data in — and it is unfalsifiable until someone
tries, by which point it is load-bearing.

Two things are worth protecting *now*, at no cost, because they keep this
possible later:

- **Tools keep wrapping services, never Prisma directly.** Already the rule;
  this is a second reason for it.
- **Answers should be able to state their own recency.** Not needed while we
  own ingestion; expensive to retrofit into every tool afterwards.

## Open questions

| # | Question | Blocks |
|---|---|---|
| 1 | Do we recompute metrics from their raw data, or accept theirs? Probably per-metric rather than a global answer | The whole shape of layer 2 |
| 2 | Does holding a customer's operational data change the DPA and residency position? Same question as #251 Q3/Q4 for transcripts, different data | Anything that syncs |
| 3 | What is the smallest coverage set that makes the assistant worth switching on? Which pillars can be missing before it stops being useful? | Roster-by-capability |
| 4 | Is the write path (Phase 3) in or out for a customer-owned source? Writing back into someone else's system of record is a different risk tier entirely | Phase 3 scope for these tenants |
