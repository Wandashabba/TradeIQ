import rateLimit from 'express-rate-limit';

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
