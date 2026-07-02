import { computeSlaDueAt } from './slaClock';

describe('computeSlaDueAt', () => {
  const from = new Date('2026-07-02T10:00:00.000Z');

  it('adds 24 hours for critical priority', () => {
    expect(computeSlaDueAt('critical', from)).toEqual(
      new Date('2026-07-03T10:00:00.000Z'),
    );
  });

  it('adds 3 days for high priority', () => {
    expect(computeSlaDueAt('high', from)).toEqual(
      new Date('2026-07-05T10:00:00.000Z'),
    );
  });

  it('adds 7 days for normal priority', () => {
    expect(computeSlaDueAt('normal', from)).toEqual(
      new Date('2026-07-09T10:00:00.000Z'),
    );
  });
});
