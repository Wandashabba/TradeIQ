import { PrismaClient } from '@prisma/client';
import { randomBytes } from 'crypto';
import { promises as fs } from 'fs';
import * as path from 'path';
import { hashPassword } from '../src/modules/auth/auth.service';
import { USERS } from './seed/catalog';

/**
 * Gives every seeded demo account a strong random password (#160).
 *
 *   npm run rotate-demo-passwords -- --dry-run
 *   npm run rotate-demo-passwords -- /secure/path/demo-credentials.txt
 *
 * Accounts are matched by the seed's demo emails (`seed/catalog.ts`), so the
 * script touches nothing else. Passwords are hashed exactly as login checks
 * them (`hashPassword`, bcrypt cost 10).
 *
 * The new passwords go ONLY to the file you name, created with mode 0600 and
 * refused if it already exists. They never reach stdout: a rotation run from a
 * shared terminal, a recorded session or a CI log must not undo itself.
 *
 * The file is written BEFORE the database changes, and removed again if the
 * database update fails. The reverse order could leave accounts with
 * passwords nobody holds.
 *
 * Sessions: there is nothing per-user to revoke. Auth issues stateless 12h
 * JWTs with no session or refresh-token store (#142). `requireAuth` re-reads
 * `active`, `role` and `clientId` per request, but not the password, so tokens
 * issued before a rotation stay valid until they expire. Rotating JWT_SECRET
 * ends every session at once; see docs/operations/deploy-hardening.md.
 */

export const DEMO_EMAILS: readonly string[] = USERS.map((u) => u.email);

export interface RotateDemoPasswordsArgs {
  /** Absolute path of the credentials file. Required unless dryRun. */
  outFile?: string;
  dryRun: boolean;
}

export function parseRotateArgs(argv: string[]): RotateDemoPasswordsArgs {
  let outFile: string | undefined;
  let dryRun = false;

  for (const arg of argv) {
    if (arg === '--dry-run') {
      dryRun = true;
    } else if (arg.startsWith('-')) {
      throw new Error(`Unknown option "${arg}"`);
    } else if (outFile !== undefined) {
      throw new Error('Expected exactly one output file path.');
    } else {
      outFile = path.resolve(arg);
    }
  }

  if (!dryRun && outFile === undefined) {
    throw new Error(
      'Usage: npm run rotate-demo-passwords -- <output-file> [--dry-run]\n' +
        'The output file receives the new passwords (mode 0600) and must not exist yet.',
    );
  }

  return { outFile, dryRun };
}

/** 24 random bytes → 32 URL-safe characters, ~192 bits. */
export function generatePassword(): string {
  return randomBytes(24).toString('base64url');
}

export interface RotateDemoPasswordsResult {
  /** Emails whose password changed (or would change, on a dry run). */
  rotated: string[];
  /** Demo emails with no account in this database. */
  missing: string[];
}

type Log = (line: string) => void;

export async function rotateDemoPasswords(
  prisma: PrismaClient,
  args: RotateDemoPasswordsArgs,
  log: Log = (line) => console.log(line),
): Promise<RotateDemoPasswordsResult> {
  const accounts = await prisma.user.findMany({
    where: { email: { in: [...DEMO_EMAILS] } },
    select: { id: true, email: true, role: true, active: true, clientId: true },
    orderBy: { email: 'asc' },
  });
  const found = new Set(accounts.map((a) => a.email));
  const missing = DEMO_EMAILS.filter((email) => !found.has(email));

  log(`${accounts.length} demo account(s) found:`);
  for (const a of accounts) {
    log(`  ${a.email}  (${a.role}, client ${a.clientId}${a.active ? '' : ', inactive'})`);
  }
  if (missing.length > 0) {
    log(`Not present, skipped: ${missing.join(', ')}`);
  }

  const rotated = accounts.map((a) => a.email);

  if (args.dryRun) {
    log(`Dry run: ${accounts.length} account(s) would get a new password. Nothing was changed.`);
    return { rotated, missing };
  }

  if (accounts.length === 0) {
    throw new Error('No demo accounts found in this database; nothing to rotate.');
  }
  if (!args.outFile) {
    throw new Error('An output file is required unless --dry-run is given.');
  }

  const credentials = accounts.map((a) => ({ id: a.id, email: a.email, password: generatePassword() }));
  const hashes = await Promise.all(credentials.map((c) => hashPassword(c.password)));

  const body = [
    `# TradeIQ demo account passwords, rotated ${new Date().toISOString()}.`,
    '# Move these into a password manager, then delete this file.',
    ...credentials.map((c) => `${c.email}\t${c.password}`),
    '',
  ].join('\n');

  // 'wx' fails if the file exists, so an earlier rotation's file is never
  // overwritten, and a symlink planted at the path is not followed into.
  let handle: fs.FileHandle;
  try {
    handle = await fs.open(args.outFile, 'wx', 0o600);
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code === 'EEXIST') {
      throw new Error(`Refusing to overwrite ${args.outFile}. Choose a path that does not exist.`);
    }
    throw err;
  }
  try {
    // The mode passed to open() is filtered by the umask; set it explicitly.
    await handle.chmod(0o600);
    await handle.writeFile(body, 'utf8');
    await handle.sync();
  } finally {
    await handle.close();
  }

  try {
    await prisma.$transaction(
      credentials.map((c, i) =>
        prisma.user.update({
          where: { id: c.id },
          data: { passwordHash: hashes[i] },
          select: { id: true },
        }),
      ),
    );
  } catch (err) {
    // Nothing changed, so the file holds passwords that match no account.
    await fs.rm(args.outFile, { force: true });
    throw err;
  }

  log(`Rotated ${credentials.length} password(s). Credentials written to ${args.outFile} (mode 0600).`);
  log(
    'Existing sessions: auth uses stateless 12h JWTs with no session store, so tokens ' +
      'issued before this rotation stay valid until they expire. Rotate JWT_SECRET to end them now.',
  );
  return { rotated, missing };
}

/** Host and database name only — never the credentials in the URL. */
function describeTarget(url: string | undefined): string {
  if (!url) return '(DATABASE_URL not set in the environment; Prisma will read .env)';
  try {
    const parsed = new URL(url);
    return `${parsed.host}${parsed.pathname}`;
  } catch {
    return '(DATABASE_URL could not be parsed)';
  }
}

async function main(): Promise<void> {
  const args = parseRotateArgs(process.argv.slice(2));
  const prisma = new PrismaClient();
  try {
    await prisma.$connect();
    console.log(`Target database: ${describeTarget(process.env.DATABASE_URL)}`);
    await rotateDemoPasswords(prisma, args);
  } finally {
    await prisma.$disconnect();
  }
}

if (require.main === module) {
  main().catch((err) => {
    console.error(err instanceof Error ? err.message : err);
    process.exitCode = 1;
  });
}
