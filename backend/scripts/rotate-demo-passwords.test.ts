import { PrismaClient } from '@prisma/client';
import { promises as fs } from 'fs';
import * as os from 'os';
import * as path from 'path';
import { comparePassword, hashPassword } from '../src/modules/auth/auth.service';
import {
  DEMO_EMAILS,
  generatePassword,
  parseRotateArgs,
  rotateDemoPasswords,
} from './rotate-demo-passwords';

/**
 * #160 — rotating the demo accounts' passwords off the published default.
 * Runs against the worker's real test database, because the properties that
 * matter (which rows change, that login's own comparison accepts the result)
 * are database properties.
 */

jest.setTimeout(60_000);

const prisma = new PrismaClient();
const CLIENT_ID = 'rotate-demo-passwords-test-client';
const OLD_PASSWORD = 'old-shared-password';
const OUTSIDER_EMAIL = 'real-person@customer.example';
// Every demo account but the last, so a missing account is exercised too.
const PRESENT = DEMO_EMAILS.slice(0, -1);
const ABSENT = DEMO_EMAILS[DEMO_EMAILS.length - 1]!;

let tmpDir: string;
let oldHash: string;

async function hashOf(email: string): Promise<string> {
  const user = await prisma.user.findUniqueOrThrow({ where: { email }, select: { passwordHash: true } });
  return user.passwordHash;
}

function parseCredentials(body: string): Map<string, string> {
  return new Map(
    body
      .split('\n')
      .filter((line) => line.length > 0 && !line.startsWith('#'))
      .map((line) => line.split('\t') as [string, string]),
  );
}

beforeAll(async () => {
  oldHash = await hashPassword(OLD_PASSWORD);
});

beforeEach(async () => {
  tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'rotate-demo-'));
  await prisma.user.deleteMany({ where: { clientId: CLIENT_ID } });
  await prisma.client.upsert({
    where: { id: CLIENT_ID },
    update: {},
    create: { id: CLIENT_ID, name: 'Rotate test', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
  });
  await prisma.user.createMany({
    data: [...PRESENT, OUTSIDER_EMAIL].map((email) => ({
      email,
      passwordHash: oldHash,
      role: 'manager' as const,
      clientId: CLIENT_ID,
    })),
  });
});

afterEach(async () => {
  await fs.rm(tmpDir, { recursive: true, force: true });
});

afterAll(async () => {
  await prisma.user.deleteMany({ where: { clientId: CLIENT_ID } });
  await prisma.client.deleteMany({ where: { id: CLIENT_ID } });
  await prisma.$disconnect();
});

describe('parseRotateArgs', () => {
  it('requires an output file unless it is a dry run', () => {
    expect(() => parseRotateArgs([])).toThrow('Usage: npm run rotate-demo-passwords');
    expect(parseRotateArgs(['--dry-run'])).toEqual({ outFile: undefined, dryRun: true });
  });

  it('resolves the output file to an absolute path', () => {
    expect(parseRotateArgs(['creds.txt'])).toEqual({
      outFile: path.resolve('creds.txt'),
      dryRun: false,
    });
  });

  it('rejects unknown options and a second path', () => {
    expect(() => parseRotateArgs(['--dryrun'])).toThrow('Unknown option "--dryrun"');
    expect(() => parseRotateArgs(['a.txt', 'b.txt'])).toThrow('exactly one output file');
  });
});

describe('generatePassword', () => {
  it('is long and not repeated', () => {
    const passwords = new Set(Array.from({ length: 50 }, generatePassword));
    expect(passwords.size).toBe(50);
    for (const p of passwords) expect(p.length).toBeGreaterThanOrEqual(32);
  });
});

describe('rotateDemoPasswords', () => {
  it('lists what would change on a dry run, and changes nothing', async () => {
    const outFile = path.join(tmpDir, 'creds.txt');
    const lines: string[] = [];

    const result = await rotateDemoPasswords(prisma, { outFile, dryRun: true }, (l) => lines.push(l));

    expect(result.rotated.sort()).toEqual([...PRESENT].sort());
    expect(result.missing).toEqual([ABSENT]);
    for (const email of PRESENT) {
      expect(lines.join('\n')).toContain(email);
      expect(await hashOf(email)).toBe(oldHash);
    }
    expect(lines.join('\n')).toContain('Dry run');
    await expect(fs.access(outFile)).rejects.toThrow();
  });

  it('sets a new login-valid password on each demo account, written only to a 0600 file', async () => {
    const outFile = path.join(tmpDir, 'creds.txt');
    const lines: string[] = [];
    const consoleLog = jest.spyOn(console, 'log').mockImplementation(() => undefined);
    const stdout = jest.spyOn(process.stdout, 'write');

    try {
      await rotateDemoPasswords(prisma, { outFile, dryRun: false }, (l) => lines.push(l));
    } finally {
      consoleLog.mockRestore();
    }

    expect((await fs.stat(outFile)).mode & 0o777).toBe(0o600);
    const credentials = parseCredentials(await fs.readFile(outFile, 'utf8'));
    expect([...credentials.keys()].sort()).toEqual([...PRESENT].sort());

    for (const [email, password] of credentials) {
      const hash = await hashOf(email);
      // The same comparison login uses.
      expect(await comparePassword(password, hash)).toBe(true);
      expect(await comparePassword(OLD_PASSWORD, hash)).toBe(false);
      // Never echoed: not through the log, console.log, or stdout directly.
      expect(lines.join('\n')).not.toContain(password);
      for (const call of stdout.mock.calls) expect(String(call[0])).not.toContain(password);
    }
    stdout.mockRestore();
    expect(consoleLog).not.toHaveBeenCalled();

    // Each account gets its own password, not one shared one.
    expect(new Set(credentials.values()).size).toBe(PRESENT.length);
    // Accounts that are not demo accounts are untouched.
    expect(await hashOf(OUTSIDER_EMAIL)).toBe(oldHash);
  });

  it('refuses to overwrite an existing file, before changing anything', async () => {
    const outFile = path.join(tmpDir, 'creds.txt');
    await fs.writeFile(outFile, 'previous rotation\n');

    await expect(
      rotateDemoPasswords(prisma, { outFile, dryRun: false }, () => undefined),
    ).rejects.toThrow('Refusing to overwrite');

    expect(await fs.readFile(outFile, 'utf8')).toBe('previous rotation\n');
    for (const email of PRESENT) expect(await hashOf(email)).toBe(oldHash);
  });

  it('removes the file again if the database update fails', async () => {
    const outFile = path.join(tmpDir, 'creds.txt');
    const failing = {
      user: { findMany: prisma.user.findMany.bind(prisma.user), update: jest.fn(() => ({})) },
      $transaction: jest.fn(() => Promise.reject(new Error('database unavailable'))),
    } as unknown as PrismaClient;

    await expect(
      rotateDemoPasswords(failing, { outFile, dryRun: false }, () => undefined),
    ).rejects.toThrow('database unavailable');

    await expect(fs.access(outFile)).rejects.toThrow();
    for (const email of PRESENT) expect(await hashOf(email)).toBe(oldHash);
  });

  it('fails without writing a file when no demo account exists', async () => {
    await prisma.user.deleteMany({ where: { email: { in: [...DEMO_EMAILS] } } });
    const outFile = path.join(tmpDir, 'creds.txt');

    await expect(
      rotateDemoPasswords(prisma, { outFile, dryRun: false }, () => undefined),
    ).rejects.toThrow('No demo accounts found');
    await expect(fs.access(outFile)).rejects.toThrow();
  });
});
