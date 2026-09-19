import {
  checkPassword,
  PASSWORD_MAX_BYTES,
  PASSWORD_MIN_LENGTH,
  PASSWORD_RULE_TEXT,
} from './passwordPolicy';

describe('password policy (#400)', () => {
  it('accepts a passphrase of ordinary words', () => {
    const result = checkPassword('blue truck monday');
    expect(result.ok).toBe(true);
    expect(result.ok && result.password).toBe('blue truck monday');
  });

  it('accepts exactly the minimum length', () => {
    expect(checkPassword('a'.repeat(PASSWORD_MIN_LENGTH)).ok).toBe(true);
  });

  it('rejects one character below the minimum', () => {
    expect(checkPassword('a'.repeat(PASSWORD_MIN_LENGTH - 1)).ok).toBe(false);
  });

  // No composition rules is a deliberate choice, not an oversight: a thumb on a
  // cracked screen pays for every keyboard switch a symbol rule forces, and the
  // shrunken space of passwords people then actually pick is worth less than
  // the length. This test is the guard against someone "tightening" it later.
  it('accepts a long all-lowercase password with no digits or symbols', () => {
    expect(checkPassword('correcthorsebatterystaple').ok).toBe(true);
  });

  it.each([
    ['null', null],
    ['a number', 1234567890123],
    ['an object', { password: 'blue truck monday' }],
    ['undefined', undefined],
  ])('rejects %s', (_label, value) => {
    expect(checkPassword(value).ok).toBe(false);
  });

  it('does not let padding count towards the length', () => {
    const padded = `hi${' '.repeat(PASSWORD_MIN_LENGTH)}`;
    expect(padded.length).toBeGreaterThan(PASSWORD_MIN_LENGTH);
    expect(checkPassword(padded).ok).toBe(false);
  });

  // bcrypt hashes the first 72 BYTES and silently ignores the rest, so two
  // different 100-character passwords sharing a prefix would be one password to
  // this system. The cap is the truth about what is checked.
  it('rejects a password longer than bcrypt actually hashes', () => {
    const result = checkPassword('x'.repeat(PASSWORD_MAX_BYTES + 1));
    expect(result.ok).toBe(false);
    expect(result.ok || result.reason).toContain(`${PASSWORD_MAX_BYTES} bytes`);
  });

  it('measures the ceiling in bytes, not characters', () => {
    // 30 four-byte characters: short on screen, 120 bytes to bcrypt.
    expect(checkPassword('🙂'.repeat(30)).ok).toBe(false);
    // 18 of them is 72 bytes exactly, which is the last one that fits.
    expect(checkPassword('🙂'.repeat(18)).ok).toBe(true);
  });

  it('rejects the email address as a password, in any case', () => {
    const email = 'sipho.ndlovu@demo-fmcg.tradeiq.com';
    expect(checkPassword(email, email).ok).toBe(false);
    expect(checkPassword(email.toUpperCase(), email).ok).toBe(false);
  });

  it('allows a password that merely contains the email', () => {
    const email = 'a@b.com';
    expect(checkPassword(`${email} and more words`, email).ok).toBe(true);
  });

  // All long enough to clear the length floor, so it is genuinely the
  // deny-list refusing them and not the length check getting there first.
  it.each([['passwordpassword'], ['tradeiq12345'], ['Password 1 2 3']])(
    'rejects the obvious fleet default %s',
    (candidate) => {
      const result = checkPassword(candidate);
      expect(result.ok).toBe(false);
      expect(result.ok || result.reason).toMatch(/first anyone would try/);
    },
  );

  // A refusal that echoes the password puts it somewhere it does not belong:
  // a response body, then a log, then a support ticket.
  it('never reproduces the password in the reason it gives', () => {
    // None of these is a word the rule text itself uses, or the assertion would
    // pass or fail on a coincidence rather than on the property.
    for (const candidate of ['hunter2', 'passwordpassword', 'x'.repeat(200), '  qwerty  ']) {
      const result = checkPassword(candidate, 'a@b.com');
      expect(result.ok).toBe(false);
      expect(result.ok || result.reason).not.toContain(candidate.trim());
    }
  });

  it('states the minimum in the rule text people are shown', () => {
    expect(PASSWORD_RULE_TEXT).toContain(`${PASSWORD_MIN_LENGTH} characters`);
  });
});
