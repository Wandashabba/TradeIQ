import { PrismaClient } from '@prisma/client';
import { hashPassword } from '../src/modules/auth/auth.service';

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
 *   ADMIN_PASSWORD='…' npm run create-admin -- --email you@co.com --client <clientId>
 *
 * Omit --client to be shown the clients that exist.
 */
async function main() {
  const args = process.argv.slice(2);
  const flag = (name: string) => {
    const i = args.indexOf(`--${name}`);
    return i >= 0 ? args[i + 1] : undefined;
  };

  const email = flag('email');
  const clientId = flag('client');
  const password = process.env.ADMIN_PASSWORD;

  if (!email) {
    throw new Error('--email is required');
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
      passwordHash: await hashPassword(password),
      role: 'admin',
      clientId: client.id,
    },
  });

  console.log(`Created admin ${admin.email} for client ${client.name} (${client.id}).`);
}

main()
  .catch((err: unknown) => {
    console.error(err instanceof Error ? err.message : err);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
