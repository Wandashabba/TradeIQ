import rateLimit from 'express-rate-limit';
import { normalizeEmail } from '../lib/email';
import type { AuthedRequest } from './auth';

/**
 * Rate limiter for the login endpoint to blunt credential brute-force and
 * enumeration attempts. The window/limit are overridable via env so ops can
 * tune them per environment without a code change; the factory form also lets
 * tests exercise the limiter deterministically with a tiny limit.
 */
export function createLoginRateLimiter(options?: { windowMs?: number; limit?: number }) {
  return rateLimit({
    windowMs: options?.windowMs ?? Number(process.env.LOGIN_RATE_LIMIT_WINDOW_MS ?? 15 * 60 * 1000),
    limit: options?.limit ?? Number(process.env.LOGIN_RATE_LIMIT_MAX ?? 10),
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'Too many login attempts, please try again later' },
  });
}

export const loginRateLimiter = createLoginRateLimiter();

/**
 * Assistant chat limiters — **two of them, and both are needed.**
 *
 * Per-user bounds one manager hammering the composer. It does nothing about a
 * tenant with forty managers, whose combined traffic is forty times the per-user
 * cap and still entirely "within limits". Per-tenant bounds the bill, which is
 * the thing that actually hurts: every turn is a metered provider call, so the
 * failure mode here is a spend blowout rather than a busy CPU.
 *
 * Keyed on the JWT, never on IP. A field team behind one corporate NAT shares an
 * IP, so an IP-keyed limiter would throttle colleagues for each other's usage
 * while a distributed caller sidesteps it entirely.
 *
 * **Neither of these bounds the account.** Rate limiting caps a user and a
 * tenant inside this process; a leaked provider key is not rate-limited by
 * anything in this repo. The hard monthly cap belongs in the provider console,
 * and it is a separate task for exactly that reason.
 *
 * Mount **after** `requireAuth`, or `req.user` is undefined and every request
 * collapses onto one shared bucket.
 */
function keyedLimiter(opts: {
  windowMs: number;
  limit: number;
  key: (req: AuthedRequest) => string | undefined;
  message: string;
}) {
  return rateLimit({
    windowMs: opts.windowMs,
    limit: opts.limit,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: opts.message },
    keyGenerator: (req) => {
      const key = opts.key(req as AuthedRequest);
      // Fail closed onto one shared bucket rather than throwing or handing back
      // `undefined`. An unauthenticated request should never reach here, and if
      // it does it gets the strictest possible treatment instead of a free pass.
      return key ?? 'anonymous';
    },
    // We key on identity, not IP, so the library's IPv6-subnet validation has
    // nothing to check and would only emit noise.
    validate: { keyGeneratorIpFallback: false },
  });
}

export function createAssistantUserRateLimiter(options?: { windowMs?: number; limit?: number }) {
  return keyedLimiter({
    windowMs: options?.windowMs ?? Number(process.env.ASSISTANT_USER_RATE_WINDOW_MS ?? 60 * 1000),
    limit: options?.limit ?? Number(process.env.ASSISTANT_USER_RATE_MAX ?? 20),
    key: (req) => req.user?.userId,
    message: 'Too many requests, please slow down',
  });
}

export function createAssistantTenantRateLimiter(options?: { windowMs?: number; limit?: number }) {
  return keyedLimiter({
    windowMs: options?.windowMs ?? Number(process.env.ASSISTANT_TENANT_RATE_WINDOW_MS ?? 60 * 1000),
    limit: options?.limit ?? Number(process.env.ASSISTANT_TENANT_RATE_MAX ?? 120),
    key: (req) => req.user?.clientId,
    message: 'Your organisation has reached its assistant request limit, please try again shortly',
  });
}

export const assistantUserRateLimiter = createAssistantUserRateLimiter();
export const assistantTenantRateLimiter = createAssistantTenantRateLimiter();

/**
 * Password-change and password-reset limiters (#400).
 *
 * Each of these guards a different door onto the same thing — setting a
 * password — and each is keyed on what actually identifies the attacker at that
 * door.
 */

