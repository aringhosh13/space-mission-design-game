import { describe, expect, it } from 'vitest';
import type { MissionAction, MissionState, SiteFinding, SiteKind } from '../../shared/types';
import { engine, EVIDENCE, RULES } from '../index';
import { isFalsePositive } from '../evidence';
import { createRandom } from '../random';
import { at, deepFreeze, DRILL, driveTo, launched, run, SCANNER, site, withEnergy } from './helpers';

const KINDS: SiteKind[] = ['ice', 'minerals', 'geology'];
const RANK: Record<SiteFinding, number> = { unconfirmed: 0, probable: 1, confirmed: 2, 'ruled-out': 2 };

/** First seed (from 0) whose truth matches the predicate. */
function findSeed(predicate: (seed: number) => boolean): number {
  for (let seed = 0; seed < 10_000; seed++) if (predicate(seed)) return seed;
  throw new Error('no matching seed');
}
const truth = (seed: number, kind: SiteKind) => {
  const s = engine.createMission(DRILL, seed);
  return isFalsePositive(seed, site(s, kind));
};

/** Teleport to a site with a full battery and run actions there. */
function investigate(state: MissionState, kind: SiteKind, actions: MissionAction[] = [{ type: 'scan' }, { type: 'sample' }]) {
  return run(at(withEnergy(state, state.maxEnergy), site(state, kind)), actions);
}

describe('research station position', () => {
  it('starts null', () => {
    expect(engine.createMission(DRILL, 1).outpostPosition).toBeNull();
    expect(launched().outpostPosition).toBeNull();
  });

  it("records the rover's position on deployment and keeps it when the rover moves", () => {
    const deployed = engine.step(at(launched(), { x: 1.5, z: -2 }), { type: 'deploy' });
    expect(deployed.outpostPosition).toEqual({ x: 1.5, z: -2 });
    expect(deployed.outpostPosition).not.toBe(deployed.position);

    const moved = run(deployed, [
      { type: 'move', dx: 1, dz: 0 }, { type: 'move', dx: 0, dz: 1 }, { type: 'move', dx: -1, dz: -1.5 }
    ]);
    expect(moved.position).not.toEqual({ x: 1.5, z: -2 });
    expect(moved.outpostPosition).toEqual({ x: 1.5, z: -2 });
  });

  it('is not moved by a repeated deployment elsewhere, mission completion or the report', () => {
    const deployed = engine.step(at(launched(), { x: 4, z: 4 }), { type: 'deploy' });
    const again = engine.step(at(deployed, { x: 6, z: 6 }), { type: 'deploy' });
    expect(again.outpostPosition).toEqual({ x: 4, z: 4 });
    const done = engine.step(again, { type: 'finish' });
    expect(done.outpostPosition).toEqual({ x: 4, z: 4 });
    expect(engine.getReport(done).feedback.join(' ')).toMatch(/X 4\.0 \/ Z 4\.0/);
  });

  it('stays null when deployment is rejected', () => {
    expect(engine.step(at(launched(), { x: -6, z: 0 }), { type: 'deploy' }).outpostPosition).toBeNull();
    expect(engine.step(withEnergy(launched(), 1), { type: 'deploy' }).outpostPosition).toBeNull();
  });

  it('does not mutate a frozen input when deploying', () => {
    const frozen = deepFreeze(at(launched(), { x: 2, z: 2 }));
    expect(engine.step(frozen, { type: 'deploy' }).outpostPosition).toEqual({ x: 2, z: 2 });
    expect(frozen.outpostPosition).toBeNull();
  });
});

