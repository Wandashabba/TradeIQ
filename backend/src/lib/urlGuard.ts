import { lookup as dnsLookup } from 'dns/promises';
import { isIP } from 'net';

/**
 * SSRF guards for outbound URLs the user controls (today: webhook targets).
 *
 * Two layers, because DNS is not stable between registration and fire:
 *   - `parsePublicHttpUrl` — sync shape check at registration. No DNS, so
 *     route handlers stay fast and their tests need no network.
 *   - `assertPublicHostname` — re-checked immediately before `fetch`. Takes an
 *     injected lookup so it unit-tests offline.
 *
 * DNS rebinding is closed by a third layer, `ssrfAgent.ts`, which validates the
 * address inside undici's connector so that one resolution is both checked and
 * used. These two layers are still necessary rather than redundant:
 *
 *   - undici skips `connect.lookup` entirely when the host is a literal IP,
 *     so the connector never sees `http://169.254.169.254/`. Only
 *     `parsePublicHttpUrl` / `assertPublicHostname` catch that.
 *   - failing at registration gives the user a clear error, where a connector
 *     refusal surfaces much later as an ordinary delivery failure.
 */

export type LookupFn = (
  hostname: string,
  options: { all: true },
) => Promise<Array<{ address: string; family: number }>>;

function isPrivateIpv4(ip: string): boolean {
  const parts = ip.split('.').map(Number);
  if (parts.length !== 4 || parts.some((p) => Number.isNaN(p))) return true; // unparseable → deny
  const [a, b, c] = parts;
  if (a === 0) return true; // "this network"
  if (a === 10) return true; // RFC1918
  if (a === 127) return true; // loopback
  if (a === 169 && b === 254) return true; // link-local + AWS/GCP/Azure metadata
  if (a === 172 && b >= 16 && b <= 31) return true; // RFC1918
  if (a === 192 && b === 168) return true; // RFC1918
  if (a === 192 && b === 0 && c === 0) return true; // 192.0.0.0/24 IETF protocol assignments
  // 100.64.0.0/10 (RFC6598) carrier-grade NAT. Reachable private infrastructure
  // under Tailscale and CGNAT'd VPC/EKS pod networks, and it holds Alibaba
  // Cloud's metadata endpoint at 100.100.100.200 — the same attack as
  // 169.254.169.254. Note the mask: only 100.64–100.127, not all of 100.x.
  if (a === 100 && b >= 64 && b <= 127) return true;
  if (a === 198 && (b === 18 || b === 19)) return true; // 198.18.0.0/15 benchmarking (RFC2544)
  if (a >= 224) return true; // multicast (224/4) + reserved (240/4) + broadcast
  return false;
}

/**
 * Expands an IPv6 literal into its 8 hextets, or null when it will not parse.
 *
 * We classify on numbers rather than string prefixes because prefixes fail
 * open: `startsWith('fe80')` misses fe90–febf, which are equally link-local,
 * and any leading-zero form (`0064:ff9b::`) slips a textual match entirely.
 */
function ipv6Hextets(input: string): number[] | null {
  let v = input;

  // A trailing dotted quad (`::ffff:127.0.0.1`, `64:ff9b::192.0.2.1`) occupies
  // the last two hextets — rewrite it to hex so the rest parses uniformly.
  const dotted = /(\d{1,3}(?:\.\d{1,3}){3})$/.exec(v);
  if (dotted) {
    const q = dotted[1].split('.').map(Number);
    if (q.some((n) => Number.isNaN(n) || n > 255)) return null;
    const hi = ((q[0] << 8) | q[1]).toString(16);
    const lo = ((q[2] << 8) | q[3]).toString(16);
    v = `${v.slice(0, dotted.index)}${hi}:${lo}`;
  }

  const halves = v.split('::');
  if (halves.length > 2) return null; // at most one '::' per RFC4291
  const split = (s: string) => (s === '' ? [] : s.split(':'));
  const head = split(halves[0]);
  const tail = halves.length === 2 ? split(halves[1]) : [];

  let groups: string[];
  if (halves.length === 2) {
    const fill = 8 - head.length - tail.length;
    if (fill < 1) return null;
    groups = [...head, ...Array<string>(fill).fill('0'), ...tail];
  } else {
    groups = head;
  }
  if (groups.length !== 8) return null;
  if (!groups.every((g) => /^[0-9a-f]{1,4}$/.test(g))) return null; // parseInt would truncate
  return groups.map((g) => parseInt(g, 16));
}

