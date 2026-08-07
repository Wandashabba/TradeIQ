import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

/**
 * Switches the conversational assistant on (or off) for one client.
 *
 * `Client.assistantEnabled` defaults to **false**, and `/assistant/*` answers
 * **404** for any tenant where it is off — deliberately, so the kill switch is
 * indistinguishable from the feature never having shipped. The first thing
 * anyone testing this hits is therefore a 404 with no obvious cause, which is
 * exactly why this script exists.
 *
 * **Deliberately not an HTTP route**, and specifically absent from
 * `PATCH /clients/me`. It is a rollout lever, not a customer preference: a
 * client admin switching on an unproven, metered AI feature for their own
 * tenant is the thing the flag exists to prevent. Flipping it requires a shell
 * on the box and the database URL — someone with those can already do anything.
 *
 *   npm run enable-assistant -- --client <clientId>
 *   npm run enable-assistant -- --client <clientId> --off
 *
 * Omit --client to list the clients that exist, with their current setting.
 */
async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const flag = (name: string): string | undefined => {
    const i = args.indexOf(`--${name}`);
    return i >= 0 ? args[i + 1] : undefined;
  };

  const clientId = flag('client');
  const turnOff = args.includes('--off');

  if (!clientId) {
    const clients = await prisma.client.findMany({
      select: { id: true, name: true, assistantEnabled: true },
      orderBy: { name: 'asc' },
    });

    if (clients.length === 0) {
      console.error('No clients exist. Run `npm run seed` first.');
      process.exitCode = 1;
      return;
    }

    console.log('Clients:\n');
    for (const client of clients) {
      console.log(
        `  ${client.assistantEnabled ? '[on] ' : '[off]'} ${client.id}  ${client.name}`,
      );
    }
    console.log('\nRe-run with --client <id> to switch the assistant on.');
    return;
  }

  // Checked before writing so a typo'd id reports as a typo rather than as a
  // Prisma "record not found" three frames deep.
  const client = await prisma.client.findUnique({
    where: { id: clientId },
    select: { id: true, name: true, assistantEnabled: true },
  });

  if (!client) {
    console.error(`No client with id "${clientId}". Re-run with no arguments to list them.`);
    process.exitCode = 1;
    return;
  }

  if (client.assistantEnabled === !turnOff) {
    console.log(
      `"${client.name}" already has the assistant ${turnOff ? 'off' : 'on'}. Nothing to do.`,
    );
    return;
  }

  await prisma.client.update({
    where: { id: clientId },
    data: { assistantEnabled: !turnOff },
  });

  console.log(`Assistant ${turnOff ? 'disabled' : 'enabled'} for "${client.name}".`);
  if (!turnOff) {
    console.log(
      'Managers and admins in this tenant can now reach POST /assistant/chat ' +
        'and the "Ask TradeIQ" console destination. Field agents cannot — their ' +
        'roster is empty in Phase 0 by design.',
    );
  }
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
