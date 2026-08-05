# Environment Setup

## Prerequisites

- Node.js 24+ — matches the version pinned in `.github/workflows/backend-ci.yml`
- Flutter 3.44+ (stable channel) — matches the version pinned in
  `.github/workflows/app-ci.yml`; the app's `pubspec.yaml` requires Dart SDK
  `^3.12.0`, which ships with Flutter 3.44, so older Flutter installs (e.g.
  3.24) will fail to resolve dependencies. Run `flutter doctor` and confirm no
  blockers for the platforms you'll build for (iOS/Android/web/desktop)
- Docker Desktop (or compatible) — for local Postgres
- GitHub CLI (`gh`) — for opening issues against deferred/stubbed work (see
  `docs/architecture/stubs-and-interfaces.md`)

## Environment variables

Copy the root example env file for the backend:

```bash
cp .env.example backend/.env
```

`DATABASE_URL` and `JWT_SECRET` are read from `backend/.env` by both the
Express server and Prisma CLI. Never commit `backend/.env` — it's covered by
the `.env` entry in `.gitignore`.
