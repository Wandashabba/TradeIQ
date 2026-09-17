/**
 * The golden question set — the Phase 0 exit gate.
 *
 * **Tool selection is the primary metric because it is deterministic.** Did the
 * model call `getStockLevels`? That needs no judge, no grader self-agreement
 * measurement, and no threshold on prose. Most of this suite is a comparison
 * between two strings, which is exactly why it can gate a release without
 * becoming the flaky suite everyone learns to re-run.
 *
 * Scored, never asserted for equality. Non-determinism is real — the same
 * question can legitimately route to `getVisitHistory` or `getAgentScorecard`
 * — so questions carry an `acceptable` set, and the gate is a rate across the
 * suite rather than a pass/fail per row.
 *
 * The questions are written the way the practitioner talks. "Rate of sale",
 * "share of shelf", "the four pillars", and the period vocabulary are all
 * theirs; inventing cleaner phrasings would measure how well the model handles
 * our language rather than the user's.
 */

export interface GoldenQuestion {
  id: string;
  question: string;
  /** The tool we expect. `null` means the right answer is to call nothing. */
  expectedTool: string | null;
  /** Other defensible choices. A hit on any of these counts. */
  acceptable?: string[];
  /** The view spec this should produce, when it should produce one. */
  expectedSpec?: string;
  /** Why this question is in the set. */
  note?: string;
}

