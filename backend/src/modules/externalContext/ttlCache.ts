/**
 * A small in-memory cache with per-entry TTLs and a size bound.
 *
 * In memory rather than in Postgres on purpose: weather is cheap to re-fetch,
 * nothing downstream needs it to survive a restart, and a table would add a
 * write to a read path. N instances each keep their own copy, which costs a
 * few extra free API calls and nothing else.
 *
 * Insertion order doubles as age order, so evicting the first key is evicting
 * the oldest write — enough of an LRU for a cache this size.
 */
export class TtlCache<V> {
  private readonly entries = new Map<string, { value: V; expiresAt: number }>();

  constructor(
    private readonly maxEntries: number,
    private readonly clock: () => number = Date.now,
  ) {}

  get(key: string): V | undefined {
    const hit = this.entries.get(key);
    if (!hit) return undefined;
    if (hit.expiresAt <= this.clock()) {
      this.entries.delete(key);
      return undefined;
    }
    return hit.value;
  }

  set(key: string, value: V, ttlMs: number): void {
    this.entries.delete(key);
    this.entries.set(key, { value, expiresAt: this.clock() + ttlMs });
    while (this.entries.size > this.maxEntries) {
      const oldest = this.entries.keys().next().value;
      if (oldest === undefined) break;
      this.entries.delete(oldest);
    }
  }

  get size(): number {
    return this.entries.size;
  }

  clear(): void {
    this.entries.clear();
  }
}
