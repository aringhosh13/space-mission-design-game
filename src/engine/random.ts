/**
 * Seeded pseudo-random generator (mulberry32). Deterministic for a given seed and
 * independent of wall-clock time, so a seed plus an action sequence always replays identically.
 */
export function normalizeSeed(seed: number): number {
  return Number.isFinite(seed) ? Math.trunc(seed) : 0;
}

export function createRandom(seed: number): () => number {
  let t = normalizeSeed(seed) >>> 0;
  return () => {
    t = (t + 0x6d2b79f5) >>> 0;
    let r = Math.imul(t ^ (t >>> 15), 1 | t);
    r = (r + Math.imul(r ^ (r >>> 7), 61 | r)) ^ r;
    return ((r ^ (r >>> 14)) >>> 0) / 4294967296;
  };
}
