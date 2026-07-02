# TradeIQ Scaffold Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scaffold the TradeIQ monorepo — repo structure, tooling, CI, backend (Node/Express/TS/Prisma) with auth + one proof-of-concept resource + all module skeletons + stubbed Phase-2 services, Flutter app shell (theme/router/offline sync) with a matching proof-of-concept vertical slice, and a complete documentation system — so a new teammate can clone, run, and start building the S1–S10 audit flow feature-by-feature in follow-up plans.

**Architecture:** Monorepo with `app/` (Flutter, mobile+web, Riverpod, Drift offline sync), `backend/` (Node/Express/TypeScript, Prisma+Postgres, JWT auth), `docs/` (markdown, ADRs), `scripts/` (seed data). Real logic (geofence haversine, SLA due-date clock, stock coverage-days formula, JWT auth) ships working; CV/OCR/fraud/dispatch ship as stubs behind interfaces with linked GitHub issues. `outlets` is the one fully-wired vertical slice (backend CRUD + integration test + Flutter list screen + widget test) proving the whole stack end-to-end; all other S1–S10 modules are skeletons only, per spec §11.

**Tech Stack:** Flutter (Riverpod, go_router, Drift), Node.js + Express + TypeScript, Prisma + PostgreSQL, JWT, Docker Compose, GitHub Actions, Jest + Supertest, flutter_test.

**Spec:** `docs/superpowers/specs/2026-07-02-tradeiq-scaffold-design.md`

---

## Track A — Repo scaffold & tooling

### Task 1: Root repo skeleton & gitignore

**Files:**
- Create: `.gitignore`
- Create: `app/.gitkeep`, `backend/.gitkeep`, `scripts/.gitkeep`, `.github/.gitkeep`

- [ ] **Step 1: Create root `.gitignore`**

```
# Node
node_modules/
dist/
*.log
.env

# Flutter
app/.dart_tool/
app/.flutter-plugins
app/.flutter-plugins-dependencies
app/build/
app/.packages
app/**/generated_plugin_registrant.dart

# IDE
.vscode/
.idea/
*.iml

# OS
.DS_Store
```

- [ ] **Step 2: Create placeholder directories**

```bash
mkdir -p app backend scripts .github/workflows .github/ISSUE_TEMPLATE
touch app/.gitkeep backend/.gitkeep scripts/.gitkeep .github/.gitkeep
```

- [ ] **Step 3: Verify structure**

Run: `find . -maxdepth 2 -not -path '*/.git*'`
Expected: shows `app/`, `backend/`, `docs/`, `scripts/`, `.github/`, `.gitignore`

- [ ] **Step 4: Commit**

```bash
git add .gitignore app/.gitkeep backend/.gitkeep scripts/.gitkeep .github/.gitkeep
git commit -m "chore: scaffold root repo structure"
```

---

### Task 2: Docker Compose for local Postgres

**Files:**
- Create: `docker-compose.yml`
- Create: `.env.example`

- [ ] **Step 1: Create `docker-compose.yml`**

```yaml
services:
  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: tradeiq
      POSTGRES_PASSWORD: tradeiq_dev
      POSTGRES_DB: tradeiq
    ports:
      - "5432:5432"
    volumes:
      - tradeiq_pg_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U tradeiq"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  tradeiq_pg_data:
```

- [ ] **Step 2: Create `.env.example`**

```
DATABASE_URL="postgresql://tradeiq:tradeiq_dev@localhost:5432/tradeiq?schema=public"
JWT_SECRET="dev-only-change-me"
PORT=4000
```

- [ ] **Step 3: Start Postgres and verify it's healthy**

Run: `docker compose up -d && sleep 3 && docker compose ps`
Expected: `postgres` service shows state `running (healthy)`

- [ ] **Step 4: Commit**

```bash
git add docker-compose.yml .env.example
git commit -m "chore: add docker-compose Postgres for local dev"
```

---

### Task 3: Backend project init (Express + TypeScript + health check)

**Files:**
- Create: `backend/package.json`, `backend/tsconfig.json`, `backend/.eslintrc.cjs`
- Create: `backend/src/app.ts`, `backend/src/server.ts`
- Test: `backend/src/app.test.ts`

- [ ] **Step 1: Init npm project and install dependencies**

```bash
cd backend
npm init -y
npm install express dotenv
npm install -D typescript ts-node-dev @types/express @types/node \
  jest ts-jest @types/jest supertest @types/supertest \
  eslint @typescript-eslint/parser @typescript-eslint/eslint-plugin
```

- [ ] **Step 2: Create `backend/tsconfig.json`**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "moduleResolution": "node",
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "resolveJsonModule": true
  },
  "include": ["src"]
}
```

- [ ] **Step 3: Create `backend/.eslintrc.cjs`**

```js
module.exports = {
  parser: '@typescript-eslint/parser',
  plugins: ['@typescript-eslint'],
  extends: ['eslint:recommended', 'plugin:@typescript-eslint/recommended'],
  env: { node: true, jest: true },
  parserOptions: { ecmaVersion: 2022, sourceType: 'module' },
};
```

- [ ] **Step 4: Add scripts to `backend/package.json`**

Edit the generated `package.json` to include:

```json
{
  "name": "tradeiq-backend",
  "version": "0.1.0",
  "scripts": {
    "dev": "ts-node-dev --respawn src/server.ts",
    "build": "tsc",
    "start": "node dist/server.js",
    "test": "jest",
    "lint": "eslint src --ext .ts"
  }
}
```

- [ ] **Step 5: Create `backend/jest.config.js`**

```js
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
};
```

- [ ] **Step 6: Write the failing test for the health check**

```ts
// backend/src/app.test.ts
import request from 'supertest';
import { app } from './app';

describe('GET /health', () => {
  it('returns 200 with status ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok' });
  });
});
```

- [ ] **Step 7: Run test to verify it fails**

Run: `cd backend && npx jest app.test.ts`
Expected: FAIL — cannot find module `./app`

- [ ] **Step 8: Create `backend/src/app.ts`**

```ts
import express from 'express';

export const app = express();

app.use(express.json());

app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok' });
});
```

- [ ] **Step 9: Create `backend/src/server.ts`**

```ts
import 'dotenv/config';
import { app } from './app';

const port = process.env.PORT ? Number(process.env.PORT) : 4000;

app.listen(port, () => {
  console.log(`TradeIQ backend listening on port ${port}`);
});
```

- [ ] **Step 10: Run test to verify it passes**

Run: `cd backend && npx jest app.test.ts`
Expected: PASS

- [ ] **Step 11: Commit**

```bash
git add backend/package.json backend/package-lock.json backend/tsconfig.json \
  backend/.eslintrc.cjs backend/jest.config.js backend/src/app.ts \
  backend/src/server.ts backend/src/app.test.ts
git commit -m "feat(backend): scaffold Express+TS app with health check"
```

---

### Task 4: Prisma schema — full data model + initial migration

**Files:**
- Create: `backend/prisma/schema.prisma`
- Modify: `backend/package.json` (add prisma scripts)

- [ ] **Step 1: Install Prisma**

```bash
cd backend
npm install @prisma/client
npm install -D prisma
npx prisma init --datasource-provider postgresql
```

This creates `backend/prisma/schema.prisma` and `backend/.env` — delete the
generated `.env` (already covered by root `.env.example`) and instead copy
root `.env.example` to `backend/.env` for local dev:

```bash
rm -f backend/.env
cp ../.env.example backend/.env
```

- [ ] **Step 2: Replace `backend/prisma/schema.prisma` with the full data model**

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

enum UserRole {
  field_agent
  manager
  admin
}

enum VisitStatus {
  in_progress
  submitted
}

enum TaskPriority {
  critical
  high
  normal
}

enum TaskStatus {
  open
  in_progress
  closed
}

model Client {
  id               String   @id @default(uuid())
  name             String
  industry         String
  scorecardWeights Json     @map("scorecard_weights")
  kpiThresholds    Json     @map("kpi_thresholds")
  users            User[]
  outlets          Outlet[]
  skus             Sku[]
  planogramTemplates PlanogramTemplate[]
  promoCalendar    PromoCalendar[]
  visits           Visit[]

  @@map("clients")
}

model User {
  id           String   @id @default(uuid())
  email        String   @unique
  passwordHash String   @map("password_hash")
  role         UserRole
  clientId     String   @map("client_id")
  client       Client   @relation(fields: [clientId], references: [id])
  visits       Visit[]
  tasksOwned   Task[]

  @@map("users")
}

model Outlet {
  id          String   @id @default(uuid())
  name        String
  code        String   @unique
  channelType String   @map("channel_type")
  lat         Float
  lng         Float
  territoryId String   @map("territory_id")
  teamProfile Json     @map("team_profile")
  clientId    String   @map("client_id")
  client      Client   @relation(fields: [clientId], references: [id])
  visits      Visit[]
  tasks       Task[]

  @@map("outlets")
}

model Sku {
  id                  String   @id @default(uuid())
  clientId            String   @map("client_id")
  client              Client   @relation(fields: [clientId], references: [id])
  name                String
  category            String
  minFacingsStandard  Int      @map("min_facings_standard")
  rrp                 Float

  @@map("skus")
}

model PlanogramTemplate {
  id       String @id @default(uuid())
  clientId String @map("client_id")
  client   Client @relation(fields: [clientId], references: [id])
  zoneMap  Json   @map("zone_map")

  @@map("planogram_templates")
}

model PromoCalendar {
  id           String   @id @default(uuid())
  clientId     String   @map("client_id")
  client       Client   @relation(fields: [clientId], references: [id])
  promoName    String   @map("promo_name")
  activeFrom   DateTime @map("active_from")
  activeTo     DateTime @map("active_to")
  requiredPosm Json     @map("required_posm")
  outletScope  Json     @map("outlet_scope")

  @@map("promo_calendar")
}

model Visit {
  id            String      @id @default(uuid())
  outletId      String      @map("outlet_id")
  outlet        Outlet      @relation(fields: [outletId], references: [id])
  agentId       String      @map("agent_id")
  agent         User        @relation(fields: [agentId], references: [id])
  clientId      String      @map("client_id")
  client        Client      @relation(fields: [clientId], references: [id])
  checkinTs     DateTime    @map("checkin_ts")
  checkinLat    Float       @map("checkin_lat")
  checkinLng    Float       @map("checkin_lng")
  geofencePass  Boolean     @map("geofence_pass")
  status        VisitStatus @default(in_progress)

  stock        VisitStock[]
  visibility   VisitVisibility?
  pricing      VisitPricing[]
  competitive  VisitCompetitive[]
  capability   VisitCapability?
  risks        VisitRisk[]
  tasks        Task[]
  photos       Photo[]
  scorecard    Scorecard?

  @@map("visits")
}

model VisitStock {
  id                     String   @id @default(uuid())
  visitId                String   @map("visit_id")
  visit                  Visit    @relation(fields: [visitId], references: [id])
  skuId                  String   @map("sku_id")
  unitsAvailable         Int      @map("units_available")
  lastStockinDate        DateTime @map("last_stockin_date")
  daysOutOfStock         Int      @map("days_out_of_stock")
  velocityAvg            Float    @map("velocity_avg")
  coverageDaysPredicted  Float    @map("coverage_days_predicted")
  salesActual            Float    @map("sales_actual")
  salesTarget            Float    @map("sales_target")

  @@map("visit_stock")
}

model VisitVisibility {
  id                       String  @id @default(uuid())
  visitId                  String  @unique @map("visit_id")
  visit                    Visit   @relation(fields: [visitId], references: [id])
  brandingElements         Json    @map("branding_elements")
  planogramCompliancePct   Float   @map("planogram_compliance_pct")
  facingsCount             Json    @map("facings_count")
  highTrafficPass          Boolean @map("high_traffic_pass")
  cleanlinessScore         Int     @map("cleanliness_score")

  @@map("visit_visibility")
}

model VisitPricing {
  id                       String  @id @default(uuid())
  visitId                  String  @map("visit_id")
  visit                    Visit   @relation(fields: [visitId], references: [id])
  skuId                    String  @map("sku_id")
  priceActual              Float   @map("price_actual")
  priceMaster              Float   @map("price_master")
  deviationPct             Float   @map("deviation_pct")
  promoActive              Boolean @map("promo_active")
  promoMaterialsDetected   Json    @map("promo_materials_detected")
  commsRating              Int     @map("comms_rating")

  @@map("visit_pricing")
}

model VisitCompetitive {
  id                       String  @id @default(uuid())
  visitId                  String  @map("visit_id")
  visit                    Visit   @relation(fields: [visitId], references: [id])
  competitorSku            String  @map("competitor_sku")
  competitorPrice          Float   @map("competitor_price")
  competitorPosmType       String  @map("competitor_posm_type")
  competitorPromoterPresent Boolean @map("competitor_promoter_present")
  geotag                   Json

  @@map("visit_competitive")
}

model VisitCapability {
  id                        String @id @default(uuid())
  visitId                   String @unique @map("visit_id")
  visit                     Visit  @relation(fields: [visitId], references: [id])
  staffHeadcountConfirmed   Int    @map("staff_headcount_confirmed")
  repTrainingStatus         Json   @map("rep_training_status")
  quizScore                 Int    @map("quiz_score")

  @@map("visit_capability")
}

model VisitRisk {
  id        String @id @default(uuid())
  visitId   String @map("visit_id")
  visit     Visit  @relation(fields: [visitId], references: [id])
  flagType  String @map("flag_type")
  severity  String
  note      String

  @@map("visit_risks")
}

model Task {
  id                String       @id @default(uuid())
  visitId           String?      @map("visit_id")
  visit             Visit?       @relation(fields: [visitId], references: [id])
  findingType       String       @map("finding_type")
  outletId          String       @map("outlet_id")
  outlet            Outlet       @relation(fields: [outletId], references: [id])
  requiredFix       String       @map("required_fix")
  priority          TaskPriority
  slaDueAt          DateTime     @map("sla_due_at")
  ownerId           String       @map("owner_id")
  owner             User         @relation(fields: [ownerId], references: [id])
  status            TaskStatus   @default(open)
  closurePhotoUrl   String?      @map("closure_photo_url")
  closureVerified   Boolean      @default(false) @map("closure_verified")

  @@map("tasks")
}

model Photo {
  id        String   @id @default(uuid())
  visitId   String   @map("visit_id")
  visit     Visit    @relation(fields: [visitId], references: [id])
  section   String
  url       String
  gpsTag    Json     @map("gps_tag")
  timestamp DateTime

  @@map("photos")
}

model Scorecard {
  id              String @id @default(uuid())
  visitId         String @unique @map("visit_id")
  visit           Visit  @relation(fields: [visitId], references: [id])
  dimensionScores Json   @map("dimension_scores")
  weightedTotal   Float  @map("weighted_total")
  ratingBand      String @map("rating_band")

  @@map("scorecards")
}
```

