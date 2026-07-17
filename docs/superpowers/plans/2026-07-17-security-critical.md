# Security Critical Remediation — Plan 1 of 4

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the four exploitable security holes found in the 2026-07-17 audit — the JWT payload cast that yields cross-tenant reads, the published default secret that makes tokens forgeable, the bcrypt-hash disclosure on the territory coverage endpoint, and the webhook SSRF — plus the 401-instead-of-404 masking that hides route mistakes.

**Architecture:** All five fixes are additive guards in existing files. No schema change, no migration, no API contract change for the Flutter client. Four of the five are confined to `backend/src/`; one adds a new pure-function library (`src/lib/urlGuard.ts`) with injected DNS so it unit-tests offline.

**Tech Stack:** Express 5 + Prisma 6 + TypeScript (strict) + Jest + supertest against a real Postgres.

**Source:** The 2026-07-17 audit (this session). Finding ids (C1/C3/H1/H6/N8) are referenced per task.

**Not in this plan** — deliberately scoped out, see `docs/ROADMAP.md`:
- **H2 (token revocation)** — needs a DB lookup in `requireAuth`, which turns 19 test files' fabricated-userId tokens into 401s, including the 16 cross-tenant tests that rely on `clientId: 'no-such-client'`. Real multi-day change; own plan.
- Backend scale (indexes, pagination, N+1) → Plan 2.
- Flutter ship-blockers → Plan 3. Design/UI integration → Plan 4.

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `backend/src/modules/auth/auth.service.ts` | Token issue/verify + secret access | Modify — validate payload; reject weak secrets |
| `backend/src/modules/auth/auth.service.test.ts` | Unit tests for the above | Modify — add payload + secret tests |
| `backend/src/modules/users/users.service.ts` | User CRUD + the safe public user shape | Modify — export `safeUserSelect` + `SafeUser` |
| `backend/src/modules/territories/territories.service.ts` | Territory queries incl. coverage | Modify — use the safe select; drop `User[]` |
| `backend/src/modules/territories/territories.routes.ts` | Territory HTTP surface | Modify — add `requireRole` to coverage |
| `backend/src/modules/territories/territories.routes.test.ts` | Territory route tests | Modify — 8 token swaps + 2 new tests |
| `backend/src/lib/urlGuard.ts` | **New** — pure URL/IP safety predicates, DNS injected | Create |
| `backend/src/lib/urlGuard.test.ts` | **New** — offline unit tests for the guard | Create |
| `backend/src/modules/webhooks/webhooks.routes.ts` | Webhook HTTP surface | Modify — use the guard on POST + PATCH |
| `backend/src/modules/webhooks/webhooks.service.ts` | Webhook persistence + dispatch | Modify — resolve+check IP, timeout, no redirects |
| `backend/src/app.ts` | App assembly + middleware order | Modify — namespace collaboration, add 404 |
| `backend/src/app.test.ts` | App-level tests | Modify — add 404 test |
| `backend/package.json` | Scripts | Modify — `NODE_ENV=development` on `dev` |

---

### Task 1: C3 — validate the JWT payload instead of casting it

**Why:** `verifyToken` does `jwt.verify(...) as AuthTokenPayload`. `jwt.verify` checks the *signature*, not the *shape*. A token signed with our secret but missing `clientId` produces `req.user.clientId === undefined`; Prisma **drops `undefined` filters from `where` clauses**, so `where: { clientId }` silently returns every tenant's rows. `strict: true` gives zero protection — the cast asserts the lie. Combined with H1 (Task 2), the secret is public, so this is remotely reachable.

**Files:**
- Modify: `backend/src/modules/auth/auth.service.ts:1-25`
- Test: `backend/src/modules/auth/auth.service.test.ts`

- [ ] **Step 1: Write the failing tests**

Replace the entire contents of `backend/src/modules/auth/auth.service.test.ts` with:

```ts
import jwt from 'jsonwebtoken';
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

  // A token can be correctly SIGNED and still carry a payload we never issued.
  // Prisma drops `undefined` from a `where` clause, so a missing clientId would
  // turn every tenant-scoped query into a cross-tenant read. Verify the shape.
  it('rejects a validly-signed token whose payload is missing clientId', () => {
    const forged = jwt.sign({ userId: 'u1', role: 'field_agent' }, process.env.JWT_SECRET!);
    expect(() => verifyToken(forged)).toThrow('Malformed token payload');
  });

  it('rejects a validly-signed token whose payload is missing userId', () => {
    const forged = jwt.sign({ role: 'manager', clientId: 'c1' }, process.env.JWT_SECRET!);
    expect(() => verifyToken(forged)).toThrow('Malformed token payload');
  });

  it('rejects a validly-signed token carrying a role outside the union', () => {
    const forged = jwt.sign(
      { userId: 'u1', role: 'superadmin', clientId: 'c1' },
      process.env.JWT_SECRET!,
    );
    expect(() => verifyToken(forged)).toThrow('Malformed token payload');
  });

  it('rejects a validly-signed token whose clientId is an empty string', () => {
    const forged = jwt.sign(
      { userId: 'u1', role: 'manager', clientId: '' },
      process.env.JWT_SECRET!,
    );
    expect(() => verifyToken(forged)).toThrow('Malformed token payload');
  });

  it('rejects a validly-signed token whose payload is a bare string', () => {
    const forged = jwt.sign('just-a-string', process.env.JWT_SECRET!);
    expect(() => verifyToken(forged)).toThrow('Malformed token payload');
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd backend && npx jest src/modules/auth/auth.service.test.ts
```

Expected: the first two tests PASS; the five new ones FAIL — they currently return a cast object instead of throwing (e.g. `Expected substring: "Malformed token payload"` / `Received function did not throw`).

- [ ] **Step 3: Implement the validation**

In `backend/src/modules/auth/auth.service.ts`, replace the `verifyToken` function (lines 23-25) with:

