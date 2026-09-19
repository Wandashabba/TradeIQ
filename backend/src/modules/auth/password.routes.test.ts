import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { comparePassword, hashPassword, issueToken, Role } from './auth.service';
import { RESET_CODE_MAX_ATTEMPTS } from './password.service';

/**
 * Changing, setting and resetting a password, end to end (#400).
 *
 * ## Budgets, because the limiters are real here
 *
 * `POST /auth/change-password` and `POST /users/:id/password` share one
 * per-USER bucket of 10 per window, so every case that needs more than a
 * handful of attempts gets its own actor. `POST /auth/reset-password` is capped
 * at 8 per EMAIL, which is why the wrong-code cases below each use a fresh
 * agent. The per-IP cap (60) is shared with everything else in this worker; the
 * file stays well under it, and the limiters' own behaviour is proved in
 * rateLimit.password.test.ts with tiny explicit limits instead of by exhausting
 * the real ones here.
 *
 * ## Why nothing here calls POST /auth/login
 *
 * That route is IP-rate-limited at 10 per window for the whole worker process,
 * and auth.routes.test.ts and users.routes.test.ts already spend nine of them
 * between them. A suite that "just checks the new password works" by logging in
 * would 429 whichever file happened to run after it, somewhere else entirely.
 *
 * `storedPasswordIs` asserts the same thing more directly and for free: it
 * bcrypt-compares against the hash actually in the row, which is what login
 * itself would do.
 */

/** True when `password` is the one stored for that user. What login checks. */
async function storedPasswordIs(userId: string, password: string): Promise<boolean> {
  const row = await prisma.user.findUnique({
    where: { id: userId },
    omit: { passwordHash: false },
  });
  return comparePassword(password, row!.passwordHash);
}

const PASSWORD = 'first-password-of-mine';
const NEW_PASSWORD = 'a second good passphrase';

let counter = 0;

async function makeUser(
  clientId: string,
  role: Role,
  options: { password?: string; active?: boolean } = {},
) {
  counter += 1;
  const email = `pw-${role}-${counter}-${Date.now()}@example.test`;
  const user = await prisma.user.create({
    data: {
      email,
      passwordHash: await hashPassword(options.password ?? PASSWORD),
      role,
      clientId,
      active: options.active ?? true,
    },
  });
  return {
    id: user.id,
    email,
    clientId,
    token: issueToken({ userId: user.id, role, clientId }),
  };
}

