# Repairing a wrong outlet pin, and the override that makes it survivable

Issue #386. Read this before changing any threshold named here.

## The failure it exists for

An outlet's coordinates used to come from exactly one place: the phone's
position at the moment the create-outlet form was submitted. There was no map,
no address lookup and no manual entry, and `outlets.routes.ts` exposed `GET`
and `POST` and nothing else.

So a manager onboarding forty stores during a Monday planning session at the
depot pinned forty stores to the depot car park. On Tuesday an agent standing
inside one of them tapped check in, was told she was 8.4 km away, and had two
buttons: Retry, which measured the same 8.4 km, and Back. Nothing in the
product could correct the number — not that day, not ever.

## The three moving parts

**`PATCH /outlets/:id`** (manager/admin) moves the pin, renames the outlet or
retires it, and writes an `outlet_change_audit` row in the same transaction.
Coordinates have one source and the body says which:

- `lat` + `lng` — typed in. They move together or not at all.
- `fromAttemptId` — "use the agent's recorded position". The coordinates are
  read out of that `CheckInAttempt` row **server-side**, scoped to this tenant
  and this outlet.

Sending both is a `400`, not a precedence rule: a body carrying both could make
the ledger say *moved to the agent's recorded position* beside coordinates that
were never any agent's position.

**`pinDispute` on `POST /visits`** (field agent) is "the pin is wrong". On a
check-in that fails the fence it creates the visit with `geofencePass: false`
and a `pin_disputes` row beside it, in one transaction.

**`GET /outlets/pin-disputes`** (manager/admin) is the queue, open claims first.
Answering one through `PATCH /outlets/:id` with its `disputeId` resolves it:
`applied` when the pin moved, `rejected` when the manager looked and let it
stand.

## Why the override is not a bypass

It is an override on the control that exists to prevent check-in fraud, so it
pays for itself five ways:

1. **It never fakes a pass.** `geofencePass` stays `false`. The value is the
   measurement, not a permission.
2. **The distance is measured server-side.** The device sends its position and
   nothing else — a client-supplied distance is a client-supplied verdict.
3. **The evidence is written in the same transaction as the visit.** A visit
   outside the fence with no dispute row beside it cannot exist. The outlet's
   pin is frozen onto the row as it read at the time, so a claim reviewed after
   the correction still shows what the agent was arguing with.
4. **The fraud engine scores it.** `geofence_override`, weight 30 — see below.
5. **Nobody grants their own.** Resolving means moving a pin, and `PATCH` is
   manager/admin only. A field agent gets `403`.

## What an operator configures

Both live in `Client.kpiThresholds`, editable at runtime through
`PATCH /clients/me`, and both fall back to the built-in default when absent.

| Key | Default | What it does |
| --- | --- | --- |
| `pinDisputeMaxDistanceM` | `25000` (25 km) | The furthest an agent may be from a pin and still claim the PIN is what is wrong. Beyond it the check-in is refused `422`, with the limit named. |
| `pinDisputeDailyCap` | `3` | How many claims one agent may open in one CLIENT-LOCAL day. Past it the check-in is refused `429`, naming the manager's queue. Zero or negative is read as a typo and falls back — *no agent may ever report a wrong pin* reinstates the bug this feature exists for. |

**Raise it carefully and lower it more carefully.** The default is deliberately
generous, because the failure it exists for is generous: #386's own case is a
store pinned to a depot 8.4 km away, and a tenant whose depot sits on the far
side of a metro can easily be further. Lowering it to something tidy-looking
recreates the bug — an agent standing in a real shop, told no, with nothing to
press. The bound is there to separate *the office pinned this store to the
wrong place in this city* from *this phone is in a different province from the
shop it says it is standing in*, which is not a pin error.

The rejected `CheckInAttempt` row is written either way, so a run of refused
overrides is as visible to the fraud engine as a run of ordinary retries.

**Raise `pinDisputeDailyCap` for a tenant whose data really is that broken.**
The depot-onboarding case puts several wrongly pinned outlets on one beat,
which is why the default is not one. An agent filing a fourth in a day is
either working a beat that needs a bulk fix from the office or is not where
they say they are, and both want a person rather than a score.

## The bounds on the override itself

The distance cap bounds ONE claim. These bound the pattern, and they exist
because scoring each visit alone could never see it: an agent sitting at home
is inside 25 km of every outlet in their metro, and ten claims, one per outlet,
each scored 30, reached no manager at all while every visit earned its points.

**One claim per pin per day.** A second wrong-pin check-in by the same agent at
the same outlet on the same client-local day is a `409` naming the visit that
already exists, whether the first is still open or has been answered. A POST
without a `clientVisitId` is deduplicated by nothing, so one failed position
could otherwise be replayed into any number of visits, disputes and
submitted-visit counts.

**Three claims per agent per day** (`pinDisputeDailyCap`), refused `429`.

**A storefront photo must come from the camera.** `POST /photos` carries an
optional `source` (`camera` or `gallery`); for section `pin_dispute` it is
required to be `camera`, the claim must still be open, and the upload must
arrive within a day of the claim's server `created_at`. A photo's `timestamp`
and `gpsTag` are stamped when the picker hands the file back, so a gallery pick
carries the moment it was PICKED — a Street View screenshot chosen at home
arrives with a fresh time and a home tag that agree with the claim perfectly
and say nothing about the shop. The dispute view returns the photo's server
`createdAt` and `source` beside the device's own account, and the console shows
both.

