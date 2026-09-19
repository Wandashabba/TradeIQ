/**
 * The one password rule (#400).
 *
 * Creation and change MUST agree, or the system tells an agent their new
 * password is unacceptable in one place and mints it in another. Before this
 * file there was exactly one rule, `password.length < 8` inline in
 * `POST /users`, and nothing else could set a password at all.
 *
 * ## Why length and (almost) nothing else
 *
 * The people typing these are field agents, one-handed, on a cracked shared
 * Android screen, often in a shop doorway. Every character-class rule
 * ("one uppercase, one digit, one symbol") costs a keyboard switch and buys
 * very little: it shrinks the space of passwords people actually choose far
 * more than it grows the space an attacker must search. NIST SP 800-63B says
 * the same thing and has since 2017 — length, a deny-list, and no composition
 * rules.
 *
 * So: **12 characters, no composition rules.** Twelve lower-case letters typed
 * as three words ("blue truck monday", 17 characters) is both stronger than
 * `P@ssw0rd` and dramatically easier to type with a thumb.
 *
 * Twelve is not a new number here: `scripts/create-admin.ts` has refused
 * anything shorter since it was written. This file makes the rule the admin
 * script already applies to the first account apply to every account, through
 * every door.
 *
 * ## The bcrypt ceiling, stated rather than hidden
 *
 * bcrypt hashes at most the first 72 BYTES of a password. A longer one is
 * silently truncated, which means two different 100-character passwords sharing
 * a 72-byte prefix are the same password to this system. We measure length in
 * bytes and cap at 72 for that reason: the cap is the truth about what is
 * actually checked, rather than a promise the hash does not keep.
 *
 * ## What is rejected beyond length
 *
 * - Anything whose trimmed length falls short, so padding with spaces is not a
 *   way to meet the floor with a three-character password.
 * - The user's own email address, in any case. It is the one string an attacker
 *   already has.
 * - A short deny-list of the passwords that get chosen anyway. Not a serious
 *   defence on its own — it is there so that `password1234` and `tradeiq12345`
 *   do not become the fleet default when one manager sets fifty agents up.
 *
 * Error messages state the RULE, never the input. Nothing here ever echoes,
 * logs or otherwise reproduces the password it was given.
 */

/** Minimum length, in characters. */
export const PASSWORD_MIN_LENGTH = 12;

/**
 * Maximum length, in bytes — bcrypt's own ceiling, not an arbitrary limit.
 * Above this the hash ignores the rest, so accepting it would be a lie.
 */
export const PASSWORD_MAX_BYTES = 72;

/**
 * Lower-cased, whitespace-stripped forms that are refused outright.
 *
 * Deliberately short. A real breach corpus belongs behind a service, and
 * pretending a 12-entry list is one would be worse than being honest that this
 * catches the obvious fleet-wide default and nothing more.
 */
const DENY_LIST = new Set([
  'password',
  'password1',
  'password123',
  'passwordpassword',
  '123456789012',
  '1234567890123',
  'qwertyuiopas',
  'qwertyuiop12',
  'tradeiq',
  'tradeiq123',
  'tradeiq12345',
  'letmeinletmein',
  'welcome12345',
  'changemenow12',
]);

/**
 * The rule, in the words a person should read when they fail it.
 *
 * Exported so the route's 400 body, the app's helper text and the tests all
 * quote one string rather than three that drift.
 */
export const PASSWORD_RULE_TEXT =
  `Use at least ${PASSWORD_MIN_LENGTH} characters. ` +
  'Three ordinary words are easier to type one-handed and harder to guess than ' +
  'a short password with symbols in it. ' +
  'It must not be your email address or an obvious phrase.';

/**
 * The success branch carries the password back, narrowed to `string`.
 *
 * That is not decoration: `checkPassword` accepts `unknown` so a route can hand
 * it a raw body field, and returning the value is what lets the caller go
 * straight to `createUser` without a second `typeof` check that could disagree
 * with this one.
 */
export type PasswordCheck = { ok: true; password: string } | { ok: false; reason: string };

/**
 * Validates a candidate password.
 *
 * `email` is optional and only used to refuse "my password is my username". It
 * is compared after `normalizeEmail`-style folding so that `Agent@X.com` is
 * caught as readily as `agent@x.com`.
 */
export function checkPassword(password: unknown, email?: string): PasswordCheck {
  if (typeof password !== 'string') {
    return { ok: false, reason: PASSWORD_RULE_TEXT };
  }

  // Length in characters for the floor (what the person counts on screen) and
  // in bytes for the ceiling (what bcrypt actually consumes). A password of
  // emoji or non-Latin script can be short in characters and long in bytes;
  // both limits have to hold.
  if (password.length < PASSWORD_MIN_LENGTH) {
    return { ok: false, reason: PASSWORD_RULE_TEXT };
  }
  if (Buffer.byteLength(password, 'utf8') > PASSWORD_MAX_BYTES) {
    return {
      ok: false,
      reason:
        `Passwords are limited to ${PASSWORD_MAX_BYTES} bytes, because anything ` +
        'beyond that is not part of what gets checked when you sign in.',
    };
  }
  // Padding is not length. " hi " repeated to twelve characters is a
  // three-character password with a wide margin.
  if (password.trim().length < PASSWORD_MIN_LENGTH) {
    return { ok: false, reason: PASSWORD_RULE_TEXT };
  }

  const folded = password.trim().toLowerCase();
  if (DENY_LIST.has(folded.replace(/\s+/g, ''))) {
    return {
      ok: false,
      reason: 'That password is one of the first anyone would try. Pick another.',
    };
  }
  if (email && folded === email.trim().toLowerCase()) {
    return {
      ok: false,
      reason: 'Your password cannot be your email address.',
    };
  }

  return { ok: true, password };
}