describe('confidence bounds and transitions', () => {
  it('starts every site unconfirmed with orbital confidence in range', () => {
    for (let seed = 0; seed < 500; seed++) {
      for (const s of engine.createMission(DRILL, seed).sites) {
        expect(s.finding).toBe('unconfirmed');
        expect(Number.isInteger(s.confidence)).toBe(true);
        expect(s.confidence).toBeGreaterThanOrEqual(EVIDENCE.orbital[0]);
        expect(s.confidence).toBeLessThanOrEqual(EVIDENCE.orbital[1]);
      }
    }
  });

  it('moves unconfirmed → probable on scan and → confirmed or ruled-out on sample, matching the hidden truth', () => {
    const within = (n: number, [min, max]: readonly [number, number]) => n >= min && n <= max && Number.isInteger(n);
    for (let seed = 0; seed < 500; seed++) {
      let s = launched(DRILL, seed);
      for (const kind of KINDS) {
        const fake = isFalsePositive(seed, site(s, kind));
        s = investigate(s, kind, [{ type: 'scan' }]);
        expect(site(s, kind).finding).toBe('probable');
        expect(within(site(s, kind).confidence, fake ? EVIDENCE.scanFalsePositive : EVIDENCE.scanGenuine)).toBe(true);

        s = investigate(s, kind, [{ type: 'sample' }]);
        expect(site(s, kind).finding).toBe(fake ? 'ruled-out' : 'confirmed');
        expect(within(site(s, kind).confidence, fake ? EVIDENCE.ruledOut : EVIDENCE.confirmed)).toBe(true);
      }
    }
  });

  it('stops at probable without a drill', () => {
    const s = investigate(launched(SCANNER), 'ice');
    expect(site(s, 'ice').finding).toBe('probable');
  });

  it('leaves the finding unconfirmed if sampling is attempted before a scan', () => {
    const before = launched();
    const s = investigate(before, 'ice', [{ type: 'sample' }]);
    expect(site(s, 'ice')).toEqual(site(before, 'ice'));
  });

  it('never moves a finding backward and keeps confidence an integer in 0–100 over long seeded random play', () => {
    for (const seed of [3, 11, 2026]) {
      const random = createRandom(seed);
      let s = launched(DRILL, seed);
      const actions: MissionAction['type'][] = ['scan', 'sample', 'recharge', 'transmit'];
      for (let i = 0; i < 1500; i++) {
        const prev = s;
        const roll = random();
        s = roll < 0.6
          ? engine.step(s, { type: 'move', dx: random() * 2 - 1, dz: random() * 2 - 1 })
          : engine.step(s, { type: actions[Math.floor(random() * actions.length)] } as MissionAction);
        for (let k = 0; k < s.sites.length; k++) {
          const before = prev.sites[k], after = s.sites[k];
          expect(RANK[after.finding]).toBeGreaterThanOrEqual(RANK[before.finding]);
          if (RANK[before.finding] === 2) expect(after).toEqual(before);
          expect(Number.isInteger(after.confidence)).toBe(true);
          expect(after.confidence).toBeGreaterThanOrEqual(0);
          expect(after.confidence).toBeLessThanOrEqual(100);
        }
      }
    }
  });
});

