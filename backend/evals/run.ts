// Matches `src/server.ts`. Without it this ran only in CI, where the workflow
// injects the key — so the one machine that could iterate on the golden set
// locally was the one that could not run it.
import 'dotenv/config';
import { writeFileSync } from 'fs';
import { resolve } from 'path';
import type { AuthTokenPayload } from '../src/modules/auth/auth.service';
import { runTurn } from '../src/modules/assistant/orchestrator';
import { providerFor } from '../src/modules/assistant/providers';
import { buildTools } from '../src/modules/assistant/tools';
import {
  GOLDEN_QUESTIONS,
  score,
  summarise,
  TOOL_SELECTION_THRESHOLD,
  type ScoredQuestion,
} from './golden-questions';

/**
 * The live tool-selection sweep — the half of the Phase 0 gate that needs a
 * provider.
 *
 * Run by `assistant-evals.yml`: a cheap slice on every assistant PR, the whole
 * set nightly. Everything checkable without a key already runs in
 * `backend-ci` via `evals.test.ts`.
 *
 * **This measures tool choice, never prose.** Which tool the model picked is a
 * string comparison — no judge, no grader self-agreement to worry about, no
 * threshold on wording. That is the whole reason tool selection is the primary
 * metric rather than answer quality: it can gate a release without becoming the
 * flaky suite everyone learns to re-run until green.
 *
 * Nothing here touches the database. Tools are built for a synthetic caller and
 * the sweep stops at the first tool call, so no service ever runs — the model
 * is being asked "what would you reach for", which is exactly what is scored.
 */

/**
 * A caller that exists only for the sweep.
 *
 * The ids are obviously fake because they are never dereferenced: the run
 * aborts at the first `tool_call` event, before any tool's `run` executes. If
 * that ever stops being true this becomes a real fixture, and the sweep starts
 * needing a database.
 */
const EVAL_USER: AuthTokenPayload = {
  userId: 'eval-user',
  role: 'manager',
  clientId: 'eval-client',
};

/** How many questions the PR slice runs. Enough to catch a collapse, cheap enough to run per PR. */
const SLICE_SIZE = 8;

/**
 * What one question produced.
 *
 * `errored` is **not** the same as `chose nothing`, and conflating them is a
 * measurement bug rather than a rounding issue: a 503 from the provider would
 * otherwise be scored as the model picking the wrong tool, so the headline
 * number would be part tool-selection accuracy and part Google's uptime. On the
 * first real run that single conflation was the difference between 88% (fail)
 * and 91.7% (pass).
 */
type Selection =
  | { kind: 'tool'; name: string }
  | { kind: 'none' }
  | { kind: 'error'; code: string };

async function attempt(question: string): Promise<Selection> {
  const controller = new AbortController();
  const tools = buildTools({ user: EVAL_USER, now: new Date() });

  for await (const event of runTurn({
    provider: providerFor(),
    tools,
    messages: [{ role: 'user', content: question }],
    signal: controller.signal,
    // One round. We are scoring the first reach, and letting the loop continue
    // would run real tools against a caller that does not exist.
    maxToolRounds: 1,
  })) {
    if (event.event === 'tool_start') {
      // Stop the turn the moment we have the answer: everything after this is
      // a paid continuation we would throw away.
      controller.abort();
      return { kind: 'tool', name: event.data.name };
    }
    if (event.event === 'error') {
      return { kind: 'error', code: event.data.code };
    }
  }

  return { kind: 'none' };
}

/**
 * Codes worth one retry.
 *
 * Deliberately narrow. `bad_request` or `not_configured` will fail identically
 * on a second attempt and retrying them just doubles the bill; a 503 or a rate
 * limit is the provider having a moment and says nothing about tool selection.
 */
const TRANSIENT = new Set(['provider_error', 'rate_limited', 'provider_unavailable']);

async function selectedToolFor(question: string): Promise<Selection> {
  const first = await attempt(question);
  if (first.kind !== 'error' || !TRANSIENT.has(first.code)) return first;

  console.error(`  ! ${first.code} — retrying once`);
  return attempt(question);
}

async function main(): Promise<void> {
  const full = process.env.EVAL_SCOPE !== 'slice';
  const questions = full
    ? GOLDEN_QUESTIONS
    : // Every Nth question rather than the first N, so the slice keeps covering
      // all five pillars and both refusal cases instead of just execution.
      GOLDEN_QUESTIONS.filter(
        (_, i) => i % Math.ceil(GOLDEN_QUESTIONS.length / SLICE_SIZE) === 0,
      );

  console.log(
    `assistant-evals: ${questions.length} question(s), ` +
      `provider=${providerFor().name}, scope=${full ? 'full' : 'slice'}`,
  );

  const scored: ScoredQuestion[] = [];
  const errored: { id: string; code: string }[] = [];

  for (const question of questions) {
    const selection = await selectedToolFor(question.question);

    if (selection.kind === 'error') {
      // Excluded from the denominator, never silently: an unreported exclusion
      // is how a run over half the set reads as a clean pass.
      errored.push({ id: question.id, code: selection.code });
      console.log(`  SKIP  ${question.id.padEnd(10)} provider error: ${selection.code}`);
      continue;
    }

    const result = score(question, selection.kind === 'tool' ? selection.name : null);
    scored.push(result);
    console.log(
      `  ${result.hit ? 'PASS' : 'FAIL'}  ${question.id.padEnd(10)} ` +
        `expected=${result.expected ?? '(none)'} actual=${result.actual ?? '(none)'}`,
    );
  }

  const report = summarise(scored);

  // Written before the threshold check, so a failing run still produces the
  // artifact that explains why it failed.
  writeFileSync(
    resolve(__dirname, 'report.json'),
    JSON.stringify(
      {
        provider: providerFor().name,
        model: process.env.GEMINI_ORCHESTRATOR_MODEL ?? '(default)',
        scope: full ? 'full' : 'slice',
        asked: questions.length,
        errored,
        ...report,
      },
      null,
      2,
    ),
  );

  console.log(
    `\ntool-selection accuracy: ${(report.accuracy * 100).toFixed(1)}% ` +
      `(${report.hits}/${report.total}), gate ${TOOL_SELECTION_THRESHOLD * 100}%`,
  );

  if (errored.length > 0) {
    // Loud, because a shrinking denominator flatters the percentage. A run that
    // errored on half the set can post a perfect score.
    console.log(
      `\n⚠ ${errored.length} of ${questions.length} question(s) excluded after a ` +
        `provider error and one retry: ${errored.map((e) => `${e.id} (${e.code})`).join(', ')}`,
    );
    console.log('  The accuracy above is over the remainder, not the whole set.');
  }

  if (report.misses.length > 0) {
    console.log('\nmisses:');
    for (const miss of report.misses) {
      console.log(`  ${miss.id}: "${miss.question}"`);
      console.log(`    expected ${miss.expected ?? '(no tool)'}, got ${miss.actual ?? '(no tool)'}`);
    }
  }

  if (!report.passed) {
    // Non-zero exit, so the gate is a gate. A sweep that reported a number and
    // exited 0 would be a dashboard, not a check.
    console.error(
      `\nFAILED: below the ${TOOL_SELECTION_THRESHOLD * 100}% gate. ` +
        'Refusals clustering on one pillar usually means a tool description ' +
        'stopped stating its trigger condition.',
    );
    process.exitCode = 1;
  }
}

main().catch((err) => {
  console.error('assistant-evals failed to run', err);
  process.exitCode = 1;
});
