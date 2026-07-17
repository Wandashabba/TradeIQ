import { isPrivateAddress, parsePublicHttpUrl, assertPublicHostname } from './urlGuard';

describe('isPrivateAddress', () => {
  it.each([
    '127.0.0.1',
    '10.0.0.1',
    '172.16.0.1',
    '172.31.255.255',
    '192.168.1.1',
    '169.254.169.254', // AWS/GCP/Azure cloud metadata
    '0.0.0.0',
    '224.0.0.1',
    '100.100.100.200', // Alibaba Cloud metadata — CGNAT space, same attack as 169.254.169.254
    '100.64.0.1', // CGNAT (RFC6598) low bound — Tailscale, CGNAT'd VPC/EKS pod networks
    '100.127.255.255', // CGNAT high bound
    '198.18.0.1', // benchmarking (RFC2544)
    '198.19.255.255', // benchmarking, high half of the /15
    '192.0.0.1', // IETF protocol assignments (192.0.0.0/24)
    '::1',
    'fd00::1',
    'fe80::1',
    'fe90::1', // link-local is fe80::/10 (fe80–febf), not fe80::/16
    'febf::1', // link-local upper bound
    'febf:0:0::1', // same, in a different compressed form
    '64:ff9b::7f00:1', // NAT64 — maps IPv4 (here 127.0.0.1) into IPv6
    '::ffff:127.0.0.1', // IPv4-mapped loopback
  ])('treats %s as private', (ip) => {
    expect(isPrivateAddress(ip)).toBe(true);
  });

  it.each([
    '8.8.8.8',
    '1.1.1.1',
    '93.184.216.34',
    '2606:2800:220:1::248',
    '::ffff:8.8.8.8', // IPv4-mapped, but mapping a public address
  ])('treats %s as public', (ip) => {
    expect(isPrivateAddress(ip)).toBe(false);
  });

  it('does not treat 172.32.x as private (boundary above the RFC1918 block)', () => {
    expect(isPrivateAddress('172.32.0.1')).toBe(false);
  });

  it('does not treat 11.x as private (boundary above the 10/8 block)', () => {
    expect(isPrivateAddress('11.0.0.1')).toBe(false);
  });

  it('does not treat all of 100.x as private — CGNAT is 100.64.0.0/10, not 100.0.0.0/8', () => {
    expect(isPrivateAddress('100.63.255.255')).toBe(false); // just below the block
    expect(isPrivateAddress('100.128.0.1')).toBe(false); // just above the block
  });

  it('does not treat 198.20.x as private (boundary above the 198.18.0.0/15 block)', () => {
    expect(isPrivateAddress('198.20.0.1')).toBe(false);
  });

  it('does not treat 192.0.1.x as private (boundary above the 192.0.0.0/24 block)', () => {
    expect(isPrivateAddress('192.0.1.1')).toBe(false);
  });

  it('treats 223.255.255.255 as public — the highest legitimate unicast address', () => {
    // The reserved/multicast deny starts at 224. One off here would blackhole
    // a real subscriber, so pin the boundary.
    expect(isPrivateAddress('223.255.255.255')).toBe(false);
  });

  it('treats fec0::1 as public — site-local is deprecated, and is not link-local', () => {
    // fec0::/10 sits directly above fe80::/10. A mask that catches it would be
    // over-blocking, and it is not reachable-private the way fe80 is.
    expect(isPrivateAddress('fec0::1')).toBe(false);
  });
});

describe('parsePublicHttpUrl', () => {
  it('accepts an ordinary https url', () => {
    expect(parsePublicHttpUrl('https://example.com/hook')?.hostname).toBe('example.com');
  });

  it('accepts an ordinary http url', () => {
    expect(parsePublicHttpUrl('http://example.com/hook')?.hostname).toBe('example.com');
  });

  it.each([
    'ftp://example.com/hook',
    'file:///etc/passwd',
    'javascript:alert(1)',
    'not-a-url',
    '',
    // `startsWith('http')` — the old check — accepted every one of these:
    'http://169.254.169.254/latest/meta-data/',
    'http://127.0.0.1:6379/',
    'http://localhost:6379/',
    'http://[::1]:6379/',
    'http://10.0.0.5/internal',
    'httpfoo://example.com',
  ])('rejects %s', (raw) => {
    expect(parsePublicHttpUrl(raw)).toBeNull();
  });
});

describe('assertPublicHostname', () => {
  it('resolves and accepts a public address', async () => {
    const lookup = jest.fn().mockResolvedValue([{ address: '93.184.216.34', family: 4 }]);
    await expect(assertPublicHostname('example.com', lookup)).resolves.toBeUndefined();
    expect(lookup).toHaveBeenCalledWith('example.com', { all: true });
  });

  it('rejects a hostname that resolves to a private address (DNS rebinding)', async () => {
    const lookup = jest.fn().mockResolvedValue([{ address: '169.254.169.254', family: 4 }]);
    await expect(assertPublicHostname('evil.example.com', lookup)).rejects.toThrow(
      /resolves to a private address/i,
    );
  });

  it('rejects when ANY resolved address is private', async () => {
    const lookup = jest.fn().mockResolvedValue([
      { address: '93.184.216.34', family: 4 },
      { address: '10.0.0.1', family: 4 },
    ]);
    await expect(assertPublicHostname('split.example.com', lookup)).rejects.toThrow(
      /resolves to a private address/i,
    );
  });

  it('rejects when the hostname does not resolve at all', async () => {
    const lookup = jest.fn().mockRejectedValue(new Error('ENOTFOUND'));
    await expect(assertPublicHostname('nope.example.com', lookup)).rejects.toThrow(
      /could not be resolved/i,
    );
  });
});