```ts
const ROLES = ['field_agent', 'manager', 'admin'] as const;

// `jwt.verify` proves the token was signed by us. It proves NOTHING about the
// payload's shape — the old `as AuthTokenPayload` cast simply asserted it.
// That mattered because Prisma DROPS `undefined` filters from a `where`
// clause: a signed token without `clientId` turned `where: { clientId }` into
// "return every tenant's rows". So we parse, never cast.
function parseTokenPayload(decoded: unknown): AuthTokenPayload {
  if (typeof decoded !== 'object' || decoded === null) {
    throw new Error('Malformed token payload');
  }
  const { userId, role, clientId } = decoded as Record<string, unknown>;
  if (
    typeof userId !== 'string' ||
    userId.length === 0 ||
    typeof clientId !== 'string' ||
    clientId.length === 0 ||
    typeof role !== 'string' ||
    !(ROLES as readonly string[]).includes(role)
  ) {
    throw new Error('Malformed token payload');
  }
  return { userId, clientId, role: role as AuthTokenPayload['role'] };
}

export function verifyToken(token: string): AuthTokenPayload {
  return parseTokenPayload(jwt.verify(token, getSecret()));
}
```

No caller changes are needed: `requireAuth` (`src/middleware/auth.ts:14-19`) already wraps `verifyToken` in try/catch and answers 401 on any throw.

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd backend && npx jest src/modules/auth/auth.service.test.ts
```

Expected: 7 passed.

- [ ] **Step 5: Run the full backend suite — nothing else may break**

```bash
cd backend && npm test
```

Expected: all suites pass. The 16 cross-tenant tests that mint `issueToken({ userId: 'x', role: 'field_agent', clientId: 'no-such-client' })` still pass — that payload is well-formed (all three fields are non-empty strings with a valid role); it just names a tenant with no rows, which is exactly what those tests assert.

- [ ] **Step 6: Commit**

```bash
git add backend/src/modules/auth/auth.service.ts backend/src/modules/auth/auth.service.test.ts
git commit -m "fix(backend): validate the JWT payload instead of casting it