async function makeClient(label: string) {
  const client = await prisma.client.create({
    data: { name: `PW-${label}-${Date.now()}`, industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
  });
  return client.id;
}

/** Issue a code as the given manager and hand back the plaintext. */
async function codeFor(managerToken: string, targetId: string) {
  const res = await request(app)
    .post(`/users/${targetId}/password-reset-code`)
    .set('Authorization', `Bearer ${managerToken}`);
  expect(res.status).toBe(201);
  return res.body.code as string;
}

describe('password change and reset (#400)', () => {
  let clientId: string;
  let otherClientId: string;
  let admin: Awaited<ReturnType<typeof makeUser>>;
  let manager: Awaited<ReturnType<typeof makeUser>>;
  let otherManager: Awaited<ReturnType<typeof makeUser>>;
  let otherAgent: Awaited<ReturnType<typeof makeUser>>;

  beforeAll(async () => {
    clientId = await makeClient('Main');
    otherClientId = await makeClient('Other');
    admin = await makeUser(clientId, 'admin');
    manager = await makeUser(clientId, 'manager');
    otherManager = await makeUser(otherClientId, 'manager');
    otherAgent = await makeUser(otherClientId, 'field_agent');
  });

  afterAll(async () => {
    for (const id of [clientId, otherClientId]) {
      await prisma.passwordResetCode.deleteMany({ where: { clientId: id } });
      await prisma.passwordChangeEvent.deleteMany({ where: { clientId: id } });
      await prisma.user.deleteMany({ where: { clientId: id } });
      await prisma.client.delete({ where: { id } });
    }
    await prisma.$disconnect();
  });

  describe('POST /auth/change-password', () => {
    it('stores the new password and stops accepting the old one', async () => {
      const agent = await makeUser(clientId, 'field_agent');

      const res = await request(app)
        .post('/auth/change-password')
        .set('Authorization', `Bearer ${agent.token}`)
        .send({ currentPassword: PASSWORD, newPassword: NEW_PASSWORD });

      expect(res.status).toBe(200);
      // Said out loud rather than left to be assumed: tokens are stateless 12h
      // JWTs, so this cannot end the account's other sessions.
      expect(res.body).toEqual({ otherSessionsEnded: false });

      const stored = await prisma.user.findUnique({
        where: { id: agent.id },
        omit: { passwordHash: false },
      });
      // Hashed, never stored as typed.
      expect(stored!.passwordHash).not.toBe(NEW_PASSWORD);
      expect(await storedPasswordIs(agent.id, NEW_PASSWORD)).toBe(true);
      expect(await storedPasswordIs(agent.id, PASSWORD)).toBe(false);
    });

    // The token in hand is not proof the person holding the phone is the owner.
    // On shared handsets left unlocked, that is the ordinary case.
    it('refuses a wrong current password with 401 and changes nothing', async () => {
      const agent = await makeUser(clientId, 'field_agent');
      const before = await prisma.user.findUnique({
        where: { id: agent.id },
        omit: { passwordHash: false },
      });

      const res = await request(app)
        .post('/auth/change-password')
        .set('Authorization', `Bearer ${agent.token}`)
        .send({ currentPassword: 'not-the-password-at-all', newPassword: NEW_PASSWORD });

      expect(res.status).toBe(401);
      // The app matches the code, not the prose, to keep the session this was
      // typed into: its interceptor signs out on any other 401.
      expect(res.body).toEqual({
        error: 'Current password is incorrect',
        code: 'current_password_incorrect',
      });
      const after = await prisma.user.findUnique({
        where: { id: agent.id },
        omit: { passwordHash: false },
      });
      expect(after!.passwordHash).toBe(before!.passwordHash);
      expect(
        await prisma.passwordChangeEvent.count({ where: { userId: agent.id } }),
      ).toBe(0);
    });

    it('applies the shared password rule to the new password', async () => {
      const agent = await makeUser(clientId, 'field_agent');
      const res = await request(app)
        .post('/auth/change-password')
        .set('Authorization', `Bearer ${agent.token}`)
        .send({ currentPassword: PASSWORD, newPassword: 'elevenchars' });

      expect(res.status).toBe(400);
      expect(res.body.error).toMatch(/12 characters/);
    });

    it('requires a token', async () => {
      const res = await request(app)
        .post('/auth/change-password')
        .send({ currentPassword: PASSWORD, newPassword: NEW_PASSWORD });
      expect(res.status).toBe(401);
    });

    it('writes one ledger row naming the user as their own actor', async () => {
      const agent = await makeUser(clientId, 'field_agent');
      await request(app)
        .post('/auth/change-password')
        .set('Authorization', `Bearer ${agent.token}`)
        .send({ currentPassword: PASSWORD, newPassword: NEW_PASSWORD });

      const rows = await prisma.passwordChangeEvent.findMany({ where: { userId: agent.id } });
      expect(rows).toHaveLength(1);
      expect(rows[0]).toMatchObject({
        actorId: agent.id,
        actorRole: 'field_agent',
        method: 'self_change',
        clientId,
      });
    });
  });

  describe('POST /users/:id/password', () => {
    it('lets an admin set a field agent’s password, audited', async () => {
      const agent = await makeUser(clientId, 'field_agent');
      const res = await request(app)
        .post(`/users/${agent.id}/password`)
        .set('Authorization', `Bearer ${admin.token}`)
        .send({ newPassword: NEW_PASSWORD });

      expect(res.status).toBe(200);
      expect(res.body).toEqual({ otherSessionsEnded: false });
      expect(await storedPasswordIs(agent.id, NEW_PASSWORD)).toBe(true);

      const rows = await prisma.passwordChangeEvent.findMany({ where: { userId: agent.id } });
      expect(rows).toHaveLength(1);
      expect(rows[0]).toMatchObject({ actorId: admin.id, actorRole: 'admin', method: 'staff_set' });
    });

    it('lets a manager set a field agent’s password', async () => {
      const agent = await makeUser(clientId, 'field_agent');
      const res = await request(app)
        .post(`/users/${agent.id}/password`)
        .set('Authorization', `Bearer ${manager.token}`)
        .send({ newPassword: NEW_PASSWORD });
      expect(res.status).toBe(200);
    });

    // A manager who could reset an admin's password could take the tenant.
    it.each([['manager'], ['admin']] as const)(
      'refuses a manager setting a %s’s password with 403',
      async (role) => {
        const target = await makeUser(clientId, role);
        const res = await request(app)
          .post(`/users/${target.id}/password`)
          .set('Authorization', `Bearer ${manager.token}`)
          .send({ newPassword: NEW_PASSWORD });
        expect(res.status).toBe(403);
        expect(
          await prisma.passwordChangeEvent.count({ where: { userId: target.id } }),
        ).toBe(0);
      },
    );

    it('refuses a field agent outright with 403', async () => {
      const agent = await makeUser(clientId, 'field_agent');
      const victim = await makeUser(clientId, 'field_agent');
      const res = await request(app)
        .post(`/users/${victim.id}/password`)
        .set('Authorization', `Bearer ${agent.token}`)
        .send({ newPassword: NEW_PASSWORD });
      expect(res.status).toBe(403);
    });

    // TENANT ISOLATION. 404 and not 403, matching PATCH /users/:id, so the
    // route cannot be used to discover that a user id exists somewhere else.
    it('refuses a cross-tenant target with 404 and changes nothing', async () => {
      const before = await prisma.user.findUnique({
        where: { id: otherAgent.id },
        omit: { passwordHash: false },
      });

      const res = await request(app)
        .post(`/users/${otherAgent.id}/password`)
        .set('Authorization', `Bearer ${admin.token}`)
        .send({ newPassword: NEW_PASSWORD });

      expect(res.status).toBe(404);
      const after = await prisma.user.findUnique({
        where: { id: otherAgent.id },
        omit: { passwordHash: false },
      });
      expect(after!.passwordHash).toBe(before!.passwordHash);
    });

    it('applies the shared password rule', async () => {
      const agent = await makeUser(clientId, 'field_agent');
      const res = await request(app)
        .post(`/users/${agent.id}/password`)
        .set('Authorization', `Bearer ${admin.token}`)
        .send({ newPassword: 'hunter2' });
      expect(res.status).toBe(400);
      // The refusal states the rule; it never reproduces what was typed.
      expect(JSON.stringify(res.body)).not.toContain('hunter2');
    });
  });

  describe('POST /users/:id/password-reset-code', () => {
    it('returns a code to the manager who asked, and stores only a hash', async () => {
      const agent = await makeUser(clientId, 'field_agent');
      const res = await request(app)
        .post(`/users/${agent.id}/password-reset-code`)
        .set('Authorization', `Bearer ${manager.token}`);

      expect(res.status).toBe(201);
      expect(res.body.code).toMatch(/^\d{8}$/);
      expect(res.body.userId).toBe(agent.id);
      expect(typeof res.body.expiresAt).toBe('string');

      const rows = await prisma.passwordResetCode.findMany({ where: { userId: agent.id } });
      expect(rows).toHaveLength(1);
      // The plaintext is in the manager's hand and nowhere in the database.
      expect(rows[0].codeHash).not.toBe(res.body.code);
      expect(rows[0].codeHash.startsWith('$2')).toBe(true);
      expect(rows[0].issuedBy).toBe(manager.id);

      const ledger = await prisma.passwordChangeEvent.findMany({ where: { userId: agent.id } });
      expect(ledger).toHaveLength(1);
      expect(ledger[0].method).toBe('code_issued');
      // The ledger has no column that could hold a code, and does not.
      expect(JSON.stringify(ledger[0])).not.toContain(res.body.code);
    });

    it('retires the previous code when a new one is generated', async () => {
      const agent = await makeUser(clientId, 'field_agent');
      const first = await codeFor(manager.token, agent.id);
      const second = await codeFor(manager.token, agent.id);
      expect(first).not.toBe(second);

      const stale = await request(app)
        .post('/auth/reset-password')
        .send({ email: agent.email, code: first, newPassword: NEW_PASSWORD });
      expect(stale.status).toBe(401);

      const fresh = await request(app)
        .post('/auth/reset-password')
        .send({ email: agent.email, code: second, newPassword: NEW_PASSWORD });
      expect(fresh.status).toBe(200);
    });

    it('refuses a manager generating a code for another manager with 403', async () => {
      const target = await makeUser(clientId, 'manager');
      const res = await request(app)
        .post(`/users/${target.id}/password-reset-code`)
        .set('Authorization', `Bearer ${manager.token}`);
      expect(res.status).toBe(403);
    });

    it('refuses a field agent with 403', async () => {
      const agent = await makeUser(clientId, 'field_agent');
      const victim = await makeUser(clientId, 'field_agent');
      const res = await request(app)
        .post(`/users/${victim.id}/password-reset-code`)
        .set('Authorization', `Bearer ${agent.token}`);
      expect(res.status).toBe(403);
    });

    // TENANT ISOLATION. A manager must not be able to mint a working credential
    // for somebody else's company.
    it('refuses a cross-tenant target with 404 and mints nothing', async () => {
      const res = await request(app)
        .post(`/users/${otherAgent.id}/password-reset-code`)
        .set('Authorization', `Bearer ${manager.token}`);

      expect(res.status).toBe(404);
      expect(res.body.code).toBeUndefined();
      expect(await prisma.passwordResetCode.count({ where: { userId: otherAgent.id } })).toBe(0);
    });

    it('proves the isolation is per-tenant: the other manager CAN reset their own agent', async () => {
      const res = await request(app)
        .post(`/users/${otherAgent.id}/password-reset-code`)
        .set('Authorization', `Bearer ${otherManager.token}`);
      expect(res.status).toBe(201);
      expect(res.body.code).toMatch(/^\d{8}$/);
    });

    it('refuses a deactivated account — a reset must not route around deactivation', async () => {
      const agent = await makeUser(clientId, 'field_agent', { active: false });
      const res = await request(app)
        .post(`/users/${agent.id}/password-reset-code`)
        .set('Authorization', `Bearer ${manager.token}`);
      expect(res.status).toBe(400);
      expect(res.body.code).toBeUndefined();
    });
  });

  describe('POST /auth/reset-password', () => {
    it('sets the password the agent chose, which the manager never learns', async () => {
      const agent = await makeUser(clientId, 'field_agent');
      const code = await codeFor(manager.token, agent.id);

      const res = await request(app)
        .post('/auth/reset-password')
        .send({ email: agent.email, code, newPassword: NEW_PASSWORD });

      expect(res.status).toBe(200);
      expect(res.body).toEqual({ otherSessionsEnded: false });
      expect(await storedPasswordIs(agent.id, NEW_PASSWORD)).toBe(true);

      // The agent is the actor: the manager opened the door, they chose what is
      // behind it.
      const redeemed = await prisma.passwordChangeEvent.findFirst({
        where: { userId: agent.id, method: 'code_redeemed' },
      });
      expect(redeemed).not.toBeNull();
      expect(redeemed!.actorId).toBe(agent.id);
      expect(redeemed!.actorRole).toBe('field_agent');
    });

    // An admin may issue a code for a manager. The ledger must say a MANAGER
    // redeemed it — it used to record every redeemer as a field agent.
    it('records the redeemer\'s own role in the ledger', async () => {
      const target = await makeUser(clientId, 'manager');
      const code = await codeFor(admin.token, target.id);

      const res = await request(app)
        .post('/auth/reset-password')
        .send({ email: target.email, code, newPassword: NEW_PASSWORD });
      expect(res.status).toBe(200);

      const redeemed = await prisma.passwordChangeEvent.findFirst({
        where: { userId: target.id, method: 'code_redeemed' },
      });
      expect(redeemed).toMatchObject({ actorId: target.id, actorRole: 'manager' });
    });

    it('accepts the code as the manager reads it out, with a space in it', async () => {
      const agent = await makeUser(clientId, 'field_agent');
      const code = await codeFor(manager.token, agent.id);
      const spoken = `${code.slice(0, 4)} ${code.slice(4)}`;

      const res = await request(app)
        .post('/auth/reset-password')
        .send({ email: agent.email, code: spoken, newPassword: NEW_PASSWORD });
      expect(res.status).toBe(200);
    });

    // A phone keyboard's auto-capitalisation, and a paste that carried
    // whitespace — the spellings #351 was about, on this route too.
    it('finds the account however the email was typed', async () => {
      const agent = await makeUser(clientId, 'field_agent');
      const code = await codeFor(manager.token, agent.id);

      const res = await request(app)
        .post('/auth/reset-password')
        .send({ email: `  ${agent.email.toUpperCase()}  `, code, newPassword: NEW_PASSWORD });
      expect(res.status).toBe(200);
    });

    it('refuses a reused code — single use means single use', async () => {
      const agent = await makeUser(clientId, 'field_agent');
      const code = await codeFor(manager.token, agent.id);

      const first = await request(app)
        .post('/auth/reset-password')
        .send({ email: agent.email, code, newPassword: NEW_PASSWORD });
      expect(first.status).toBe(200);

      const second = await request(app)
        .post('/auth/reset-password')
        .send({ email: agent.email, code, newPassword: 'a third good passphrase' });
      expect(second.status).toBe(401);

      // And the password is still the one the first redemption set.
      expect(await storedPasswordIs(agent.id, NEW_PASSWORD)).toBe(true);
    });

    it('refuses an expired code', async () => {
      const agent = await makeUser(clientId, 'field_agent');
      const code = await codeFor(manager.token, agent.id);
      await prisma.passwordResetCode.updateMany({
        where: { userId: agent.id, usedAt: null },
        data: { expiresAt: new Date(Date.now() - 1000) },
      });

      const res = await request(app)
        .post('/auth/reset-password')
        .send({ email: agent.email, code, newPassword: NEW_PASSWORD });
      expect(res.status).toBe(401);
      expect(await storedPasswordIs(agent.id, PASSWORD)).toBe(true);
    });

    it('refuses a code whose account was deactivated after it was issued', async () => {
      const agent = await makeUser(clientId, 'field_agent');
      const code = await codeFor(manager.token, agent.id);
      await prisma.user.update({ where: { id: agent.id }, data: { active: false } });

      const res = await request(app)
        .post('/auth/reset-password')
        .send({ email: agent.email, code, newPassword: NEW_PASSWORD });
      expect(res.status).toBe(401);
    });

    // The counter travels WITH the code, so rotating IP addresses does not
    // refresh it.
    it('burns a code after too many wrong guesses, even with the right one afterwards', async () => {
      const agent = await makeUser(clientId, 'field_agent');
      const code = await codeFor(manager.token, agent.id);
      const wrong = code === '00000000' ? '11111111' : '00000000';

      for (let i = 0; i < RESET_CODE_MAX_ATTEMPTS; i += 1) {
        const bad = await request(app)
          .post('/auth/reset-password')
          .send({ email: agent.email, code: wrong, newPassword: NEW_PASSWORD });
        expect(bad.status).toBe(401);
      }

      const right = await request(app)
        .post('/auth/reset-password')
        .send({ email: agent.email, code, newPassword: NEW_PASSWORD });
      expect(right.status).toBe(401);
    });

    // NO ENUMERATION. An address that matches nobody must be indistinguishable
    // from one that does — same status, same body, same shape.
    it('answers an unknown email exactly as it answers a known one with a bad code', async () => {
      const agent = await makeUser(clientId, 'field_agent');
      await codeFor(manager.token, agent.id);

      const known = await request(app)
        .post('/auth/reset-password')
        .send({ email: agent.email, code: '01234567', newPassword: NEW_PASSWORD });
      const unknown = await request(app)
        .post('/auth/reset-password')
        .send({ email: `nobody-${Date.now()}@example.test`, code: '01234567', newPassword: NEW_PASSWORD });

      expect(unknown.status).toBe(known.status);
      expect(unknown.body).toEqual(known.body);
    });

    it('answers a known email with no code at all the same way', async () => {
      const agent = await makeUser(clientId, 'field_agent');
      const res = await request(app)
        .post('/auth/reset-password')
        .send({ email: agent.email, code: '01234567', newPassword: NEW_PASSWORD });
      expect(res.status).toBe(401);
      expect(res.body).toEqual({
        error: 'That reset code is not valid or has expired',
        code: 'reset_code_invalid',
      });
    });

    // A 400 for "that is not eight digits" and a 401 for "eight digits but
    // wrong" is a free oracle for nothing in return.
    it('answers a malformed code with the same 401 as a wrong one', async () => {
      const res = await request(app)
        .post('/auth/reset-password')
        .send({ email: `nobody-${Date.now()}@example.test`, code: 'abc', newPassword: NEW_PASSWORD });
      expect(res.status).toBe(401);
      expect(res.body).toEqual({
        error: 'That reset code is not valid or has expired',
        code: 'reset_code_invalid',
      });
    });

    // The password's own rules depend only on what the caller typed, so this
    // one CAN be a 400 — and should be, or an agent who typed a good code and a
    // short password silently burns an attempt learning nothing.
    it('rejects a password that breaks the rules with 400, without burning the code', async () => {
      const agent = await makeUser(clientId, 'field_agent');
      const code = await codeFor(manager.token, agent.id);

      const bad = await request(app)
        .post('/auth/reset-password')
        .send({ email: agent.email, code, newPassword: 'elevenchars' });
      expect(bad.status).toBe(400);
      expect(bad.body.error).toMatch(/12 characters/);

      const good = await request(app)
        .post('/auth/reset-password')
        .send({ email: agent.email, code, newPassword: NEW_PASSWORD });
      expect(good.status).toBe(200);
    });

    it('never echoes the code or the password in any response', async () => {
      const agent = await makeUser(clientId, 'field_agent');
      const code = await codeFor(manager.token, agent.id);

      const ok = await request(app)
        .post('/auth/reset-password')
        .send({ email: agent.email, code, newPassword: NEW_PASSWORD });
      expect(JSON.stringify(ok.body)).not.toContain(code);
      expect(JSON.stringify(ok.body)).not.toContain(NEW_PASSWORD);
    });

    // A code minted by one tenant's manager unlocks an account in that tenant
    // and nothing else. The account it names is the only account it can reach.
    it('cannot be redeemed against a different tenant’s account', async () => {
      const agent = await makeUser(clientId, 'field_agent');
      const code = await codeFor(manager.token, agent.id);

      const res = await request(app)
        .post('/auth/reset-password')
        .send({ email: otherAgent.email, code, newPassword: NEW_PASSWORD });
      expect(res.status).toBe(401);
      expect(await storedPasswordIs(otherAgent.id, PASSWORD)).toBe(true);
    });

    it('retires outstanding codes when the password changes by another route', async () => {
      const agent = await makeUser(clientId, 'field_agent');
      const code = await codeFor(manager.token, agent.id);

      const set = await request(app)
        .post(`/users/${agent.id}/password`)
        .set('Authorization', `Bearer ${admin.token}`)
        .send({ newPassword: NEW_PASSWORD });
      expect(set.status).toBe(200);

      // Otherwise the code overheard an hour ago is a live back door onto the
      // password the admin has just set.
      const stale = await request(app)
        .post('/auth/reset-password')
        .send({ email: agent.email, code, newPassword: 'a third good passphrase' });
      expect(stale.status).toBe(401);
    });
  });

  describe('GET /users/password-events', () => {
    it('shows an admin who reset whose password, when — and carries no secret', async () => {
      const agent = await makeUser(clientId, 'field_agent');
      await request(app)
        .post(`/users/${agent.id}/password`)
        .set('Authorization', `Bearer ${admin.token}`)
        .send({ newPassword: NEW_PASSWORD });

      const res = await request(app)
        .get('/users/password-events')
        .query({ userId: agent.id })
        .set('Authorization', `Bearer ${admin.token}`);

      expect(res.status).toBe(200);
      expect(res.body.data).toHaveLength(1);
      expect(res.body.data[0]).toMatchObject({
        userId: agent.id,
        actorId: admin.id,
        actorRole: 'admin',
        method: 'staff_set',
      });
      expect(Object.keys(res.body.data[0]).sort()).toEqual([
        'actorId',
        'actorRole',
        'clientId',
        'createdAt',
        'id',
        'method',
        'userId',
      ]);
      expect(JSON.stringify(res.body)).not.toContain(NEW_PASSWORD);
    });

    it('refuses a manager with 403 — the ledger is an admin’s view', async () => {
      const res = await request(app)
        .get('/users/password-events')
        .set('Authorization', `Bearer ${manager.token}`);
      expect(res.status).toBe(403);
    });

    // TENANT ISOLATION.
    it('never shows another tenant’s events, and that tenant sees its own', async () => {
      const mine = await makeUser(clientId, 'field_agent');
      await request(app)
        .post(`/users/${mine.id}/password`)
        .set('Authorization', `Bearer ${admin.token}`)
        .send({ newPassword: NEW_PASSWORD });

      const otherAdmin = await makeUser(otherClientId, 'admin');
      await request(app)
        .post(`/users/${otherAgent.id}/password`)
        .set('Authorization', `Bearer ${otherAdmin.token}`)
        .send({ newPassword: NEW_PASSWORD });

      const res = await request(app)
        .get('/users/password-events')
        .query({ limit: 200 })
        .set('Authorization', `Bearer ${admin.token}`);
      expect(res.status).toBe(200);
      const userIds = res.body.data.map((r: { userId: string }) => r.userId);
      expect(userIds).toContain(mine.id);
      expect(userIds).not.toContain(otherAgent.id);
      for (const row of res.body.data) {
        expect(row.clientId).toBe(clientId);
      }

      const theirs = await request(app)
        .get('/users/password-events')
        .query({ limit: 200 })
        .set('Authorization', `Bearer ${otherAdmin.token}`);
      expect(theirs.status).toBe(200);
      expect(theirs.body.data.map((r: { userId: string }) => r.userId)).toContain(otherAgent.id);
    });

    it('rejects an unauthenticated read with 401', async () => {
      const res = await request(app).get('/users/password-events');
      expect(res.status).toBe(401);
    });
  });
});