**A mocked or coarse fix cannot become a pin.** `POST /visits` accepts optional
`accuracyM` and `isMocked` from the device; they are recorded on the
`CheckInAttempt` and on the claim and can never make a failing check-in pass.
`PATCH /outlets/:id` with `fromAttemptId` refuses (`400`) an attempt the
platform reported as mocked, or one whose reported accuracy is worse than
100 m: adopting a position moves the fence, and a fix good to ±500 m cannot say
where a shop's door is. An attempt that reports NO accuracy is still adoptable
— an older handset must not lock a manager out of fixing a pin — and is shown
as unknown rather than as fine.

**The ledger names the source.** An `agent_position` change records
`from_attempt_id` and `from_agent_id`, so *whose phone* can be asked later. The
dispute view also carries `agentIsOnlyVisitor`: true when the reporting agent
is the only person who has ever visited that outlet, so nobody else's check-ins
could disagree with a pin moved onto their position. A warning, never a
refusal — a genuinely new store has exactly one visitor too.

## The fraud weight, and why it is 30

`geofence_override` **replaces** the borderline `geofence_distance` signal
rather than stacking with it. A visit cannot both hug the fence edge and be
outside it, and charging for both would put every honest override at 50 — the
default review threshold — on geofence evidence alone.

At 30 it accuses nobody by itself and corroborates everything. Combined with a
photo whose GPS diverges, a run of earlier failed attempts, or stock logged
inside a different store, it carries the visit over easily, which is exactly
when an override deserves a second look.

Raising it above the client's review threshold would make every honest use of
the override a suspected fraud case, and a queue full of the ordinary case is a
queue managers stop reading — which is how the flagged visit that mattered goes
unread. The manager's real queue for these is
`GET /outlets/pin-disputes`, where the claim arrives with its evidence whatever
the score says.

### The three signals that read the claim, not just the visit

Thirty stays thirty. What changed is that it is no longer the only thing the
engine has to say about an override. All three read the `pin_disputes` row, and
deliberately by its SERVER `created_at` rather than the device's `checkinTs`:
the whole attack is a device asserting things, and a backdated timestamp would
otherwise walk straight out of a device-timed window.

| Signal | Weight | Fires when |
| --- | --- | --- |
| `geofence_override_rejected` | 55 | A manager answered the claim with *the pin stands*. **Replaces** `geofence_override`. |
| `geofence_override_rate` | 10 per claim past the first, capped at 40 | The agent made several claims in the 7 days ending at this one. |
| `geofence_override_cluster` | 30 | Claims about DIFFERENT outlets were made from within 100 m of each other. |

`geofence_override_rejected` is above the review threshold on its own, and
`PATCH /outlets/:id` re-scores the visit in the same request that rules on the
claim, so a rejection puts the visit into `GET /fraud/flagged` immediately
rather than at the next nightly rescore. Before this, a manager's finding that
the agent was not at the shop changed nothing about the visit at all: same
score, same queue, same points.

The rate signal leaves one report alone — that is the ordinary case this
feature exists for — and carries the third over the threshold with the base 30.
The cluster signal fires on the SECOND claim, because one position cannot be
standing in two shops, and that is the home attack's actual signature.

## `outlets.status`

`active` or `closed`. It keeps a retired store out of planning without deleting
it — deleting would take its visit history with it.

**It does not gate check-in, on purpose.** A store the office believes is
closed but whose shutters an agent is standing in front of must still be
visitable. Adding a second way to strand an agent while fixing the first would
be absurd.

## What the agent sees

On the too-far screen, under the distance and below *Try again*, sits a quiet
third action: **The pin is wrong**. It opens a report that lists what goes with
it — the distance and the position the failed check-in measured, not a second
fix taken later — takes an optional note and an optional storefront photo, and
says in words that the visit starts outside the fence, stays flagged, and is not
the agent's to clear. *Start the visit, flagged* writes the local draft with
`geofencePass: false` and queues `POST /visits` with `pinDispute`.

The hub then carries two neutral flag chips — **Out of fence · 180 m** and
**Pin reported** — each opening a sheet that says what the manager sees. They
are never crimson: out of fence is a measurement and a report is a claim, not a
verdict.

The capture for that photo offers the camera only. Everywhere else in the app
the gallery sits beside it deliberately — a cracked camera in a dark aisle
still has to be able to file evidence — but here the picture IS the claim, the
server refuses a gallery image for this section, and a button that is not there
is kinder than an error after the work.

Beyond 25 km the action is replaced by a sentence telling the agent to ask their
manager. The app mirrors the server's *default* cap only so it does not offer a
claim the default would refuse: a queued check-in the server rejects would
strand the whole visit behind it. A tenant that lowers
`pinDisputeMaxDistanceM` below 25 km should know that an agent between the two
numbers can still file, and that the check-in will then be refused on sync.

## Evidence photos

A storefront photo offered with a dispute rides the ordinary photo pipeline
against the created visit, under section `pin_dispute`. It does not travel
inside the check-in body: a check-in POST from a shop doorway should carry
coordinates and a sentence, not megabytes, and the photo module already does
the hashing, duplicate detection and GPS tagging this evidence benefits from as
much as any other photo.
