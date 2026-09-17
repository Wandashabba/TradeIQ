import { z } from 'zod';
import type { RawWebSource } from './providers/types';
import { neutraliseUntrustedText, scanForInstructions } from './sanitize';

/**
 * Web sources — the citations behind outside information in an answer.
 *
 * Both vendors hand us cited pages in their own shapes (Anthropic's
 * `web_search_result_location`, Gemini's grounding chunks). The adapters flatten
 * those into {@link RawWebSource}; this file is the one place that decides what
 * a client is allowed to see, the same way `viewspec.ts` is for artifacts.
 *
 * **Everything in a source is untrusted.** A page title is written by the page's
 * owner, and a search index will happily return a page whose title is an
 * injection attempt or whose link is `javascript:`. So, before anything is
 * published:
 *
 * - the url must parse, be `http:` or `https:`, and carry no credentials —
 *   anything else is dropped whole, never "repaired";
 * - title and snippet lose our fence, invisible text, and the answer's
 *   authoritative markup (`neutraliseUntrustedText`), then are bounded;
 * - a snippet that reads like an instruction to a model is dropped rather than
 *   shown, and the drop is logged — the page is still cited, but the words that
 *   look like an attack are not put under a manager's thumb.
 *
 * Pure — no Prisma, no network — so every rejection is unit-testable.
 */

/** Enough to cite a busy news turn; more is a wall of chips nobody reads. */
export const MAX_SOURCES = 10;
export const MAX_SNIPPET_CHARS = 200;
export const MAX_TITLE_CHARS = 160;
const MAX_URL_CHARS = 2048;
const MAX_PAGE_AGE_CHARS = 40;

/** What goes out on the `sources` SSE event, one entry per cited page. */
export const webSourceSchema = z.object({
  title: z.string().min(1).max(MAX_TITLE_CHARS),
  url: z.string().url().max(MAX_URL_CHARS),
  /** Hostname without `www.` — the publisher, as far as a url can say. */
  domain: z.string().min(1),
  /** Free text from the vendor ("3 days ago"); null when unknown. Not a date. */
  pageAge: z.string().max(MAX_PAGE_AGE_CHARS).nullable(),
  /** When this turn retrieved it, ISO-8601. */
  retrievedAt: z.string().datetime(),
  snippet: z.string().max(MAX_SNIPPET_CHARS).nullable(),
});
export type WebSource = z.infer<typeof webSourceSchema>;

/** A url a client may open, or null. Never rewrites a bad one into a good one. */
export function safeSourceUrl(raw: unknown): URL | null {
  if (typeof raw !== 'string' || raw.length === 0 || raw.length > MAX_URL_CHARS) return null;
  let url: URL;
  try {
    url = new URL(raw.trim());
  } catch {
    return null;
  }
  if (url.protocol !== 'https:' && url.protocol !== 'http:') return null;
  // `https://bank.example@evil.example/` reads as the bank and opens the other.
  if (url.username || url.password) return null;
  if (!url.hostname) return null;
  return url;
}

function isControl(code: number): boolean {
  return code < 0x20 || (code >= 0x7f && code <= 0x9f);
}

/** Collapse whitespace, strip control characters, disarm, and bound. */
function cleanText(raw: unknown, max: number): string | null {
  if (typeof raw !== 'string') return null;
  const flattened = neutraliseUntrustedText(raw)
    // C0/C1 controls become spaces, then whitespace is collapsed below.
    .split('')
    .map((ch) => (isControl(ch.charCodeAt(0)) ? ' ' : ch))
    .join('')
    .replace(/\s+/g, ' ')
    .trim();
  if (flattened.length === 0) return null;
  return flattened.length > max ? `${flattened.slice(0, max - 1).trimEnd()}…` : flattened;
}

/**
 * Raw vendor sources → the published list.
 *
 * Deduplicated by url (a page cited three times is one source, keeping the
 * first snippet and the first known page age), capped at {@link MAX_SOURCES},
 * and every survivor re-validated against {@link webSourceSchema} so the wire
 * shape is a checked contract rather than an intention.
 */
export function normaliseSources(raw: readonly RawWebSource[], retrievedAt: Date): WebSource[] {
  const byUrl = new Map<string, WebSource>();

  for (const candidate of raw) {
    const url = safeSourceUrl(candidate?.url);
    if (!url) {
      if (candidate?.url) console.warn('[assistant] dropped a web source with an unsafe url');
      continue;
    }
    const href = url.toString();
    const domain = url.hostname.replace(/^www\./i, '').toLowerCase();

    let snippet = cleanText(candidate.snippet, MAX_SNIPPET_CHARS);
    if (snippet && scanForInstructions(candidate.snippet ?? '').length > 0) {
      console.warn(`[assistant] withheld an instruction-like snippet from ${domain}`);
      snippet = null;
    }
    const pageAge = cleanText(candidate.pageAge, MAX_PAGE_AGE_CHARS);

    const existing = byUrl.get(href);
    if (existing) {
      if (!existing.snippet && snippet) existing.snippet = snippet;
      if (!existing.pageAge && pageAge) existing.pageAge = pageAge;
      continue;
    }
    if (byUrl.size >= MAX_SOURCES) continue;

    const source = {
      // A page with no usable title is still citable; its domain names it.
      title: cleanText(candidate.title, MAX_TITLE_CHARS) ?? domain,
      url: href,
      domain,
      pageAge,
      retrievedAt: retrievedAt.toISOString(),
      snippet,
    };
    const checked = webSourceSchema.safeParse(source);
    if (checked.success) byUrl.set(href, checked.data);
  }

  return [...byUrl.values()];
}
