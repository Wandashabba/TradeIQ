# Contributing

## Commit style

Use [Conventional Commits](https://www.conventionalcommits.org/):
`feat(scope): ...`, `fix(scope): ...`, `docs: ...`, `chore: ...`, `ci: ...`.
Scope is usually `app` or `backend`.

## Before opening a PR

```bash
make test          # both suites
make backend-test  # backend/: npm run lint && npm test
make app-test      # app/: flutter analyze && flutter test
```

Both run in CI on every PR (`.github/workflows/backend-ci.yml` and
`.github/workflows/app-ci.yml`) — fix failures locally first.

## Adding a new backend module

Follow the shape of `backend/src/modules/outlets/` (the one fully-wired
example): `<module>.service.ts` for Prisma queries, `<module>.routes.ts` for
Express routes guarded by `requireAuth`, wired into `backend/src/app.ts`.

## Adding a new Flutter feature

Follow the shape of `app/lib/features/outlets/`: a `data/` repository
behind an abstract interface (for testability via fakes), a `presentation/`
screen consuming a Riverpod provider.

## Introducing a Phase 2+ capability

If you're building something the scaffold stubbed (CV, OCR, fraud,
dispatch, Kafka, PostGIS, Redis), start from its entry in
`docs/architecture/stubs-and-interfaces.md` and its linked GitHub issue.
Replace the `.stub.ts` file's implementation behind the same interface
so callers don't need to change.

## Database schema changes

Edit `backend/prisma/schema.prisma`, then run
`npx prisma migrate dev --name <description>` from `backend/`. Never
hand-edit generated migration files.
