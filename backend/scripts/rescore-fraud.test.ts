import { parseRescoreArgs } from './rescore-fraud';

/**
 * #236 — the CLI's arguments. The loop itself is tested in
 * src/modules/fraud/fraudRescore.test.ts; this pins that a mistyped command
 * fails loudly instead of running a different, wider rescore.
 */
describe('rescore-fraud arguments (#236)', () => {
  it('defaults to scoring every unscored visit of every client', () => {
    expect(parseRescoreArgs([])).toEqual({});
  });

  it('reads every option', () => {
    expect(
      parseRescoreArgs([
        '--client',
        'client-1',
        '--since',
        '2026-09-01',
        '--all',
        '--scored-before',
        '2026-09-15T08:00:00.000Z',
        '--batch',
        '25',
      ]),
    ).toEqual({
      clientId: 'client-1',
      since: new Date('2026-09-01'),
      all: true,
      scoredBefore: new Date('2026-09-15T08:00:00.000Z'),
      batchSize: 25,
    });
  });

  it.each<[string[], string]>([
    [['--clinet', 'client-1'], 'Unknown option "--clinet"'],
    [['--client'], '--client needs a value'],
    [['--client', '--all'], '--client needs a value'],
    [['--since', 'last week'], '--since must be an ISO-8601 date'],
    [['--batch', '0'], '--batch must be a positive integer'],
    [['--batch', '1e3'], '--batch must be a positive integer'],
    [['--scored-before', '2026-09-15T08:00:00.000Z'], '--scored-before only applies with --all'],
  ])('rejects %j', (argv, message) => {
    expect(() => parseRescoreArgs(argv)).toThrow(message);
  });
});