- [ ] **Step 3: Add Prisma scripts to `backend/package.json`**

```json
{
  "scripts": {
    "prisma:migrate": "prisma migrate dev",
    "prisma:generate": "prisma generate"
  }
}
```

- [ ] **Step 4: Run the initial migration against the dockerized Postgres**

Run: `cd backend && npx prisma migrate dev --name init`
Expected: `Your database is now in sync with your schema` and a new
`backend/prisma/migrations/<timestamp>_init/migration.sql` file created

- [ ] **Step 5: Generate the Prisma client**

Run: `cd backend && npx prisma generate`
Expected: `Generated Prisma Client`

- [ ] **Step 6: Commit**

```bash
git add backend/prisma backend/package.json backend/package-lock.json backend/.gitignore
git commit -m "feat(backend): add full Prisma data model and initial migration"
```

---

### Task 5: Backend CI workflow

**Files:**
- Create: `.github/workflows/backend-ci.yml`

- [ ] **Step 1: Create the workflow**

```yaml
name: backend-ci

on:
  pull_request:
    paths:
      - 'backend/**'
      - '.github/workflows/backend-ci.yml'

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_USER: tradeiq
          POSTGRES_PASSWORD: tradeiq_dev
          POSTGRES_DB: tradeiq
        ports:
          - 5432:5432
        options: >-
          --health-cmd "pg_isready -U tradeiq"
          --health-interval 5s
          --health-timeout 5s
          --health-retries 5
    env:
      DATABASE_URL: postgresql://tradeiq:tradeiq_dev@localhost:5432/tradeiq?schema=public
      JWT_SECRET: ci-test-secret
    defaults:
      run:
        working-directory: backend
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
          cache-dependency-path: backend/package-lock.json
      - run: npm ci
      - run: npx prisma migrate deploy
      - run: npm run lint
      - run: npm test
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/backend-ci.yml
git commit -m "ci: add backend lint+test workflow"
```

---

### Task 6: Flutter app init

**Files:**
- Create: `app/` (via `flutter create`)
- Create: `app/analysis_options.yaml`
- Test: `app/test/widget_test.dart` (Flutter default, updated)

- [ ] **Step 1: Create the Flutter project inside `app/`**

```bash
flutter create --org com.tradeiq --project-name tradeiq_app app
```

- [ ] **Step 2: Replace `app/analysis_options.yaml`**

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_single_quotes: true
    always_declare_return_types: true
```

- [ ] **Step 3: Replace the default smoke test at `app/test/widget_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots and renders a MaterialApp', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd app && flutter test test/widget_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Run analyzer**

Run: `cd app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add app
git commit -m "feat(app): scaffold Flutter project (tradeiq_app)"
```

---

### Task 7: App CI workflow

**Files:**
- Create: `.github/workflows/app-ci.yml`

- [ ] **Step 1: Create the workflow**

```yaml
name: app-ci

on:
  pull_request:
    paths:
      - 'app/**'
      - '.github/workflows/app-ci.yml'

jobs:
  test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: app
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: stable
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/app-ci.yml
git commit -m "ci: add app analyze+test workflow"
```

---

## Track B — Backend core logic, auth, proof-of-concept resource

### Task 8: Geofence haversine check

**Files:**
- Create: `backend/src/lib/geofence.ts`
- Test: `backend/src/lib/geofence.test.ts`

- [ ] **Step 1: Write the failing test**

```ts
// backend/src/lib/geofence.test.ts
import { isWithinGeofence } from './geofence';

describe('isWithinGeofence', () => {
  it('returns true when within 50m of the outlet', () => {
    // ~11m north of the outlet
    const outlet = { lat: -26.2041, lng: 28.0473 };
    const checkin = { lat: -26.20400, lng: 28.0473 };
    expect(isWithinGeofence(outlet, checkin, 50)).toBe(true);
  });

  it('returns false when more than 50m from the outlet', () => {
    const outlet = { lat: -26.2041, lng: 28.0473 };
    const checkin = { lat: -26.2100, lng: 28.0473 }; // ~650m away
    expect(isWithinGeofence(outlet, checkin, 50)).toBe(false);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && npx jest geofence.test.ts`
Expected: FAIL — cannot find module `./geofence`

- [ ] **Step 3: Implement**

```ts
// backend/src/lib/geofence.ts
interface Coordinates {
  lat: number;
  lng: number;
}

const EARTH_RADIUS_METERS = 6371000;

function toRadians(degrees: number): number {
  return (degrees * Math.PI) / 180;
}

export function haversineDistanceMeters(a: Coordinates, b: Coordinates): number {
  const dLat = toRadians(b.lat - a.lat);
  const dLng = toRadians(b.lng - a.lng);
  const lat1 = toRadians(a.lat);
  const lat2 = toRadians(b.lat);

  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;

  return 2 * EARTH_RADIUS_METERS * Math.asin(Math.sqrt(h));
}

export function isWithinGeofence(
  outlet: Coordinates,
  checkin: Coordinates,
  radiusMeters = 50,
): boolean {
  return haversineDistanceMeters(outlet, checkin) <= radiusMeters;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && npx jest geofence.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/src/lib/geofence.ts backend/src/lib/geofence.test.ts
git commit -m "feat(backend): add haversine geofence check"
```

---

### Task 9: SLA due-date clock

**Files:**
- Create: `backend/src/lib/slaClock.ts`
- Test: `backend/src/lib/slaClock.test.ts`

- [ ] **Step 1: Write the failing test**

```ts
// backend/src/lib/slaClock.test.ts
import { computeSlaDueAt } from './slaClock';

describe('computeSlaDueAt', () => {
  const from = new Date('2026-07-02T10:00:00.000Z');

  it('adds 24 hours for critical priority', () => {
    expect(computeSlaDueAt('critical', from)).toEqual(
      new Date('2026-07-03T10:00:00.000Z'),
    );
  });

  it('adds 3 days for high priority', () => {
    expect(computeSlaDueAt('high', from)).toEqual(
      new Date('2026-07-05T10:00:00.000Z'),
    );
  });

  it('adds 7 days for normal priority', () => {
    expect(computeSlaDueAt('normal', from)).toEqual(
      new Date('2026-07-09T10:00:00.000Z'),
    );
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && npx jest slaClock.test.ts`
Expected: FAIL — cannot find module `./slaClock`

- [ ] **Step 3: Implement**

```ts
// backend/src/lib/slaClock.ts
export type TaskPriority = 'critical' | 'high' | 'normal';

const SLA_HOURS: Record<TaskPriority, number> = {
  critical: 24,
  high: 24 * 3,
  normal: 24 * 7,
};

export function computeSlaDueAt(priority: TaskPriority, from: Date): Date {
  const dueAt = new Date(from);
  dueAt.setUTCHours(dueAt.getUTCHours() + SLA_HOURS[priority]);
  return dueAt;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && npx jest slaClock.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/src/lib/slaClock.ts backend/src/lib/slaClock.test.ts
git commit -m "feat(backend): add SLA due-date clock"
```

---

### Task 10: Auth — JWT issue/verify + login endpoint

**Files:**
- Create: `backend/src/modules/auth/auth.service.ts`
- Create: `backend/src/modules/auth/auth.routes.ts`
- Create: `backend/src/middleware/auth.ts`
- Create: `backend/src/middleware/roleGuard.ts`
- Test: `backend/src/modules/auth/auth.service.test.ts`
- Modify: `backend/src/app.ts`

- [ ] **Step 1: Install auth dependencies**

```bash
cd backend
npm install jsonwebtoken bcryptjs
npm install -D @types/jsonwebtoken @types/bcryptjs
```

- [ ] **Step 2: Write the failing test for token issue/verify**

```ts
// backend/src/modules/auth/auth.service.test.ts
import { issueToken, verifyToken } from './auth.service';

describe('auth.service', () => {
  const payload = { userId: 'user-1', role: 'field_agent' as const, clientId: 'client-1' };

  it('issues a token that verifies back to the same payload', () => {
    const token = issueToken(payload);
    const decoded = verifyToken(token);
    expect(decoded.userId).toBe(payload.userId);
    expect(decoded.role).toBe(payload.role);
    expect(decoded.clientId).toBe(payload.clientId);
  });

  it('throws when verifying a malformed token', () => {
    expect(() => verifyToken('not-a-real-token')).toThrow();
  });
});
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd backend && JWT_SECRET=test-secret npx jest auth.service.test.ts`
Expected: FAIL — cannot find module `./auth.service`

- [ ] **Step 4: Implement `auth.service.ts`**

