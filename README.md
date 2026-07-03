# TradeIQ

Multi-industry trade marketing & field intelligence platform — OMS, audit
app, and AI-assisted compliance scoring, configurable per client/industry.
Phase 1 targets FMCG demo data on an industry-agnostic architecture.

## Repo layout

- `app/` — Flutter (mobile field-agent audit flow + web manager/admin dashboard)
- `backend/` — Node.js + Express + TypeScript + Prisma/PostgreSQL API
- `docs/` — architecture, ADRs, onboarding, API reference
- `scripts/` — dev tooling (currently: `backend/scripts/seed.ts` demo data)

## Getting started

```bash
make setup   # one-time: docker up, npm install, migrate, seed
make dev     # starts Postgres + backend dev server
make app     # (separate terminal) flutter pub get + flutter run -d chrome
```

Run `make help` for the full list of targets. See
[`docs/onboarding/getting-started.md`](docs/onboarding/getting-started.md)
for what each step does under the hood, plus troubleshooting.

## Architecture

See [`docs/architecture/overview.md`](docs/architecture/overview.md) and
[`docs/architecture/stubs-and-interfaces.md`](docs/architecture/stubs-and-interfaces.md)
for what's real vs. stubbed in Phase 1.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md).
