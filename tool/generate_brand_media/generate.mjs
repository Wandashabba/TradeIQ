#!/usr/bin/env node
/**
 * Generates brand illustration CANDIDATES for TradeIQ via Google's Imagen
 * REST API. Build-time only: this script runs on a developer machine, never
 * in CI and never in the app — the app ships only human-curated, committed
 * assets and holds no API key. See README.md for the curation workflow.
 *
 * Node >= 18 (global fetch), zero npm dependencies.
 *
 *   GEMINI_API_KEY=<your key> node generate.mjs
 *
 * Output: out/<slug>-<n>.png (gitignored — candidates, not assets).
 */
import { mkdir, rm, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { prompts, styleSuffix } from './prompts.mjs';

const MODEL = 'imagen-3.0-generate-002';
const ENDPOINT = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:predict`;
const SAMPLE_COUNT = 2;

// The key is read once from the environment and only ever placed in the
// request header. It must never be hardcoded, logged or echoed.
const apiKey = process.env.GEMINI_API_KEY;
if (!apiKey) {
  fail(
    'GEMINI_API_KEY is not set.\n\n' +
      'Run:  GEMINI_API_KEY=<your key> node generate.mjs\n' +
      '(Get a key at https://aistudio.google.com/apikey — do not commit it.)',
  );
}

const outDir = join(dirname(fileURLToPath(import.meta.url)), 'out');

/** Print a clean, actionable message (never a stack trace) and exit 1. */
function fail(message) {
  console.error(`error: ${message}`);
  process.exit(1);
}

/** Extract Google's error message from a non-2xx body, if it is JSON. */
async function apiErrorDetail(res) {
  try {
    const body = await res.json();
    return body?.error?.message ?? '';
  } catch {
    return '';
  }
}

/** Generate SAMPLE_COUNT candidates for one prompt; returns files written. */
async function generate({ slug, prompt, aspectRatio }) {
  let res;
  try {
    res = await fetch(ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: JSON.stringify({
        instances: [{ prompt: `${prompt} ${styleSuffix}` }],
        parameters: { sampleCount: SAMPLE_COUNT, aspectRatio },
      }),
    });
  } catch (err) {
    fail(
      `could not reach the Imagen API (${err?.cause?.code ?? err?.message ?? 'network error'}). ` +
        'Check your connection and try again.',
    );
  }

  if (res.status === 400 || res.status === 401 || res.status === 403) {
    const detail = await apiErrorDetail(res);
    fail(
      `the Imagen API rejected the request for "${slug}" (HTTP ${res.status}).\n` +
        (detail ? `${detail}\n` : '') +
        `Your GEMINI_API_KEY is likely invalid, expired, or lacks access to ${MODEL}.`,
    );
  }
  if (!res.ok) {
    const detail = await apiErrorDetail(res);
    fail(
      `Imagen API error for "${slug}" (HTTP ${res.status})` +
        (detail ? `: ${detail}` : '.'),
    );
  }

  let predictions;
  try {
    ({ predictions } = await res.json());
  } catch {
    fail(
      `unexpected non-JSON response from the Imagen API for "${slug}" ` +
        `(HTTP ${res.status}). Retry; if it persists the API may have changed.`,
    );
  }
  if (!Array.isArray(predictions) || predictions.length === 0) {
    fail(
      `the Imagen API returned no images for "${slug}" — the prompt may ` +
        'have been filtered. Soften the prompt in prompts.mjs and retry.',
    );
  }

  let written = 0;
  for (const [i, prediction] of predictions.entries()) {
    const b64 = prediction?.bytesBase64Encoded;
    if (!b64) continue;
    const file = join(outDir, `${slug}-${i + 1}.png`);
    await writeFile(file, Buffer.from(b64, 'base64'));
    written += 1;
    console.log(`  wrote ${file}`);
  }
  if (written === 0) {
    fail(
      `the Imagen API returned predictions without image bytes for ` +
        `"${slug}" — nothing was written. Retry; if it persists the ` +
        'response shape may have changed.',
    );
  }
  return written;
}

// Fresh slate: stale candidates from an earlier (possibly partial) run must
// never mix with this run's output.
await rm(outDir, { recursive: true, force: true });
await mkdir(outDir, { recursive: true });
let total = 0;
for (const p of prompts) {
  console.log(`${p.slug} (${SAMPLE_COUNT} candidates)…`);
  total += await generate(p);
}
console.log(`\nDone: ${total} candidate(s) in ${outDir}`);
console.log('Next: curate per README.md — pick ONE per slug, by hand.');