```ts
// backend/src/modules/auth/auth.service.ts
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';

export interface AuthTokenPayload {
  userId: string;
  role: 'field_agent' | 'manager' | 'admin';
  clientId: string;
}

function getSecret(): string {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    throw new Error('JWT_SECRET is not set');
  }
  return secret;
}

export function issueToken(payload: AuthTokenPayload): string {
  return jwt.sign(payload, getSecret(), { expiresIn: '12h' });
}

export function verifyToken(token: string): AuthTokenPayload {
  return jwt.verify(token, getSecret()) as AuthTokenPayload;
}

export async function hashPassword(plain: string): Promise<string> {
  return bcrypt.hash(plain, 10);
}

export async function comparePassword(plain: string, hash: string): Promise<boolean> {
  return bcrypt.compare(plain, hash);
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd backend && JWT_SECRET=test-secret npx jest auth.service.test.ts`
Expected: PASS

- [ ] **Step 6: Implement the auth middleware**

```ts
// backend/src/middleware/auth.ts
import { NextFunction, Request, Response } from 'express';
import { AuthTokenPayload, verifyToken } from '../modules/auth/auth.service';

export interface AuthedRequest extends Request {
  user?: AuthTokenPayload;
}

export function requireAuth(req: AuthedRequest, res: Response, next: NextFunction): void {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing bearer token' });
    return;
  }
  try {
    req.user = verifyToken(header.slice('Bearer '.length));
    next();
  } catch {
    res.status(401).json({ error: 'Invalid or expired token' });
  }
}
```

- [ ] **Step 7: Implement the role guard middleware**

```ts
// backend/src/middleware/roleGuard.ts
import { NextFunction, Response } from 'express';
import { AuthedRequest } from './auth';

export function requireRole(...allowed: Array<'field_agent' | 'manager' | 'admin'>) {
  return (req: AuthedRequest, res: Response, next: NextFunction): void => {
    if (!req.user || !allowed.includes(req.user.role)) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }
    next();
  };
}
```

- [ ] **Step 8: Implement the login route**

```ts
// backend/src/modules/auth/auth.routes.ts
import { Router } from 'express';
import { PrismaClient } from '@prisma/client';
import { comparePassword, issueToken } from './auth.service';

const prisma = new PrismaClient();
export const authRouter = Router();

authRouter.post('/login', async (req, res) => {
  const { email, password } = req.body as { email?: string; password?: string };
  if (!email || !password) {
    res.status(400).json({ error: 'email and password are required' });
    return;
  }

  const user = await prisma.user.findUnique({ where: { email } });
  if (!user || !(await comparePassword(password, user.passwordHash))) {
    res.status(401).json({ error: 'Invalid credentials' });
    return;
  }

  const token = issueToken({ userId: user.id, role: user.role, clientId: user.clientId });
  res.status(200).json({ token, role: user.role });
});
```

- [ ] **Step 9: Wire the auth router into `backend/src/app.ts`**

```ts
// backend/src/app.ts
import express from 'express';
import { authRouter } from './modules/auth/auth.routes';

export const app = express();

app.use(express.json());

app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.use('/auth', authRouter);
```

- [ ] **Step 10: Run the full backend test suite**

Run: `cd backend && JWT_SECRET=test-secret npx jest`
Expected: PASS (all existing tests still pass)

- [ ] **Step 11: Commit**

```bash
git add backend/src/modules/auth backend/src/middleware backend/src/app.ts \
  backend/package.json backend/package-lock.json
git commit -m "feat(backend): add JWT auth service, middleware, and login route"
```

---

### Task 11: Central error handler

**Files:**
- Create: `backend/src/middleware/errorHandler.ts`
- Modify: `backend/src/app.ts`
- Test: `backend/src/middleware/errorHandler.test.ts`

- [ ] **Step 1: Write the failing test**

```ts
// backend/src/middleware/errorHandler.test.ts
import express from 'express';
import request from 'supertest';
import { errorHandler, NotImplementedError } from './errorHandler';

describe('errorHandler', () => {
  it('maps NotImplementedError to 501', async () => {
    const app = express();
    app.get('/boom', () => {
      throw new NotImplementedError('not built yet');
    });
    app.use(errorHandler);

    const res = await request(app).get('/boom');
    expect(res.status).toBe(501);
    expect(res.body).toEqual({ error: 'not built yet' });
  });

  it('maps unknown errors to 500 without leaking stack traces', async () => {
    const app = express();
    app.get('/boom', () => {
      throw new Error('unexpected');
    });
    app.use(errorHandler);

    const res = await request(app).get('/boom');
    expect(res.status).toBe(500);
    expect(res.body).toEqual({ error: 'Internal server error' });
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && npx jest errorHandler.test.ts`
Expected: FAIL — cannot find module `./errorHandler`

- [ ] **Step 3: Implement**

```ts
// backend/src/middleware/errorHandler.ts
import { NextFunction, Request, Response } from 'express';

export class NotImplementedError extends Error {}
export class GeofenceRejectedError extends Error {}

// eslint-disable-next-line @typescript-eslint/no-unused-vars
export function errorHandler(err: Error, _req: Request, res: Response, _next: NextFunction): void {
  if (err instanceof NotImplementedError) {
    res.status(501).json({ error: err.message });
    return;
  }
  if (err instanceof GeofenceRejectedError) {
    res.status(422).json({ error: err.message });
    return;
  }
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
}
```

- [ ] **Step 4: Wire it in as the last middleware in `backend/src/app.ts`**

```ts
// backend/src/app.ts (append at the bottom, after all routes)
import { errorHandler } from './middleware/errorHandler';
// ...existing app.use(...) calls above...
app.use(errorHandler);
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd backend && npx jest errorHandler.test.ts`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add backend/src/middleware/errorHandler.ts backend/src/middleware/errorHandler.test.ts backend/src/app.ts
git commit -m "feat(backend): add centralized error handler"
```

---

### Task 12: Outlets module — proof-of-concept CRUD resource

**Files:**
- Create: `backend/src/modules/outlets/outlets.service.ts`
- Create: `backend/src/modules/outlets/outlets.routes.ts`
- Test: `backend/src/modules/outlets/outlets.routes.test.ts`
- Modify: `backend/src/app.ts`

This is the one module implemented fully in the scaffold — it proves
Prisma + Express + auth + error handling work end-to-end. Every other
module (Task 14) is a skeleton by comparison.

- [ ] **Step 1: Write the failing integration test (against the real dockerized Postgres)**

```ts
// backend/src/modules/outlets/outlets.routes.test.ts
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

const prisma = new PrismaClient();

