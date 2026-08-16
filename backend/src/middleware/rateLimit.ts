import rateLimit from 'express-rate-limit';
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
