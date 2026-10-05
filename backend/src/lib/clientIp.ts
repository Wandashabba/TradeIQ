import { isIP } from 'net';
import type { Request } from 'express';

/**
 * Who is knocking — the caller's real IP, for the limiters keyed on the
 * *attacker* rather than on a signed-in identity (login, and the per-IP half of
 * the reset-redeem pair).
 *
 * ## The bug this exists to fix
 *
 * `req.ip` alone was wrong in production. Express leaves `trust proxy` off by
 * default, so `req.ip` is the socket peer — and on Fly.io the socket peer is
 * Fly's proxy, the same address for every request that reaches the app. Both
 * IP-keyed limiters therefore collapsed the entire fleet onto ONE bucket:
 *
 *   - `POST /auth/reset-password`'s per-IP backstop, which is supposed to stop
 *     "one guess each at a thousand accounts", was a single global 60/15min
 *     counter rather than a per-attacker one; and, far worse,
 *   - `POST /auth/login` at 10/15min was a global cap. Roughly eleven honest
 *     logins across every tenant in a quarter of an hour locked everyone out.
 *     On a deployment built for shared cheap phones in the field — where a
 *     depot's agents sign in one after another on the same handset — that is a
 *     self-inflicted outage, not a theoretical one.
 *
 * ## Why not `app.set('trust proxy', 1)`
 *
 * That is the obvious fix and it is the wrong one here. With one hop trusted,
 * Express reads the **rightmost** `X-Forwarded-For` entry (verified, not
 * assumed: `trust proxy: 1` against `9.9.9.9, 203.0.113.7` yields
 * `203.0.113.7`). But Fly's own documentation says of `X-Forwarded-For`:
 *
 *   > "On the Fly.io platform, the last address (rightmost) in this list will
 *   > be a shared or dedicated IP address assigned to your app."
 *
 * The rightmost entry is the app's own anycast address — a constant. Trusting
 * one hop would swap one fleet-wide bucket for another and fix nothing, while
 * looking like a fix.
 *
 * And trusting *two* hops, the natural next guess once someone notices that,
 * is actively dangerous: it reaches the leftmost entry, which is whatever the
 * client sent. An attacker would put a fresh invented address in
 * `X-Forwarded-For` on every request and walk past every per-IP limiter in the
 * codebase. That is strictly worse than the shared bucket it replaced.
 *
 * So `trust proxy` stays **off** (`app.ts` sets it to `false` explicitly, with
 * a pointer here) and the client IP is read from the header Fly sets instead.
 *
 * ## `Fly-Client-IP`, and the `FLY_APP_NAME` guard
 *
 * Fly documents `Fly-Client-IP` as "the IP address of the client from the
 * perspective of Fly Proxy", and recommends it over parsing `X-Forwarded-For`
 * for exactly our shape — no other reverse proxy in front of Fly. Fly Proxy
 * sets it on every request it handles, so a client-supplied value does not
 * survive to the app.
 *
 * It is only honoured when `FLY_APP_NAME` is set, which Fly injects into every
 * Machine and which a request cannot mint. Off-platform — a laptop, a test, a
 * container run straight from the Dockerfile — the header is ignored outright,
 * so forging it buys nothing. This is the whole reason the check is on an
 * environment variable rather than on the header's presence.
 *
 * The value must also parse as a single address. `isIP` rejects anything else,
 * which includes the comma-joined form Node produces when a header arrives
 * more than once — so a duplicated `Fly-Client-IP` falls back rather than
 * becoming a limiter key in its own right.
 *
 * ## Verifying it on the live app
 *
 * This is the one claim here that the repository cannot prove by itself, so
 * `docs/operations/deploy-hardening.md` §5 carries the one-command check
 * against the deployed backend, plus what to do if it ever comes back false.
 */

/**
 * True when this process is running on a Fly Machine.
 *
 * `FLY_APP_NAME` is part of the Machine runtime environment. It is not
 * something an HTTP request can set, which is precisely the point: it lets a
 * forged `Fly-Client-IP` be ignored everywhere except where Fly itself is the
 * one writing the header.
 */
export function runningOnFly(): boolean {
  return (process.env.FLY_APP_NAME ?? '').trim().length > 0;
}

