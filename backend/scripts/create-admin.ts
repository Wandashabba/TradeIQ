import { PrismaClient } from '@prisma/client';
import { hashPassword } from '../src/modules/auth/auth.service';
import { DISPLAY_NAME_MAX_LENGTH, parseDisplayName } from '../src/lib/personName';
import { normalizeEmail } from '../src/lib/email';

const prisma = new PrismaClient();

/**
 * Mints the first admin for a client.
 *
 * TradeIQ has no public registration — by design, since an endpoint that hands
 * out accounts to strangers is a hole, not a feature. But `POST /users` is
 * admin-only, which left a real deployment with a chicken-and-egg problem: no
 * admin exists, and only an admin can create one. Scoring config, user
 * management and webhooks were unreachable on any database that wasn't seeded.
 *
 * This is the way out, and it is deliberately not an HTTP route: it requires a
 * shell on the box and the database URL. Someone who has those can already do
 * anything.
 *
 *   ADMIN_PASSWORD='…' npm run create-admin -- --email you@co.com --client <clientId> \
 *     --name "Thandi Mokoena"
 *
 * Omit --client to be shown the clients that exist. --name is optional; it is
 * what the console shows for this person and what the assistant matches when
 * someone asks about them by name (#280). Without it the email is shown.
 */
async function main() {
  const args = process.argv.slice(2);
  const flag = (name: string) => {
    const i = args.indexOf(`--${name}`);
    return i >= 0 ? args[i + 1] : undefined;
  };

  const emailArg = flag('email');
  const clientId = flag('client');
  const password = process.env.ADMIN_PASSWORD;

  if (!emailArg) {
    throw new Error('--email is required');
  }

  // Stored and checked in the one canonical form (#351), so the admin this
  // mints can log in whatever case their keyboard produces — and so the
  // "already exists" check below cannot be walked past by re-running with a
  // differently-capitalised spelling of the same address.
  const email = normalizeEmail(emailArg);

  const name = parseDisplayName(flag('name'));
  if (!name.ok) {
    throw new Error(`--name must be at most ${DISPLAY_NAME_MAX_LENGTH} characters.`);
  }

  if (!password) {
    // Never a default, and never generated-and-printed: a password that ships
    // in a repo or a CI log is not a password.
    throw new Error(
      'Set ADMIN_PASSWORD in the environment. It is read from there, not from ' +
        'the command line, so it does not land in your shell history.',
    );
  }
  if (password.length < 12) {
    throw new Error('ADMIN_PASSWORD must be at least 12 characters.');
  }

  if (!clientId) {
    const clients = await prisma.client.findMany({ select: { id: true, name: true } });
    if (clients.length === 0) {
      throw new Error('No clients exist yet. Create one first (npm run seed for the demo).');
    }
    throw new Error(
      `--client is required. Clients on this database:\n` +
        clients.map((c) => `  ${c.id}  ${c.name}`).join('\n'),
    );
  }

  const client = await prisma.client.findUnique({ where: { id: clientId } });
  if (!client) {
    throw new Error(`No client with id ${clientId}.`);
  }

  // Refuse to overwrite. If this email is already someone, promoting them is a
  // decision a human should make explicitly, not a side effect of a typo.
  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    throw new Error(
      `${email} already exists (role: ${existing.role}). This script will not ` +
        'change an existing user. Promote them with an admin session, or use a ' +
        'different email.',
    );
  }

  const admin = await prisma.user.create({
    data: {
      email,
      displayName: name.value ?? null,
      passwordHash: await hashPassword(password),
      role: 'admin',
      clientId: client.id,
    },
  });

  const who = admin.displayName ? `${admin.displayName} <${admin.email}>` : admin.email;
  console.log(`Created admin ${who} for client ${client.name} (${client.id}).`);
}

main()
  .catch((err: unknown) => {
    console.error(err instanceof Error ? err.message : err);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
