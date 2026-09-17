/**
 * robots.txt, per RFC 9309 (the Robots Exclusion Protocol).
 *
 * Implemented rather than approximated, because "we checked robots.txt" is a
 * claim this feature's legal position leans on:
 *
 * - Groups: one or more `user-agent` lines followed by rules. Every group whose
 *   user-agent matches our product token (case-insensitive) is combined; only
 *   when none matches are the `*` groups used.
 * - Rules: `allow` / `disallow` with `*` (any run of characters) and a trailing
 *   `$` (end of path). The MOST SPECIFIC match — the longest pattern — wins,
 *   and `allow` wins a tie. An empty `disallow` matches nothing.
 * - Paths are compared after percent-encoding normalisation, so `/caf%C3%A9`
 *   and `/café` are the same path.
 * - `crawl-delay` is not in the RFC, but where a site states one it is honoured
 *   as a floor on our spacing: asking politely is the point.
 *
 * What happens when robots.txt cannot be read is decided in the fetcher, not
 * here (see `robotsForStatus`).
 */

export interface RobotsRule {
  allow: boolean;
  pattern: string;
}

export interface RobotsPolicy {
  /** Is this path (path + query) allowed for our token? */
  isAllowed(pathAndQuery: string): boolean;
  /** Seconds, when the matched group states one. */
  crawlDelaySeconds: number | null;
}

interface Group {
  agents: string[];
  rules: RobotsRule[];
  crawlDelay: number | null;
}

/** RFC 9309 §2.5: parsers must handle at least 500 KiB. Beyond that is ignored. */
export const ROBOTS_MAX_BYTES = 500 * 1024;

function normaliseEncoding(value: string): string {
  // Decode what can be decoded, then re-encode consistently. Percent-escapes
  // that do not decode (a lone `%`) are left as they were.
  let decoded: string;
  try {
    decoded = decodeURI(value);
  } catch {
    decoded = value;
  }
  return encodeURI(decoded).replace(/%[0-9a-f]{2}/gi, (m) => m.toUpperCase());
}

function parseGroups(text: string): Group[] {
  const groups: Group[] = [];
  let current: Group | null = null;
  let lastWasAgent = false;

  for (const rawLine of text.slice(0, ROBOTS_MAX_BYTES).split(/\r\n|\r|\n/)) {
    const line = rawLine.replace(/#.*$/, '').trim();
    if (line === '') continue;
    const colon = line.indexOf(':');
    if (colon === -1) continue;
    const key = line.slice(0, colon).trim().toLowerCase();
    const value = line.slice(colon + 1).trim();

    if (key === 'user-agent') {
      if (!current || !lastWasAgent) {
        current = { agents: [], rules: [], crawlDelay: null };
        groups.push(current);
      }
      current.agents.push(value.toLowerCase());
      lastWasAgent = true;
      continue;
    }

    lastWasAgent = false;
    // A rule before any user-agent line belongs to no group (RFC 9309 §2.2.1).
    if (!current) continue;

    if (key === 'allow' || key === 'disallow') {
      // An empty disallow means "nothing disallowed", which is no rule at all.
      if (value === '') continue;
      current.rules.push({ allow: key === 'allow', pattern: normaliseEncoding(value) });
    } else if (key === 'crawl-delay') {
      const seconds = Number(value);
      if (Number.isFinite(seconds) && seconds >= 0) current.crawlDelay = seconds;
    }
    // sitemap and unknown keys are ignored.
  }
  return groups;
}

function patternToRegExp(pattern: string): RegExp {
  const anchored = pattern.endsWith('$');
  const body = anchored ? pattern.slice(0, -1) : pattern;
  const source = body
    .split('*')
    .map((part) => part.replace(/[.+?^${}()|[\]\\]/g, '\\$&'))
    .join('.*');
  return new RegExp(`^${source}${anchored ? '$' : ''}`);
}

/**
 * Whether `agentLine` names our product token. RFC 9309 matches the product
 * token case-insensitively; a line like `TradeIQPriceBot/1.0` is also ours.
 */
function agentMatches(agentLine: string, token: string): boolean {
  const name = agentLine.split('/')[0].trim();
  return name === token.toLowerCase();
}

export function parseRobots(text: string, token: string): RobotsPolicy {
  const groups = parseGroups(text);
  let matched = groups.filter((g) => g.agents.some((a) => agentMatches(a, token)));
  if (matched.length === 0) matched = groups.filter((g) => g.agents.includes('*'));

  const rules = matched.flatMap((g) => g.rules).map((r) => ({ ...r, re: patternToRegExp(r.pattern) }));
  const delays = matched.map((g) => g.crawlDelay).filter((d): d is number => d !== null);

  return {
    crawlDelaySeconds: delays.length > 0 ? Math.max(...delays) : null,
    isAllowed(pathAndQuery: string): boolean {
      const target = normaliseEncoding(pathAndQuery || '/');
      // robots.txt itself is always allowed (RFC 9309 §2.2.2).
      if (target === '/robots.txt') return true;
      let best: { allow: boolean; length: number } | null = null;
      for (const rule of rules) {
        if (!rule.re.test(target)) continue;
        const length = rule.pattern.length;
        if (!best || length > best.length || (length === best.length && rule.allow && !best.allow)) {
          best = { allow: rule.allow, length };
        }
      }
      return best ? best.allow : true;
    },
  };
}

/** Everything allowed — for a robots.txt that does not exist (4xx). */
export const ALLOW_ALL: RobotsPolicy = { isAllowed: () => true, crawlDelaySeconds: null };
/** Nothing allowed — for a robots.txt that could not be read (5xx, network). */
export const DISALLOW_ALL: RobotsPolicy = { isAllowed: () => false, crawlDelaySeconds: null };

/**
 * What an unreadable robots.txt means, by status.
 *
 * RFC 9309 §2.3.1.3–4: a 4xx means there are no restrictions; a 5xx or a
 * network failure means assume complete disallow. We are stricter on one
 * point: a 401 or 403 on robots.txt itself is a site refusing us, and is read
 * as complete disallow rather than as permission.
 */
export function robotsForStatus(status: number): RobotsPolicy | null {
  if (status >= 200 && status < 300) return null; // parse the body
  if (status === 401 || status === 403 || status === 429) return DISALLOW_ALL;
  if (status >= 400 && status < 500) return ALLOW_ALL;
  return DISALLOW_ALL;
}
