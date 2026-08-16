module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testPathIgnorePatterns: ['/node_modules/', '/dist/'],
  setupFiles: ['<rootDir>/jest.setup-env.ts'],
  globalSetup: '<rootDir>/jest.global-setup.ts',
  testTimeout: 20000,
  // Every worker opens its own Prisma client with its own connection pool
  // against one Postgres whose `max_connections` is the default 100. Jest's
  // default is roughly one worker per core, so on a many-core machine the
  // workers exhaust the pool and later suites cannot connect at all —
  // surfacing as a wall of `PrismaClientInitializationError` across suites
  // that have nothing wrong with them (#181).
  //
  // The failure is worse than slow: it reads as "you broke 133 tests" rather
  // than "you ran out of connections", so it costs a contributor real time
  // before they find the cause. Capping workers is also dramatically FASTER
  // here — 38s versus 318s on the machine this was diagnosed on — because the
  // box stops thrashing. There is no throughput trade being made.
  maxWorkers: 4,

  // A ratchet, not a target.
  //
  // Measured 2026-08-17: 92.95% statements, 84.19% branches, 92.89% functions,
  // 93.61% lines. The floors sit a few points below that, which is the point —
  // they exist to catch a PR that adds a large untested module, not to make
  // anyone chase a number. Raise them when the real figure has moved up and
  // stayed there.
  //
  // Branches is the loosest deliberately: it counts every `?? default` and
  // every defensive `if (!x) throw`, so it is the metric most easily gamed by
  // deleting a guard. It is here to notice a cliff, not to be optimised.
  //
  // Nothing is excluded from the denominator. An exclusion list is how a file
  // stops being measured and nobody notices.
  coverageThreshold: {
    global: {
      statements: 90,
      branches: 80,
      functions: 90,
      lines: 90,
    },
  },
  coveragePathIgnorePatterns: ['/node_modules/', '/dist/', '/test-utils/'],
};
