# Background location tracking (#153 T2)

Background tracking records where a field agent is **while TradeIQ is closed**,
so a manager can see the route they travelled between stores. It is the only
capture in this product that runs with nobody looking at the phone, and it is
built to be bounded, visible and refusable.

It is **Android only**, **off until each agent switches it on**, and it runs
**only inside the client's working hours**.

This page is for whoever operates and answers for the feature. It covers what is
collected, when, how an agent turns it off, how long it is kept, what must be
submitted to the Play Console, and where the legal responsibility sits.

---

## What is different from foreground sharing (#153 T1)

| | Foreground sharing (T1) | Background tracking (T2) |
|---|---|---|
| Runs when | TradeIQ is open and on screen | TradeIQ is open **or closed**, inside working hours |
| Platforms | Android, iOS | **Android only** |
| How often | Every 2 minutes (per client, 60–900s) | Every 10 minutes |
| Consent | The location notice | A **separate** notice with its own acceptance |
| Visible while on | An in-app banner that cannot be dismissed | The same, **plus a permanent phone notification** |
| Can say "at store" | Yes | **No** — see below |
| Kept for | 90 days, then a day summary | The same, unchanged |

Accepting one has never implied the other. They are separate rows on the server
(`location_consents.kind`), separate notice versions, and separate off switches.
Turning background tracking off leaves foreground sharing exactly as it was, and
the reverse is also true.

---

## What is collected

For each point: **latitude, longitude, the GPS accuracy estimate the phone gave,
and the time the phone took the fix.** Nothing else. No speed, no heading, no
altitude, no address, no list of nearby networks, no activity type.

A point is stamped with the moment the *device* took it, never the moment the
server received it — agents work without signal, and points queue on the phone
and arrive late and out of order.

### When, and how often

- Only on a **working day**, between the client's **start and end times**, read
  on the clock of the client's own timezone (`Client.timezone`, #309).
- Defaults to **Monday–Friday, 07:00–17:00**. The end is exclusive: a point
  stamped exactly at 17:00 is outside the window.
- **Every 10 minutes** inside that window — roughly **60 points per agent per
  working day**. Android may deliver a fix sooner when it has a cheap one to
  hand; the app takes those but never more than one per five minutes.
- Nothing at all at night, and nothing at a weekend, unless the client has
  deliberately widened the window.

The window is enforced **twice**. The app starts and stops the service on the
window's edges, using two instants the server resolves in the client's timezone.
The server then re-checks every point on arrival against the same window, so a
phone with a wrong clock, or one holding a stale window, cannot widen it.

### What happens to a point recorded outside working hours

It is **ignored, not stored, and counted** — the `POST /locations` response
reports it as `outsideWorkingHours`. The request itself succeeds.

This is deliberate. A batch is a queue flush, so it routinely straddles the edge
of the window: an agent with no signal all afternoon flushes at 18:30 a queue
holding points from 15:00 onwards plus the one that fired as the window closed.
Rejecting that batch would throw away the legitimate points along with the late
one — and the app deletes a rejected batch outright, so they would be gone for
good. The window is a property of each point's own timestamp, not of the
request, so it can only honestly be judged one point at a time.

Refusal (a 403) is reserved for the one condition that really is about the whole
request: **consent**. A background batch from an agent who has not accepted the
background notice is refused with `background_location_consent_required`, which
is the signal the app acts on to stop the service. That code is specific to the
background notice, so it can never make the app stop foreground sharing too.

### Can a background point say "at store"?

**No.** A background point can read `in_transit` on the manager's map, or
`stale` / `offline` by age. It never reads `at_store` or `near_store`, and it
never names an outlet.

Three reasons:

1. `at_store` is the strongest claim the map makes and a background fix is the
   weakest evidence it has — taken on a ten-minute timer with the phone in a
   pocket, which lets Android answer from a cached or low-power network fix.
   Those routinely land inside the 50 m fence of a shop the agent is only parked
   beside. The 100 m accuracy gate catches many, not all.
2. This tier exists to show *movement between* stores. Presence *in* a store is
   already established twice over — by check-in, and by the foreground heartbeat
   an agent runs while actually working the shelf. A pocketed phone asserting
   the visit would add nothing those two do not already say, while quietly
   lowering the bar for what "at store" means.
