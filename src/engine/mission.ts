import type { MissionConfig, MissionState, Site, SiteKind } from '../shared/types';
import { batteryCapacity } from './design';
import { orbitalEvidence } from './evidence';
import { createRandom, normalizeSeed } from './random';
import { RULES } from './rules';

interface SiteTemplate { id: string; name: string; kind: SiteKind; x: number; z: number }

/**
 * Illustrative candidate signals. The ice signal sits in the shaded western zone, loosely inspired by
 * ice in permanently shadowed polar craters; positions are fictional, not real lunar terrain.
 */
const SITE_TEMPLATES: readonly SiteTemplate[] = [
  { id: 'a', name: 'Shackleton signal', kind: 'ice', x: -6, z: -5 },
  { id: 'b', name: 'Ridge anomaly', kind: 'minerals', x: 6, z: -3 },
  { id: 'c', name: 'Exposed formation', kind: 'geology', x: 3, z: 7 }
];

/**
 * Seeded offset of up to ±1.5 units per axis. With these anchors the sites always stay inside the map,
 * the ice site stays shaded, no site is in range of the landing point, and sites are always more than
 * twice the proximity range apart, so at most one site is ever in range.
 */
const SITE_JITTER = 1.5;

const round1 = (n: number) => Math.round(n * 10) / 10;

export function generateSites(seed: number): Site[] {
  const random = createRandom(seed);
  return SITE_TEMPLATES.map(t => ({
    id: t.id, name: t.name, kind: t.kind,
    x: round1(t.x + (random() * 2 - 1) * SITE_JITTER),
    z: round1(t.z + (random() * 2 - 1) * SITE_JITTER),
    scanned: false, sampled: false,
    ...orbitalEvidence(seed, t.id)
  }));
}

export function createMission(config: MissionConfig, seed: number): MissionState {
  const normalizedSeed = normalizeSeed(seed);
  const capacity = batteryCapacity(config);
  return {
    seed: normalizedSeed,
    phase: 'planning',
    config: { ...config },
    position: { x: 0, z: 0 },
    energy: capacity,
    maxEnergy: capacity,
    turns: 0,
    scienceCollected: 0,
    scienceReturned: 0,
    outpostDeployed: false,
    outpostPosition: null,
    fuelCells: config?.power === 'fuel-cell' ? RULES.fuelCellSupplies : 0,
    sites: generateSites(normalizedSeed),
    log: ['Orbital survey received. Three unconfirmed signals await investigation.']
  };
}
