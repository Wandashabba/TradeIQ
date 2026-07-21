import { lookup as dnsLookupCb } from 'dns';
import { Agent } from 'undici';
import { isPrivateAddress } from './urlGuard';

/**
 * The shape Node's `dns.lookup` presents to undici's connector.
 *
 * Deliberately loose: undici calls it with `{ all: true }`, so the callback
 * receives an array, while the single-address signature is what the types
 * describe. Both are handled below.
 */
export type ConnectLookup = (
  hostname: string,
  options: Record<string, unknown>,
  callback: (
    err: NodeJS.ErrnoException | null,
    address: string | Array<{ address: string; family: number }>,
    family?: number,
  ) => void,
) => void;

/**
 * Wraps a DNS lookup so the address actually handed to the socket is the one
 * that gets validated.
 *
 * This is what closes the rebinding hole. `assertPublicHostname` resolves the
 * name, and then `fetch` resolves it *again* — two independent answers, so an
 * attacker with authoritative DNS and TTL=0 can serve a public address to the
 * check and a private one to the connect. That was proven end to end during
 * the Plan 1 review: the guard passed on a public address while the fetch
 * returned attacker content.
 *
 * Validating inside the connector removes the second resolution from the
 * equation entirely: there is exactly one answer, and the socket cannot be
 * given an address that was not checked.
 *
 * Injectable so the rebinding case can be exercised offline — a test can hand
 * back a private address that no real resolver would return for a public name.
 */
export function createGuardedLookup(dnsLookup = dnsLookupCb): ConnectLookup {
  return (hostname, options, callback) => {
    (dnsLookup as unknown as ConnectLookup)(hostname, options, (err, address, family) => {
      if (err) {
        callback(err, address, family);
        return;
      }

      const candidates = Array.isArray(address)
        ? address.map((entry) => entry.address)
        : [address];

      for (const candidate of candidates) {
        if (isPrivateAddress(candidate)) {
          // ECONNREFUSED rather than a bespoke code: undici surfaces this as an
          // ordinary connection failure, which the dispatcher already treats as
          // a failed delivery. A subscriber must not be able to distinguish
          // "your DNS pointed somewhere private" from "your server was down" —
          // that difference is a probe of our internal network.
          const denied: NodeJS.ErrnoException = new Error(
            `Refusing to connect to ${hostname}: resolved to a private address`,
          );
          denied.code = 'ECONNREFUSED';
          callback(denied, '', undefined);
          return;
        }
      }

      callback(null, address, family);
    });
  };
}

/**
 * The dispatcher every outbound webhook must use.
 *
 * Keeping it a module-level singleton is deliberate: undici pools connections
 * per-Agent, and building one per dispatch would discard the pool and open a
 * fresh socket for every event.
 */
export const ssrfSafeAgent = new Agent({
  connect: {
    lookup: createGuardedLookup() as never,
  },
});
