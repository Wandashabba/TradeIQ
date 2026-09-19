import type { Request } from 'express';
import { clientIp, runningOnFly } from './clientIp';

/**
 * The resolver behind the IP-keyed rate limiters.
 *
 * The behavioural end of this — that two agents signing in do not share a
 * bucket — is in `middleware/rateLimit.clientIp.test.ts`. These are the edges
 * that are awkward to reach through a socket: a header that arrives twice, an
 * empty `FLY_APP_NAME`, a request with no `req.ip` at all.
 */
function req(headers: Record<string, string | string[]>, ip?: string): Request {
  return { headers, ip } as unknown as Request;
}

describe('clientIp', () => {
  const original = process.env.FLY_APP_NAME;

  afterEach(() => {
    if (original === undefined) delete process.env.FLY_APP_NAME;
    else process.env.FLY_APP_NAME = original;
  });

  describe('off a Fly Machine', () => {
    beforeEach(() => {
      delete process.env.FLY_APP_NAME;
    });

    it('is the socket address', () => {
      expect(clientIp(req({}, '198.51.100.4'))).toBe('198.51.100.4');
    });

    it('ignores Fly-Client-IP entirely', () => {
      // Nothing stops a caller writing this header. Off-platform the only
      // safe reading of it is "a string someone sent me".
      expect(clientIp(req({ 'fly-client-ip': '1.2.3.4' }, '198.51.100.4'))).toBe('198.51.100.4');
    });

    it('treats an empty FLY_APP_NAME as off-platform', () => {
      // A variable set to '' is a variable that is not set. Reading presence
      // rather than content would open the header up on any host where
      // something exported it blank.
      process.env.FLY_APP_NAME = '   ';
      expect(runningOnFly()).toBe(false);
      expect(clientIp(req({ 'fly-client-ip': '1.2.3.4' }, '198.51.100.4'))).toBe('198.51.100.4');
    });
  });

  describe('on a Fly Machine', () => {
    beforeEach(() => {
      process.env.FLY_APP_NAME = 'tradeiq-backend';
    });

    it('is the address Fly Proxy recorded', () => {
      expect(runningOnFly()).toBe(true);
      expect(clientIp(req({ 'fly-client-ip': '41.13.0.7' }, '172.19.0.1'))).toBe('41.13.0.7');
    });

    it('accepts IPv6, which is most of mobile South Africa', () => {
      expect(clientIp(req({ 'fly-client-ip': '2001:db8::1' }, '172.19.0.1'))).toBe('2001:db8::1');
    });

    it('trims surrounding whitespace', () => {
      expect(clientIp(req({ 'fly-client-ip': ' 41.13.0.7 ' }, '172.19.0.1'))).toBe('41.13.0.7');
    });

    it('falls back when the header arrives more than once', () => {
      // Node joins repeats of a non-Set-Cookie header with ", ". Fly Proxy
      // writes one value, so two means the pair is not what Fly wrote, and the
      // joined string is not an address anyway.
      expect(clientIp(req({ 'fly-client-ip': '1.2.3.4, 41.13.0.7' }, '172.19.0.1'))).toBe(
        '172.19.0.1',
      );
      expect(clientIp(req({ 'fly-client-ip': ['1.2.3.4', '41.13.0.7'] }, '172.19.0.1'))).toBe(
        '172.19.0.1',
      );
    });

    it.each([['not-an-ip'], [''], ['999.999.999.999'], ['41.13.0.7:443']])(
      'falls back when the header is not an address (%p)',
      (value) => {
        expect(clientIp(req({ 'fly-client-ip': value }, '172.19.0.1'))).toBe('172.19.0.1');
      },
    );

    it('returns undefined when there is nothing to go on, so callers fail closed', () => {
      // `keyGenerator` turns this into one shared bucket rather than a free
      // pass — the strictest treatment available, never "no limit applies".
      expect(clientIp(req({}))).toBeUndefined();
    });
  });
});
