import { DEMO_PASSWORD } from './catalog';

/** Same floor as `create-admin`'s ADMIN_PASSWORD. */
export const MIN_SEED_PASSWORD_LENGTH = 12;

export interface SeedPassword {
  password: string;
  /** True only for the repo's published default — the one safe to print. */
  isWellKnownDefault: boolean;
}

/**
 * Picks the password every seeded demo account gets (#160).
 *
 * Local development keeps the well-known default, because onboarding depends
 * on anyone being able to sign in to a freshly seeded laptop database.
 *
 * Production never gets it. The default is committed to this repository, and
 * the deployed hostname is guessable, so a production seed that used it would
 * hand the demo tenant — admin account included — to anyone who has read the
 * repo. A production seed must name its own password in SEED_DEMO_PASSWORD.
 * It is never generated and printed: a password that lands in a terminal
 * scrollback or a CI log is not a password.
 */
export function resolveSeedPassword(env: NodeJS.ProcessEnv = process.env): SeedPassword {
  const production = env.NODE_ENV === 'production';
  const supplied = env.SEED_DEMO_PASSWORD;

  if (supplied === undefined || supplied === '' || supplied === DEMO_PASSWORD) {
    if (production) {
      throw new Error(
        supplied
          ? 'SEED_DEMO_PASSWORD is the well-known default published in this repository. ' +
              'Choose a unique password for a production seed.'
          : 'Refusing to seed demo accounts in production with the well-known default ' +
              `password. Set SEED_DEMO_PASSWORD (${MIN_SEED_PASSWORD_LENGTH}+ characters).`,
      );
    }
    return { password: DEMO_PASSWORD, isWellKnownDefault: true };
  }

  if (supplied.length < MIN_SEED_PASSWORD_LENGTH) {
    throw new Error(
      `SEED_DEMO_PASSWORD must be at least ${MIN_SEED_PASSWORD_LENGTH} characters.`,
    );
  }

  return { password: supplied, isWellKnownDefault: false };
}
