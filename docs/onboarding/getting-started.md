# Getting Started

Clone, run, and see real data in under 10 minutes.

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
  not part of this scaffold.

## 4. Run the test suites

```bash
cd backend && npm test
cd app && flutter test
```

## Troubleshooting

- **`P1001: Can't reach database server`** — Postgres isn't up yet; run
  `docker compose ps` and check the `postgres` service is `healthy`.
- **`flutter: command not found`** — install Flutter and ensure it's on your
  `PATH`; run `flutter doctor` to verify.
- **`flutter pub get` fails to resolve dependencies** — check your Flutter
  version is 3.44+ (`flutter --version`); the app's Dart SDK constraint
  (`^3.12.0`) isn't satisfied by older Flutter releases.
