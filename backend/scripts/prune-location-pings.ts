import { prisma } from '../src/lib/prisma';
import { parsePruneArgs, pruneLocationPings } from '../src/modules/locations/locationRetention';

/**
 * Enforces the agent location retention policy (#178).
 *
 *   npm run prune-location-pings -- --dry-run
 *   npm run prune-location-pings
 *   npm run prune-location-pings -- --client <clientId>
 *   npm run prune-location-pings -- --max-agent-days 500
 *
 *   --dry-run         count what is past retention; delete nothing
 *   --client          one tenant only
 *   --max-agent-days  stop after this many agent-days (run it again to continue)
 *
 * Folds each agent's UTC day of raw pings into an AgentDaySummary, then deletes
 * those pings, in one transaction per agent-day: pings older than 90 days, and
 * every raw ping of a deactivated agent. Safe to kill and to re-run.
 *
 * Nothing schedules this yet; the scheduler (#66) should call
 * pruneLocationPings() from src/modules/locations/locationRetention.ts.
 */
async function main(): Promise<void> {
  const options = parsePruneArgs(process.argv.slice(2));
  const started = Date.now();
  const result = await pruneLocationPings({ ...options, log: (line) => console.log(line) });
  const scope = options.clientId ? ` for client ${options.clientId}` : '';
  if (result.dryRun) {
    console.log(
      `Dry run${scope}: ${result.expiredPings} ping(s) recorded before ${result.cutoff.toISOString()} ` +
        `and ${result.deactivatedAgentPings} ping(s) of deactivated agents would be summarised and deleted. ` +
        'Nothing was deleted.',
    );
    return;
  }
  const seconds = Math.round((Date.now() - started) / 1000);
  console.log(
    `Done in ${seconds}s${scope}: summarised ${result.agentDaysSummarised} agent-day(s), deleted ` +
      `${result.pingsDeleted} ping(s), fully purged ${result.deactivatedAgentsPurged} deactivated agent(s).` +
      (result.stoppedEarly ? ' Stopped at --max-agent-days with work remaining; run again to continue.' : ''),
  );
}

main()
  .catch((err) => {
    console.error(err instanceof Error ? err.message : err);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