describe('reproducible false positives', () => {
  it('never makes geology signals false positives', () => {
    for (let seed = 0; seed < 2000; seed++) expect(truth(seed, 'geology')).toBe(false);
  });

  it('produces both outcomes for ice and minerals at roughly the configured rate', () => {
    for (const kind of ['ice', 'minerals'] as const) {
      let fakes = 0;
      for (let seed = 0; seed < 2000; seed++) if (truth(seed, kind)) fakes++;
      expect(fakes / 2000).toBeGreaterThan(EVIDENCE.falsePositiveChance[kind] - 0.05);
      expect(fakes / 2000).toBeLessThan(EVIDENCE.falsePositiveChance[kind] + 0.05);
    }
  });

  it('gives identical outcomes for the same seed in separate missions', () => {
    for (const seed of [0, 7, 42, 99, 12345]) {
      const a = KINDS.reduce((s, k) => investigate(s, k), launched(DRILL, seed));
      const b = KINDS.reduce((s, k) => investigate(s, k), launched(DRILL, seed));
      expect(a.sites).toEqual(b.sites);
    }
  });

  it('does not depend on visit order or equipment choice', () => {
    for (const seed of [1, 5, 77, 314]) {
      const forward = KINDS.reduce((s, k) => investigate(s, k), launched(DRILL, seed));
      const backward = [...KINDS].reverse().reduce((s, k) => investigate(s, k), launched(DRILL, seed));
      expect(backward.sites).toEqual(forward.sites);

      // A different design must not reroll the scan outcome.
      const scannerOnly = KINDS.reduce((s, k) => investigate(s, k, [{ type: 'scan' }]), launched(SCANNER, seed));
      const drillScan = KINDS.reduce((s, k) => investigate(s, k, [{ type: 'scan' }]), launched(DRILL, seed));
      expect(scannerOnly.sites).toEqual(drillScan.sites);
    }
  });

  it('cannot be rerolled by revisiting a site or repeating scans and samples', () => {
    const seed = findSeed(n => truth(n, 'ice'));
    let s = investigate(launched(DRILL, seed), 'ice');
    const settled = site(s, 'ice');
    expect(settled.finding).toBe('ruled-out');

    s = engine.step(at(s, { x: 0, z: 0 }), { type: 'move', dx: 1, dz: 0 }); // leave
    const science = s.scienceCollected;
    s = investigate(s, 'ice', [{ type: 'scan' }, { type: 'sample' }, { type: 'scan' }, { type: 'sample' }]); // return and retry
    expect(site(s, 'ice')).toEqual(settled);
    expect(s.scienceCollected).toBe(science);
  });

  it('rejects a repeated scan without changing the probable confidence', () => {
    const once = investigate(launched(), 'minerals', [{ type: 'scan' }]);
    const twice = engine.step(once, { type: 'scan' });
    expect(site(twice, 'minerals')).toEqual(site(once, 'minerals'));
    expect(twice.scienceCollected).toBe(once.scienceCollected);
  });

  it('still awards sample science for a ruled-out signal and explains it in the report', () => {
    const seed = findSeed(n => truth(n, 'minerals'));
    const s = investigate(launched(DRILL, seed), 'minerals');
    expect(site(s, 'minerals').finding).toBe('ruled-out');
    expect(s.scienceCollected).toBe(RULES.scanScience + RULES.sampleScience);
    const report = engine.getReport(engine.step(s, { type: 'finish' }));
    expect(report.confirmedSites).toBe(0);
    expect(report.feedback.join(' ')).toMatch(/Ruled out by sample, still useful evidence: Ridge anomaly/);
  });
});

describe('report: confirmedSites and unchanged score', () => {
  function fullMission(seed: number): MissionState {
    let s = launched(DRILL, seed);
    for (const kind of ['minerals', 'ice', 'geology'] as const) {
      s = driveTo(s, site(s, kind), 2);
      s = run(s, [{ type: 'scan' }, { type: 'sample' }]);
      s = driveTo(s, { x: Math.max(s.position.x, RULES.shadeBoundaryX + 0.5), z: s.position.z }, 0.05);
    }
    return run(s, [{ type: 'recharge' }, { type: 'transmit' }, { type: 'deploy' }, { type: 'finish' }]);
  }

  it('counts only confirmed sites, and false positives do not lower the score', () => {
    const allGenuine = findSeed(n => !truth(n, 'ice') && !truth(n, 'minerals'));
    const oneFake = findSeed(n => truth(n, 'ice') && !truth(n, 'minerals'));
    const twoFakes = findSeed(n => truth(n, 'ice') && truth(n, 'minerals'));

    const expected: Array<[number, number]> = [[allGenuine, 3], [oneFake, 2], [twoFakes, 1]];
    for (const [seed, confirmed] of expected) {
      const report = engine.getReport(fullMission(seed));
      expect(report.confirmedSites).toBe(confirmed);
      expect(report).toMatchObject({ score: 100, returnedScience: 120, investigatedSites: 3, outpostOperational: true });
    }
  });

  it('reports zero confirmed sites before any sampling', () => {
    expect(engine.getReport(engine.createMission(DRILL, 1)).confirmedSites).toBe(0);
    expect(engine.getReport(investigate(launched(SCANNER), 'geology')).confirmedSites).toBe(0);
  });
});