/**
 * `POST /auth/change-password`. Keyed on the authenticated user, because that
 * is who is guessing their own current password. IP would be wrong twice over:
 * a field team behind one NAT shares an IP, and an attacker with a stolen token
 * does not.
 *
 * Mount **after** `requireAuth`.
 */
export function createChangePasswordRateLimiter(options?: { windowMs?: number; limit?: number }) {
  return keyedLimiter({
    windowMs:
      options?.windowMs ?? Number(process.env.CHANGE_PASSWORD_RATE_WINDOW_MS ?? 15 * 60 * 1000),
    limit: options?.limit ?? Number(process.env.CHANGE_PASSWORD_RATE_MAX ?? 10),
    key: (req) => req.user?.userId,
    message: 'Too many password change attempts, please try again later',
  });
}

/**
 * `POST /users/:id/password-reset-code`. Keyed on the manager generating codes.
 *
 * Generous, because the legitimate shape is bursty: a manager at a depot on
 * Monday morning resets six agents in five minutes. It exists to bound a
 * compromised manager account minting codes for the whole tenant, not to pace
 * ordinary work.
 */
export function createResetCodeIssueRateLimiter(options?: { windowMs?: number; limit?: number }) {
  return keyedLimiter({
    windowMs:
      options?.windowMs ?? Number(process.env.RESET_CODE_ISSUE_RATE_WINDOW_MS ?? 60 * 60 * 1000),
    limit: options?.limit ?? Number(process.env.RESET_CODE_ISSUE_RATE_MAX ?? 30),
    key: (req) => req.user?.userId,
    message: 'Too many reset codes generated, please try again later',
  });
}

/**
 * `POST /auth/reset-password`, keyed on the email in the body.
 *
 * This is the one that bounds guessing at a NAMED account — the attack that
 * matters, since an attacker who is guessing a code already knows whose account
 * they want. It runs before any database lookup, so a 429 says nothing about
 * whether the address exists: unknown and known emails are throttled
 * identically, and enumeration is not reopened by the limiter.
 *
 * It does mean someone who knows an agent's email can keep that agent's reset
 * window full for 15 minutes. That is a real, accepted cost: the alternative —
 * no per-account bound — hands an attacker unlimited guesses at an 8-digit code
 * simply by rotating IP addresses. The code's own `attempts` counter is the
 * backstop that does not care where the guesses came from.
 */
export function createResetRedeemEmailRateLimiter(options?: { windowMs?: number; limit?: number }) {
  return keyedLimiter({
    windowMs:
      options?.windowMs ?? Number(process.env.RESET_REDEEM_EMAIL_RATE_WINDOW_MS ?? 15 * 60 * 1000),
    limit: options?.limit ?? Number(process.env.RESET_REDEEM_EMAIL_RATE_MAX ?? 8),
    key: (req) => {
      const email = (req.body as { email?: unknown } | undefined)?.email;
      // Normalised, or `Agent@x.com` and `agent@x.com` would be two buckets and
      // the limit would be worth double to anyone who noticed.
      return typeof email === 'string' ? `email:${normalizeEmail(email)}` : undefined;
    },
    message: 'Too many password reset attempts, please try again later',
  });
}

/**
 * `POST /auth/reset-password`, keyed on IP.
 *
 * The companion to the per-email limiter: that one stops a thousand guesses at
 * one account, this one stops one guess each at a thousand accounts. Looser,
 * because a whole depot behind one NAT legitimately shares this key.
 */
export function createResetRedeemIpRateLimiter(options?: { windowMs?: number; limit?: number }) {
  return rateLimit({
    windowMs:
      options?.windowMs ?? Number(process.env.RESET_REDEEM_IP_RATE_WINDOW_MS ?? 15 * 60 * 1000),
    limit: options?.limit ?? Number(process.env.RESET_REDEEM_IP_RATE_MAX ?? 60),
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'Too many password reset attempts, please try again later' },
  });
}

export const changePasswordRateLimiter = createChangePasswordRateLimiter();
export const resetCodeIssueRateLimiter = createResetCodeIssueRateLimiter();
export const resetRedeemEmailRateLimiter = createResetRedeemEmailRateLimiter();
export const resetRedeemIpRateLimiter = createResetRedeemIpRateLimiter();
