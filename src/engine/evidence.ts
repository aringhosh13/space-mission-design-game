/**
 * Evidence model, milestone 2: scientific confidence and reproducible false positives.
 *
 * `confidence` is the integer 0–100 certainty in a site's current `finding`, NOT the probability that
 * the resource exists. A ruled-out site with confidence 90 means "we are 90% sure this signal is not
 * the resource it looked like".
 *
 *   finding       how it is reached                    confidence (fictional ranges)
 *   unconfirmed   orbital survey, at mission creation  15–30
 *   probable      scan (preliminary evidence)          genuine 50–70, false positive 35–55 (ranges overlap,
 *                                                      so a scan hints but cannot settle the question)
 *   confirmed     sample of a genuine signal (drill)   85–95
 *   ruled-out     sample of a false positive (drill)   80–95
 *
 * Transitions only move forward and each happens at most once per site:
 *   unconfirmed --scan--> probable --sample--> confirmed | ruled-out
 * A scanner-only design therefore stops at 'probable'. Repeated scans or samples are rejected and
 * change nothing.
 *
 * Whether a signal is genuine is a pure function of (mission seed, site id), never stored in state and
 * never drawn from a shared random stream. Revisiting a site, repeating an action, or visiting sites in
 * a different order cannot reroll an outcome, and the same seed always yields the same truth.
 *
 * Only ice and mineral signals can be false positives (orbital signatures of those can be mimicked by
 * other surface materials); geology signals are exposed rock and always genuine. Every probability and
 * range here is a FICTIONAL BALANCING VALUE, not NASA data or a validated detection model.
 */
import type { Site, SiteFinding, SiteKind } from '../shared/types';
import { createRandom, normalizeSeed } from './random';

export const EVIDENCE = {
  falsePositiveChance: { ice: 0.35, minerals: 0.3, geology: 0 } satisfies Record<SiteKind, number>,
  orbital: [15, 30],
  scanGenuine: [50, 70],
  scanFalsePositive: [35, 55],
  confirmed: [85, 95],
  ruledOut: [80, 95]
} as const;

type Range = readonly [number, number];

/** FNV-1a hash of the seed, site id and purpose, so each draw has its own independent, fixed stream. */
function streamSeed(seed: number, siteId: string, purpose: string): number {
  const text = `${normalizeSeed(seed)}|${siteId}|${purpose}`;
  let h = 0x811c9dc5;
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}

/** A fixed integer in [min, max] for this seed, site and purpose. */
function drawInt(seed: number, siteId: string, purpose: string, [min, max]: Range): number {
  const r = createRandom(streamSeed(seed, siteId, purpose))();
  return min + Math.floor(r * (max - min + 1));
}

export function isFalsePositive(seed: number, site: Pick<Site, 'id' | 'kind'>): boolean {
  const chance = EVIDENCE.falsePositiveChance[site.kind];
  return createRandom(streamSeed(seed, site.id, 'truth'))() < chance;
}

export function orbitalEvidence(seed: number, siteId: string): { finding: SiteFinding; confidence: number } {
  return { finding: 'unconfirmed', confidence: drawInt(seed, siteId, 'orbital', EVIDENCE.orbital) };
}

export function scanEvidence(seed: number, site: Pick<Site, 'id' | 'kind'>): { finding: SiteFinding; confidence: number } {
  const range = isFalsePositive(seed, site) ? EVIDENCE.scanFalsePositive : EVIDENCE.scanGenuine;
  return { finding: 'probable', confidence: drawInt(seed, site.id, 'scan', range) };
}

export function sampleEvidence(seed: number, site: Pick<Site, 'id' | 'kind'>): { finding: SiteFinding; confidence: number } {
  return isFalsePositive(seed, site)
    ? { finding: 'ruled-out', confidence: drawInt(seed, site.id, 'sample', EVIDENCE.ruledOut) }
    : { finding: 'confirmed', confidence: drawInt(seed, site.id, 'sample', EVIDENCE.confirmed) };
}