describe('outlets routes', () => {
  let clientId: string;
  let token: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: {
        name: 'Test Client',
        industry: 'FMCG',
        scorecardWeights: {},
        kpiThresholds: {},
      },
    });
    clientId = client.id;
    token = issueToken({ userId: 'seed-user', role: 'manager', clientId });
  });

  afterAll(async () => {
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  it('creates and lists outlets for the caller\'s client', async () => {
    const createRes = await request(app)
      .post('/outlets')
      .set('Authorization', `Bearer ${token}`)
      .send({
        name: 'Test Hypermarket',
        code: 'TH-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 'territory-1',
        teamProfile: { headcount: 3 },
      });

    expect(createRes.status).toBe(201);
    expect(createRes.body.name).toBe('Test Hypermarket');

    const listRes = await request(app)
      .get('/outlets')
      .set('Authorization', `Bearer ${token}`);

    expect(listRes.status).toBe(200);
    expect(listRes.body).toHaveLength(1);
    expect(listRes.body[0].code).toBe('TH-001');
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).get('/outlets');
    expect(res.status).toBe(401);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && JWT_SECRET=test-secret npx jest outlets.routes.test.ts`
Expected: FAIL — 404 (no `/outlets` route registered yet)

- [ ] **Step 3: Implement `outlets.service.ts`**

```ts
// backend/src/modules/outlets/outlets.service.ts
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export interface CreateOutletInput {
  name: string;
  code: string;
  channelType: string;
  lat: number;
  lng: number;
  territoryId: string;
  teamProfile: unknown;
  clientId: string;
}

export function listOutletsForClient(clientId: string) {
  return prisma.outlet.findMany({ where: { clientId } });
}

export function createOutlet(input: CreateOutletInput) {
  return prisma.outlet.create({ data: input });
}
```

- [ ] **Step 4: Implement `outlets.routes.ts`**

```ts
// backend/src/modules/outlets/outlets.routes.ts
import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { createOutlet, listOutletsForClient } from './outlets.service';

export const outletsRouter = Router();

outletsRouter.use(requireAuth);

outletsRouter.get('/', async (req: AuthedRequest, res) => {
  const outlets = await listOutletsForClient(req.user!.clientId);
  res.status(200).json(outlets);
});

outletsRouter.post('/', async (req: AuthedRequest, res) => {
  const { name, code, channelType, lat, lng, territoryId, teamProfile } = req.body;
  const outlet = await createOutlet({
    name,
    code,
    channelType,
    lat,
    lng,
    territoryId,
    teamProfile,
    clientId: req.user!.clientId,
  });
  res.status(201).json(outlet);
});
```

- [ ] **Step 5: Wire the router into `backend/src/app.ts`**

```ts
// backend/src/app.ts
import { outletsRouter } from './modules/outlets/outlets.routes';
// ...
app.use('/outlets', outletsRouter);
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd backend && JWT_SECRET=test-secret npx jest outlets.routes.test.ts`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add backend/src/modules/outlets backend/src/app.ts
git commit -m "feat(backend): implement outlets module as proof-of-concept CRUD resource"
```

---

### Task 13: Stub services (Phase 2+) + real forecast service + GitHub issues

**Files:**
- Create: `backend/src/services/vision.stub.ts`
- Create: `backend/src/services/ocr.stub.ts`
- Create: `backend/src/services/fraud.stub.ts`
- Create: `backend/src/services/dispatch.stub.ts`
- Create: `backend/src/services/forecast.service.ts`
- Test: `backend/src/services/vision.stub.test.ts`
- Test: `backend/src/services/forecast.service.test.ts`

- [ ] **Step 1: Write the failing test for the forecast service (real logic, not a stub)**

```ts
// backend/src/services/forecast.service.test.ts
import { predictCoverageDays, coverageStatus } from './forecast.service';

describe('predictCoverageDays', () => {
  it('divides units available by average daily velocity', () => {
    expect(predictCoverageDays({ unitsAvailable: 40, velocityAvg: 10 })).toBe(4);
  });

  it('returns Infinity when velocity is zero', () => {
    expect(predictCoverageDays({ unitsAvailable: 40, velocityAvg: 0 })).toBe(Infinity);
  });
});

describe('coverageStatus', () => {
  it('flags red when under 3 days', () => {
    expect(coverageStatus(2)).toBe('red');
  });

  it('flags amber when under 7 days', () => {
    expect(coverageStatus(5)).toBe('amber');
  });

  it('flags green otherwise', () => {
    expect(coverageStatus(10)).toBe('green');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && npx jest forecast.service.test.ts`
Expected: FAIL — cannot find module `./forecast.service`

- [ ] **Step 3: Implement `forecast.service.ts`**

```ts
// backend/src/services/forecast.service.ts
// REAL logic (not a stub) — simple velocity-based coverage-days formula per
// the Phase 1 spec. Per-SKU ML demand forecasting is Phase 2+ (tracked in
// docs/architecture/stubs-and-interfaces.md).

export function predictCoverageDays(input: { unitsAvailable: number; velocityAvg: number }): number {
  if (input.velocityAvg <= 0) return Infinity;
  return input.unitsAvailable / input.velocityAvg;
}

export type CoverageStatus = 'red' | 'amber' | 'green';

export function coverageStatus(coverageDays: number): CoverageStatus {
  if (coverageDays < 3) return 'red';
  if (coverageDays < 7) return 'amber';
  return 'green';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && npx jest forecast.service.test.ts`
Expected: PASS

- [ ] **Step 5: Write the failing test for the vision stub**

```ts
// backend/src/services/vision.stub.test.ts
import { detectBranding } from './vision.stub';

describe('detectBranding (stub)', () => {
  it('returns a result with the expected shape', async () => {
    const result = await detectBranding('https://example.com/photo.jpg');
    expect(typeof result.pass).toBe('boolean');
    expect(result.elementsDetected).toBeGreaterThanOrEqual(0);
    expect(result.elementsDetected).toBeLessThanOrEqual(8);
  });
});
```

- [ ] **Step 6: Run test to verify it fails**

Run: `cd backend && npx jest vision.stub.test.ts`
Expected: FAIL — cannot find module `./vision.stub`

- [ ] **Step 7: Implement the stub services**

```ts
// backend/src/services/vision.stub.ts
// STUB — Phase 2+. Real on-device/server computer vision for branding
// detection, planogram compliance, facings count, and cleanliness scoring
// is not built. This weighted-random implementation exists so Phase 1
// callers (S3/S4 visibility+display screens) have a working interface to
// build against. See: docs/architecture/stubs-and-interfaces.md

export interface BrandingResult {
  pass: boolean;
  elementsDetected: number;
}

const TOTAL_BRANDING_ELEMENTS = 8;
const PASS_WEIGHT = 0.8;

export async function detectBranding(_photoUrl: string): Promise<BrandingResult> {
  const elementsDetected = Array.from({ length: TOTAL_BRANDING_ELEMENTS }).filter(
    () => Math.random() < PASS_WEIGHT,
  ).length;
  return { pass: elementsDetected === TOTAL_BRANDING_ELEMENTS, elementsDetected };
}

export async function scorePlanogramCompliance(_photoUrl: string, _templateId: string): Promise<number> {
  return Math.round((0.6 + Math.random() * 0.4) * 100) / 100;
}

export async function countFacings(_photoUrl: string, _skuId: string): Promise<number> {
  return Math.floor(Math.random() * 6) + 1;
}

export async function scoreCleanliness(_photoUrl: string): Promise<number> {
  return Math.ceil(Math.random() * 5);
}
```

```ts
// backend/src/services/ocr.stub.ts
// STUB — Phase 2+. Real OCR price extraction is not built. For Phase 1,
// price entry is manual (agent types the shelf price) — this passthrough
// exists so the S5 pricing module has a stable interface to call.
// See: docs/architecture/stubs-and-interfaces.md

export async function extractPriceFromPhoto(_photoUrl: string, manualEntry: number): Promise<number> {
  return manualEntry;
}
```

```ts
// backend/src/services/fraud.stub.ts
// STUB — Phase 2+. Behavioural fraud/ghost-visit detection is not built in
// Phase 1. No Phase 1 caller exists yet; this throws so any accidental call
// fails loudly instead of silently returning fake data.
// See: docs/architecture/stubs-and-interfaces.md
import { NotImplementedError } from '../middleware/errorHandler';

export async function detectGhostVisit(_visitId: string): Promise<never> {
  throw new NotImplementedError('Fraud detection is not implemented in Phase 1');
}
```

```ts
// backend/src/services/dispatch.stub.ts
// STUB — Phase 2+. Predictive field dispatch is not built in Phase 1. No
// Phase 1 caller exists yet; this throws so any accidental call fails
// loudly instead of silently returning fake data.
// See: docs/architecture/stubs-and-interfaces.md
import { NotImplementedError } from '../middleware/errorHandler';

export async function dispatchNearestAgent(_outletId: string): Promise<never> {
  throw new NotImplementedError('Predictive dispatch is not implemented in Phase 1');
}
```

- [ ] **Step 8: Run test to verify it passes**

Run: `cd backend && npx jest vision.stub.test.ts forecast.service.test.ts`
Expected: PASS

- [ ] **Step 9: Commit**

```bash
git add backend/src/services
git commit -m "feat(backend): add Phase-2+ stub services and real forecast service"
```

- [ ] **Step 10: Open one GitHub issue per stub, linked from the stub file**

```bash
gh issue create --repo Wandashabba/TradeIQ \
  --title "[Phase 2] Replace vision.stub with real CV branding/planogram/facings/cleanliness detection" \
  --label "phase-2,computer-vision" \
  --body "Current: backend/src/services/vision.stub.ts returns weighted-random results.
Needed: real CV model for the S3/S4 in-store visibility and display sections —
8-element branding checklist, planogram compliance %, facings count, cleanliness score.
See docs/architecture/stubs-and-interfaces.md for the full interface."

gh issue create --repo Wandashabba/TradeIQ \
  --title "[Phase 2] Replace ocr.stub with real price-tag OCR extraction" \
  --label "phase-2,ocr" \
  --body "Current: backend/src/services/ocr.stub.ts passes through the agent's manual price entry.
Needed: real OCR extraction from a shelf-price photo for the S5 pricing module.
See docs/architecture/stubs-and-interfaces.md for the full interface."

gh issue create --repo Wandashabba/TradeIQ \
  --title "[Phase 2] Implement behavioural fraud / ghost-visit detection" \
  --label "phase-2,fraud-detection" \
  --body "Current: backend/src/services/fraud.stub.ts throws NotImplementedError (no Phase 1 caller).
Needed: behavioural fraud detection flagging ghost visits / fake attendance.
See docs/architecture/stubs-and-interfaces.md for the full interface."

gh issue create --repo Wandashabba/TradeIQ \
  --title "[Phase 2] Implement predictive field dispatch" \
  --label "phase-2,dispatch" \
  --body "Current: backend/src/services/dispatch.stub.ts throws NotImplementedError (no Phase 1 caller).
Needed: auto-assign the nearest available field agent when AI detects a share-of-shelf drop or planogram gap.
See docs/architecture/stubs-and-interfaces.md for the full interface."
```

Record the four issue URLs returned by these commands — they're needed
verbatim in Task 27.

---

### Task 14: Remaining module route skeletons (S2, S3-4, S5-S10, dashboard)

**Files:**
- Create: `backend/src/modules/visits/visits.routes.ts`
- Create: `backend/src/modules/stock/stock.routes.ts`
- Create: `backend/src/modules/visibility/visibility.routes.ts`
- Create: `backend/src/modules/pricing/pricing.routes.ts`
- Create: `backend/src/modules/competitive/competitive.routes.ts`
- Create: `backend/src/modules/capability/capability.routes.ts`
- Create: `backend/src/modules/risks/risks.routes.ts`
- Create: `backend/src/modules/tasks/tasks.routes.ts`
- Create: `backend/src/modules/scorecards/scorecards.routes.ts`
- Create: `backend/src/modules/dashboard/dashboard.routes.ts`
- Test: `backend/src/modules/moduleSkeletons.test.ts`
- Modify: `backend/src/app.ts`

Each of these modules is a skeleton: one `GET /` route returning `501 Not
Implemented` via the shared error handler, proving the route is wired and
authenticated, with the real CRUD logic left for the follow-up S1–S10
implementation plan (per spec §11).

- [ ] **Step 1: Write the failing test covering all ten skeleton routes**

```ts
// backend/src/modules/moduleSkeletons.test.ts
import request from 'supertest';
import { app } from '../app';
import { issueToken } from './auth/auth.service';

const token = issueToken({ userId: 'user-1', role: 'manager', clientId: 'client-1' });

const skeletonRoutes = [
  '/visits', '/stock', '/visibility', '/pricing', '/competitive',
  '/capability', '/risks', '/tasks', '/scorecards', '/dashboard',
];

describe('module skeleton routes', () => {
  it.each(skeletonRoutes)('GET %s requires auth and returns 501 when authed', async (path) => {
    const unauthed = await request(app).get(path);
    expect(unauthed.status).toBe(401);

    const authed = await request(app).get(path).set('Authorization', `Bearer ${token}`);
    expect(authed.status).toBe(501);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && JWT_SECRET=test-secret npx jest moduleSkeletons.test.ts`
Expected: FAIL — 404 for all ten paths (routes not registered)

- [ ] **Step 3: Implement each skeleton router with identical shape**

```ts
// backend/src/modules/visits/visits.routes.ts
import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { NotImplementedError } from '../../middleware/errorHandler';

export const visitsRouter = Router();
visitsRouter.use(requireAuth);
visitsRouter.get('/', () => {
  throw new NotImplementedError('Visits module (S1 check-in flow) is not implemented yet');
});
```

```ts
// backend/src/modules/stock/stock.routes.ts
import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { NotImplementedError } from '../../middleware/errorHandler';

export const stockRouter = Router();
stockRouter.use(requireAuth);
stockRouter.get('/', () => {
  throw new NotImplementedError('Stock module (S2) is not implemented yet');
});
```

```ts
// backend/src/modules/visibility/visibility.routes.ts
import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { NotImplementedError } from '../../middleware/errorHandler';

export const visibilityRouter = Router();
visibilityRouter.use(requireAuth);
visibilityRouter.get('/', () => {
  throw new NotImplementedError('Visibility/display module (S3-S4) is not implemented yet');
});
```

```ts
// backend/src/modules/pricing/pricing.routes.ts
import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { NotImplementedError } from '../../middleware/errorHandler';

export const pricingRouter = Router();
pricingRouter.use(requireAuth);
pricingRouter.get('/', () => {
  throw new NotImplementedError('Pricing/promotions module (S5) is not implemented yet');
});
```

```ts
// backend/src/modules/competitive/competitive.routes.ts
import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { NotImplementedError } from '../../middleware/errorHandler';

export const competitiveRouter = Router();
competitiveRouter.use(requireAuth);
competitiveRouter.get('/', () => {
  throw new NotImplementedError('Competitive intelligence module (S6) is not implemented yet');
});
```

```ts
// backend/src/modules/capability/capability.routes.ts
import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { NotImplementedError } from '../../middleware/errorHandler';

export const capabilityRouter = Router();
capabilityRouter.use(requireAuth);
capabilityRouter.get('/', () => {
  throw new NotImplementedError('Sales capability module (S7) is not implemented yet');
});
```

```ts
// backend/src/modules/risks/risks.routes.ts
import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { NotImplementedError } from '../../middleware/errorHandler';

export const risksRouter = Router();
risksRouter.use(requireAuth);
risksRouter.get('/', () => {
  throw new NotImplementedError('Opportunities/risks module (S8) is not implemented yet');
});
```

```ts
// backend/src/modules/tasks/tasks.routes.ts
import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { NotImplementedError } from '../../middleware/errorHandler';

export const tasksRouter = Router();
tasksRouter.use(requireAuth);
tasksRouter.get('/', () => {
  throw new NotImplementedError('Task lifecycle module (S9) is not implemented yet');
});
```

```ts
// backend/src/modules/scorecards/scorecards.routes.ts
import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { NotImplementedError } from '../../middleware/errorHandler';

export const scorecardsRouter = Router();
scorecardsRouter.use(requireAuth);
scorecardsRouter.get('/', () => {
  throw new NotImplementedError('Scorecard engine module (S10) is not implemented yet');
});
```

```ts
// backend/src/modules/dashboard/dashboard.routes.ts
import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { NotImplementedError } from '../../middleware/errorHandler';

export const dashboardRouter = Router();
dashboardRouter.use(requireAuth);
dashboardRouter.get('/', () => {
  throw new NotImplementedError('Dashboard KPI aggregation module is not implemented yet');
});
```

- [ ] **Step 4: Wire all ten routers into `backend/src/app.ts`**

```ts
// backend/src/app.ts
import { visitsRouter } from './modules/visits/visits.routes';
import { stockRouter } from './modules/stock/stock.routes';
import { visibilityRouter } from './modules/visibility/visibility.routes';
import { pricingRouter } from './modules/pricing/pricing.routes';
import { competitiveRouter } from './modules/competitive/competitive.routes';
import { capabilityRouter } from './modules/capability/capability.routes';
import { risksRouter } from './modules/risks/risks.routes';
import { tasksRouter } from './modules/tasks/tasks.routes';
import { scorecardsRouter } from './modules/scorecards/scorecards.routes';
import { dashboardRouter } from './modules/dashboard/dashboard.routes';

// ...after app.use('/outlets', outletsRouter):
app.use('/visits', visitsRouter);
app.use('/stock', stockRouter);
app.use('/visibility', visibilityRouter);
app.use('/pricing', pricingRouter);
app.use('/competitive', competitiveRouter);
app.use('/capability', capabilityRouter);
app.use('/risks', risksRouter);
app.use('/tasks', tasksRouter);
app.use('/scorecards', scorecardsRouter);
app.use('/dashboard', dashboardRouter);
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd backend && JWT_SECRET=test-secret npx jest moduleSkeletons.test.ts`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add backend/src/modules backend/src/app.ts
git commit -m "feat(backend): add route skeletons for remaining S2-S10 and dashboard modules"
```

---

### Task 15: OpenAPI spec

**Files:**
- Create: `backend/openapi.yaml`

- [ ] **Step 1: Write the spec covering the fully-implemented endpoints, with stubs noted**

```yaml
openapi: 3.0.3
info:
  title: TradeIQ API
  version: 0.1.0
  description: >
    Phase 1 scaffold. /auth and /outlets are fully implemented. All other
    module routes (/visits, /stock, /visibility, /pricing, /competitive,
    /capability, /risks, /tasks, /scorecards, /dashboard) currently return
    501 Not Implemented and will be filled in by follow-up plans — see
    docs/architecture/stubs-and-interfaces.md.
servers:
  - url: http://localhost:4000
paths:
  /health:
    get:
      summary: Health check
      responses:
        '200':
          description: OK
  /auth/login:
    post:
      summary: Log in and receive a JWT
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [email, password]
              properties:
                email: { type: string }
                password: { type: string }
      responses:
        '200':
          description: Login successful
          content:
            application/json:
              schema:
                type: object
                properties:
                  token: { type: string }
                  role: { type: string, enum: [field_agent, manager, admin] }
        '401':
          description: Invalid credentials
  /outlets:
    get:
      summary: List outlets for the authenticated user's client
      security: [{ bearerAuth: [] }]
      responses:
        '200':
          description: List of outlets
        '401':
          description: Missing or invalid token
    post:
      summary: Create an outlet
      security: [{ bearerAuth: [] }]
      responses:
        '201':
          description: Outlet created
components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
```

- [ ] **Step 2: Commit**

```bash
git add backend/openapi.yaml
git commit -m "docs(backend): add OpenAPI spec for implemented endpoints"
```

---

## Track C — Flutter app shell

### Task 16: Theme tokens

**Files:**
- Create: `app/lib/core/theme/app_colors.dart`
- Create: `app/lib/core/theme/app_theme.dart`
- Test: `app/test/core/theme/app_theme_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/core/theme/app_theme_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';

void main() {
  test('dark theme uses the deck navy background', () {
    final theme = AppTheme.dark();
    expect(theme.scaffoldBackgroundColor, const Color(0xFF0B1220));
  });
}
```

Add the `Color` import implicitly via `package:flutter/material.dart` re-export
used in the test above — Flutter's `Color` is exported by `material.dart`, so
add that import too:

```dart
import 'package:flutter/material.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/theme/app_theme_test.dart`
Expected: FAIL — cannot find `package:tradeiq_app/core/theme/app_theme.dart`

- [ ] **Step 3: Implement `app_colors.dart`**

```dart
// app/lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

/// Brand tokens derived from the TradeIQ pitch deck (dark navy background,
/// blue primary accent, supporting orange/teal/purple/gold accents).
class AppColors {
  AppColors._();

  static const navyBackground = Color(0xFF0B1220);
  static const navySurface = Color(0xFF141B2E);
  static const primaryBlue = Color(0xFF4C7CF3);
  static const accentOrange = Color(0xFFE8895A);
  static const accentTeal = Color(0xFF3FC7A6);
  static const accentGold = Color(0xFFE8C15A);
  static const accentPink = Color(0xFFE85A8A);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB4BCD0);
}
```

- [ ] **Step 4: Implement `app_theme.dart`**

```dart
// app/lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.navyBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryBlue,
        brightness: Brightness.dark,
        surface: AppColors.navySurface,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: AppColors.textPrimary),
        bodySmall: TextStyle(color: AppColors.textSecondary),
      ),
      useMaterial3: true,
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/core/theme/app_theme_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/lib/core/theme app/test/core/theme
git commit -m "feat(app): add brand theme tokens"
```

---

### Task 17: Router shell with role-based guards

**Files:**
- Create: `app/lib/core/router/app_router.dart`
- Create: `app/lib/features/auth/presentation/login_screen.dart`
- Create: `app/lib/features/dashboard/presentation/dashboard_shell_screen.dart`
- Create: `app/lib/features/audit/presentation/audit_shell_screen.dart`
- Modify: `app/lib/main.dart`
- Test: `app/test/core/router/app_router_test.dart`

- [ ] **Step 1: Add `go_router` and `flutter_riverpod` dependencies**

```bash
cd app
flutter pub add go_router flutter_riverpod
```

- [ ] **Step 2: Write the failing test**

```dart
// app/test/core/router/app_router_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/router/app_router.dart';

void main() {
  testWidgets('unauthenticated root route shows the login screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: buildRouter()),
      ),
    );
    expect(find.text('TradeIQ Login'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd app && flutter test test/core/router/app_router_test.dart`
Expected: FAIL — cannot find `package:tradeiq_app/core/router/app_router.dart`

- [ ] **Step 4: Implement the placeholder screens**

```dart
// app/lib/features/auth/presentation/login_screen.dart
import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('TradeIQ Login')),
    );
  }
}
```

```dart
// app/lib/features/dashboard/presentation/dashboard_shell_screen.dart
import 'package:flutter/material.dart';

class DashboardShellScreen extends StatelessWidget {
  const DashboardShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Manager Dashboard')),
    );
  }
}
```

```dart
// app/lib/features/audit/presentation/audit_shell_screen.dart
import 'package:flutter/material.dart';

class AuditShellScreen extends StatelessWidget {
  const AuditShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Audit Flow')),
    );
  }
}
```

- [ ] **Step 5: Implement the router**

```dart
// app/lib/core/router/app_router.dart
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_shell_screen.dart';
import '../../features/audit/presentation/audit_shell_screen.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/dashboard', builder: (context, state) => const DashboardShellScreen()),
      GoRoute(path: '/audit', builder: (context, state) => const AuditShellScreen()),
    ],
  );
}
```

- [ ] **Step 6: Wire the router into `app/lib/main.dart`**

```dart
// app/lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: TradeIqApp()));
}

class TradeIqApp extends StatelessWidget {
  const TradeIqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TradeIQ',
      theme: AppTheme.dark(),
      routerConfig: buildRouter(),
    );
  }
}
```

- [ ] **Step 7: Run test to verify it passes**

Run: `cd app && flutter test test/core/router/app_router_test.dart`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add app/lib/core/router app/lib/features/auth/presentation/login_screen.dart \
  app/lib/features/dashboard/presentation/dashboard_shell_screen.dart \
  app/lib/features/audit/presentation/audit_shell_screen.dart \
  app/lib/main.dart app/test/core/router app/pubspec.yaml app/pubspec.lock
git commit -m "feat(app): add go_router shell with login/dashboard/audit routes"
```

---

### Task 18: Auth feature — login calling the backend

**Files:**
- Create: `app/lib/core/network/api_client.dart`
- Create: `app/lib/core/auth/auth_repository.dart`
- Create: `app/lib/core/auth/session_controller.dart`
- Test: `app/test/core/auth/session_controller_test.dart`

- [ ] **Step 1: Add `dio` and `flutter_secure_storage` dependencies**

```bash
cd app
flutter pub add dio flutter_secure_storage
flutter pub add --dev mocktail
```

- [ ] **Step 2: Write the failing test with a fake auth repository**

```dart
// app/test/core/auth/session_controller_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/auth_repository.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthResult> login(String email, String password) async {
    return const AuthResult(token: 'fake-token', role: 'manager');
  }
}

void main() {
  test('login success updates the session state with the returned role', async () {
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(FakeAuthRepository())],
    );
    addTearDown(container.dispose);

    final controller = container.read(sessionControllerProvider.notifier);
    await controller.login('agent@tradeiq.com', 'password123');

    final state = container.read(sessionControllerProvider);
    expect(state.value?.role, 'manager');
  });
}
```

Note: the test body above uses `async () { ... }` for a Dart test callback,
matching Dart's async test syntax (`test('description', () async { ... })`)
— write it exactly as:

```dart
  test('login success updates the session state with the returned role', () async {
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd app && flutter test test/core/auth/session_controller_test.dart`
Expected: FAIL — cannot find `package:tradeiq_app/core/auth/auth_repository.dart`

- [ ] **Step 4: Implement the API client**

```dart
// app/lib/core/network/api_client.dart
import 'package:dio/dio.dart';

final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'));
```

- [ ] **Step 5: Implement the auth repository interface + real implementation**

```dart
// app/lib/core/auth/auth_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../network/api_client.dart';

class AuthResult {
  const AuthResult({required this.token, required this.role});
  final String token;
  final String role;
}

abstract class AuthRepository {
  Future<AuthResult> login(String email, String password);
}

class DioAuthRepository implements AuthRepository {
  @override
  Future<AuthResult> login(String email, String password) async {
    final response = await dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return AuthResult(token: response.data['token'] as String, role: response.data['role'] as String);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => DioAuthRepository());
```

- [ ] **Step 6: Implement the session controller**

```dart
// app/lib/core/auth/session_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_repository.dart';

class SessionState {
  const SessionState({this.role});
  final String? role;
}

class SessionController extends AsyncNotifier<SessionState> {
  @override
  Future<SessionState> build() async => const SessionState();

  Future<void> login(String email, String password) async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.login(email, password);
    state = AsyncData(SessionState(role: result.role));
  }
}

final sessionControllerProvider = AsyncNotifierProvider<SessionController, SessionState>(
  SessionController.new,
);
```

- [ ] **Step 7: Run test to verify it passes**

Run: `cd app && flutter test test/core/auth/session_controller_test.dart`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add app/lib/core/network app/lib/core/auth app/test/core/auth app/pubspec.yaml app/pubspec.lock
git commit -m "feat(app): add auth repository and session controller"
```

---

### Task 19: Drift local DB + sync queue

**Files:**
- Create: `app/lib/core/storage/local_db.dart`
- Create: `app/lib/core/storage/tables.dart`
- Test: `app/test/core/storage/local_db_test.dart`

- [ ] **Step 1: Add Drift dependencies**

```bash
cd app
flutter pub add drift sqlite3_flutter_libs path_provider path
flutter pub add --dev drift_dev build_runner
```

- [ ] **Step 2: Define the tables**

```dart
// app/lib/core/storage/tables.dart
import 'package:drift/drift.dart';

class VisitDrafts extends Table {
  TextColumn get id => text()();
  TextColumn get outletId => text()();
  TextColumn get status => text().withDefault(const Constant('in_progress'))();
  DateTimeColumn get checkinTs => dateTime()();
  RealColumn get checkinLat => real()();
  RealColumn get checkinLng => real()();
  BoolColumn get geofencePass => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncQueueItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get queuedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
}
```

- [ ] **Step 3: Define the database class**

```dart
// app/lib/core/storage/local_db.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'tables.dart';

part 'local_db.g.dart';

@DriftDatabase(tables: [VisitDrafts, SyncQueueItems])
class LocalDb extends _$LocalDb {
  LocalDb([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'tradeiq_local.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
```

- [ ] **Step 4: Write the failing test using an in-memory database**

```dart
// app/test/core/storage/local_db_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/storage/tables.dart';

void main() {
  test('enqueues a sync item and reads it back unsynced', async () {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);

    await db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
      entityType: 'visit',
      entityId: 'visit-1',
      payloadJson: '{"outletId":"outlet-1"}',
    ));

    final rows = await db.select(db.syncQueueItems).get();
    expect(rows, hasLength(1));
    expect(rows.first.synced, isFalse);
  });
}
```

Write the test function using correct Dart async test syntax:

```dart
  test('enqueues a sync item and reads it back unsynced', () async {
```

- [ ] **Step 5: Generate Drift code and run the test**

Run: `cd app && dart run build_runner build --delete-conflicting-outputs`
Run: `cd app && flutter test test/core/storage/local_db_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/lib/core/storage app/test/core/storage app/pubspec.yaml app/pubspec.lock
git commit -m "feat(app): add Drift local DB with visit-draft and sync-queue tables"
```

---

### Task 20: Sync service skeleton

**Files:**
- Create: `app/lib/core/sync/sync_service.dart`
- Test: `app/test/core/sync/sync_service_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/core/sync/sync_service_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/storage/tables.dart';
import 'package:tradeiq_app/core/sync/sync_service.dart';

class NoopFlusher implements QueueFlusher {
  int callCount = 0;

  @override
  Future<void> flush(SyncQueueItem item) async {
    callCount += 1;
  }
}

void main() {
  test('flushPending marks queued items as synced', () async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.syncQueueItems).insert(SyncQueueItemsCompanion.insert(
      entityType: 'visit',
      entityId: 'visit-1',
      payloadJson: '{}',
    ));

    final flusher = NoopFlusher();
    final service = SyncService(db: db, flusher: flusher);
    await service.flushPending();

    expect(flusher.callCount, 1);
    final rows = await db.select(db.syncQueueItems).get();
    expect(rows.first.synced, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/sync/sync_service_test.dart`
Expected: FAIL — cannot find `package:tradeiq_app/core/sync/sync_service.dart`

- [ ] **Step 3: Implement**

```dart
// app/lib/core/sync/sync_service.dart
import 'package:drift/drift.dart';
import '../storage/local_db.dart';
import '../storage/tables.dart';

abstract class QueueFlusher {
  Future<void> flush(SyncQueueItem item);
}

/// Real network flusher wired in once the S1-S10 API endpoints exist.
/// Currently only the /outlets endpoint is implemented backend-side
/// (see backend/src/modules/outlets), so this is not yet used in `main.dart`.
class HttpQueueFlusher implements QueueFlusher {
  @override
  Future<void> flush(SyncQueueItem item) async {
    // Intentionally left for the follow-up S1-S10 implementation plan to
    // route `item.entityType` to the matching backend endpoint.
    throw UnimplementedError('HTTP sync for ${item.entityType} not wired yet');
  }
}

class SyncService {
  SyncService({required this.db, required this.flusher});

  final LocalDb db;
  final QueueFlusher flusher;

  Future<void> flushPending() async {
    final pending = await (db.select(db.syncQueueItems)
          ..where((tbl) => tbl.synced.equals(false)))
        .get();

    for (final item in pending) {
      await flusher.flush(item);
      await (db.update(db.syncQueueItems)..where((tbl) => tbl.id.equals(item.id)))
          .write(const SyncQueueItemsCompanion(synced: Value(true)));
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/core/sync/sync_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/sync app/test/core/sync
git commit -m "feat(app): add sync-queue flush service skeleton"
```

---

### Task 21: Outlets feature — proof-of-concept vertical slice

**Files:**
- Create: `app/lib/features/outlets/data/outlets_repository.dart`
- Create: `app/lib/features/outlets/presentation/outlets_list_screen.dart`
- Test: `app/test/features/outlets/outlets_list_screen_test.dart`
- Modify: `app/lib/core/router/app_router.dart`

- [ ] **Step 1: Write the failing widget test with a fake repository**

```dart
// app/test/features/outlets/outlets_list_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/outlets/presentation/outlets_list_screen.dart';

class FakeOutletsRepository implements OutletsRepository {
  @override
  Future<List<Outlet>> listOutlets() async => const [
        Outlet(id: 'o1', name: 'Test Hypermarket', code: 'TH-001'),
      ];
}

void main() {
  testWidgets('renders outlet names once loaded', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          outletsRepositoryProvider.overrideWithValue(FakeOutletsRepository()),
        ],
        child: const MaterialApp(home: OutletsListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Hypermarket'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/outlets/outlets_list_screen_test.dart`
Expected: FAIL — cannot find `package:tradeiq_app/features/outlets/data/outlets_repository.dart`

- [ ] **Step 3: Implement the repository**

```dart
// app/lib/features/outlets/data/outlets_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class Outlet {
  const Outlet({required this.id, required this.name, required this.code});
  final String id;
  final String name;
  final String code;

  factory Outlet.fromJson(Map<String, dynamic> json) => Outlet(
        id: json['id'] as String,
        name: json['name'] as String,
        code: json['code'] as String,
      );
}

abstract class OutletsRepository {
  Future<List<Outlet>> listOutlets();
}

class DioOutletsRepository implements OutletsRepository {
  @override
  Future<List<Outlet>> listOutlets() async {
    final response = await dio.get('/outlets');
    return (response.data as List)
        .map((json) => Outlet.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

final outletsRepositoryProvider = Provider<OutletsRepository>((ref) => DioOutletsRepository());

final outletsListProvider = FutureProvider<List<Outlet>>((ref) {
  return ref.read(outletsRepositoryProvider).listOutlets();
});
```

- [ ] **Step 4: Implement the screen**

```dart
// app/lib/features/outlets/presentation/outlets_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/outlets_repository.dart';

class OutletsListScreen extends ConsumerWidget {
  const OutletsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outlets = ref.watch(outletsListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Outlets')),
      body: outlets.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) => ListTile(
            title: Text(list[index].name),
            subtitle: Text(list[index].code),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Failed to load outlets: $err')),
      ),
    );
  }
}
```

- [ ] **Step 5: Add the route in `app_router.dart`**

```dart
// app/lib/core/router/app_router.dart
import '../../features/outlets/presentation/outlets_list_screen.dart';
// ...inside routes list:
GoRoute(path: '/outlets', builder: (context, state) => const OutletsListScreen()),
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd app && flutter test test/features/outlets/outlets_list_screen_test.dart`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/outlets app/test/features/outlets app/lib/core/router/app_router.dart
git commit -m "feat(app): add outlets list screen as proof-of-concept vertical slice"
```

---

### Task 22: Audit flow shell — S1-S10 section stubs

**Files:**
- Create: `app/lib/features/audit/presentation/sections/s1_outlet_info_screen.dart`
- Create: `app/lib/features/audit/presentation/sections/s2_stock_screen.dart`
- Create: `app/lib/features/audit/presentation/sections/s3_4_visibility_display_screen.dart`
- Create: `app/lib/features/audit/presentation/sections/s5_pricing_promotions_screen.dart`
- Create: `app/lib/features/audit/presentation/sections/s6_competitive_screen.dart`
- Create: `app/lib/features/audit/presentation/sections/s7_capability_screen.dart`
- Create: `app/lib/features/audit/presentation/sections/s8_risks_screen.dart`
- Create: `app/lib/features/audit/presentation/sections/s9_action_plan_screen.dart`
- Create: `app/lib/features/audit/presentation/sections/s10_scorecard_screen.dart`
- Modify: `app/lib/features/audit/presentation/audit_shell_screen.dart`
- Test: `app/test/features/audit/audit_shell_screen_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/audit/audit_shell_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/audit/presentation/audit_shell_screen.dart';

void main() {
  testWidgets('shows a stepper with all 10 audit sections', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuditShellScreen()));
    expect(find.text('S1 Outlet Information'), findsOneWidget);
    expect(find.text('S10 Execution Scorecard'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/audit/audit_shell_screen_test.dart`
Expected: FAIL — text not found (shell still shows the old placeholder)

- [ ] **Step 3: Implement each section screen (identical minimal shape, one per section)**

```dart
// app/lib/features/audit/presentation/sections/s1_outlet_info_screen.dart
import 'package:flutter/material.dart';

class S1OutletInfoScreen extends StatelessWidget {
  const S1OutletInfoScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('S1 Outlet Information'));
}
```

```dart
// app/lib/features/audit/presentation/sections/s2_stock_screen.dart
import 'package:flutter/material.dart';

class S2StockScreen extends StatelessWidget {
  const S2StockScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('S2 Stock & Availability'));
}
```

```dart
// app/lib/features/audit/presentation/sections/s3_4_visibility_display_screen.dart
import 'package:flutter/material.dart';

class S3S4VisibilityDisplayScreen extends StatelessWidget {
  const S3S4VisibilityDisplayScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('S3-S4 Visibility & Display'));
}
```

```dart
// app/lib/features/audit/presentation/sections/s5_pricing_promotions_screen.dart
import 'package:flutter/material.dart';

class S5PricingPromotionsScreen extends StatelessWidget {
  const S5PricingPromotionsScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('S5 Pricing & Promotions'));
}
```

```dart
// app/lib/features/audit/presentation/sections/s6_competitive_screen.dart
import 'package:flutter/material.dart';

