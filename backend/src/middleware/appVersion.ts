import { NextFunction, Request, Response } from 'express';
import { compareAppVersions, formatAppVersion, parseAppVersion } from '../lib/appVersion';

/**
 * The `X-App-Version` gate (#400).
 *
 * ## The header
 *
 * Every request from the Flutter app now carries `X-App-Version: <version>`
 * (and `X-App-Build`, which this gate ignores but a log or a stuck-row
 * investigation can read). It is attached on `req.appVersion` for anything
 * downstream that wants it.
 *
 * ## The floor, and why it is off by default
 *
 * `MIN_APP_VERSION` is unset by default, and unset means **no minimum**: this
 * middleware then does nothing but record. That default is not timidity, it is
 * the only backward-compatible one. Every build in the field today sends no
 * version header at all, so any floor that treated "no header" as "too old"
 * would, the moment an operator set the variable, take the entire fleet offline
 * — which is precisely the outage a forced-upgrade path is supposed to prevent.
 *
 * So there are two switches, not one:
 *   - `MIN_APP_VERSION` — e.g. `1.5.0`. Refuses builds that SAY they are older.
 *   - `MIN_APP_VERSION_REQUIRE_HEADER` — `true` refuses builds that say
 *     nothing. Default false. Turn it on only once the header-sending build is
 *     itself the floor, at which point "no header" genuinely does mean "older
 *     than the floor".
 *
 * ## The response
 *
 * `426 Upgrade Required`, with a machine-readable discriminator so the client
 * does not have to match on prose:
 *
 * ```json
 * { "error": "…", "code": "app_update_required", "minimumVersion": "1.5.0" }
 * ```
 *
 * 426 and not 401: a 401 makes the app sign the user out and ask for a password
 * they do not need to re-enter, and `api_client.dart`'s interceptor does
 * exactly that on any 401. The build is stale; the session is fine.
 *
 * `/health` is exempt. An ops probe is not an app build, and a load balancer
 * pulling every instance out of rotation because of an app-version setting
 * would be a self-inflicted outage.
 */

/** The response body's `code`, so the client matches a constant, not prose. */
export const APP_UPDATE_REQUIRED_CODE = 'app_update_required';

export interface VersionedRequest extends Request {
  /** The raw header, exactly as sent. Undefined when the client sent none. */
  appVersion?: string;
}

function requireHeaderConfigured(): boolean {
  return (process.env.MIN_APP_VERSION_REQUIRE_HEADER ?? '').trim().toLowerCase() === 'true';
}

export function appVersionGate(
  req: VersionedRequest,
  res: Response,
  next: NextFunction,
): void {
  const header = req.headers['x-app-version'];
  // Express gives an array when a header is repeated. Take the first rather
  // than joining: a joined value parses as nothing and would read as "unknown"
  // even though the client did say.
  const raw = Array.isArray(header) ? header[0] : header;
  if (typeof raw === 'string' && raw.length > 0) {
    // Bounded before it is stored or logged. A header is attacker-controlled,
    // and an unbounded one is a way to put a megabyte into every log line.
    req.appVersion = raw.slice(0, 64);
  }

  if (req.path === '/health') {
    next();
    return;
  }

  const configured = (process.env.MIN_APP_VERSION ?? '').trim();
  if (configured.length === 0) {
    next();
    return;
  }

  const minimum = parseAppVersion(configured);
  if (!minimum) {
    // Fail OPEN, loudly. A typo in an env var must not lock every agent out of
    // the product — the failure mode of the safe direction is a gate that is
    // not enforcing, which is exactly the state the system was in yesterday.
    console.warn(
      `[app-version] MIN_APP_VERSION is not a version I can parse; the gate is not enforcing. ` +
        `Expected something like "1.5.0".`,
    );
    next();
    return;
  }

  const sent = req.appVersion ? parseAppVersion(req.appVersion) : null;
  const tooOld = sent ? compareAppVersions(sent, minimum) < 0 : requireHeaderConfigured();

  if (!tooOld) {
    next();
    return;
  }

  res.status(426).json({
    error:
      'This version of the TradeIQ app is too old to talk to the server. ' +
      'Please update the app to carry on.',
    code: APP_UPDATE_REQUIRED_CODE,
    minimumVersion: formatAppVersion(minimum),
  });
}
