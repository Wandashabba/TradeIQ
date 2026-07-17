import { lookup as dnsLookup } from 'dns/promises';
import { isIP } from 'net';

/**
 * SSRF guards for outbound URLs the user controls (today: webhook targets).
 *
 * Two layers, because DNS is not stable between registration and fire:
 *   - `parsePublicHttpUrl` — sync shape check at registration. No DNS, so
 *     route handlers stay fast and their tests need no network.
 *   - `assertPublicHostname` — the real boundary, called immediately before
 *     `fetch`. Takes an injected lookup so it unit-tests offline.
 */

export type LookupFn = (
  hostname: string,
  options: { all: true },
) => Promise<Array<{ address: string; family: number }>>;

function isPrivateIpv4(ip: string): boolean {
  const parts = ip.split('.').map(Number);
  if (parts.length !== 4 || parts.some((p) => Number.isNaN(p))) return true; // unparseable → deny
  const [a, b] = parts;
  if (a === 0) return true; // "this network"
  if (a === 10) return true; // RFC1918
  if (a === 127) return true; // loopback
  if (a === 169 && b === 254) return true; // link-local + cloud metadata
  if (a === 172 && b >= 16 && b <= 31) return true; // RFC1918
  if (a === 192 && b === 168) return true; // RFC1918
  if (a >= 224) return true; // multicast (224/4) + reserved (240/4) + broadcast
  return false;
}

function isPrivateIpv6(ip: string): boolean {
  const v = ip.toLowerCase().split('%')[0]; // strip any zone index
  if (v === '::1' || v === '::') return true;
  if (v.startsWith('::ffff:')) {
    const mapped = v.slice('::ffff:'.length);
    return isIP(mapped) === 4 ? isPrivateIpv4(mapped) : true;
  }
  if (v.startsWith('fc') || v.startsWith('fd')) return true; // unique-local
  if (v.startsWith('fe80')) return true; // link-local
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
