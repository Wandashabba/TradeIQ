# Getting Started

Clone, run, and see real data in under 10 minutes.

## The fast path: Makefile

```bash
make setup      # one-time: docker up, npm install, migrate, seed
make dev        # starts Postgres (waits for healthy) + backend dev server
```

Then in a second terminal:

```bash
make app        # flutter pub get + flutter run -d chrome
```

If you have more than one Flutter SDK on your machine and `flutter --version`
doesn't resolve to 3.44+, override the binary per-command instead of editing
your shell's `PATH`:

```bash
make app FLUTTER=/path/to/flutter-3.44/bin/flutter
```

Run `make help` to see every target (`test`, `backend-test`, `app-test`,
`stop`, `restart`). The rest of this doc explains what those targets do
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

`npm run seed` seeds a demo FMCG client, two demo users, three outlets, and
one SKU, and prints a confirmation line, e.g.:

```
Seeded client Demo FMCG Brand, manager manager@demo-fmcg.tradeiq.com, 3 outlets, 1 SKU
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
flutter run -d chrome   # or an attached device/simulator
```

The app boots to the login screen (`/login`). The login screen and the
login-to-outlets navigation are not wired up yet — there's no form on that
screen, and the router doesn't redirect to an authenticated route on success
(see `docs/architecture/stubs-and-interfaces.md` for what's scaffolded vs.
what's a follow-up).

To see the proof-of-concept vertical slice (outlets list backed by a real
`GET /outlets` call) working end-to-end today, without waiting on that
follow-up work, you have two options:

- **Fastest / no code changes:** run the existing widget test, which drives
  `OutletsListScreen` against a fake repository and asserts it renders
  outlet data: `flutter test test/features/outlets/outlets_list_screen_test.dart`.
- **Against the real backend:** the app keeps its bearer token in a
  top-level `currentAuthToken` variable in
  `app/lib/core/network/api_client.dart` (there's no UI for setting it yet).
  Temporarily set `currentAuthToken` to the token from the `curl
  /auth/login` call above (e.g. hardcode it in `main.dart` before
  `runApp`), then run the app and navigate to `/outlets` in the browser
  address bar (for the Chrome build). Revert the hardcoded token before
  committing — full login-to-outlets wiring is tracked as follow-up work,
  not part of this scaffold. Tracked as
  [issue #5](https://github.com/Wandashabba/TradeIQ/issues/5).

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
- **`flutter: command not found`** — install Flutter and ensure it's on your
  `PATH`; run `flutter doctor` to verify.
- **`flutter pub get` fails to resolve dependencies** (`requires SDK version
  ^3.12.0`) — you likely have an older Flutter earlier in your `PATH`. Check
  with `which flutter && flutter --version`. If it's not 3.44+, either
  reorder your `PATH` or, without touching global config, invoke a specific
  install directly (or via `make app FLUTTER=/path/to/flutter`):
  `/path/to/flutter-3.44/bin/flutter pub get`.
