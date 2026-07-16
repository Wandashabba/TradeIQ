module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testPathIgnorePatterns: ['/node_modules/', '/dist/'],
  setupFiles: ['<rootDir>/jest.setup-env.ts'],
  globalSetup: '<rootDir>/jest.global-setup.ts',
  testTimeout: 20000,
};