class S6CompetitiveScreen extends StatelessWidget {
  const S6CompetitiveScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('S6 Competitive Intelligence'));
}
```

```dart
// app/lib/features/audit/presentation/sections/s7_capability_screen.dart
import 'package:flutter/material.dart';

class S7CapabilityScreen extends StatelessWidget {
  const S7CapabilityScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('S7 Sales Capability'));
}
```

```dart
// app/lib/features/audit/presentation/sections/s8_risks_screen.dart
import 'package:flutter/material.dart';

class S8RisksScreen extends StatelessWidget {
  const S8RisksScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('S8 Opportunities & Risks'));
}
```

```dart
// app/lib/features/audit/presentation/sections/s9_action_plan_screen.dart
import 'package:flutter/material.dart';

class S9ActionPlanScreen extends StatelessWidget {
  const S9ActionPlanScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('S9 Action Plan'));
}
```

```dart
// app/lib/features/audit/presentation/sections/s10_scorecard_screen.dart
import 'package:flutter/material.dart';

class S10ScorecardScreen extends StatelessWidget {
  const S10ScorecardScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('S10 Execution Scorecard'));
}
```

- [ ] **Step 4: Rebuild the audit shell as a stepper over the ten sections**

```dart
// app/lib/features/audit/presentation/audit_shell_screen.dart
import 'package:flutter/material.dart';
import 'sections/s1_outlet_info_screen.dart';
import 'sections/s2_stock_screen.dart';
import 'sections/s3_4_visibility_display_screen.dart';
import 'sections/s5_pricing_promotions_screen.dart';
import 'sections/s6_competitive_screen.dart';
import 'sections/s7_capability_screen.dart';
import 'sections/s8_risks_screen.dart';
import 'sections/s9_action_plan_screen.dart';
import 'sections/s10_scorecard_screen.dart';

