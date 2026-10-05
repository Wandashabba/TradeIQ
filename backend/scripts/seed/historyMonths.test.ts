import { resolveHistoryMonths } from './historyMonths';

/**
 * The knob exists because the hosted demo is on a Supabase Free project with a
 * 500 MB cap and the full 24-month world measures 1013 MB. Getting it wrong is
 * expensive in a specific way: the seed deletes first and builds for minutes,
 * so a bad value is six silent minutes followed by the wrong world — or a
 * half-built one, if the project filled up. Hence it throws rather than clamps.
 */
describe('resolveHistoryMonths', () => {
  it('uses the profile default when unset or blank', () => {
    expect(resolveHistoryMonths(24, {})).toBe(24);
    expect(resolveHistoryMonths(24, { SEED_HISTORY_MONTHS: '   ' })).toBe(24);
    expect(resolveHistoryMonths(3, {})).toBe(3);
  });

  it('takes a positive integer', () => {
    expect(resolveHistoryMonths(24, { SEED_HISTORY_MONTHS: '6' })).toBe(6);
    expect(resolveHistoryMonths(24, { SEED_HISTORY_MONTHS: ' 6 ' })).toBe(6);
    expect(resolveHistoryMonths(24, { SEED_HISTORY_MONTHS: '24' })).toBe(24);
  });

  it('rejects a value that merely starts with a number', () => {
    // parseInt('6months') is 6. Number('6months') is NaN, which is the whole
    // reason this does not use parseInt: a near-miss is the typo to catch.
    expect(() => resolveHistoryMonths(24, { SEED_HISTORY_MONTHS: '6months' })).toThrow(
      /not a whole number/,
    );
  });

  it('rejects fractions, zero and negatives', () => {
    for (const bad of ['6.5', '0', '-3']) {
      expect(() => resolveHistoryMonths(24, { SEED_HISTORY_MONTHS: bad })).toThrow(
        /not a whole number/,
      );
    }
  });

  it('rejects more months than the calendar plans for', () => {
    // Nothing would exist out there, so asking for it is a mistake rather than
    // a bigger world.
    expect(() => resolveHistoryMonths(24, { SEED_HISTORY_MONTHS: '36' })).toThrow(
      /beyond the 24 months/,
    );
  });
});
