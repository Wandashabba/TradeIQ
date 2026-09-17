# Getting Started

Clone, run, and see real data in under 10 minutes.

## The fast path: Makefile

```bash
make setup      # one-time: docker up, npm install, migrate, seed
make dev        # starts Postgres (waits for healthy) + backend dev server
```

Then in a second terminal:

```bash
make app        # pub get + build_runner codegen + flutter run -d chrome
```

If you have more than one Flutter SDK on your machine and `flutter --version`
doesn't resolve to 3.44+, override the binary per-command instead of editing
your shell's `PATH`. Pass `DART` alongside it, so codegen runs on the same
SDK:

```bash
make app FLUTTER=/path/to/flutter-3.44/bin/flutter DART=/path/to/flutter-3.44/bin/dart
```

Run `make help` to see every target (`codegen`, `test`, `backend-test`,
`app-test`, `stop`, `restart`). The rest of this doc explains what those targets do
under the hood — useful if something goes wrong, or you want to run a step
manually.

## 1. Start Postgres

```bash
docker compose up -d
```

## 2. Backend

```bash
cd backend
npm install
npx prisma migrate deploy
npm run seed
npm run dev
```

The API is now running at `http://localhost:4000`. Confirm with:

```bash
curl http://localhost:4000/health
# {"status":"ok"}
```

`npm run seed` builds the full demo dataset — one client (Kalahari
Beverages), 13 territories across seven provinces, 50 field agents, 400
outlets, 20 SKUs and 24 months of history ending yesterday: about 140k visits
with every audit section, sell-in orders, monthly sales targets, campaigns,
contests, beat plans, tasks with SLAs, alerts and stored fraud scores. It
deletes and rebuilds the demo client's data, takes several minutes, and prints
a summary with per-phase timings.

The data carries deliberate, discoverable problems (a declining territory, a
chronic out-of-stock, an overpricing chain, a ghost-visit agent and more) for
testing Ask TradeIQ; `docs/testing/ask-tradeiq-questions.md` lists them with
questions and expected answers.

The calendar is anchored to the day you seed, so dates move with it. To
rebuild exactly the dataset the test questions quote, pin the anchor:

```bash
SEED_ANCHOR_DATE=2026-09-17 npm run seed
```

`SEED_PROFILE=test npm run seed` builds a small three-month version in seconds.

The seed also creates a **home-base outlet** for testing a live geofenced
check-in. It defaults to central Johannesburg; set both `DEMO_HOME_LAT` and
`DEMO_HOME_LNG` to seed it where you actually are, or the 50m geofence will
reject you:

```bash
DEMO_HOME_LAT=-26.1076 DEMO_HOME_LNG=28.0567 npm run seed
```

Log in as the seeded demo manager:

```bash
curl -X POST http://localhost:4000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"manager@demo-fmcg.tradeiq.com","password":"demo-password-123"}'
```

This returns a JWT (`{"token":"...","role":"manager"}`). There's also a
seeded field agent at `agent@demo-fmcg.tradeiq.com` with the same password.

## 3. App

In a second terminal:

```bash
cd app
flutter pub get
dart run build_runner build   # REQUIRED on a fresh clone — see below
flutter run -d chrome         # or an attached device/simulator
```

**Do not skip the `build_runner` step.** Drift's generated database code
(`*.g.dart`) is gitignored, so a fresh clone has none of it and the app will
not compile — you get a wall of `The method 'select' isn't defined for the
type 'LocalDb'` errors ending in `Failed to compile application`. `make app`
and `make app-test` run it for you; the manual path does not.

The app boots to the login screen (`/login`), which has a working form.
Sign in with a seeded account (see `backend/scripts/seed.ts` — e.g.
`agent@demo-fmcg.tradeiq.com` / `demo-password-123` for a field agent, or
`manager@demo-fmcg.tradeiq.com` for a manager). On success the router
redirects by role: field agents land on the audit outlet-picker (`/audit`),
managers/admins on the dashboard (`/dashboard`). The session is persisted, so
a restart keeps you logged in until you log out.

From there a field agent can run the full S1-S10 offline-first audit flow
(check-in → capture → submit); a manager sees the 8-KPI dashboard and the
task list (`/tasks`). Run `npm run seed` in `backend/` first so the dashboard
has demo visits/scorecards to show.

To point the app at a non-local backend, pass
`--dart-define=API_BASE_URL=https://your-host` to `flutter run`.

## 4. Run the test suites

```bash
cd backend && npm test
cd app && flutter test
```

## Troubleshooting

- **`P1001: Can't reach database server`** — Postgres isn't up yet; run
  `docker compose ps` and check the `postgres` service is `healthy`.
- **Still `P1001` even though `docker compose ps` shows the container
  running/healthy** — the container may have been created without its port
  actually bound to the host (this happens if an earlier `docker compose up`
  failed partway through, e.g. because port 5432 was already taken by
  another Postgres). Check with `docker port tradeiq-postgres-1` — if it
  prints nothing, force a clean recreate:
  `docker compose down && docker compose up -d --force-recreate`.
- **`Bind for 0.0.0.0:5432 failed: port is already allocated`** — something
  else on your machine is already using 5432 (often another project's
  Postgres, or a stale container from an old worktree of this repo). Find it
  with `docker ps --format 'table {{.Names}}\t{{.Ports}}'` and stop it
  (`docker stop <name>`), then retry.
- **`The method 'select' isn't defined for the type 'LocalDb'`** (or
  `syncQueueItems` / `transaction`), ending in `Failed to compile
  application` — Drift's generated code is missing. `*.g.dart` is gitignored,
  so a fresh clone never has it. Run `cd app && dart run build_runner build`,
  or just use `make app`, which now does it for you.
- **`flutter: command not found`** — install Flutter and ensure it's on your
  `PATH`; run `flutter doctor` to verify.
- **`flutter pub get` fails to resolve dependencies** (`requires SDK version
  ^3.12.0`) — you likely have an older Flutter earlier in your `PATH`. Check
  with `which flutter && flutter --version`. If it's not 3.44+, either
  reorder your `PATH` or, without touching global config, invoke a specific
  install directly (or via `make app FLUTTER=/path/to/flutter`):
  `/path/to/flutter-3.44/bin/flutter pub get`.
