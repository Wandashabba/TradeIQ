/**
 * The one spelling of an email address (#351).
 *
 * `User.email` is a plain unique column and Postgres compares text
 * case-sensitively, so `Agent@demo-fmcg.tradeiq.com` and
 * `agent@demo-fmcg.tradeiq.com` are two different rows to the database and a
 * lookup for one never finds the other. That turned an Android keyboard's
 * default auto-capitalisation into "Invalid credentials" on a correct password:
 * the row simply was not found. Leading or trailing whitespace — what a paste
 * or a long-press "Paste" on mobile leaves behind — failed the same way.
 *
 * The fix is to store and look up one canonical form. Every write path
 * (provisioning, the seed, create-admin) and every read path that matches an
 * email exactly (login) must pass through here, or the two drift apart again
 * and the same bug comes back through a different door.
 *
 * Case folding is applied to the WHOLE address, local part included. RFC 5321
 * permits a case-sensitive local part, but no mail provider in practice treats
 * `Agent@` and `agent@` as different mailboxes, and TradeIQ emails are account
 * identifiers typed on phone keyboards rather than addresses we deliver to.
 * Matching what users expect beats matching the letter of the RFC here.
 */

/** Trim surrounding whitespace and fold to lower case. */
export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}