class AuditShellScreen extends StatefulWidget {
  const AuditShellScreen({super.key});

  @override
  State<AuditShellScreen> createState() => _AuditShellScreenState();
}

class _AuditShellScreenState extends State<AuditShellScreen> {
  int _step = 0;

  static const _sections = [
    S1OutletInfoScreen(),
    S2StockScreen(),
    S3S4VisibilityDisplayScreen(),
    S5PricingPromotionsScreen(),
    S6CompetitiveScreen(),
    S7CapabilityScreen(),
    S8RisksScreen(),
    S9ActionPlanScreen(),
    S10ScorecardScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit Visit')),
      body: Stepper(
        currentStep: _step,
        onStepContinue: () {
          if (_step < _sections.length - 1) setState(() => _step += 1);
        },
        onStepTapped: (index) => setState(() => _step = index),
        steps: _sections
            .map((screen) => Step(title: const SizedBox.shrink(), content: screen))
            .toList(),
      ),
    );
  }
}
```

Note this implementation renders each section's title text via the section
widget itself (e.g. `S1OutletInfoScreen` renders the text `'S1 Outlet
Information'`), which the test asserts on directly regardless of Stepper
chrome.

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/features/audit/audit_shell_screen_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/audit app/test/features/audit
git commit -m "feat(app): add S1-S10 audit section stubs behind a stepper shell"
```

---

### Task 23: Dashboard shell — 8 KPI tile placeholders

**Files:**
- Modify: `app/lib/features/dashboard/presentation/dashboard_shell_screen.dart`
- Test: `app/test/features/dashboard/dashboard_shell_screen_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/dashboard/dashboard_shell_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/dashboard/presentation/dashboard_shell_screen.dart';

