import { isPrivateAddress, parsePublicHttpUrl, assertPublicHostname } from './urlGuard';

describe('isPrivateAddress', () => {
  it.each([
    '127.0.0.1',
    '10.0.0.1',
    '172.16.0.1',
    '172.31.255.255',
    '192.168.1.1',
    '169.254.169.254', // cloud metadata
    '0.0.0.0',
    '224.0.0.1',
    '::1',
    'fd00::1',
    'fe80::1',
    '::ffff:127.0.0.1', // IPv4-mapped loopback
  ])('treats %s as private', (ip) => {
    expect(isPrivateAddress(ip)).toBe(true);
  });

  it.each(['8.8.8.8', '1.1.1.1', '93.184.216.34', '2606:2800:220:1::248'])(
    'treats %s as public',
    (ip) => {
      expect(isPrivateAddress(ip)).toBe(false);
    },
  );

  it('does not treat 172.32.x as private (boundary above the RFC1918 block)', () => {
    expect(isPrivateAddress('172.32.0.1')).toBe(false);
  });

  it('does not treat 11.x as private (boundary above the 10/8 block)', () => {
    expect(isPrivateAddress('11.0.0.1')).toBe(false);
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