3. The same rule governs the day summaries retention writes, so a recorded stop
   continues to mean "somebody was confirmed present" rather than "a phone was
   nearby".

---

## What the agent sees, and how they turn it off

Background tracking starts **off**. It is never switched on for an agent by a
manager, an admin, or a deploy.

1. A quiet line on every agent screen: **"Route tracking is off — tap to see
   what it does."** Not the full notice unasked; the foreground notice is
   already on screen when an agent first signs in, and stacking a second wall of
   text under it is how people learn to tap past both.
2. Tapping opens the **background notice**: what is recorded, how often, that it
   runs with the app closed, the exact hours, that a notification stays up the
   whole time, and that they can stop whenever they like. A clear accept and a
   clear decline.
3. Only **after** they accept does the app ask Android for permission, in
   Android's own two-step order: the ordinary while-in-use prompt first, then
   "Allow all the time". From Android 11 the system will not show a dialog for
   the second step at all, so the app explains it and offers a button to the
   app's settings page. **Refusing leaves everything else in TradeIQ working.**
4. While it runs, two things are always visible: a non-dismissable in-app banner
   ("Recording your route between stores · Working hours only · tap to stop")
   and a **permanent Android notification** that cannot be swiped away. Android
   requires the notification for a location foreground service; it is also the
   honest thing to show, because "am I being tracked right now" must have an
   answer without opening the app.

### Turning it off

Any of these stops it, immediately and completely:

- **Tap the route-tracking banner → "Stop route tracking".** This is a separate
  control from the foreground "Stop sharing", and it stops only background
  tracking. Points still queued on the phone are deleted rather than sent.
- **Log out.** The service is torn down with the session.
- **Revoke "Allow all the time"** in Android settings.
- Outside working hours it stops on its own, and starts again when the window
  next opens.

Stopping does not delete points already sent. Those follow the normal 90-day
retention below — the same rule as everyone else's, which is what makes the
retention promise a promise rather than an exception.

---

## Retention

**Unchanged from #178, and it applies to background points identically.**

- Raw points are kept **90 days**, counted in whole local days of the client's
  own timezone.
- After that a daily job (02:00 SAST) folds each agent-day into a summary and
  deletes the raw points. Background points count towards the day's totals but
  never open a stop, for the same reason they never read "at store".
- A **deactivated agent's raw points are deleted straight away.**
- `npm run prune-location-pings` runs the same job by hand; `--dry-run` counts
  what would go.

---

## Where it is configured

| Setting | Where | Who |
|---|---|---|
| Working hours (start, end, days) | Manager console → Scoring Config → **Working hours** | Manager or admin |
| Client timezone | The panel above it | Manager or admin |
| Background interval (10 min) | `BACKGROUND_PING_INTERVAL_SECONDS`, code | Not runtime-configurable |
| Notice wording | `BACKGROUND_LOCATION_NOTICE_VERSION`, code | See below |

Working hours are **not a shift model and not attendance.** Nothing is scored
against them and no agent is measured by them. They exist only to put an outer
boundary on tracking, and that is the only thing that reads them.

**Changing the notice wording:** bump `BACKGROUND_LOCATION_NOTICE_VERSION` in
`backend/src/modules/locations/locationPolicy.ts` whenever the text changes in a
way an agent should answer again. Every agent is then asked afresh and **nothing
is collected in the background until they answer**. The foreground notice
version is separate and does not move with it.

---

## Play Console: what the owner must submit

**Do this before shipping a build that contains `ACCESS_BACKGROUND_LOCATION`.**
Google reviews background location by hand and rejects builds that ship it
without an approved declaration. A rejection blocks the whole release, not just
the feature.

Play Console → your app → **Policy → App content → Location permissions**.

### Checklist

- [ ] **Confirm the permission is actually in the build.** `ACCESS_BACKGROUND_LOCATION`,
      `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_LOCATION` are declared in
      `app/android/app/src/main/AndroidManifest.xml`.
- [ ] **Which feature uses it.** One feature: showing a manager the route a field
      agent travelled between the stores on their round.
- [ ] **Why foreground access is not enough.** Agents spend most of the working
      day driving between stores with the phone in a pocket or on a cradle and
      the app closed. Foreground-only access produces points at the two ends of
      a journey and nothing in between, which is exactly the part of the day the
      feature is about.
