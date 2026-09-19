import { compareAppVersions, formatAppVersion, parseAppVersion } from './appVersion';

describe('app version parsing (#400)', () => {
  it.each([
    ['1.4.2', { major: 1, minor: 4, patch: 2 }],
    ['1.4', { major: 1, minor: 4, patch: 0 }],
    ['2', { major: 2, minor: 0, patch: 0 }],
    ['  1.4.2  ', { major: 1, minor: 4, patch: 2 }],
    // Flutter's `version: 1.4.2+318` — the build number is not part of the
    // version for gate purposes.
    ['1.4.2+318', { major: 1, minor: 4, patch: 2 }],
    ['1.4.2-beta.3', { major: 1, minor: 4, patch: 2 }],
  ])('parses %s', (raw, expected) => {
    expect(parseAppVersion(raw)).toEqual(expected);
  });

  it.each([
    ['an empty string', ''],
    ['prose', 'latest'],
    ['a leading v', 'v1.4.2'],
    ['four components', '1.2.3.4'],
    ['a negative', '-1.2'],
    ['a number', 142],
    ['null', null],
    ['undefined', undefined],
  ])('returns null for %s', (_label, raw) => {
    expect(parseAppVersion(raw)).toBeNull();
  });

  it('orders by major, then minor, then patch', () => {
    const v = (s: string) => parseAppVersion(s)!;
    expect(compareAppVersions(v('1.4.2'), v('1.4.2'))).toBe(0);
    expect(compareAppVersions(v('1.4.1'), v('1.4.2'))).toBeLessThan(0);
    expect(compareAppVersions(v('1.3.9'), v('1.4.0'))).toBeLessThan(0);
    expect(compareAppVersions(v('2.0.0'), v('1.99.99'))).toBeGreaterThan(0);
    // The reason string comparison is not enough: '10' sorts before '9'.
    expect(compareAppVersions(v('1.10.0'), v('1.9.0'))).toBeGreaterThan(0);
  });

  it('renders back to major.minor.patch', () => {
    expect(formatAppVersion(parseAppVersion('1.4')!)).toBe('1.4.0');
  });
});
