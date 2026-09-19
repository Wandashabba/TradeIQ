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

## `outlets.status`

`active` or `closed`. It keeps a retired store out of planning without deleting
it — deleting would take its visit history with it.

**It does not gate check-in, on purpose.** A store the office believes is
closed but whose shutters an agent is standing in front of must still be
visitable. Adding a second way to strand an agent while fixing the first would
be absurd.

## Evidence photos

A storefront photo offered with a dispute rides the ordinary photo pipeline
against the created visit, under section `pin_dispute`. It does not travel
inside the check-in body: a check-in POST from a shop doorway should carry
coordinates and a sentence, not megabytes, and the photo module already does
the hashing, duplicate detection and GPS tagging this evidence benefits from as
much as any other photo.
