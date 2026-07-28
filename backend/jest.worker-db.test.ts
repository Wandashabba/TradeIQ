import { workerDatabaseUrl } from './jest.worker-db';

const BASE = 'postgresql://tradeiq:tradeiq_dev@localhost:5432/tradeiq_test?schema=public';

describe('workerDatabaseUrl', () => {
  it('suffixes the database name with the worker id', () => {
    expect(workerDatabaseUrl(BASE, '3')).toBe(
      'postgresql://tradeiq:tradeiq_dev@localhost:5432/tradeiq_test_3?schema=public',
    );
  });

  it('gives different workers different databases — the whole point of #186', () => {
    expect(workerDatabaseUrl(BASE, '1')).not.toBe(workerDatabaseUrl(BASE, '2'));
  });

  it('preserves credentials, host, port and query parameters', () => {
    const url = new URL(workerDatabaseUrl(BASE, '2'));
    expect(url.username).toBe('tradeiq');
    expect(url.password).toBe('tradeiq_dev');
    expect(url.hostname).toBe('localhost');
    expect(url.port).toBe('5432');
    expect(url.searchParams.get('schema')).toBe('public');
  });

  it('works on a url with no query string', () => {
    expect(workerDatabaseUrl('postgresql://u:p@db:5432/t', '4')).toBe(
      'postgresql://u:p@db:5432/t_4',
    );
  });

  // Guards the failure mode that would silently reintroduce the bug: if the
  // helper quietly returned the base url, every worker would share one database
  // again and #186 would come back with no visible signal.
  it('throws when the url has no database name rather than returning it unchanged', () => {
    expect(() => workerDatabaseUrl('postgresql://u:p@localhost:5432/', '1')).toThrow(
      'no database name',
    );
  });

  it('throws on a worker id that would produce an invalid identifier', () => {
    expect(() => workerDatabaseUrl(BASE, '')).toThrow('worker id');
    expect(() => workerDatabaseUrl(BASE, 'a"b')).toThrow('worker id');
  });
});

describe('the running test process', () => {
  // The integration proof: this suite is itself executing against a
  // worker-scoped database. If setup-env stops rewriting DATABASE_URL, this
  // fails immediately instead of resurfacing as a random flake elsewhere.
  it('is connected to its own per-worker database', () => {
    const workerId = process.env.JEST_WORKER_ID;
    expect(workerId).toBeDefined();

    const dbName = new URL(process.env.DATABASE_URL!).pathname.replace(/^\//, '');
    expect(dbName).toBe(`tradeiq_test_${workerId}`);
  });
});
