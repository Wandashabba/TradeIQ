# Onboarding

Welcome to TradeIQ. Start here, in order:

1. [`docs/onboarding/environment-setup.md`](docs/onboarding/environment-setup.md) — install prerequisites
2. [`docs/onboarding/getting-started.md`](docs/onboarding/getting-started.md) — clone → running in under 10 minutes
3. [`docs/architecture/overview.md`](docs/architecture/overview.md) — how the pieces fit together
4. [`docs/architecture/data-model.md`](docs/architecture/data-model.md) — the Postgres schema
5. [`docs/architecture/stubs-and-interfaces.md`](docs/architecture/stubs-and-interfaces.md) — what's real vs. stubbed, and why
6. [`docs/adr/`](docs/adr/) — why key decisions were made (Flutter for mobile+web, lean Phase 1 infra, Node/Express, Riverpod, offline-first Drift sync, Prisma)
7. [`CONTRIBUTING.md`](CONTRIBUTING.md) — how to add a module/feature, commit style, PR checks
8. [`docs/onboarding/release-builds.md`](docs/onboarding/release-builds.md) — release signing and building for a real device

Then look at `backend/src/modules/outlets/` and `app/lib/features/outlets/`
— the one fully-wired vertical slice — as the template for building out the
remaining S1–S10 sections in follow-up plans.