- [ ] **User benefit.** Tick that it is for an enterprise/employee use case, not
      a consumer one. Agents are employees of the TradeIQ customer, working a
      planned route; the feature exists so their manager can dispatch the
      nearest agent and see that a round is running to plan.
- [ ] **Confirm it is not used for ads, analytics or sale of data.** It is not.
      Points are visible only to managers and admins inside the agent's own
      tenant, and are never shared, sold or sent to a third party.
- [ ] **Confirm the in-app disclosure.** Screenshot the background notice
      (the "Recording your route between stores" panel) showing what is
      recorded, how often, that it runs when the app is closed, and the working
      hours. Google requires the disclosure to appear **before** the permission
      prompt, which is the order the app enforces.
- [ ] **Confirm it is optional and revocable.** Screenshot the "Stop route
      tracking" control and note that refusing the permission leaves the rest of
      the app fully working.
- [ ] **Data safety form.** Under **Location → Approximate/Precise location**,
      declare: collected, **not** shared with third parties, processed
      ephemerally = no, **users can request deletion** = yes, collection is
      **optional**. Keep this consistent with the declaration above — an
      inconsistency between the two is a common rejection reason.
- [ ] **Privacy policy URL** must mention background location collection and the
      90-day retention.

### The demo video

Google requires a short video showing the feature in use. Record it on a real
Android device, in English, and upload it to YouTube (unlisted is fine) or
Google Drive with link access — then paste the link into the declaration.

It must show, in this order:

1. Signing in as a field agent.
2. The **"Route tracking is off"** line, and tapping it.
3. The **background notice in full**, readable on screen — pause long enough to
   read it, including the hours and the "even when TradeIQ is closed" sentence.
4. Tapping **"Turn on route tracking"**.
5. The **Android permission prompts**, both steps, including the settings page
   where "Allow all the time" is chosen.
6. The **permanent notification** appearing in the notification shade, with the
   app closed.
7. The manager's map showing the agent moving — this is the "why" shot.
8. Tapping **"Stop route tracking"**, and the notification disappearing.

Keep it under about two minutes. Do not use a simulator, a mock-up or a slide
deck; reviewers reject those.

**Nothing in this repository performs any store submission.** The build and the
manifest are ready; the declaration, the video and the data-safety form are the
owner's to submit.

---

## POPIA

Continuous employee location tracking needs a lawful basis under POPIA, and
**that basis is the business's decision, not this software's.** TradeIQ does not
and cannot make it for them.

What this build provides, and what a customer can rely on when they make that
decision:

- **A notice.** Its own wording, separate from foreground sharing, shown before
  anything is collected and before any permission is requested. It states what
  is recorded, how often, that it runs while the app is closed, in which hours,
  and how to stop it.
- **An acceptance.** Nothing runs until the agent taps accept. Accepting
  foreground sharing does not accept this, in either direction.
- **A record.** Every acceptance and every decline is an append-only row
  (`location_consents`, with its `kind` and the exact notice version the agent
  saw). What an agent agreed to, and when, is never overwritten.
- **A standing, unavoidable indication** that collection is happening: an in-app
  banner that cannot be dismissed and a phone notification that cannot be swiped
  away.
- **A withdrawal that works**, in one tap, without affecting anything else.
- **A bounded window** — working hours only — so the collection is limited to
  the purpose rather than running all day and all night.
- **A retention limit**, 90 days, applied by an automated job, plus immediate
  deletion for a deactivated agent.

What the customer must still do for themselves: identify their lawful basis,
tell their agents about it through their own employment terms or a workplace
policy, appoint and inform their Information Officer, and be able to answer a
data subject request. Set the working hours to the hours the team actually
works — a window wider than the real working day weakens the purpose limitation
that the window exists to provide.

---

## Related

- `backend/src/lib/workingHours.ts` — the window, and why it is half-open
- `backend/src/modules/locations/locationPolicy.ts` — intervals, notice
  versions, and why a background point cannot say "at store"
- `app/lib/core/location/background_location.dart` — the Android service
- `app/ios/Runner/Info.plist` — why iOS is deliberately foreground-only
- `docs/operations/deploy-hardening.md` — #178 retention job in production
