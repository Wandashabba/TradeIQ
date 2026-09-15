import { DEMO_PASSWORD } from './catalog';
import { resolveSeedPassword } from './password';

describe('resolveSeedPassword (#160)', () => {
  it('keeps the well-known default for local development', () => {
    expect(resolveSeedPassword({})).toEqual({
      password: DEMO_PASSWORD,
      isWellKnownDefault: true,
    });
    expect(resolveSeedPassword({ NODE_ENV: 'development' }).isWellKnownDefault).toBe(true);
  });

  it('refuses the default in production when no password is supplied', () => {
    expect(() => resolveSeedPassword({ NODE_ENV: 'production' })).toThrow(
      'Refusing to seed demo accounts in production',
    );
    expect(() => resolveSeedPassword({ NODE_ENV: 'production', SEED_DEMO_PASSWORD: '' })).toThrow(
      'Set SEED_DEMO_PASSWORD',
    );
  });

  it('refuses the default in production even when it is passed explicitly', () => {
    // Someone copying the onboarding command into a production shell must not
    // be able to reintroduce the published password by naming it.
    expect(() =>
      resolveSeedPassword({ NODE_ENV: 'production', SEED_DEMO_PASSWORD: DEMO_PASSWORD }),
    ).toThrow('well-known default');
  });

  it('uses a supplied password in production, and does not mark it printable', () => {
    expect(
      resolveSeedPassword({ NODE_ENV: 'production', SEED_DEMO_PASSWORD: 'a-long-unique-one' }),
    ).toEqual({ password: 'a-long-unique-one', isWellKnownDefault: false });
  });

  it('rejects a short supplied password anywhere', () => {
    expect(() => resolveSeedPassword({ SEED_DEMO_PASSWORD: 'short' })).toThrow(
      'at least 12 characters',
    );
    expect(() =>
      resolveSeedPassword({ NODE_ENV: 'production', SEED_DEMO_PASSWORD: 'short' }),
    ).toThrow('at least 12 characters');
  });
});
