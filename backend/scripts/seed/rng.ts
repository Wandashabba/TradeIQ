/**
 * Deterministic PRNG for the demo seed.
 *
 * The seed is generated, not hand-written, so reproducibility has to come from
 * somewhere: a fixed seed here means every run produces byte-identical values.
 * Only dates move (see `calendar.ts`), so a bug seen in a demo can always be
 * recreated.
 *
 * mulberry32 — small, fast, and good enough for demo data. Not for anything
 * security-sensitive.
 */
/** Deterministic sequence generator — same seed, same numbers. */
export function makeRng(seed: number): () => number {
  let a = seed >>> 0;
  return function next(): number {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Inclusive of both `min` and `max`. */
export function intBetween(rng: () => number, min: number, max: number): number {
  if (min > max) {
    throw new Error(`intBetween: min ${min} is greater than max ${max}`);
  }
  return min + Math.floor(rng() * (max - min + 1));
}

/** Uniform choice from a non-empty list. */
export function pick<T>(rng: () => number, items: readonly T[]): T {
  if (items.length === 0) {
    throw new Error('pick from empty list');
  }
  return items[Math.floor(rng() * items.length)] as T;
}

/** Symmetric noise in [-magnitude, +magnitude]. */
export function jitter(rng: () => number, magnitude: number): number {
  return (rng() * 2 - 1) * magnitude;
}
