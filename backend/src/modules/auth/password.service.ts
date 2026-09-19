import { randomInt } from 'crypto';
import type { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { normalizeEmail } from '../../lib/email';
import { NotFoundError, ValidationError } from '../../middleware/errorHandler';
import { checkPassword } from '../../lib/passwordPolicy';
import { compareAgainstOptionalHash, hashPassword, Role } from './auth.service';

/**
 * Setting a password, by the three routes a person can actually take (#400).
 *
 * ## The honest limit, stated first
 *
 * **Changing a password does not end the account's other sessions.** Tokens are
 * stateless 12-hour JWTs; `requireAuth` re-reads `active`, `role` and
 * `clientId` on every request but nothing about the password, so a token minted
 * before the change keeps working until it expires. Every function here that
 * changes a password returns `otherSessionsEnded: false` so the caller states
 * that rather than implying otherwise, and the app says it in plain words.
 *
 * Making it true needs a token-versioning column checked in `requireAuth` —
 * a real change to the token design, deliberately not smuggled in here. If a
 * phone is lost, `PATCH /users/:id { active: false }` IS immediate, because
 * `requireAuth` does check that.
 *
 * ## What the three routes are
 *
 * - `changeOwnPassword` — the agent knows their password and wants a new one.
 * - `setPasswordForUser` — an admin (or a manager, for a field agent) sets one
 *   directly. The in-office move.
 * - `issueResetCode` + `redeemResetCode` — the in-field move: the manager
 *   generates a code, reads it out, and the agent sets their own password. The
 *   manager never learns what the agent chose.
 *
 * ## Enumeration
 *
 * `redeemResetCode` is the only unauthenticated one, and it is the only one
 * where enumeration is possible. It answers identically — same status, same
 * body, same bcrypt cost — for an unknown email, a known email with no live
 * code, a wrong code, an expired code, a spent code, and a deactivated account.
 */

/** How the change happened, as written to the ledger. */
export const PASSWORD_CHANGE_METHODS = [
  'self_change',
  'staff_set',
  'code_issued',
  'code_redeemed',
] as const;
export type PasswordChangeMethod = (typeof PASSWORD_CHANGE_METHODS)[number];

/**
 * Digits, not letters.
 *
 * This code is spoken out loud, frequently across a noisy shop floor and
 * between two people who may not share a first language. "B" and "V" and "P"
 * are the same sound down a bad line; "5" is "five" in a way that survives.
 * Digits also mean the agent's phone can show a numeric keypad, which is the
 * difference between one thumb and two hands on a cracked screen.
 */
const CODE_ALPHABET = '0123456789';

/**
 * Eight digits: 100 million codes.
 *
 * On its own that is not a lot. It does not have to be, because guessing is
 * bounded three ways at once — the code dies after
 * {@link RESET_CODE_MAX_ATTEMPTS} wrong tries wherever they come from, it
 * expires in minutes, and the per-email limiter caps attempts per window well
 * below the attempt counter anyway. Lengthening it buys far less than any of
 * those and costs the thing that makes the flow work: a manager reading it out
 * once and an agent typing it right first time.
 */
export const RESET_CODE_LENGTH = 8;

/** Wrong guesses before the code is dead. Travels WITH the code, not with an IP. */
export const RESET_CODE_MAX_ATTEMPTS = 5;

/**
 * Minutes a code is good for.
 *
 * Short because the manager and the agent are standing together: the whole
 * exchange is a minute. Not one minute, because the agent may have to walk back
 * to where there is signal.
 */
export function resetCodeTtlMinutes(): number {
  const configured = Number(process.env.PASSWORD_RESET_CODE_TTL_MINUTES);
  return Number.isFinite(configured) && configured > 0 ? configured : 15;
}

/** A fresh code. `randomInt` is the CSPRNG; `Math.random` would not be. */
export function generateResetCode(): string {
  let code = '';
  for (let i = 0; i < RESET_CODE_LENGTH; i += 1) {
    code += CODE_ALPHABET[randomInt(0, CODE_ALPHABET.length)];
  }
  return code;
}

/**
 * Who may set whose password.
 *
 * Mirrors the existing user routes and then closes the one hole they do not
 * have to think about, because they have no manager-facing write at all:
 * a manager who could reset an admin's password could take the tenant. So a
 * manager may reset field agents and nobody else — not other managers, not
 * admins, not themselves through this door (they have `changeOwnPassword`).
 *
 * An admin may reset anyone inside their own tenant, which is what "admin"
 * means here and matches `PATCH /users/:id`, where an admin can already demote
 * or deactivate any of them.
 */
export function staffMaySetPasswordFor(actorRole: Role, targetRole: Role): boolean {
  if (actorRole === 'admin') return true;
  if (actorRole === 'manager') return targetRole === 'field_agent';
  return false;
}

/** The result every password-changing call returns. Never carries a secret. */
export interface PasswordChangeResult {
  /**
   * Always false today, and said out loud rather than omitted. See the header
   * comment: tokens are stateless, so other sessions run to their 12h expiry.
   */
  otherSessionsEnded: false;
}

const UNCHANGED_SESSIONS: PasswordChangeResult = { otherSessionsEnded: false };

/**
 * Writes the new hash, burns every outstanding reset code for that user, and
 * appends the ledger row — in one transaction, so a crash cannot leave a
 * changed password with a live code still able to change it again.
 */
async function applyNewPassword(input: {
  userId: string;
  clientId: string;
  actorId: string;
  actorRole: Role;
  method: PasswordChangeMethod;
  newPassword: string;
  /** Extra work inside the same transaction — marking the redeemed code spent. */
  also?: (tx: Prisma.TransactionClient) => Promise<void>;
}): Promise<PasswordChangeResult> {
  const passwordHash = await hashPassword(input.newPassword);

  await prisma.$transaction(async (tx) => {
    await tx.user.update({ where: { id: input.userId }, data: { passwordHash } });
    // Any password change invalidates every outstanding code for that account.
    // Otherwise a manager's code issued an hour ago still works against the
    // password the agent has since chosen — which is a live back door held by
    // whoever overheard it.
    await tx.passwordResetCode.updateMany({
      where: { userId: input.userId, usedAt: null },
      data: { usedAt: new Date() },
    });
    await input.also?.(tx);
    await tx.passwordChangeEvent.create({
      data: {
        clientId: input.clientId,
        userId: input.userId,
        actorId: input.actorId,
        actorRole: input.actorRole,
        method: input.method,
      },
    });
  });

  return UNCHANGED_SESSIONS;
}

export class InvalidCurrentPasswordError extends Error {}
export class InvalidResetCodeError extends Error {}
/** The caller's role does not reach this target. A 403, distinct from a 404. */
export class ForbiddenTargetError extends Error {}

export interface ChangeOwnPasswordInput {
  userId: string;
  clientId: string;
  role: Role;
  currentPassword: string;
  newPassword: string;
}

/**
 * The signed-in user changes their own password.
 *
 * The current password is re-checked even though the caller holds a valid
 * token, because the token may be a borrowed phone left unlocked — which on
 * shared handsets is the normal case, not the exotic one.
 */
export async function changeOwnPassword(
  input: ChangeOwnPasswordInput,
): Promise<PasswordChangeResult> {
  // `omit` rather than `select` — Prisma refuses both on one query, and the
  // client's global omit is what keeps `passwordHash` out of every other read.
  // Opting back in here is the explicit, grep-able exception, exactly as
  // authenticateUser does it.
  const user = await prisma.user.findFirst({
    where: { id: input.userId, clientId: input.clientId },
    omit: { passwordHash: false },
  });
  // The token was already validated by requireAuth, which re-reads the user, so
  // a miss here means the row vanished between the two reads. Treat it as a bad
  // current password rather than a 404 — same answer, no new signal.
  const valid = await compareAgainstOptionalHash(input.currentPassword, user?.passwordHash);
  if (!user || !valid) {
    throw new InvalidCurrentPasswordError('Current password is incorrect');
  }

  const check = checkPassword(input.newPassword, user.email);
  if (!check.ok) {
    throw new ValidationError(check.reason);
  }

  return applyNewPassword({
    userId: user.id,
    clientId: input.clientId,
    actorId: input.userId,
    actorRole: input.role,
    method: 'self_change',
    newPassword: input.newPassword,
  });
}

export interface SetPasswordForUserInput {
  targetUserId: string;
  clientId: string;
  actorId: string;
  actorRole: Role;
  newPassword: string;
}

/**
 * An admin — or a manager, for a field agent — sets someone's password.
 *
 * Tenant-scoped exactly as `updateUser` is: a target in another client is a 404,
 * not a 403, so the route cannot be used to discover that a user id exists
 * somewhere else.
 */
export async function setPasswordForUser(
  input: SetPasswordForUserInput,
): Promise<PasswordChangeResult> {
  const target = await prisma.user.findFirst({
    where: { id: input.targetUserId, clientId: input.clientId },
    select: { id: true, email: true, role: true },
  });
  if (!target) {
    throw new NotFoundError('User not found');
  }
  if (!staffMaySetPasswordFor(input.actorRole, target.role as Role)) {
    throw new ForbiddenTargetError('You may not set this user’s password');
  }

  const check = checkPassword(input.newPassword, target.email);
  if (!check.ok) {
    throw new ValidationError(check.reason);
  }

  return applyNewPassword({
    userId: target.id,
    clientId: input.clientId,
    actorId: input.actorId,
    actorRole: input.actorRole,
    method: 'staff_set',
    newPassword: input.newPassword,
  });
}

export interface IssueResetCodeInput {
  targetUserId: string;
  clientId: string;
  actorId: string;
  actorRole: Role;
}

export interface IssuedResetCode {
  /**
   * The plaintext code — returned **once**, to the manager who asked for it,
   * and stored only as a bcrypt hash. It must never be logged, echoed into an
   * error, written to the ledger, or returned from any other endpoint.
   */
  code: string;
  expiresAt: Date;
  /** Who it is for, so the manager can confirm they picked the right person. */
  userId: string;
  email: string;
}

/**
 * Generates a one-time code for an agent standing in front of the manager.
 *
 * Issuing supersedes any earlier live code for that user, so "it didn't work,
 * make me another" leaves exactly one code alive rather than a growing set of
 * valid ones. A deactivated account gets no code: reactivating is the admin's
 * decision, and a reset must not route around it.
 */
export async function issueResetCode(input: IssueResetCodeInput): Promise<IssuedResetCode> {
  const target = await prisma.user.findFirst({
    where: { id: input.targetUserId, clientId: input.clientId },
    select: { id: true, email: true, role: true, active: true },
  });
  if (!target) {
    throw new NotFoundError('User not found');
  }
  if (!staffMaySetPasswordFor(input.actorRole, target.role as Role)) {
    throw new ForbiddenTargetError('You may not reset this user’s password');
  }
  if (!target.active) {
    throw new ValidationError(
      'This account is deactivated. Reactivate it first, then generate a code.',
    );
  }

  const code = generateResetCode();
  const codeHash = await hashPassword(code);
  const expiresAt = new Date(Date.now() + resetCodeTtlMinutes() * 60_000);

  await prisma.$transaction(async (tx) => {
    await tx.passwordResetCode.updateMany({
      where: { userId: target.id, usedAt: null },
      data: { usedAt: new Date() },
    });
    await tx.passwordResetCode.create({
      data: {
        clientId: input.clientId,
        userId: target.id,
        codeHash,
        issuedBy: input.actorId,
        expiresAt,
      },
    });
    await tx.passwordChangeEvent.create({
      data: {
        clientId: input.clientId,
        userId: target.id,
        actorId: input.actorId,
        actorRole: input.actorRole,
        method: 'code_issued',
      },
    });
  });

  return { code, expiresAt, userId: target.id, email: target.email };
}

export interface RedeemResetCodeInput {
  email: string;
  code: string;
  newPassword: string;
}

/**
 * The agent redeems the code and chooses their own password.
 *
 * Unauthenticated, so every refusal is the same refusal. The order of work is
 * load-bearing:
 *
 * 1. The password rules are checked FIRST, before anything touches the
 *    database. That answer depends only on the password the caller typed, never
 *    on whether the account exists, so it leaks nothing — and it means an agent
 *    who typed a good code and a too-short password is told about the password
 *    instead of silently burning an attempt.
 * 2. The bcrypt comparison runs on EVERY path, against a decoy hash when there
 *    is no real one, so unknown email / no live code / wrong code all cost the
 *    same wall-clock time.
 * 3. Only then do "is it expired", "is it spent", "is the account active"
 *    decide — and all of them produce the identical {@link InvalidResetCodeError}.
 */
export async function redeemResetCode(
  input: RedeemResetCodeInput,
): Promise<PasswordChangeResult> {
  const check = checkPassword(input.newPassword, input.email);
  if (!check.ok) {
    throw new ValidationError(check.reason);
  }

  const user = await prisma.user.findUnique({
    where: { email: normalizeEmail(input.email) },
    select: { id: true, clientId: true, active: true },
  });

  const candidate = user
    ? await prisma.passwordResetCode.findFirst({
        where: {
          userId: user.id,
          usedAt: null,
          expiresAt: { gt: new Date() },
          attempts: { lt: RESET_CODE_MAX_ATTEMPTS },
        },
        orderBy: { createdAt: 'desc' },
      })
    : null;

  // Runs whether or not there is anything to compare against — that is the
  // whole point. See compareAgainstOptionalHash.
  const matched = await compareAgainstOptionalHash(input.code, candidate?.codeHash);

  if (!user || !candidate || !matched) {
    if (candidate) {
      // A wrong guess against a real code costs that code one of its lives.
      // Unconditional increment rather than a read-modify-write, so concurrent
      // guesses cannot each read "attempts: 0" and write "attempts: 1".
      await prisma.passwordResetCode.update({
        where: { id: candidate.id },
        data: { attempts: { increment: 1 } },
      });
    }
    throw new InvalidResetCodeError('That reset code is not valid or has expired');
  }

  if (!user.active) {
    // Deactivated between issuing and redeeming. Indistinguishable from a bad
    // code on the wire — telling the caller "this account is disabled" would
    // confirm the address exists.
    await prisma.passwordResetCode.update({
      where: { id: candidate.id },
      data: { usedAt: new Date() },
    });
    throw new InvalidResetCodeError('That reset code is not valid or has expired');
  }

  return applyNewPassword({
    userId: user.id,
    clientId: user.clientId,
    // The agent set it themselves; the manager only opened the door. Recording
    // the manager as the actor would say they chose the password, which they
    // did not and must not be able to.
    actorId: user.id,
    actorRole: 'field_agent',
    method: 'code_redeemed',
    newPassword: input.newPassword,
    also: async (tx) => {
      // Single use, enforced by the same transaction that sets the password —
      // and guarded against a double redemption by re-asserting `usedAt: null`
      // in the WHERE. `updateMany` reports how many rows it touched; zero means
      // another request spent it first.
      const spent = await tx.passwordResetCode.updateMany({
        where: { id: candidate.id, usedAt: null },
        data: { usedAt: new Date() },
      });
      if (spent.count === 0) {
        throw new InvalidResetCodeError('That reset code is not valid or has expired');
      }
    },
  });
}

export interface ListPasswordEventsInput {
  clientId: string;
  userId?: string;
  limit: number;
  cursor?: string;
}

/**
 * The audit trail, readable.
 *
 * A ledger nobody can read is a ledger nobody checks. Admin-only and
 * tenant-scoped; it carries no secret, by construction — the table has no
 * column that could hold one.
 */
export async function listPasswordEvents(input: ListPasswordEventsInput) {
  return prisma.passwordChangeEvent.findMany({
    where: {
      clientId: input.clientId,
      ...(input.userId ? { userId: input.userId } : {}),
    },
    // Newest first, with `id` as the tiebreaker in the SAME direction as the
    // primary sort — the keyset-pagination rule the other modules spell out.
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: input.limit + 1,
    ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
  });
}