jwt.verify proves the signature, not the shape. A signed token missing
clientId yielded req.user.clientId === undefined, and Prisma drops
undefined filters from a where clause — turning every tenant-scoped
query into a cross-tenant read. Parse the payload; reject malformed."
```

---

### Task 2: H1 — refuse to boot on a known-default or weak JWT secret

**Why:** `.env.example` ships `JWT_SECRET="dev-only-change-me"` and `docs/onboarding/environment-setup.md:20` instructs `cp .env.example backend/.env`. The value is public in the repo. `getSecret()` checks only presence. If that reaches production, anyone mints a token for any `clientId` and role. Chained with Task 1's hole (omit `clientId`) it was a full cross-tenant read with no credentials at all.

**Design note — fail safe:** the check is skipped only when `NODE_ENV` is *explicitly* `development` or `test`. An unset `NODE_ENV` (the likeliest production misconfiguration) enforces the check. Jest sets `NODE_ENV=test` automatically; the `dev` script is updated to set `development`.

**Files:**
- Modify: `backend/src/modules/auth/auth.service.ts:11-17`
- Modify: `backend/package.json:8` (the `dev` script)
- Test: `backend/src/modules/auth/auth.service.test.ts`

- [ ] **Step 1: Write the failing tests**

Append these tests inside the `describe('auth.service', ...)` block in `backend/src/modules/auth/auth.service.test.ts`, after the last test:

```ts
  describe('secret strength', () => {
    const originalSecret = process.env.JWT_SECRET;
    const originalEnv = process.env.NODE_ENV;

    afterEach(() => {
      process.env.JWT_SECRET = originalSecret;
      process.env.NODE_ENV = originalEnv;
    });

    it('refuses the published example default outside dev/test', () => {
      process.env.NODE_ENV = 'production';
      process.env.JWT_SECRET = 'dev-only-change-me';
      expect(() => issueToken(payload)).toThrow(/known default/i);
    });

    it('refuses a too-short secret outside dev/test', () => {
      process.env.NODE_ENV = 'production';
      process.env.JWT_SECRET = 'short';
      expect(() => issueToken(payload)).toThrow(/at least 32 characters/i);
    });

    // An unset NODE_ENV is the likeliest production misconfiguration, so the
    // check must FAIL SAFE — enforce unless dev/test is explicitly declared.
    it('enforces the check when NODE_ENV is unset', () => {
      delete process.env.NODE_ENV;
      process.env.JWT_SECRET = 'dev-only-change-me';
      expect(() => issueToken(payload)).toThrow(/known default/i);
    });

    it('accepts a strong secret outside dev/test', () => {
      process.env.NODE_ENV = 'production';
      process.env.JWT_SECRET = 'S'.repeat(32);
      expect(() => issueToken(payload)).not.toThrow();
    });

    it('still allows the weak dev secret when NODE_ENV=test', () => {
      process.env.NODE_ENV = 'test';
      process.env.JWT_SECRET = 'dev-only-change-me';
      expect(() => issueToken(payload)).not.toThrow();
    });

    it('still throws when the secret is absent entirely', () => {
      delete process.env.JWT_SECRET;
      expect(() => issueToken(payload)).toThrow('JWT_SECRET is not set');
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd backend && npx jest src/modules/auth/auth.service.test.ts -t "secret strength"
```

Expected: the four enforcement tests FAIL (`Received function did not throw`); the two permissive ones pass.

- [ ] **Step 3: Implement the guard**

In `backend/src/modules/auth/auth.service.ts`, replace `getSecret` (lines 11-17) with:

```ts
// Secrets we ship in the repo or that are common placeholders. `.env.example`
// carries `dev-only-change-me` and the onboarding doc says to copy it, so the
// value is public — anyone could forge a token for any tenant and role.
const KNOWN_DEFAULT_SECRETS = new Set([
  'dev-only-change-me',
  'change-me',
  'changeme',
  'secret',
  'ci-test-secret',
]);
const MIN_SECRET_LENGTH = 32;

// Fail SAFE: only an explicit dev/test declaration relaxes the check. An unset
// NODE_ENV — the likeliest production misconfiguration — is treated as prod.
function secretChecksRelaxed(): boolean {
  const env = process.env.NODE_ENV;
  return env === 'development' || env === 'test';
}

function getSecret(): string {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    throw new Error('JWT_SECRET is not set');
  }
  if (!secretChecksRelaxed()) {
    if (KNOWN_DEFAULT_SECRETS.has(secret)) {
      throw new Error(
        'JWT_SECRET is a known default published in this repository. Set a unique, random secret (32+ chars).',
      );
    }
    if (secret.length < MIN_SECRET_LENGTH) {
      throw new Error(`JWT_SECRET must be at least ${MIN_SECRET_LENGTH} characters.`);
    }
  }
  return secret;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd backend && npx jest src/modules/auth/auth.service.test.ts
```

Expected: 13 passed.

- [ ] **Step 5: Make `npm run dev` declare its environment**

In `backend/package.json`, change the `dev` script from:

```json
    "dev": "ts-node-dev --respawn src/server.ts",
```

to:

```json
    "dev": "NODE_ENV=development ts-node-dev --respawn src/server.ts",
```

Without this, local dev has an unset `NODE_ENV` and the new fail-safe guard would reject the `dev-only-change-me` in `backend/.env`.

- [ ] **Step 6: Verify local dev still boots**

```bash
cd backend && timeout 10 npm run dev
```

Expected: `TradeIQ backend listening on port 4000`. (Requires Postgres up: `docker compose up -d`.) Ctrl-C / timeout ends it.

- [ ] **Step 7: Document the production requirement**

In `.env.example`, replace the `JWT_SECRET` line with:

```
# Generate a unique secret per environment: `openssl rand -base64 48`
# The backend REFUSES to start with this placeholder unless NODE_ENV is
# explicitly `development` or `test`.
JWT_SECRET="dev-only-change-me"
```

- [ ] **Step 8: Run the full suite and commit**

```bash
cd backend && npm test
git add backend/src/modules/auth/auth.service.ts backend/src/modules/auth/auth.service.test.ts backend/package.json .env.example
git commit -m "fix(backend): refuse to boot on a known-default or weak JWT secret

.env.example ships dev-only-change-me and the onboarding doc says to copy
it, so the secret is public. getSecret() only checked presence. Reject
known defaults and secrets under 32 chars, failing safe: the check is
relaxed only when NODE_ENV is explicitly development or test."
```

---

### Task 2b: H1 (cont.) — make the guard actually fail at boot

**Added 2026-07-17 during execution.** Task 2 shipped the guard, but the implementer proved the task title was a lie: `getSecret()` is only reached lazily from `issueToken`/`verifyToken`, so with a bad secret the server **boots normally**, answers `/health` 200, and only fails at first token use — a login 500s and every authed request 401s, with `requireAuth`'s bare `catch {}` swallowing the reason so **nothing reaches the logs**. An operator deploying with the published secret sees a healthy service and mystery 401s.

That also makes the `.env.example` line Task 2 Step 7 dictated ("The backend REFUSES to start with this placeholder") factually false. This task makes it true.

**Files:**
- Modify: `backend/src/modules/auth/auth.service.ts` (export an assertion)
- Modify: `backend/src/server.ts`
- Test: `backend/src/modules/auth/auth.service.test.ts`

- [ ] **Step 1: Write the failing test**

Append inside the `describe('secret strength', ...)` block in `backend/src/modules/auth/auth.service.test.ts`:

```ts
    it('assertJwtSecretUsable throws on a known default outside dev/test', () => {
      process.env.NODE_ENV = 'production';
      process.env.JWT_SECRET = 'dev-only-change-me';
      expect(() => assertJwtSecretUsable()).toThrow(/known default/i);
    });

    it('assertJwtSecretUsable passes on a strong secret outside dev/test', () => {
      process.env.NODE_ENV = 'production';
      process.env.JWT_SECRET = 'S'.repeat(32);
      expect(() => assertJwtSecretUsable()).not.toThrow();
    });
```

Add `assertJwtSecretUsable` to the import at the top of the file.

- [ ] **Step 2: Run it to verify it fails**

```bash
npx jest src/modules/auth/auth.service.test.ts -t "assertJwtSecretUsable"
```

Expected: FAIL — `assertJwtSecretUsable is not a function` / not exported.

- [ ] **Step 3: Export the assertion**

In `backend/src/modules/auth/auth.service.ts`, add directly beneath `getSecret`:

```ts
/**
 * Validates the JWT secret at startup so a misconfigured deploy dies loudly.
 *
 * `getSecret()` is otherwise only reached lazily from issueToken/verifyToken,
 * which meant a bad secret let the process boot, serve /health, and then fail
 * every login with a 500 and every authed request with a 401 — with the reason
 * swallowed by requireAuth's catch. A bad secret should stop the process, not
 * produce a healthy-looking service that cannot authenticate anyone.
 */
export function assertJwtSecretUsable(): void {
  getSecret();
}
```

- [ ] **Step 4: Call it before listening**

In `backend/src/server.ts`, replace the file with:

```ts
import 'dotenv/config';
import { app } from './app';
import { assertJwtSecretUsable } from './modules/auth/auth.service';

// Fail fast and loudly: a published or weak JWT_SECRET must stop the process
// here, not surface later as unexplainable 401s.
assertJwtSecretUsable();

const port = process.env.PORT ? Number(process.env.PORT) : 4000;

app.listen(port, () => {
  console.log(`TradeIQ backend listening on port ${port}`);
});
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
npx jest src/modules/auth/auth.service.test.ts
```

Expected: 15 passed.

- [ ] **Step 6: Prove the boot actually fails now**

```bash
cd backend && NODE_ENV=production JWT_SECRET=dev-only-change-me npx ts-node src/server.ts; echo "exit=$?"
```

Expected: a thrown `JWT_SECRET is a known default published in this repository...`, a non-zero exit, and **no** "listening on port" line.

Then confirm normal dev still boots:

```bash
cd backend && timeout 10 npm run dev
```

Expected: `TradeIQ backend listening on port 4000`.

- [ ] **Step 7: Run the suite and commit**

```bash
npm run lint && npm test
git add backend/src/modules/auth/auth.service.ts backend/src/modules/auth/auth.service.test.ts backend/src/server.ts
git commit -m "fix(backend): fail at boot on a bad JWT secret, not at first login

The Task 2 guard was only reached lazily from issueToken/verifyToken, so a
published secret let the server boot healthy and then 500 every login and
401 every request with the reason swallowed. Assert the secret before
listen() so a misconfigured deploy dies loudly, which is also what
.env.example now promises."
```

---

### Task 3: C1 — stop returning every agent's bcrypt hash from territory coverage

**Why:** `getTerritoryCoverage` does `include: { user: true }`, which selects **every** `User` scalar including `passwordHash` (`prisma/schema.prisma:66`), types the result `agents: User[]`, and returns it verbatim. `GET /territories/:id/coverage` has router-level `requireAuth` but **no `requireRole`** — so any field agent dumps every colleague's bcrypt hash (offline-crackable → manager/admin takeover) plus last-known GPS. The other three routes on this router *are* role-guarded; this one was missed. `/users` already defines a `safeUserSelect` to hide exactly this field — we reuse it so one allowlist governs every user-shaped response.

**Client impact: none.** `/territories` is already in the app router's `managerOnly` set (`app/lib/core/router/app_router.dart:69`), so field agents never legitimately reach it. `TerritoryCoverage.fromJson` reads only `agents.length` (`app/lib/features/territories/data/territories_repository.dart:50`), so narrowing the fields breaks no client parsing.

**Files:**
- Modify: `backend/src/modules/users/users.service.ts:10-16`
- Modify: `backend/src/modules/territories/territories.service.ts:63-122`
- Modify: `backend/src/modules/territories/territories.routes.ts:75`
- Test: `backend/src/modules/territories/territories.routes.test.ts`

- [ ] **Step 1: Write the failing tests**

In `backend/src/modules/territories/territories.routes.test.ts`, add these two tests immediately after the `'returns coverage with matching outlets and assigned agents'` test (which ends around line 185):

```ts
  it('never exposes passwordHash on the agents in a coverage response', async () => {
    const territory = await prisma.territory.create({
      data: { clientId, name: 'TERR-NoHash', code: 'TERR-NOHASH' },
    });
    const assigned = await prisma.user.create({
      data: {
        email: 'TERR-hash-victim@example.com',
        passwordHash: 'super-secret-bcrypt-hash',
        role: 'manager',
        clientId,
      },
    });
    await prisma.userTerritory.create({
      data: { userId: assigned.id, territoryId: territory.id },
    });

    const res = await request(app)
      .get(`/territories/${territory.id}/coverage`)
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    const agents = res.body.agents as Array<Record<string, unknown>>;
    expect(agents.length).toBeGreaterThan(0);
    for (const agent of agents) {
      expect(agent).not.toHaveProperty('passwordHash');
    }
    // The whole serialized body, not just the parsed field — a hash must not
    // reach the wire by any path.
    expect(JSON.stringify(res.body)).not.toContain('super-secret-bcrypt-hash');
  });

  it('forbids a field agent from reading territory coverage', async () => {
    const territory = await prisma.territory.create({
      data: { clientId, name: 'TERR-AgentForbidden', code: 'TERR-FORBID' },
    });

    const res = await request(app)
      .get(`/territories/${territory.id}/coverage`)
      .set('Authorization', `Bearer ${agentToken}`);

    expect(res.status).toBe(403);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd backend && npx jest src/modules/territories --runInBand
```

Expected: `'never exposes passwordHash'` FAILS (`expect(received).not.toHaveProperty("passwordHash")`); `'forbids a field agent'` FAILS (`Expected: 403, Received: 200`).

- [ ] **Step 3: Export the safe user shape from the users module**

In `backend/src/modules/users/users.service.ts`, change line 10 from:

```ts
const safeUserSelect = {
```

to:

```ts
export const safeUserSelect = {
```

Then add this type export directly beneath the `satisfies Prisma.UserSelect;` line (after line 16):

```ts
/** A user as it may be exposed over the wire — never carries passwordHash. */
export type SafeUser = Prisma.UserGetPayload<{ select: typeof safeUserSelect }>;
```

- [ ] **Step 4: Use the safe select in territory coverage**

In `backend/src/modules/territories/territories.service.ts`:

**(a)** Add to the imports at the top of the file:

```ts
import { safeUserSelect, SafeUser } from '../users/users.service';
```

**(b)** Change the return-type annotation on line 71 from:

```ts
  agents: User[];
```

to:

```ts
  agents: SafeUser[];
```

**(c)** Replace the assignments query (lines 82-86):

```ts
  const assignments = await prisma.userTerritory.findMany({
    where: { territoryId: territory.id },
    include: { user: true },
  });
  const agents = assignments.map((assignment) => assignment.user);
```

with:

```ts
  // `include: { user: true }` selects EVERY User scalar — passwordHash included
  // — and this endpoint returned it to any authenticated caller. Select the
  // same allowlist /users uses, so one definition governs every user-shaped
  // response.
  const assignments = await prisma.userTerritory.findMany({
    where: { territoryId: territory.id },
    select: { user: { select: safeUserSelect } },
  });
  const agents = assignments.map((assignment) => assignment.user);
```

**(d)** If `User` is now an unused import from `@prisma/client`, remove it from the import list — `npm run lint` will flag it.

- [ ] **Step 5: Add the missing role guard**

In `backend/src/modules/territories/territories.routes.ts`, change line 75 from:

```ts
territoriesRouter.get('/:id/coverage', async (req: AuthedRequest, res) => {
```

to:

```ts
// Coverage exposes per-agent assignment and outlet-level visit data — a
// management view. The other mutating routes on this router are already
// manager/admin; this read was the one that was missed.
territoriesRouter.get(
  '/:id/coverage',
  requireRole('manager', 'admin'),
  async (req: AuthedRequest, res) => {
```

and close the new argument list — change the route's final line (currently `});` at line 98) to:

```ts
  },
);
```

- [ ] **Step 6: Update the 8 coverage tests that used an agent token**

`requireRole('manager','admin')` now 403s a field agent. Eight existing coverage assertions mint `agentToken`. In `backend/src/modules/territories/territories.routes.test.ts`, change `Bearer ${agentToken}` to `Bearer ${managerToken}` on these lines **only** — they are all `/coverage` requests:

- line 174, 260, 268, 314, 330, 341, 351, 388

Leave every other `agentToken` use untouched (lines 92 and 108 test `GET /territories` list access for agents, which is still allowed and must keep passing).

- [ ] **Step 7: Run the territory tests to verify they pass**

```bash
cd backend && npx jest src/modules/territories --runInBand
```

Expected: all pass, including the two new tests.

- [ ] **Step 8: Run the full suite, lint, and commit**

```bash
cd backend && npm run lint && npm test
git add backend/src/modules/users/users.service.ts backend/src/modules/territories/
git commit -m "fix(backend): stop returning every agent's bcrypt hash from territory coverage

include: { user: true } selects every User scalar — passwordHash included
— and GET /territories/:id/coverage had no requireRole, so any field agent
could dump colleagues' hashes and GPS. Reuse the /users safeUserSelect
allowlist and gate the route to manager/admin, matching the app router,
which already treats /territories as manager-only."
```

---

### Task 4: H6 — block SSRF in webhook registration and dispatch

**Why:** the only URL check is `!url.startsWith('http')` (`webhooks.routes.ts:24`, and the same check on PATCH at line 59), and the value is fetched at `webhooks.service.ts:116`. A manager/admin on any tenant can register `http://169.254.169.254/latest/meta-data/` or `http://localhost:6379/` and make the server POST attacker-chosen JSON to it. The response is discarded, so it's *blind* SSRF — still good for hitting internal write endpoints and port-scanning by timing.

**Design:** two layers, because DNS can change between registration and fire (rebinding).
- **Registration** (sync, offline, no DNS): parse with `new URL()`, require http/https, reject a hostname that is a *literal* private IP. Keeps route handlers fast and tests network-free.
- **Dispatch** (async, the security boundary): resolve the hostname and reject private addresses, add `redirect: 'manual'` (Node follows redirects by default — a 302 to `169.254.169.254` bypasses any hostname allowlist), and add a timeout (which also fixes H7's 300s hang on the visit-submit path).

**Files:**
- Create: `backend/src/lib/urlGuard.ts`
- Create: `backend/src/lib/urlGuard.test.ts`
- Modify: `backend/src/modules/webhooks/webhooks.routes.ts:22-34` and `:57-67`
- Modify: `backend/src/modules/webhooks/webhooks.service.ts:99-120`

- [ ] **Step 1: Write the failing tests**

Create `backend/src/lib/urlGuard.test.ts`:

```ts
import { isPrivateAddress, parsePublicHttpUrl, assertPublicHostname } from './urlGuard';

describe('isPrivateAddress', () => {
  it.each([
    '127.0.0.1',
    '10.0.0.1',
    '172.16.0.1',
    '172.31.255.255',
    '192.168.1.1',
    '169.254.169.254', // cloud metadata
    '0.0.0.0',
    '224.0.0.1',
    '::1',
    'fd00::1',
    'fe80::1',
    '::ffff:127.0.0.1', // IPv4-mapped loopback
  ])('treats %s as private', (ip) => {
    expect(isPrivateAddress(ip)).toBe(true);
  });

  it.each(['8.8.8.8', '1.1.1.1', '93.184.216.34', '2606:2800:220:1::248'])(
    'treats %s as public',
    (ip) => {
      expect(isPrivateAddress(ip)).toBe(false);
    },
  );

  it('does not treat 172.32.x as private (boundary above the RFC1918 block)', () => {
    expect(isPrivateAddress('172.32.0.1')).toBe(false);
  });

  it('does not treat 11.x as private (boundary above the 10/8 block)', () => {
    expect(isPrivateAddress('11.0.0.1')).toBe(false);
  });
});

describe('parsePublicHttpUrl', () => {
  it('accepts an ordinary https url', () => {
    expect(parsePublicHttpUrl('https://example.com/hook')?.hostname).toBe('example.com');
  });

  it('accepts an ordinary http url', () => {
    expect(parsePublicHttpUrl('http://example.com/hook')?.hostname).toBe('example.com');
  });

  it.each([
    'ftp://example.com/hook',
    'file:///etc/passwd',
    'javascript:alert(1)',
    'not-a-url',
    '',
    // `startsWith('http')` — the old check — accepted every one of these:
    'http://169.254.169.254/latest/meta-data/',
    'http://127.0.0.1:6379/',
    'http://localhost:6379/',
    'http://[::1]:6379/',
    'http://10.0.0.5/internal',
    'httpfoo://example.com',
  ])('rejects %s', (raw) => {
    expect(parsePublicHttpUrl(raw)).toBeNull();
  });
});

describe('assertPublicHostname', () => {
  it('resolves and accepts a public address', async () => {
    const lookup = jest.fn().mockResolvedValue([{ address: '93.184.216.34', family: 4 }]);
    await expect(assertPublicHostname('example.com', lookup)).resolves.toBeUndefined();
    expect(lookup).toHaveBeenCalledWith('example.com', { all: true });
  });

  it('rejects a hostname that resolves to a private address (DNS rebinding)', async () => {
    const lookup = jest.fn().mockResolvedValue([{ address: '169.254.169.254', family: 4 }]);
    await expect(assertPublicHostname('evil.example.com', lookup)).rejects.toThrow(
      /resolves to a private address/i,
    );
  });

  it('rejects when ANY resolved address is private', async () => {
    const lookup = jest.fn().mockResolvedValue([
      { address: '93.184.216.34', family: 4 },
      { address: '10.0.0.1', family: 4 },
    ]);
    await expect(assertPublicHostname('split.example.com', lookup)).rejects.toThrow(
      /resolves to a private address/i,
    );
  });

  it('rejects when the hostname does not resolve at all', async () => {
    const lookup = jest.fn().mockRejectedValue(new Error('ENOTFOUND'));
    await expect(assertPublicHostname('nope.example.com', lookup)).rejects.toThrow(
      /could not be resolved/i,
    );
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd backend && npx jest src/lib/urlGuard.test.ts
```

Expected: FAIL — `Cannot find module './urlGuard'`.

- [ ] **Step 3: Implement the guard**

Create `backend/src/lib/urlGuard.ts`:

```ts
import { lookup as dnsLookup } from 'dns/promises';
import { isIP } from 'net';

/**
 * SSRF guards for outbound URLs the user controls (today: webhook targets).
 *
 * Two layers, because DNS is not stable between registration and fire:
 *   - `parsePublicHttpUrl` — sync shape check at registration. No DNS, so
 *     route handlers stay fast and their tests need no network.
 *   - `assertPublicHostname` — the real boundary, called immediately before
 *     `fetch`. Takes an injected lookup so it unit-tests offline.
 */

export type LookupFn = (
  hostname: string,
  options: { all: true },
) => Promise<Array<{ address: string; family: number }>>;

function isPrivateIpv4(ip: string): boolean {
  const parts = ip.split('.').map(Number);
  if (parts.length !== 4 || parts.some((p) => Number.isNaN(p))) return true; // unparseable → deny
  const [a, b] = parts as [number, number, number, number];
  if (a === 0) return true; // "this network"
  if (a === 10) return true; // RFC1918
  if (a === 127) return true; // loopback
  if (a === 169 && b === 254) return true; // link-local + cloud metadata
  if (a === 172 && b >= 16 && b <= 31) return true; // RFC1918
  if (a === 192 && b === 168) return true; // RFC1918
  if (a >= 224) return true; // multicast + reserved
  return false;
}

function isPrivateIpv6(ip: string): boolean {
  const v = ip.toLowerCase().split('%')[0]!; // strip any zone index
  if (v === '::1' || v === '::') return true;
  if (v.startsWith('::ffff:')) {
    const mapped = v.slice('::ffff:'.length);
    return isIP(mapped) === 4 ? isPrivateIpv4(mapped) : true;
  }
  if (v.startsWith('fc') || v.startsWith('fd')) return true; // unique-local
  if (v.startsWith('fe80')) return true; // link-local
  return false;
}

/** True for loopback, RFC1918, link-local, unique-local, multicast and reserved. */
export function isPrivateAddress(ip: string): boolean {
  const family = isIP(ip);
  if (family === 4) return isPrivateIpv4(ip);
  if (family === 6) return isPrivateIpv6(ip);
  return true; // not an IP at all → deny
}

/**
 * Parses a user-supplied webhook URL. Returns null when it is not a plain
 * http(s) URL or when its host is a literal private address.
 *
 * The check this replaces was `url.startsWith('http')`, which accepted
 * `http://169.254.169.254/`, `http://localhost:6379/` and `httpfoo://…`.
 */
export function parsePublicHttpUrl(raw: string): URL | null {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return null;
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') return null;

  // `new URL('http://[::1]/')` gives hostname '[::1]' — unwrap before isIP.
  const host = url.hostname.replace(/^\[|\]$/g, '');
  if (host.length === 0) return null;
  if (host.toLowerCase() === 'localhost') return null;
  if (isIP(host) !== 0 && isPrivateAddress(host)) return null;
  return url;
}

/**
 * Resolves `hostname` and throws unless every address is public. Call this
 * immediately before fetching — a name that was public at registration can
 * point at 169.254.169.254 by the time the event fires.
 */
export async function assertPublicHostname(
  hostname: string,
  lookup: LookupFn = dnsLookup as unknown as LookupFn,
): Promise<void> {
  const host = hostname.replace(/^\[|\]$/g, '');
  if (isIP(host) !== 0) {
    if (isPrivateAddress(host)) {
      throw new Error(`Webhook host ${hostname} resolves to a private address`);
    }
    return;
  }

  let addresses: Array<{ address: string }>;
  try {
    addresses = await lookup(host, { all: true });
  } catch {
    throw new Error(`Webhook host ${hostname} could not be resolved`);
  }
  if (addresses.length === 0) {
    throw new Error(`Webhook host ${hostname} could not be resolved`);
  }
  for (const { address } of addresses) {
    if (isPrivateAddress(address)) {
      throw new Error(`Webhook host ${hostname} resolves to a private address`);
    }
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd backend && npx jest src/lib/urlGuard.test.ts
```

Expected: all pass.

- [ ] **Step 5: Write the failing route tests**

In `backend/src/modules/webhooks/webhooks.routes.test.ts`, add these tests inside the `POST /webhooks` describe block, right after the existing `'rejects a non-http url'` test (around line 66):

```ts
    it.each([
      'http://169.254.169.254/latest/meta-data/',
      'http://127.0.0.1:6379/',
      'http://localhost:6379/',
      'http://10.0.0.5/internal',
    ])('rejects the SSRF target %s', async (url) => {
      const res = await request(app)
        .post('/webhooks')
        .set('Authorization', `Bearer ${managerToken}`)
        .send({ url, event: 'order.created' });
      expect(res.status).toBe(400);
    });

    it('rejects an SSRF target on PATCH too', async () => {
      const created = await request(app)
        .post('/webhooks')
        .set('Authorization', `Bearer ${managerToken}`)
        .send({ url: 'https://example.com/hook', event: 'order.created' });
      expect(created.status).toBe(201);

      const res = await request(app)
        .patch(`/webhooks/${created.body.id}`)
        .set('Authorization', `Bearer ${managerToken}`)
        .send({ url: 'http://169.254.169.254/' });
      expect(res.status).toBe(400);
    });
```

- [ ] **Step 6: Run them to verify they fail**

```bash
cd backend && npx jest src/modules/webhooks --runInBand
```

Expected: the five new cases FAIL with `Expected: 400, Received: 201` / `200` — `startsWith('http')` accepts every one.

- [ ] **Step 7: Use the guard in both routes**

In `backend/src/modules/webhooks/webhooks.routes.ts`:

**(a)** Add to the imports:

```ts
import { parsePublicHttpUrl } from '../../lib/urlGuard';
```

**(b)** In the POST handler, replace the validation block (lines 22-34) with:

```ts
  if (
    typeof url !== 'string' ||
    parsePublicHttpUrl(url) === null ||
    typeof event !== 'string' ||
    event.length === 0 ||
    (secret !== undefined && typeof secret !== 'string')
  ) {
    res.status(400).json({
      error:
        'url must be a public http(s) URL (private and link-local addresses are rejected) and event is required; secret must be a string when given',
    });
    return;
  }
```

**(c)** In the PATCH handler, replace the `url` clause on line 59:

```ts
    (url !== undefined && (typeof url !== 'string' || !url.startsWith('http'))) ||
```

with:

```ts
    (url !== undefined && (typeof url !== 'string' || parsePublicHttpUrl(url) === null)) ||
```

and update that handler's error message (line 64-65) to:

```ts
      error:
        'active must be a boolean, url (when given) must be a public http(s) URL, and event must be a non-empty string',
```

- [ ] **Step 8: Harden the dispatch itself**

In `backend/src/modules/webhooks/webhooks.service.ts`:

**(a)** Add to the imports:

```ts
import { assertPublicHostname } from '../../lib/urlGuard';
```

**(b)** Replace the `await fetch(...)` line (line 116) with:

```ts
        // The real SSRF boundary. A name that was public at registration can
        // point at 169.254.169.254 by the time the event fires, so re-resolve
        // here. `redirect: 'manual'` matters just as much: Node follows
        // redirects by default, so a 302 to the metadata service would walk
        // straight through a hostname check.
        await assertPublicHostname(new URL(webhook.url).hostname);
        await fetch(webhook.url, {
          method: 'POST',
          headers,
          body,
          redirect: 'manual',
          // Without this, undici waits ~300s for headers. Visit submit awaits
          // this dispatch, so one hung subscriber held a field agent's submit
          // open for five minutes (audit H7).
          signal: AbortSignal.timeout(5000),
        });
```

The surrounding `try { … } catch { /* best-effort */ }` (lines 101, 117-119) already swallows the throw, so a rejected host silently skips that subscriber without breaking the caller — which is the existing, documented contract.

- [ ] **Step 9: Run the webhook tests to verify they pass**

```bash
cd backend && npx jest src/modules/webhooks --runInBand
```

Expected: all pass. The existing `'rejects a non-http url'` test (`ftp://example.com/hook`) still passes — `parsePublicHttpUrl` rejects a non-http(s) protocol. Existing `https://example.com/hook` registrations still succeed: registration does no DNS.

- [ ] **Step 10: Run the full suite and commit**

```bash
cd backend && npm run lint && npm test
git add backend/src/lib/urlGuard.ts backend/src/lib/urlGuard.test.ts backend/src/modules/webhooks/
git commit -m "fix(backend): block SSRF in webhook registration and dispatch

The only check was url.startsWith('http'), which accepted
http://169.254.169.254/ and http://localhost:6379/. Validate the URL
shape at registration and re-resolve the host immediately before fetch,
rejecting private/link-local addresses. Add redirect: 'manual' (Node
follows redirects, bypassing any host check) and a 5s timeout, which also
caps the 300s tail a hung subscriber put on visit submit."
```

---

### Task 5: N8 — return 404 for unknown routes instead of 401

**Why:** `app.use('/', collaborationRouter)` (`app.ts:89`) mounts a router at the root whose first middleware is `requireAuth` (`collaboration.routes.ts:13`). Because a path-less `.use()` matches every path under its mount point, an unauthenticated request to *any* unknown route hits that guard and gets `401 {"error":"Missing bearer token"}`. There is no catch-all 404. A typo'd or mis-mounted route is therefore indistinguishable from a bad token — a debugging trap, and it silently applies auth to anything mounted after line 89.

**Client impact: none.** The Flutter client calls `/messages` and `/announcements` (`app/lib/features/collaboration/data/collaboration_repository.dart:57,67,73`), so the mount must keep those exact paths. Mounting the router twice at the two real prefixes preserves them.

**Files:**
- Modify: `backend/src/app.ts:89`, and the end of the file
- Test: `backend/src/app.test.ts`

- [ ] **Step 1: Write the failing tests**

In `backend/src/app.test.ts`, add:

```ts
  it('answers 404 — not 401 — for an unknown route', async () => {
    const res = await request(app).get('/definitely-not-a-real-route');
    expect(res.status).toBe(404);
    expect(res.body).toEqual({ error: 'Not found' });
  });

  it('still answers 401 for a real protected route with no token', async () => {
    const res = await request(app).get('/outlets');
    expect(res.status).toBe(401);
  });
```

(If `request` and `app` are not already imported in this file, add `import request from 'supertest';` and `import { app } from './app';`.)

- [ ] **Step 2: Run them to verify the first fails**

```bash
cd backend && npx jest src/app.test.ts
```

Expected: `'answers 404'` FAILS with `Expected: 404, Received: 401`. The 401 test passes.

- [ ] **Step 3: Namespace the collaboration mount**

In `backend/src/app.ts`, replace line 89:

```ts
app.use('/', collaborationRouter);
```

with:

```ts
// Mounted at the two real prefixes rather than at '/'. The root mount meant
// collaboration's own `requireAuth` ran for EVERY path that reached it, so an
// unknown route answered 401 instead of 404 and anything mounted below here
// silently inherited auth. The Flutter client calls /messages and
// /announcements, so those paths must not change.
app.use('/messages', collaborationRouter);
app.use('/announcements', collaborationRouter);
```

This works because the router's own routes are declared as `/messages`, `/messages/:id/read` and `/announcements` — mounting it at `/messages` would make those `/messages/messages`. So the router's internal paths must be re-rooted in Step 4.

- [ ] **Step 4: Re-root the collaboration router's own paths**

In `backend/src/modules/collaboration/collaboration.routes.ts`, the router is now mounted at each prefix, so its paths become relative. Change:

- line 15: `collaborationRouter.post('/messages', …)` → `messagesRouter.post('/', …)`
- line 41: `collaborationRouter.get('/messages', …)` → `messagesRouter.get('/', …)`
- line 49: `collaborationRouter.patch('/messages/:id/read', …)` → `messagesRouter.patch('/:id/read', …)`
- line 59: `collaborationRouter.post('/announcements', …)` → `announcementsRouter.post('/', …)`
- line 84: `collaborationRouter.get('/announcements', …)` → `announcementsRouter.get('/', …)`

Replace the router declaration (lines 12-13):

```ts
export const collaborationRouter = Router();
collaborationRouter.use(requireAuth);
```

with:

```ts
export const messagesRouter = Router();
messagesRouter.use(requireAuth);

export const announcementsRouter = Router();
announcementsRouter.use(requireAuth);
```

Then in `backend/src/app.ts`, update the import on line 29:

```ts
import { collaborationRouter } from './modules/collaboration/collaboration.routes';
```

to:

```ts
import {
  announcementsRouter,
  messagesRouter,
} from './modules/collaboration/collaboration.routes';
```

and the mount from Step 3 to:

```ts
app.use('/messages', messagesRouter);
app.use('/announcements', announcementsRouter);
```

- [ ] **Step 5: Add the catch-all 404**

In `backend/src/app.ts`, insert this immediately **before** `app.use(errorHandler);` (line 98):

```ts
// Every route is mounted above. Anything reaching here does not exist — say so,
// rather than letting it fall through to a misleading 401 or a hanging request.
app.use((_req, res) => {
  res.status(404).json({ error: 'Not found' });
});
```

Order matters: this must sit after all routers and before `errorHandler`.

- [ ] **Step 6: Run the tests to verify they pass**

```bash
cd backend && npx jest src/app.test.ts src/modules/collaboration --runInBand
```

Expected: all pass — including the existing collaboration tests, which call `/messages` and `/announcements` and must be unaffected.

- [ ] **Step 7: Run the full suite, lint, and commit**

```bash
cd backend && npm run lint && npm test
git add backend/src/app.ts backend/src/app.test.ts backend/src/modules/collaboration/
git commit -m "fix(backend): 404 unknown routes instead of 401

app.use('/', collaborationRouter) mounted a requireAuth-guarded router at
the root, so every unknown path answered 401 and anything mounted after it
silently inherited auth. Mount messages/announcements at their own
prefixes and add a catch-all 404 before the error handler. The client's
/messages and /announcements paths are unchanged."
```

---

### Task 6: Verify the whole plan end-to-end

- [ ] **Step 1: Full gate**

```bash
cd backend && npm run lint && npm run typecheck && npm test
```

Expected: lint clean, typecheck clean, all suites pass.

- [ ] **Step 2: Prove C1 is actually closed against a running server**

```bash
cd backend && docker compose -f ../docker-compose.yml up -d && npm run dev &
# Wait for "listening on port 4000", then with a field-agent token:
curl -s localhost:4000/territories/<id>/coverage -H "Authorization: Bearer <agent-token>" | head -c 200
```

Expected: `{"error":"Forbidden"}` with status 403 — not a body containing `passwordHash`.

- [ ] **Step 3: Prove C3 is closed**

```bash
cd backend && node -e "
const jwt = require('jsonwebtoken');
console.log(jwt.sign({ userId: 'u1', role: 'field_agent' }, 'dev-only-change-me'));
"
# Then:
curl -s -o /dev/null -w "%{http_code}\n" localhost:4000/outlets -H "Authorization: Bearer <that-token>"
```

Expected: `401`. Before this plan it returned `200` with every tenant's outlets.

- [ ] **Step 4: Update the status doc**

Tick the Plan 1 rows in `docs/ROADMAP.md` under "Security remediation (2026-07-17 audit)".

---

## Self-Review

**Spec coverage.** Audit findings claimed by this plan: C3 → Task 1. H1 → Task 2. C1 → Task 3. H6 + the H7 timeout half → Task 4. N8 → Task 5. Explicitly deferred with a reason recorded above: H2 (own plan), Plan 2/3/4 scope, and the three ticketed structural items.

**Type consistency.** `safeUserSelect` and `SafeUser` are defined in Task 3 Step 3 and consumed in Step 4 under those exact names. `parsePublicHttpUrl`, `isPrivateAddress`, `assertPublicHostname` and `LookupFn` are defined in Task 4 Step 3 and used under those names in the tests (Step 1) and callers (Steps 7-8). `messagesRouter`/`announcementsRouter` are introduced in Task 5 Step 4 and imported under those names in the same step.

**Known ordering constraint.** Task 5 Step 3 is superseded by Step 4 — Step 3 alone leaves the paths doubled (`/messages/messages`). Execute Steps 3 and 4 together, and rely on Step 6's collaboration tests to catch it if not.

**Residual risk this plan does NOT close:** a valid token for a deactivated or demoted user still works for up to 12h (H2). That is the largest remaining auth gap after this plan, and it is deliberately deferred, not forgotten.