function isPrivateIpv6(ip: string): boolean {
  const h = ipv6Hextets(ip.toLowerCase().split('%')[0]); // strip any zone index
  if (h === null) return true; // unparseable → deny

  const zeros = (from: number, to: number) => h.slice(from, to).every((x) => x === 0);

  if (zeros(0, 7) && (h[7] === 0 || h[7] === 1)) return true; // :: and ::1

  // ::ffff:0:0/96 — IPv4-mapped. Judge the address it actually carries.
  if (zeros(0, 5) && h[5] === 0xffff) {
    return isPrivateIpv4(`${h[6] >> 8}.${h[6] & 0xff}.${h[7] >> 8}.${h[7] & 0xff}`);
  }

  // 64:ff9b::/96 — NAT64. Reaches IPv4 through a translator, so the whole
  // prefix is denied rather than judged on its embedded address: a translator
  // is exactly the thing that would carry us into private v4 space.
  if (h[0] === 0x64 && h[1] === 0xff9b && zeros(2, 6)) return true;

  if ((h[0] & 0xfe00) === 0xfc00) return true; // fc00::/7 unique-local
  if ((h[0] & 0xffc0) === 0xfe80) return true; // fe80::/10 link-local (fe80–febf)
  return false;
}

/** True for loopback, RFC1918, link-local, unique-local, multicast and reserved. */
export function isPrivateAddress(ip: string): boolean {
  const family = isIP(ip);
  if (family === 4) return isPrivateIpv4(ip);
  if (family === 6) return isPrivateIpv6(ip);
  return true; // not an IP at all → deny
}

/**
 * Parses a user-supplied webhook URL. Returns null when it is not a plain
 * http(s) URL or when its host is a literal private address.
 *
 * The check this replaces was `url.startsWith('http')`, which accepted
 * `http://169.254.169.254/`, `http://localhost:6379/` and `httpfoo://…`.
 */
export function parsePublicHttpUrl(raw: string): URL | null {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return null;
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') return null;

  // `new URL('http://[::1]/')` gives hostname '[::1]' — unwrap before isIP.
  const host = url.hostname.replace(/^\[|\]$/g, '');
  if (host.length === 0) return null;
  if (host.toLowerCase() === 'localhost') return null;
  if (isIP(host) !== 0 && isPrivateAddress(host)) return null;
  return url;
}

/**
 * Resolves `hostname` and throws unless every address is public. Call this
 * immediately before fetching — a name that was public at registration can
 * point at 169.254.169.254 by the time the event fires.
 *
 * Closes registration→fire drift only, NOT check→connect drift: the caller's
 * `fetch` performs its own resolution, which can differ from this one. See the
 * file header.
 */
export async function assertPublicHostname(
  hostname: string,
  lookup: LookupFn = dnsLookup as unknown as LookupFn,
): Promise<void> {
  const host = hostname.replace(/^\[|\]$/g, '');
  if (isIP(host) !== 0) {
    if (isPrivateAddress(host)) {
      throw new Error(`Webhook host ${hostname} resolves to a private address`);
    }
    return;
  }

  let addresses: Array<{ address: string }>;
  try {
    addresses = await lookup(host, { all: true });
  } catch {
    throw new Error(`Webhook host ${hostname} could not be resolved`);
  }
  if (addresses.length === 0) {
    throw new Error(`Webhook host ${hostname} could not be resolved`);
  }
  for (const { address } of addresses) {
    if (isPrivateAddress(address)) {
      throw new Error(`Webhook host ${hostname} resolves to a private address`);
    }
  }
}