export const GOLDEN_QUESTIONS: readonly GoldenQuestion[] = [
  // ── Execution ────────────────────────────────────────────────────────────
  {
    id: 'exec-1',
    question: 'How has Tumo been performing this month?',
    expectedTool: 'getAgentScorecard',
    expectedSpec: 'agent_scorecard',
    note: 'The exit demo, verbatim from the plan.',
  },
  {
    id: 'exec-2',
    question: 'Compare Sipho against the rest of the team for month to date.',
    expectedTool: 'getAgentScorecard',
    note: 'Comparison is the job, not a follow-up.',
  },
  {
    id: 'exec-3',
    question: 'Which outlets did we actually call on last week?',
    expectedTool: 'getVisitHistory',
  },
  {
    id: 'exec-4',
    question: 'Has anyone not checked in today?',
    expectedTool: 'getVisitHistory',
  },
  {
    id: 'exec-5',
    question: 'Show me any visits that look suspicious.',
    expectedTool: 'getFraudFlags',
    note: 'Was "two or three months" to spot manually. The highest-value question.',
  },
  {
    id: 'exec-6',
    question: 'Is anyone gaming their numbers?',
    expectedTool: 'getFraudFlags',
  },
  {
    id: 'exec-7',
    question: 'Are agents checking in from where they say they are?',
    expectedTool: 'getFraudFlags',
    acceptable: ['getVisitHistory'],
  },
  // getMetricTrend is registered under execution, so its questions carry the
  // exec- prefix — the pillar-coverage test pins the prefix vocabulary.
  {
    id: 'exec-8',
    question: 'Is our on-shelf availability getting better or worse month to date?',
    expectedTool: 'getMetricTrend',
    expectedSpec: 'trend_chart',
    note: 'Movement, not a level — the phrasing that separates this from getStockLevels.',
  },
  {
    id: 'exec-9',
    question: 'How has the execution score moved week on week this year?',
    expectedTool: 'getMetricTrend',
    expectedSpec: 'trend_chart',
  },
  // The operational tools (#362) are registered under execution too.
  {
    id: 'exec-10',
    question: 'Who is leading the September Visit Sprint?',
    expectedTool: 'getContestStandings',
    note: 'A contest leaderboard, not an agent scorecard.',
  },
  {
    id: 'exec-11',
    question: 'Who won the August Execution Cup?',
    expectedTool: 'getContestStandings',
  },
  {
    id: 'exec-12',
    question: 'How many overdue tasks does Kagiso have?',
    expectedTool: 'getTaskSummary',
    note: 'Names an agent, but asks about tasks — must not collapse into getAgentScorecard.',
  },
  {
    id: 'exec-13',
    question: 'Which territories have the most overdue tasks?',
    expectedTool: 'getTaskSummary',
    note: 'Ranks territories, but by tasks — must not collapse into getTerritoryRanking.',
  },
  {
    id: 'exec-14',
    question: 'Which alerts are still unacknowledged?',
    expectedTool: 'getAlerts',
  },
  {
    id: 'exec-15',
    question: 'How many price alerts were raised last week?',
    expectedTool: 'getAlerts',
    note: 'About the alerts, not the prices — must not collapse into getPriceCompliance.',
  },
  {
    id: 'exec-16',
    question: 'What territories do we have?',
    expectedTool: 'findTerritories',
  },
  {
    id: 'exec-17',
    question: 'How is Nelson Mandela Bay doing on stock this month?',
    expectedTool: 'findTerritories',
    acceptable: ['getStockLevels'],
    note: 'The planted gap from #362: a territory named, no id. Resolve it before scoping.',
  },

  // ── Sales ────────────────────────────────────────────────────────────────
  {
    id: 'sales-1',
    question: 'What is our rate of sale year to date?',
    expectedTool: 'getRateOfSale',
    note: 'The practitioner\'s own term.',
  },
  {
    id: 'sales-2',
    question: 'Are we hitting target in Gauteng?',
    expectedTool: 'getRateOfSale',
    // A named place is resolved to its id first (#362); the eval scores the
    // first tool reached, and the lookup is the correct first reach.
    acceptable: ['findTerritories'],
  },
  {
    id: 'sales-3',
    question: 'Which SKUs are not moving?',
    expectedTool: 'getSkuMovement',
  },
  {
    id: 'sales-4',
    question: 'What is my best selling line this month?',
    expectedTool: 'getSkuMovement',
    acceptable: ['getRateOfSale'],
  },
  {
    id: 'sales-5',
    question: 'How did we do against target yesterday versus the day before?',
    expectedTool: 'getRateOfSale',
    note: 'Exercises the period vocabulary and an implied comparison at once.',
  },
  {
    id: 'sales-6',
    question: 'Which territories are driving the drop in sell-in this month?',
    expectedTool: 'getTerritoryRanking',
    note: 'Ranks territories against each other by sell-in change. Must not collapse into getRateOfSale, which gives a total or a single territory.',
  },
  {
    id: 'sales-7',
    question: 'Did the Winter Warmer campaign work? Execution looked great.',
    expectedTool: 'getCampaignPerformance',
    note: 'The planted flop: strong execution, negative lift.',
  },
  {
    id: 'sales-8',
    question: 'Which of our campaigns delivered a return?',
    expectedTool: 'getCampaignPerformance',
  },
  {
    id: 'sales-9',
    question: 'How much Cola 2L are outlets likely to order per day over the coming days?',
    expectedTool: 'getSellInForecast',
  },
  {
    id: 'sales-10',
    question: 'Give me a demand forecast for Kalahari Cola 1L.',
    expectedTool: 'getSellInForecast',
  },

  // ── Stock ────────────────────────────────────────────────────────────────
  {
    id: 'stock-1',
    question: 'What is our on-shelf availability?',
    expectedTool: 'getStockLevels',
  },
  {
    id: 'stock-2',
    question: 'Which stores keep running out of stock?',
    expectedTool: 'getStockLevels',
  },
  {
    id: 'stock-3',
    question: 'Do we have any out of stocks right now?',
    expectedTool: 'getStockLevels',
  },
  {
    id: 'stock-4',
    question: 'How long has the 500ml been out at those outlets?',
    expectedTool: 'getSkuMovement',
    acceptable: ['getStockLevels'],
  },

  // ── Visibility ───────────────────────────────────────────────────────────
  {
    id: 'vis-1',
    question: 'What is our share of shelf in Western Cape?',
    expectedTool: 'getShareOfShelf',
    acceptable: ['findTerritories'],
  },
  {
    id: 'vis-2',
    question: 'How many facings are we holding versus the competition?',
    expectedTool: 'getShareOfShelf',
  },
  {
    id: 'vis-3',
    question: 'Are stores following the planogram?',
    expectedTool: 'getVisibilityCompliance',
  },
  {
    id: 'vis-4',
    question: 'How is our merchandising compliance tracking month to date?',
    expectedTool: 'getVisibilityCompliance',
  },

  // ── Competition ──────────────────────────────────────────────────────────
  {
    id: 'comp-1',
    question: 'What are competitors pricing at?',
    expectedTool: 'getCompetitorActivity',
  },
  {
    id: 'comp-2',
    question: 'Are competitors running promoters in our outlets?',
    expectedTool: 'getCompetitorActivity',
  },
  {
    id: 'comp-3',
    question: 'Which competitor brands are showing up most?',
    expectedTool: 'getCompetitorActivity',
  },
  {
    id: 'comp-4',
    question: 'Are any retailers overpricing our products?',
    expectedTool: 'getPriceCompliance',
    note: 'Our shelf prices against RRP — not competitor prices (comp-1).',
  },
  {
    id: 'comp-5',
    question: 'What is QuickSave charging for Cola 2L compared with RRP?',
    expectedTool: 'getPriceCompliance',
  },

  // ── Outside context — calendar, weather, economy ─────────────────────────
  // Public data that explains a movement; never the client's own figures.
  {
    id: 'ctx-1',
    question: 'Were there any public holidays or school holidays last week?',
    expectedTool: 'getCalendarContext',
  },
  {
    id: 'ctx-2',
    question: 'When are SASSA grants paid this month?',
    expectedTool: 'getCalendarContext',
    note: 'A calendar fact, not a sales question.',
  },
  {
    id: 'ctx-3',
    question: 'Has it been wetter than usual in our territories this month?',
    expectedTool: 'getWeatherContext',
    acceptable: ['findTerritories'],
  },
  {
    id: 'ctx-4',
    question: 'Was last week hotter than the same week last year where our outlets are?',
    expectedTool: 'getWeatherContext',
  },
  {
    id: 'ctx-5',
    question: 'What is food inflation doing in South Africa at the moment?',
    expectedTool: 'getEconomicContext',
    note: 'Market-wide, from Stats SA — must not collapse into getCompetitorActivity or getPriceCompliance.',
  },
  {
    id: 'ctx-6',
    question: 'Were retail sales across the country up or down year to date?',
    expectedTool: 'getEconomicContext',
    note: 'National retail trade, not our sell-in — must not collapse into getRateOfSale.',
  },

  // ── Refusals — an acceptable failure mode, by design ──────────────────────
  {
    id: 'refuse-1',
    question: 'Deactivate Sipho\'s account.',
    expectedTool: null,
    note:
      'Phase 0 is read-only. The right answer is to say so, not to hunt for a tool. ' +
      'A model that calls something here is the excessive-agency failure.',
  },
  {
    id: 'refuse-2',
    question: 'What will interest rates do to our volumes next quarter?',
    expectedTool: null,
    note:
      'The macro overlay is backlog (#249), not built. Refusing is correct; ' +
      'inventing a number is the exact failure the semantic layer prevents.',
  },
];

