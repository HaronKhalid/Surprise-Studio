// Run via `npm test`: Nest 12 packages are ESM-only, and Jest only loads them (via require(esm))
// when Node is started with --experimental-vm-modules. Plain `npx jest` fails with "Must use import".
/** @type {import('jest').Config} */
module.exports = {
  rootDir: 'src',
  testRegex: '.*\\.spec\\.ts$',
  moduleFileExtensions: ['js', 'json', 'ts'],
  transform: { '^.+\\.ts$': ['ts-jest', { tsconfig: '<rootDir>/../tsconfig.json' }] },
  testEnvironment: 'node',
};
