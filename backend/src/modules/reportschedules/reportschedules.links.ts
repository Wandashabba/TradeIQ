import { createHmac, timingSafeEqual } from 'node:crypto';

/**
 * Signed, time-limited download links for a report run's CSV (#66).
 *
 * A machine subscriber (an ERP job, a mailbox rule, a person reading an email
 * on a phone) should not need a manager's bearer token to fetch a report it
 * was sent. The link carries a token that names exactly one run of one
 * schedule of one tenant, and when it stops working:
 *
 *   base64url(JSON { v, c: clientId, s: scheduleId, r: runId, e: expiresAtSec })
 *   "." base64url(HMAC-SHA256(REPORT_LINK_SECRET, "report-csv." + payload))
 *
 * **Its own secret, not a reused one.** `JWT_SECRET` signs sessions, and a
 * webhook's `secret` is per-subscriber and known to that subscriber, so it
 * cannot sign anything a different party must not forge. Sharing `JWT_SECRET`
 * would couple two rotations: rotating it after a leak would silently kill
 * every emailed link, and a leaked link-signing key would mint sessions. A
 * separate key keeps each blast radius to its own purpose. The `report-csv.`
 * prefix is domain separation, so a signature over this payload can never be
 * replayed as a signature for some future token type under the same key.
 *
 * **Deterministic per run.** The expiry is derived from the run's
 * `generatedAt`, so the webhook payload and every email attempt — including a
 * retry hours later — carry the same link, and re-sending never extends it.
 *
 * A link is a bearer credential for one report: anyone holding it can
 * download that CSV until it expires. Rotating REPORT_LINK_SECRET revokes
 * every link at once.
 */

/** How long a link works after its run was generated. */
export const REPORT_LINK_TTL_MS = 7 * 24 * 60 * 60 * 1000;

/**
 * Shortest secret accepted. HMAC-SHA256 wants a key of at least its output
 * size; 32 characters of `openssl rand -base64 48` output is well past that,
 * and a short hand-typed value is refused rather than trusted.
 */
export const MIN_REPORT_LINK_SECRET_LENGTH = 32;

const TOKEN_VERSION = 1;
const SIGNING_DOMAIN = 'report-csv.';

/** The run a verified token grants access to. */
export interface ReportLinkClaims {
  clientId: string;
  scheduleId: string;
  runId: string;
  expiresAt: Date;
}

export type LinkSecretState =
  | { ok: true; secret: string }
  | { ok: false; reason: string };

export function reportLinkSecret(env: NodeJS.ProcessEnv = process.env): LinkSecretState {
  const secret = env.REPORT_LINK_SECRET?.trim();
  if (!secret) return { ok: false, reason: 'REPORT_LINK_SECRET is not set' };
  if (secret.length < MIN_REPORT_LINK_SECRET_LENGTH) {
    return {
      ok: false,
      reason: `REPORT_LINK_SECRET is shorter than ${MIN_REPORT_LINK_SECRET_LENGTH} characters`,
    };
  }
  return { ok: true, secret };
}

function sign(secret: string, payload: string): string {
  return createHmac('sha256', secret).update(`${SIGNING_DOMAIN}${payload}`).digest('base64url');
}

/** The instant a run's link expires. */
export function reportLinkExpiry(generatedAt: Date): Date {
  return new Date(generatedAt.getTime() + REPORT_LINK_TTL_MS);
}

export function signReportLinkToken(
  secret: string,
  claims: Omit<ReportLinkClaims, 'expiresAt'> & { expiresAt: Date },
): string {
  const payload = Buffer.from(
    JSON.stringify({
      v: TOKEN_VERSION,
      c: claims.clientId,
      s: claims.scheduleId,
      r: claims.runId,
      e: Math.floor(claims.expiresAt.getTime() / 1000),
    }),
  ).toString('base64url');
  return `${payload}.${sign(secret, payload)}`;
}

export type VerifyResult =
  | { ok: true; claims: ReportLinkClaims }
  | { ok: false; reason: 'malformed' | 'bad_signature' | 'expired' };

/**
 * Checks a token's signature and expiry. The claims it returns still have to
 * match a real run of that tenant — the caller looks the run up by all three
 * ids, so a token for a deleted run, or claims that name another tenant's run,
 * find nothing.
 */
export function verifyReportLinkToken(secret: string, token: string, now: Date = new Date()): VerifyResult {
  const parts = token.split('.');
  if (parts.length !== 2 || !parts[0] || !parts[1]) return { ok: false, reason: 'malformed' };
  const [payload, signature] = parts;

  // Signature first, and in constant time: nothing about the payload is
  // trusted, or even parsed, until the key has vouched for it.
  const expected = Buffer.from(sign(secret, payload));
  const given = Buffer.from(signature);
  if (expected.length !== given.length || !timingSafeEqual(expected, given)) {
    return { ok: false, reason: 'bad_signature' };
  }

  let body: unknown;
  try {
    body = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
  } catch {
    return { ok: false, reason: 'malformed' };
  }
  const b = body as Record<string, unknown>;
  if (
    typeof body !== 'object' ||
    body === null ||
    b.v !== TOKEN_VERSION ||
    typeof b.c !== 'string' ||
    typeof b.s !== 'string' ||
    typeof b.r !== 'string' ||
    typeof b.e !== 'number' ||
    !Number.isFinite(b.e)
  ) {
    return { ok: false, reason: 'malformed' };
  }

  const expiresAt = new Date(b.e * 1000);
  if (expiresAt.getTime() <= now.getTime()) return { ok: false, reason: 'expired' };

  return { ok: true, claims: { clientId: b.c, scheduleId: b.s, runId: b.r, expiresAt } };
}

/** Where a download token is redeemed on this API. */
export function reportDownloadPath(token: string): string {
  return `/report-downloads/${token}`;
}

/** `PUBLIC_API_URL` without a trailing slash, or null when unset. */
export function publicApiBase(env: NodeJS.ProcessEnv = process.env): string | null {
  const base = env.PUBLIC_API_URL?.trim();
  return base ? base.replace(/\/+$/, '') : null;
}

export interface SignedReportLink {
  url: string;
  expiresAt: Date;
}

/**
 * The signed download URL for one run, or null when links are not set up on
 * this deployment (no PUBLIC_API_URL, or no usable REPORT_LINK_SECRET).
 */
export function signedReportLink(
  run: { clientId: string; scheduleId: string; runId: string; generatedAt: Date },
  env: NodeJS.ProcessEnv = process.env,
): SignedReportLink | null {
  const base = publicApiBase(env);
  const secret = reportLinkSecret(env);
  if (!base || !secret.ok) return null;
  const expiresAt = reportLinkExpiry(run.generatedAt);
  const token = signReportLinkToken(secret.secret, { ...run, expiresAt });
  return { url: `${base}${reportDownloadPath(token)}`, expiresAt };
}
