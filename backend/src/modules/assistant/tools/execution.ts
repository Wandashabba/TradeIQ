import { z } from 'zod';
import type { AuthTokenPayload } from '../../auth/auth.service';
import { getAgentPerformance } from '../../scorecards/scorecards.service';
import { periodSchema, resolvePeriod } from '../period';
import { eraseToolTypes, type AnyAssistantTool, type AssistantTool } from '../types';

/**
 * Execution-pillar tools — how well the field team is actually working.
 *
 * Every tool here is a **closure over the authenticated caller**. `clientId`
 * never appears in an args schema, so there is no parameter through which the
 * model could request another tenant's data. That is the difference between a
 * boundary enforced by the type signature and one enforced by a validation step
 * somebody has to remember to write for each new tool.
 *
 * `now` is injected rather than read from the clock inside `run`, so a tool's
 * behaviour is reproducible in a test and a turn's several tool calls all
 * resolve "today" to the same day — a turn that straddles midnight would
 * otherwise answer two questions about two different days.
 */

export interface ToolContext {
  user: AuthTokenPayload;
  now: Date;
}

const agentScorecardArgs = z.object({
  agentId: z
    .string()
    .min(1)
    .describe('The id of the field agent. Ids come from other tool results, never from the user.'),
  period: periodSchema,
});

export function buildExecutionTools(ctx: ToolContext): AnyAssistantTool[] {
  const { user, now } = ctx;

  const getAgentScorecard: AssistantTool<z.infer<typeof agentScorecardArgs>, unknown> = {
    name: 'getAgentScorecard',
    pillar: 'execution',
    // Prescriptive, not descriptive. Stating the trigger condition measurably
    // improves should-call rate over "Returns an agent's scorecard".
    // Leads with the named-person trigger, and says outright that a *quality*
    // question about a person belongs here. The first live eval sweep routed
    // both "How has Tumo been performing this month?" and "Compare Sipho
    // against the rest of the team" to `getVisitHistory` — whose description
    // ended "...or whether an agent has been checking in", which a model
    // reasonably reads as covering how an agent is doing. The two tools are
    // now explicitly disambiguated in both directions.
    description:
      'Call this when the user asks how well a NAMED field agent is performing, how good ' +
      'their work is, or asks to compare an agent against their team or another agent. ' +
      'This is the tool for questions about an individual\'s quality or score. ' +
      'Returns visit counts, an average execution score, per-dimension averages, and the ' +
      'team average over the same period. ' +
      'Use getVisitHistory instead if they want the raw list of visits rather than a judgement.',
    args: agentScorecardArgs,
    run: async (args) => {
      const { from, to } = resolvePeriod(args.period, now);
      return getAgentPerformance({
        // The tenant comes from the JWT. It is not, and must never become, an
        // argument the model supplies.
        clientId: user.clientId,
        agentId: args.agentId,
        from,
        to,
      });
    },
    // The tool declares what it draws; the model never names a spec type. The
    // period is echoed from the args rather than from the result so the
    // artifact can be re-run against a different one in Phase 2.
    view: (args) => ({
      type: 'agent_scorecard',
      params: { agentId: args.agentId, period: args.period },
    }),
  };

  return [eraseToolTypes(getAgentScorecard)];
}