/** The Phase 0 gate. Per provider, never averaged across them. */
export const TOOL_SELECTION_THRESHOLD = 0.9;

export interface ScoredQuestion {
  id: string;
  question: string;
  expected: string | null;
  actual: string | null;
  hit: boolean;
}

/**
 * Score one answer.
 *
 * A question expecting `null` is a **refusal check**: calling any tool is a
 * miss. Those are in the suite deliberately — "I can't answer that" is an
 * acceptable failure mode by design, and a suite with no refusals rewards a
 * model that always guesses.
 */
export function score(question: GoldenQuestion, actualTool: string | null): ScoredQuestion {
  const acceptable = new Set(
    [question.expectedTool, ...(question.acceptable ?? [])].filter(
      (name): name is string => name !== null,
    ),
  );

  const hit =
    question.expectedTool === null ? actualTool === null : actualTool !== null && acceptable.has(actualTool);

  return {
    id: question.id,
    question: question.question,
    expected: question.expectedTool,
    actual: actualTool,
    hit,
  };
}

export interface EvalReport {
  total: number;
  hits: number;
  accuracy: number;
  passed: boolean;
  misses: ScoredQuestion[];
}

export function summarise(scored: readonly ScoredQuestion[]): EvalReport {
  const hits = scored.filter((s) => s.hit).length;
  // Guard the empty case: 0/0 is NaN, and `NaN >= 0.9` is false, so an empty
  // run would report as a *failure* rather than as the misconfiguration it is.
  const accuracy = scored.length > 0 ? hits / scored.length : 0;

  return {
    total: scored.length,
    hits,
    accuracy: Math.round(accuracy * 1000) / 1000,
    passed: scored.length > 0 && accuracy >= TOOL_SELECTION_THRESHOLD,
    misses: scored.filter((s) => !s.hit),
  };
}
