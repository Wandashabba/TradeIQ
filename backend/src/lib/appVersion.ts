/**
 * Parsing and comparing the app build a request came from (#400).
 *
 * `api_client.dart` used to send only `Authorization`, so the server had no
 * idea which build it was talking to. That is not an abstract gap:
 * `local_db.dart`'s `from < 7` migration left older outbox rows unowned and
 * they never flushed, and support could not tell which build had produced a
 * stuck row because nothing in the request said.
 *
 * Two separate jobs, and it matters that they are separate:
 *   - **Knowing** the build. Free, harmless, always on.
 *   - **Refusing** a build. Off unless an operator sets a floor, because a
 *     forced upgrade is a decision with a cost — it takes working phones out of
 *     the field until someone finds Wi-Fi.
 */

export interface AppVersion {
  major: number;
  minor: number;
  patch: number;
}

/**
 * Parses `1.4.2`, `1.4`, `1`, and the decorated forms a build pipeline
 * produces: `1.4.2+318` (Flutter's build number) and `1.4.2-beta.3`.
 *
 * Missing components read as 0, so `1.4` is `1.4.0` — the reading that makes
 * "at least 1.4" behave the way whoever typed it meant.
 *
 * Returns null for anything else, INCLUDING an empty string. A caller must
 * decide what an unparseable version means; guessing here would bury that
 * decision in a parser.
 */
export function parseAppVersion(raw: unknown): AppVersion | null {
  if (typeof raw !== 'string') return null;
  // Strip a build suffix (`+318`) and a pre-release suffix (`-beta.3`) before
  // the numeric match. Both sort AFTER the release they decorate for our
  // purposes, which is the lenient direction: a tester on `1.4.2-beta.3` is not
  // locked out by a floor of `1.4.2`. That is a deliberate trade — this gate
  // exists to move a fleet off genuinely old builds, not to police pre-release
  // ordering.
  const core = raw.trim().split('+')[0]!.split('-')[0]!;
  const match = /^(\d{1,6})(?:\.(\d{1,6}))?(?:\.(\d{1,6}))?$/.exec(core);
  if (!match) return null;
  return {
    major: Number(match[1]),
    minor: Number(match[2] ?? 0),
    patch: Number(match[3] ?? 0),
  };
}

/** Negative when `a` is older than `b`, 0 when equal, positive when newer. */
export function compareAppVersions(a: AppVersion, b: AppVersion): number {
  if (a.major !== b.major) return a.major - b.major;
  if (a.minor !== b.minor) return a.minor - b.minor;
  return a.patch - b.patch;
}

/** Renders a parsed version back to `major.minor.patch`. */
export function formatAppVersion(v: AppVersion): string {
  return `${v.major}.${v.minor}.${v.patch}`;
}
