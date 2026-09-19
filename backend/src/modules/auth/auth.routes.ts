import { Router } from 'express';
import { z } from 'zod';
import {
  changePasswordRateLimiter,
  loginRateLimiter,
  resetRedeemEmailRateLimiter,
  resetRedeemIpRateLimiter,
} from '../../middleware/rateLimit';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { PASSWORD_RULE_TEXT } from '../../lib/passwordPolicy';
import { authenticateUser, issueToken } from './auth.service';
import {
  changeOwnPassword,
  InvalidCurrentPasswordError,
  InvalidResetCodeError,
  redeemResetCode,
  RESET_CODE_LENGTH,
} from './password.service';

export const authRouter = Router();

/**
 * The 401 bodies carry a machine-readable `code` so the app can tell "this
 * request's secret was wrong" from "your session expired" without matching on
 * prose. Each is ONE constant per route: every failure on a route shares it, so
 * the code is no more an oracle than the message beside it.
 */
export const CURRENT_PASSWORD_INCORRECT_CODE = 'current_password_incorrect';
export const RESET_CODE_INVALID_CODE = 'reset_code_invalid';

authRouter.post('/login', loginRateLimiter, async (req, res) => {
  const { email, password } = req.body as { email?: string; password?: string };
  if (!email || !password) {
    res.status(400).json({ error: 'email and password are required' });
    return;
  }

  const user = await authenticateUser(email, password);
  if (!user) {
    res.status(401).json({ error: 'Invalid credentials' });
    return;
  }

  const token = issueToken({ userId: user.id, role: user.role, clientId: user.clientId });
  res.status(200).json({ token, role: user.role });
});

// The zod issue list the 400 envelope carries, as competitorPrices.routes.ts
// spells it: `{ error, issues }`, one line per failed field path.
//
// It reports PATHS and the schema's own messages, never values — so a failed
// password never reaches the response body through this door either.
function issues(error: z.ZodError) {
  return error.issues.map((i) => `${i.path.join('.') || '<root>'}: ${i.message}`);
}

/**
 * The rules are NOT restated in zod beyond "it is a non-empty string" (#400).
 *
 * `checkPassword` in `lib/passwordPolicy.ts` is the single rule, shared by
 * `POST /users`, this route and `POST /auth/reset-password`. A zod `.min(12)`
 * here would be a second copy of the floor, and the first thing to drift the
 * day someone changes one number.
 */
const changePasswordBody = z
  .object({
    currentPassword: z.string().min(1),
    newPassword: z.string().min(1),
  })
  .strict();

/**
 * POST /auth/change-password — the signed-in user changes their own password.
 *
 * **204, and no new token.** The caller's existing token stays valid, because
 * nothing about it changed: it is a 12h JWT that carries userId, role and
 * clientId and none of those moved. That is also, plainly, why this endpoint
 * cannot end the account's OTHER sessions — see password.service.ts. The body
 * of the success response says so rather than staying quiet about it.
 *
 * Rate-limited per user, after requireAuth so the limiter has an identity to
 * key on.
 */
authRouter.post(
  '/change-password',
  requireAuth,
  changePasswordRateLimiter,
  async (req: AuthedRequest, res) => {
    const parsed = changePasswordBody.safeParse(req.body ?? {});
    if (!parsed.success) {
      res.status(400).json({
        error: `currentPassword and newPassword are required. ${PASSWORD_RULE_TEXT}`,
        issues: issues(parsed.error),
      });
      return;
    }

    try {
      const result = await changeOwnPassword({
        userId: req.user!.userId,
        clientId: req.user!.clientId,
        role: req.user!.role,
        currentPassword: parsed.data.currentPassword,
        newPassword: parsed.data.newPassword,
      });
      res.status(200).json(result);
    } catch (err) {
      if (err instanceof InvalidCurrentPasswordError) {
        // 401 and a flat message. Not "your current password is wrong, and by
        // the way your new one was fine" — one refusal, no extra signal.
        //
        // The `code` is what the app matches on. Its interceptor signs the user
        // out on any 401, because everywhere else a 401 means the 12h token
        // expired; a mistyped current password must not end the session it
        // was typed into.
        res.status(401).json({
          error: 'Current password is incorrect',
          code: CURRENT_PASSWORD_INCORRECT_CODE,
        });
        return;
      }
      // ValidationError -> 400 via the shared error handler, carrying the rule
      // text and never the password.
      throw err;
    }
  },
);

/**
 * The code is bounded in the schema so a megabyte of digits never reaches
 * bcrypt. Digits only — see generateResetCode for why the alphabet is numeric.
 * Whitespace is trimmed first: a manager reads out "4821 7390" and the agent
 * types the space.
 */
/**
 * One string for every way a redemption can fail, written once so no refactor
 * can make two of them differ. Differing messages ARE the enumeration oracle.
 */
const INVALID_CODE_MESSAGE = 'That reset code is not valid or has expired';

const INVALID_CODE_BODY = { error: INVALID_CODE_MESSAGE, code: RESET_CODE_INVALID_CODE };

const resetPasswordBody = z
  .object({
    email: z.string().min(1).max(320),
    code: z
      .string()
      .trim()
      .transform((s) => s.replace(/[\s-]/g, ''))
      .pipe(z.string().regex(new RegExp(`^\\d{${RESET_CODE_LENGTH}}$`))),
    newPassword: z.string().min(1),
  })
  .strict();

/**
 * POST /auth/reset-password — the agent redeems a manager's code.
 *
 * **Unauthenticated by necessity**: the entire point is that this person cannot
 * sign in. That makes it the one endpoint here where enumeration is possible,
 * so every refusal below is the same refusal.
 *
 * A malformed code is answered with the same 401 as a wrong one, NOT a 400.
 * A 400 for "that is not eight digits" and a 401 for "that is eight digits but
 * wrong" would be a free oracle for nothing in return; the shape of a code is
 * not a secret, but two different answers on this route are a habit worth not
 * starting. A bad **password**, by contrast, still gets its 400 — that answer
 * depends only on what the caller typed and tells them the one thing they need.
 *
 * Two limiters, per-email and per-IP. See rateLimit.ts for why both.
 */
authRouter.post(
  '/reset-password',
  resetRedeemIpRateLimiter,
  resetRedeemEmailRateLimiter,
  async (req, res) => {
    const parsed = resetPasswordBody.safeParse(req.body ?? {});
    if (!parsed.success) {
      // A missing or non-string `email`/`newPassword` is a client bug and says
      // nothing about any account, so it gets a real 400 with the rule text.
      // A `code` that is not eight digits gets the same 401 a wrong code gets.
      const onlyCodeFailed = parsed.error.issues.every((i) => i.path[0] === 'code');
      if (onlyCodeFailed) {
        res.status(401).json(INVALID_CODE_BODY);
        return;
      }
      res.status(400).json({
        error: `email, code and newPassword are required. ${PASSWORD_RULE_TEXT}`,
        issues: issues(parsed.error),
      });
      return;
    }

    try {
      const result = await redeemResetCode({
        email: parsed.data.email,
        code: parsed.data.code,
        newPassword: parsed.data.newPassword,
      });
      res.status(200).json(result);
    } catch (err) {
      if (err instanceof InvalidResetCodeError) {
        res.status(401).json(INVALID_CODE_BODY);
        return;
      }
      // A ValidationError from the password rules becomes a 400 through the
      // shared error handler, carrying the rule and never the password.
      throw err;
    }
  },
);