/**
 * True when this process is running on Render.
 *
 * Same contract as `runningOnFly`, and for the same reason: `RENDER` is part of
 * the service runtime environment and no HTTP request can set it, so a forged
 * forwarding header is ignored everywhere except where Render itself is the one
 * writing it.
 *
 * This exists because the move off Fly silently removed the whole protection
 * above. `FLY_APP_NAME` is unset on Render, so `clientIp()` fell through to
 * `req.ip`; `app.ts` pins `trust proxy` to false, so that is the socket peer,
 * which behind Render's proxy is the proxy itself. Every caller in the fleet
 * collapsed onto one bucket again — `POST /auth/login` at 10 per 15 minutes
 * becoming a global cap is the outage #160 was opened to fix.
 *
 * ## What Render actually sends, measured
 *
 * Taken against the live service on 5 October 2026 with a temporary probe,
 * since none of this can be proven from the repository. Render fronts
 * `*.onrender.com` with Cloudflare, and the measurement from a client whose
 * real address was `196.50.223.130` was:
 *
 * | | value | forgeable? |
 * |---|---|---|
 * | `req.ip` | `::ffff:10.194.163.130` | — |
 * | `X-Forwarded-For` | `196.50.223.130, 162.158.110.13` | **yes** |
 * | `True-Client-IP` | `196.50.223.130` | no |
 * | `CF-Connecting-IP` | `196.50.223.130` | no |
 *
 * Three things follow, and each one rules out an otherwise reasonable choice:
 *
 * 1. `req.ip` is a PRIVATE 10.x address that CHANGES between requests
 *    (10.194.163.130, 10.192.245.168, 10.194.73.133 across three calls). It is
 *    the internal Render proxy that happened to handle the request, so the
 *    limiters were not even keyed on one stable bucket — they were keyed on an
 *    unpredictable handful of them, shared by every caller alive.
 *
 * 2. The LEFTMOST `X-Forwarded-For` entry is attacker-controlled. Sending
 *    `X-Forwarded-For: 203.0.113.99` produced
 *    `203.0.113.99,196.50.223.130, 162.158.110.13` — prepended, not replaced.
 *    So the Fly trap exists here too, simply at the other end of the list.
 *
 * 3. `True-Client-IP` and `CF-Connecting-IP` are written by the edge and a
 *    client-supplied value does not survive. Sending `True-Client-IP:
 *    198.51.100.5` still yielded `196.50.223.130`, repeatedly. Sending
 *    `CF-Connecting-IP` at all is refused by Cloudflare outright with
 *    `403 error code 1000`, before the request reaches this app.
 *
 * Hence `CF-Connecting-IP`, then `True-Client-IP`. Both are validated with
 * `isIP` exactly as the Fly branch is, so if Render ever stops fronting with
 * Cloudflare — a custom domain is the likely way — the value fails validation
 * and this degrades to the shared `req.ip` bucket. That is the safe direction:
 * too strict, never forgeable.
 */
export function runningOnRender(): boolean {
  return (process.env.RENDER ?? '').trim().length > 0;
}

/**
 * The client IP to key a rate limiter on, or `undefined` if none can be
 * determined.
 *
 * Callers must fail **closed** on `undefined` — one shared bucket — and never
 * treat it as "no limit applies".
 */
export function clientIp(req: Request): string | undefined {
  if (runningOnFly()) {
    const value = singleAddress(req, 'fly-client-ip');
    if (value) return value;
  }

  if (runningOnRender()) {
    // In this order because Cloudflare refuses a request that carries
    // `CF-Connecting-IP` at all, so it is the one a caller cannot even attempt.
    // `True-Client-IP` is accepted and then overwritten, which is equally safe
    // but one step further from the edge.
    const value = singleAddress(req, 'cf-connecting-ip') ?? singleAddress(req, 'true-client-ip');
    if (value) return value;
  }

  return req.ip;
}

/**
 * One header, read as a single IP address, or `undefined`.
 *
 * `isIP` is the whole guard. It rejects the comma-joined form Node produces
 * when a header arrives more than once, so a duplicated header falls back
 * rather than becoming a limiter key in its own right — and it rejects the
 * empty or malformed value left behind if a platform ever stops setting the
 * header, which is what makes the fallback to `req.ip` safe rather than silent.
 */
function singleAddress(req: Request, header: string): string | undefined {
  const raw = req.headers[header];
  const value = typeof raw === 'string' ? raw.trim() : undefined;
  return value && isIP(value) !== 0 ? value : undefined;
}