void main() {
  testWidgets('renders all 8 KPI tile labels', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardShellScreen()));
    const labels = [
      'Numeric Distribution',
      'Weighted Distribution',
      'OSA %',
      'Execution Score',
      'Price Compliance %',
      'Visibility Compliance %',
      'Share of Shelf',
      'Perfect Store Rate',
    ];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/dashboard/dashboard_shell_screen_test.dart`
Expected: FAIL — labels not found (screen still shows the old placeholder text)

- [ ] **Step 3: Implement the KPI grid**

```dart
// app/lib/features/dashboard/presentation/dashboard_shell_screen.dart
import 'package:flutter/material.dart';

const _kpiLabels = [
  'Numeric Distribution',
  'Weighted Distribution',
  'OSA %',
  'Execution Score',
  'Price Compliance %',
  'Visibility Compliance %',
  'Share of Shelf',
  'Perfect Store Rate',
];

class DashboardShellScreen extends StatelessWidget {
  const DashboardShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manager Dashboard')),
      body: GridView.count(
        crossAxisCount: 2,
        children: _kpiLabels
            .map((label) => Card(
                  child: Center(
                    child: Text(label, textAlign: TextAlign.center),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/dashboard/dashboard_shell_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/dashboard app/test/features/dashboard
git commit -m "feat(app): add 8-KPI dashboard tile grid (placeholders, no live data yet)"
```

---

## Track D — Docs & seed data

### Task 24: FMCG demo seed script

**Files:**
- Create: `backend/scripts/seed.ts`
- Modify: `backend/package.json` (add `seed` script)

- [ ] **Step 1: Install `ts-node` for running the seed script**

```bash
cd backend
npm install -D ts-node
```

- [ ] **Step 2: Write `backend/scripts/seed.ts`**

```ts
// backend/scripts/seed.ts
import { PrismaClient } from '@prisma/client';
import { hashPassword } from '../src/modules/auth/auth.service';

const prisma = new PrismaClient();

async function main() {
  const client = await prisma.client.upsert({
    where: { id: 'demo-fmcg-client' },
    update: {},
    create: {
      id: 'demo-fmcg-client',
      name: 'Demo FMCG Brand',
      industry: 'FMCG',
      scorecardWeights: {
        availability: 0.3,
        visibility: 0.25,
        display: 0.15,
        pricing: 0.1,
        salesCapability: 0.1,
        competitive: 0.1,
      },
      kpiThresholds: { excellent: 90, good: 70, needsImprovement: 50 },
    },
  });

  const manager = await prisma.user.upsert({
    where: { email: 'manager@demo-fmcg.tradeiq.com' },
    update: {},
    create: {
      email: 'manager@demo-fmcg.tradeiq.com',
      passwordHash: await hashPassword('demo-password-123'),
      role: 'manager',
      clientId: client.id,
    },
  });

  await prisma.user.upsert({
    where: { email: 'agent@demo-fmcg.tradeiq.com' },
    update: {},
    create: {
      email: 'agent@demo-fmcg.tradeiq.com',
      passwordHash: await hashPassword('demo-password-123'),
      role: 'field_agent',
      clientId: client.id,
    },
  });

  const outlets = [
    { name: 'Sandton Hypermarket', code: 'SAN-001', channelType: 'hypermarket', lat: -26.1076, lng: 28.0567 },
    { name: 'Rosebank Supermarket', code: 'ROS-002', channelType: 'supermarket', lat: -26.1467, lng: 28.0436 },
    { name: 'Fourways Convenience', code: 'FOU-003', channelType: 'convenience', lat: -26.0164, lng: 28.0122 },
  ];

  for (const outlet of outlets) {
    await prisma.outlet.upsert({
      where: { code: outlet.code },
      update: {},
      create: {
        ...outlet,
        territoryId: 'gauteng-north',
        teamProfile: { headcount: 4 },
        clientId: client.id,
      },
    });
  }

  await prisma.sku.upsert({
    where: { id: 'demo-sku-1' },
    update: {},
    create: {
      id: 'demo-sku-1',
      clientId: client.id,
      name: 'Demo Brand 500ml',
      category: 'Beverages',
      minFacingsStandard: 4,
      rrp: 24.99,
    },
  });

  console.log(`Seeded client ${client.name}, manager ${manager.email}, ${outlets.length} outlets, 1 SKU`);
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
```

- [ ] **Step 3: Add the `seed` script to `backend/package.json`**

```json
{
  "scripts": {
    "seed": "ts-node scripts/seed.ts"
  }
}
```

- [ ] **Step 4: Run the seed script against the local dockerized Postgres**

Run: `cd backend && npm run seed`
Expected: `Seeded client Demo FMCG Brand, manager manager@demo-fmcg.tradeiq.com, 3 outlets, 1 SKU`

- [ ] **Step 5: Commit**

```bash
git add backend/scripts backend/package.json backend/package-lock.json
git commit -m "feat(backend): add FMCG demo seed script"
```

---

### Task 25: Onboarding docs

**Files:**
- Create: `docs/onboarding/getting-started.md`
- Create: `docs/onboarding/environment-setup.md`

- [ ] **Step 1: Write `docs/onboarding/environment-setup.md`**

```markdown
# Environment Setup

## Prerequisites

- Node.js 20+
- Flutter 3.24+ (stable channel) — `flutter doctor` should show no blockers
  for the platforms you'll build for (iOS/Android/web/desktop)
- Docker Desktop (or compatible) — for local Postgres
- GitHub CLI (`gh`) — for opening issues against deferred/stubbed work

## Environment variables

Copy the root example env file for the backend:

\`\`\`bash
cp .env.example backend/.env
\`\`\`

`DATABASE_URL` and `JWT_SECRET` are read from `backend/.env` by both the
Express server and Prisma CLI. Never commit `backend/.env` — it's covered by
`.gitignore`.
```

- [ ] **Step 2: Write `docs/onboarding/getting-started.md`**

```markdown
# Getting Started

Clone, run, and see real data in under 10 minutes.

## 1. Start Postgres

\`\`\`bash
docker compose up -d
\`\`\`

## 2. Backend

\`\`\`bash
cd backend
npm install
npx prisma migrate deploy
npm run seed
npm run dev
\`\`\`

The API is now running at `http://localhost:4000`. Confirm with:

\`\`\`bash
curl http://localhost:4000/health
# {"status":"ok"}
\`\`\`

Log in as the seeded demo manager:

\`\`\`bash
curl -X POST http://localhost:4000/auth/login \\
  -H "Content-Type: application/json" \\
  -d '{"email":"manager@demo-fmcg.tradeiq.com","password":"demo-password-123"}'
\`\`\`

## 3. App

In a second terminal:

\`\`\`bash
cd app
flutter pub get
flutter run -d chrome   # or an attached device/simulator
\`\`\`

The app boots to the login screen. There's no login-flow wiring into the
router yet (see `docs/architecture/stubs-and-interfaces.md` for what's
scaffolded vs. what's a follow-up) — to see the proof-of-concept vertical
slice working end-to-end, navigate directly to `/outlets` in the running app
(e.g. via the browser address bar in the Chrome build) once you've logged in
through the `/auth/login` API call above and manually set the returned token
using the app's dev tools — full login-to-outlets wiring is tracked as
follow-up work, not part of this scaffold.

## 4. Run the test suites

\`\`\`bash
cd backend && npm test
cd app && flutter test
\`\`\`

## Troubleshooting

- **`P1001: Can't reach database server`** — Postgres isn't up yet; run
  `docker compose ps` and check the `postgres` service is `healthy`.
- **`flutter: command not found`** — install Flutter and ensure it's on your
  `PATH`; run `flutter doctor` to verify.
```

- [ ] **Step 3: Commit**

```bash
git add docs/onboarding
git commit -m "docs: add onboarding getting-started and environment-setup guides"
```

---

### Task 26: Architecture docs

**Files:**
- Create: `docs/architecture/overview.md`
- Create: `docs/architecture/data-model.md`

- [ ] **Step 1: Write `docs/architecture/overview.md`**

```markdown
# Architecture Overview

TradeIQ Phase 1 is a monorepo:

- `app/` — Flutter, single codebase for the field-agent mobile audit flow
  and the manager/admin web dashboard. State management: Riverpod.
  Offline-first: Drift (SQLite) local DB + a sync-queue table flushed by
  `core/sync/sync_service.dart` when connectivity returns.
- `backend/` — Node.js + Express + TypeScript. Prisma ORM against
  PostgreSQL. One module per data-model entity group under
  `src/modules/*`. JWT auth with role guards (`field_agent` / `manager` /
  `admin`).
- `docs/` — this documentation system.
- `scripts/` — currently just the backend demo-data seed script
  (`backend/scripts/seed.ts`, run via `npm run seed`).

## Request flow (proof-of-concept slice)

1. Agent/manager logs in via `POST /auth/login` → receives a JWT.
2. App calls `GET /outlets` with `Authorization: Bearer <token>`.
3. `requireAuth` middleware verifies the JWT and attaches `req.user`.
4. `outlets.routes.ts` calls `outlets.service.ts`, which queries Postgres via
   Prisma, scoped to `req.user.clientId`.
5. App's `OutletsListScreen` renders the response via
   `outletsListProvider` (Riverpod `FutureProvider`).

Every other S1–S10 module follows the same shape once implemented (see
`docs/architecture/stubs-and-interfaces.md` and the follow-up implementation
plan for each section).

## Real logic vs. stubbed logic

See `docs/architecture/stubs-and-interfaces.md` for the definitive list.
Short version: geofencing, SLA due-date computation, and stock coverage-days
prediction are real and shipped. Computer vision, OCR, fraud detection, and
predictive dispatch are stubbed behind interfaces pending Phase 2+.
```

- [ ] **Step 2: Write `docs/architecture/data-model.md`**

```markdown
# Data Model

Managed via Prisma — `backend/prisma/schema.prisma` is the single source of
truth. Summary of entities (see the schema file for exact fields/types):

| Entity | Purpose |
|---|---|
| `Client` | A brand/tenant. Holds `scorecardWeights` and `kpiThresholds` (jsonb), configurable per client. |
| `User` | `field_agent`, `manager`, or `admin`, scoped to one `Client`. |
| `Outlet` | A store/branch. Has lat/lng for geofencing, a `territoryId`, and a `teamProfile` jsonb blob. |
| `Sku` | A product, scoped to a `Client`, with `minFacingsStandard` and `rrp`. |
| `PlanogramTemplate` | Stub-era zone map for planogram compliance scoring (Phase 2+ CV target). |
| `PromoCalendar` | Active promotions per client, with required POSM and outlet scope. |
| `Visit` | One agent's audit visit to one outlet — the root of S1–S10 data. |
| `VisitStock` / `VisitVisibility` / `VisitPricing` / `VisitCompetitive` / `VisitCapability` / `VisitRisk` | One row (or set of rows) per `Visit`, one per audit section (S2, S3-4, S5, S6, S7, S8). |
| `Task` | Auto-created from a flagged finding; has `priority`, `slaDueAt` (via `slaClock.ts`), `ownerId`, and closure-verification fields. |
| `Photo` | GPS+timestamp-tagged photo evidence, one per required capture point. |
| `Scorecard` | The S10 weighted-total output for a `Visit`. |

## Migrations

Run `npx prisma migrate dev --name <description>` from `backend/` after any
schema change. Never hand-edit files under `backend/prisma/migrations/`.
```

- [ ] **Step 3: Commit**

```bash
git add docs/architecture/overview.md docs/architecture/data-model.md
git commit -m "docs: add architecture overview and data-model reference"
```

---

### Task 27: Stubs-and-interfaces index

**Files:**
- Create: `docs/architecture/stubs-and-interfaces.md`

- [ ] **Step 1: Write the doc, filling in the four GitHub issue URLs recorded in Task 13, Step 10**

```markdown
# Stubs and Interfaces

Everything in this table is Phase 2+ scope. Each stub lives behind a
narrow interface so a real implementation can swap in later without
touching callers.

| Capability | Stub file | Interface | Real implementation needed | Tracking issue |
|---|---|---|---|---|
| Computer vision (branding/planogram/facings/cleanliness) | `backend/src/services/vision.stub.ts` | `detectBranding`, `scorePlanogramCompliance`, `countFacings`, `scoreCleanliness` | On-device or server CV model for S3/S4 | <ISSUE_URL_1> |
| OCR price extraction | `backend/src/services/ocr.stub.ts` | `extractPriceFromPhoto` | Real OCR from a shelf-price photo for S5 | <ISSUE_URL_2> |
| Behavioural fraud / ghost-visit detection | `backend/src/services/fraud.stub.ts` | `detectGhostVisit` (currently throws, no Phase 1 caller) | Fraud/ghost-visit detection | <ISSUE_URL_3> |
| Predictive field dispatch | `backend/src/services/dispatch.stub.ts` | `dispatchNearestAgent` (currently throws, no Phase 1 caller) | Auto-assign nearest agent on share-of-shelf drop | <ISSUE_URL_4> |

## What is real (not stubbed)

- `backend/src/lib/geofence.ts` — haversine distance check, ≤50m threshold
- `backend/src/lib/slaClock.ts` — SLA due-date computation (critical=+24h, high=+3d, normal=+7d)
- `backend/src/services/forecast.service.ts` — stock coverage-days prediction from velocity (simple formula, not ML — per-SKU ML demand forecasting is Phase 2+ and has no stub yet because no Phase 1 caller needs it)
- `backend/src/modules/auth/*` — JWT issue/verify, login, role guards
- `backend/src/modules/outlets/*` — full CRUD, the one fully-wired Phase 1 module

## What is a route skeleton (not a stub, but not implemented)

`visits`, `stock`, `visibility`, `pricing`, `competitive`, `capability`,
`risks`, `tasks`, `scorecards`, and `dashboard` modules currently return
`501 Not Implemented` for every route. These are Phase 1 features (not
deferred to Phase 2+) — they're scoped to the follow-up S1–S10
implementation plan, not this scaffold. No GitHub issues are needed for
these; they're just not built yet within Phase 1's own scope.

## Deferred infrastructure (Phase 2+, no code yet)

Kafka event streaming, PostGIS (currently plain lat/lng + haversine), Redis
soft-reserve cache, territory heatmaps, campaign ROI measurement, retailer
incentive engine, and ERP/POS/API marketplace integrations have no stub
because Phase 1 has no caller for them. Track these as issues once a
Phase 2 plan identifies the first real caller.
```

- [ ] **Step 2: Replace the four `<ISSUE_URL_N>` placeholders with the actual URLs returned by `gh issue create` in Task 13, Step 10**

- [ ] **Step 3: Commit**

```bash
git add docs/architecture/stubs-and-interfaces.md
git commit -m "docs: add stubs-and-interfaces index linking Phase 2+ GitHub issues"
```

---

### Task 28: Architecture Decision Records

**Files:**
- Create: `docs/adr/0001-flutter-for-mobile-and-web.md`
- Create: `docs/adr/0002-lean-phase-1-infra.md`
- Create: `docs/adr/0003-nodejs-express-backend.md`
- Create: `docs/adr/0004-riverpod-state-management.md`
- Create: `docs/adr/0005-offline-first-drift-sync.md`
- Create: `docs/adr/0006-prisma-orm.md`

- [ ] **Step 1: Write each ADR using the same template**

```markdown
# 0001. Flutter for mobile and web

Date: 2026-07-02
Status: Accepted

## Context

The deck's original architecture specified React Native for the field-agent
mobile app and implied a separate web stack for the manager dashboard. The
team wants one codebase and one skillset across both surfaces.

## Decision

Build both the field-agent mobile app and the manager/admin dashboard as a
single Flutter codebase (`app/`), using responsive layouts to adapt between
mobile and web/desktop form factors.

## Consequences

- One team, one skillset, maximum code reuse between mobile and web.
- Flutter Web dashboards are less "native web" than a dedicated web
  framework — acceptable tradeoff for a small team's velocity.
```

```markdown
# 0002. Lean Phase 1 infrastructure

Date: 2026-07-02
Status: Accepted

## Context

The pitch deck's "Technical Foundation" slide shows Kafka, PostGIS, and Redis
as part of the platform's architecture, but that slide spans all four
roadmap phases (Foundation through Scale & Optimise), not just Phase 1.

## Decision

Build Phase 1 on plain PostgreSQL (haversine geofencing, no PostGIS), a
simple REST API (no Kafka), and no Redis cache. All Phase 2+ capabilities
(real CV/OCR/ML/fraud/dispatch, Kafka, PostGIS, Redis) sit behind narrow
service interfaces so they can be swapped in later without rewriting
callers.

## Consequences

- Faster path to a working Phase 1 demo; less ops surface for a small team
  to maintain before there's real load or real ML models to justify it.
- Some Phase 2+ work will require adding new infrastructure later — accepted
  because the interfaces are designed for that swap.
```

```markdown
# 0003. Node.js + Express backend

Date: 2026-07-02
Status: Accepted

## Context

The detailed MVP prompt specified Node.js + Express. The pitch deck's
architecture slide shows "Node.js / FastAPI" ambiguously.

## Decision

Use Node.js + Express + TypeScript, matching the detailed MVP prompt.

## Consequences

- Consistent with the original detailed spec.
- If real ML/CV models are built in Python during Phase 2+, they'll likely
  run as a separate service called from this API rather than in-process.
```

```markdown
# 0004. Riverpod for Flutter state management

Date: 2026-07-02
Status: Accepted

## Context

Needed one consistent state-management pattern across all Flutter feature
modules, chosen before any screens were built, given the app's heavy
async/offline-sync requirements.

## Decision

Use Riverpod (`flutter_riverpod`) throughout the app.

## Consequences

- Compile-safe, testable providers; strong support for the offline-first
  sync work (Task 19-20).
- New Flutter hires need to learn Riverpod specifically, not BLoC or plain
  Provider.
```

```markdown
# 0005. Offline-first with Drift + a sync queue

Date: 2026-07-02
Status: Accepted

## Context

Field agents in low-connectivity outlets need to complete a full audit visit
and see their score before leaving, without a network connection.

## Decision

Persist visit drafts locally via Drift (SQLite) and enqueue mutations in a
`SyncQueueItems` table, flushed by `SyncService` when connectivity returns.
Built into the scaffold now rather than retrofitted later.

## Consequences

- Every audit-section repository (once implemented) must write locally
  first, then enqueue a sync — this pattern needs to be followed
  consistently in the follow-up S1-S10 implementation plan.
- More upfront complexity than an online-only MVP, justified because
  retrofitting offline support after screens assume always-online is much
  more expensive.
```

```markdown
# 0006. Prisma as the backend ORM

Date: 2026-07-02
Status: Accepted

## Context

Needed to choose between raw SQL migrations (e.g. via Knex) and a
type-safe ORM, for a 16-table schema that will grow as Phase 1 features are
implemented.

## Decision

Use Prisma. `backend/prisma/schema.prisma` is the single source of truth for
the data model; migrations are generated via `prisma migrate dev`.

## Consequences

- Type-safe queries throughout `backend/src/modules/*`.
- New tables/columns require a schema.prisma edit + `prisma migrate dev`,
  not hand-written SQL — documented in `docs/architecture/data-model.md`.
```

- [ ] **Step 2: Commit**

```bash
git add docs/adr
git commit -m "docs: add ADRs for the six scaffold architecture decisions"
```

---

### Task 29: Root README, CONTRIBUTING, ONBOARDING

**Files:**
- Modify: `README.md`
- Create: `CONTRIBUTING.md`
- Create: `ONBOARDING.md`

- [ ] **Step 1: Replace `README.md`**

```markdown
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

See [`docs/onboarding/getting-started.md`](docs/onboarding/getting-started.md)
— clone to running app + backend + seeded demo data in under 10 minutes.

## Architecture

See [`docs/architecture/overview.md`](docs/architecture/overview.md) and
[`docs/architecture/stubs-and-interfaces.md`](docs/architecture/stubs-and-interfaces.md)
for what's real vs. stubbed in Phase 1.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md).
```

- [ ] **Step 2: Create `CONTRIBUTING.md`**

```markdown
# Contributing

## Commit style

Use [Conventional Commits](https://www.conventionalcommits.org/):
`feat(scope): ...`, `fix(scope): ...`, `docs: ...`, `chore: ...`, `ci: ...`.
Scope is usually `app` or `backend`.

## Before opening a PR

- `backend/`: `npm run lint && npm test`
- `app/`: `flutter analyze && flutter test`

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
```

- [ ] **Step 3: Create `ONBOARDING.md`**

```markdown
# Onboarding

Welcome to TradeIQ. Start here, in order:

1. [`docs/onboarding/environment-setup.md`](docs/onboarding/environment-setup.md) — install prerequisites
2. [`docs/onboarding/getting-started.md`](docs/onboarding/getting-started.md) — clone → running in under 10 minutes
3. [`docs/architecture/overview.md`](docs/architecture/overview.md) — how the pieces fit together
4. [`docs/architecture/data-model.md`](docs/architecture/data-model.md) — the Postgres schema
5. [`docs/architecture/stubs-and-interfaces.md`](docs/architecture/stubs-and-interfaces.md) — what's real vs. stubbed, and why
6. [`docs/adr/`](docs/adr/) — why key decisions were made (Flutter for mobile+web, lean Phase 1 infra, Node/Express, Riverpod, offline-first Drift sync, Prisma)
7. [`CONTRIBUTING.md`](CONTRIBUTING.md) — how to add a module/feature, commit style, PR checks

Then look at `backend/src/modules/outlets/` and `app/lib/features/outlets/`
— the one fully-wired vertical slice — as the template for building out the
remaining S1–S10 sections in follow-up plans.
```

- [ ] **Step 4: Commit**

```bash
git add README.md CONTRIBUTING.md ONBOARDING.md
git commit -m "docs: write root README, CONTRIBUTING, and ONBOARDING guides"
```

---

## Plan self-review notes

- **Spec coverage:** repo layout (§4) → Task 1; DB schema (§5) → Task 4;
  backend architecture incl. stubs (§6) → Tasks 8-15; Flutter architecture
  incl. offline sync (§7) → Tasks 16-23; docs/issue workflow (§8) → Tasks
  25-28; CI/testing (§9) → Tasks 5, 7; explicitly-out-of-scope items (§11)
  are respected — no task implements full S1-S10 business logic or Phase 2+
  features.
- **Placeholder scan:** the only bracketed placeholders are the four
  `<ISSUE_URL_N>` tokens in Task 27, which Task 13 Step 10 explicitly
  generates real values for before Task 27 runs — not an unresolved TBD.
- **Type consistency:** `AuthTokenPayload` (Task 10) is reused as-is by
  `outlets.routes.ts` (Task 12) and the module skeletons (Task 14) via
  `AuthedRequest`. `Outlet` (Flutter, Task 21) mirrors the JSON shape
  returned by `outlets.service.ts` (Task 12). `SyncQueueItem` (Drift-generated
  row type, Task 19) is the type `QueueFlusher.flush` (Task 20) accepts.
