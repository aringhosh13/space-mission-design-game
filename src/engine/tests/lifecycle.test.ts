import { describe, expect, it } from 'vitest';
import type { MissionAction, MissionState } from '../../shared/types';
import { engine, RULES } from '../index';
import { generateSites } from '../mission';
import { at, deepFreeze, DRILL, driveTo, launched, run, SCANNER, site, withEnergy } from './helpers';

const ALL_ACTIONS: MissionAction[] = [
  { type: 'launch' }, { type: 'move', dx: 1, dz: 0 }, { type: 'move', dx: Number.NaN, dz: 0 },
  { type: 'scan' }, { type: 'sample' }, { type: 'recharge' }, { type: 'transmit' }, { type: 'deploy' }, { type: 'finish' }
];

/** One state per phase plus some mid-mission states, used to check every action against each. */
function sampleStates(): MissionState[] {
  const surface = launched();
  const scanned = engine.step(at(surface, site(surface, 'minerals')), { type: 'scan' });
  return [
    engine.createMission(DRILL, 3),
    surface,
    scanned,
    withEnergy(scanned, 10),
    engine.step(scanned, { type: 'finish' })
  ];
}

describe('immutability', () => {
  it('never mutates the input state for any action in any phase', () => {
    for (const state of sampleStates()) {
      const snapshot = structuredClone(state);
      const frozen = deepFreeze(structuredClone(state));
      for (const action of ALL_ACTIONS) {
        const next = engine.step(frozen, action);
        expect(next).not.toBe(frozen);
        expect(frozen).toEqual(snapshot);
      }
    }
  });

  it('does not share nested objects between input and output', () => {
    const before = launched();
    const after = engine.step(before, { type: 'move', dx: 1, dz: 0 });
    expect(after.position).not.toBe(before.position);
    expect(after.sites).not.toBe(before.sites);
    expect(after.sites[0]).not.toBe(before.sites[0]);
    expect(after.log).not.toBe(before.log);
  });

  it('ignores unrecognised commands', () => {
    const before = launched();
    const after = engine.step(before, { type: 'teleport' } as unknown as MissionAction);
    expect({ ...after, log: [] }).toEqual({ ...before, log: [] });
    expect(after.log[0]).toMatch(/Unrecognised/);
  });

  it('keeps the log bounded', () => {
    const s = run(launched(), Array.from({ length: 20 }, () => ({ type: 'transmit' as const })));
    expect(s.log).toHaveLength(RULES.maxLogLines);
  });
});

describe('mission completion', () => {
  it('closes the mission and then refuses every further change', () => {
    const done = engine.step(launched(), { type: 'finish' });
    expect(done.phase).toBe('complete');
    for (const action of ALL_ACTIONS) expect(engine.step(done, action)).toEqual(done);
  });

  it('cannot be finished before launch', () => {
    expect(engine.step(engine.createMission(DRILL, 1), { type: 'finish' }).phase).toBe('planning');
  });

  it('reports untransmitted science as lost', () => {
    let s = launched(SCANNER);
    s = engine.step(at(s, site(s, 'minerals')), { type: 'scan' });
    const report = engine.getReport(engine.step(s, { type: 'finish' }));
    expect(report.returnedScience).toBe(0);
    expect(report.investigatedSites).toBe(1);
    expect(report.score).toBe(0);
    expect(report.feedback.join(' ')).toMatch(/15 science units were collected but never transmitted, and were lost/);
    expect(report.feedback.join(' ')).toMatch(/Without a drill/);
  });

  it('marks a report for an unfinished mission as provisional', () => {
    expect(engine.getReport(launched()).feedback[0]).toMatch(/provisional/);
    expect(engine.getReport(engine.createMission(DRILL, 1)).feedback[0]).toMatch(/never launched/);
  });

  it('plays a full mission with real moves and earns the maximum score', () => {
    let s = launched(DRILL, 42);
    for (const kind of ['minerals', 'ice', 'geology'] as const) {
      s = driveTo(s, site(s, kind), 2);
      s = run(s, [{ type: 'scan' }, { type: 'sample' }]);
      expect(site(s, kind).sampled).toBe(true);
      // Return to sunlight before the next leg so the solar battery can be topped up.
      s = driveTo(s, { x: Math.max(s.position.x, RULES.shadeBoundaryX + 0.5), z: s.position.z }, 0.05);
    }
    s = run(s, [{ type: 'recharge' }, { type: 'transmit' }, { type: 'deploy' }, { type: 'finish' }]);

    const report = engine.getReport(s);
    expect(s.phase).toBe('complete');
    expect(report).toMatchObject({ score: 100, returnedScience: 120, investigatedSites: 3, outpostOperational: true });
    expect(report.feedback.join(' ')).toMatch(/All collected evidence was returned/);
  });

  it('scores returned science and the station separately', () => {
    let s = launched(SCANNER);
    s = engine.step(at(s, site(s, 'minerals')), { type: 'scan' });
    s = run(s, [{ type: 'transmit' }, { type: 'deploy' }, { type: 'finish' }]);
    // 15 of 120 science → 8.75 points, plus 30 for the station.
    expect(engine.getReport(s).score).toBe(39);
  });
});

describe('seeded reproducibility', () => {
  const script: MissionAction[] = [
    { type: 'launch' }, ...Array.from({ length: 6 }, () => ({ type: 'move' as const, dx: 1, dz: -0.5 })),
    { type: 'scan' }, { type: 'sample' }, { type: 'transmit' }, { type: 'recharge' }, { type: 'deploy' }, { type: 'finish' }
  ];

  it('replays a seed and action sequence to an identical state', () => {
    const a = run(engine.createMission(DRILL, 2026), script);
    const b = run(engine.createMission(DRILL, 2026), script);
    expect(a).toEqual(b);
    expect(engine.getReport(a)).toEqual(engine.getReport(b));
  });

  it('places sites differently for different seeds', () => {
    expect(generateSites(1)).not.toEqual(generateSites(2));
  });

  it('normalises seeds to integers', () => {
    expect(engine.createMission(DRILL, 3.7).seed).toBe(3);
    expect(engine.createMission(DRILL, Number.NaN).seed).toBe(0);
  });

  it('always generates playable site layouts', () => {
    for (let seed = -500; seed < 1500; seed++) {
      const sites = generateSites(seed);
      expect(sites).toHaveLength(3);
      for (const s of sites) {
        expect(Math.abs(s.x)).toBeLessThanOrEqual(RULES.mapLimit);
        expect(Math.abs(s.z)).toBeLessThanOrEqual(RULES.mapLimit);
        expect(Math.hypot(s.x, s.z)).toBeGreaterThan(RULES.proximity);
      }
      expect(sites.find(s => s.kind === 'ice')!.x).toBeLessThan(RULES.shadeBoundaryX);
      for (let i = 0; i < sites.length; i++) {
        for (let j = i + 1; j < sites.length; j++) {
          expect(Math.hypot(sites[i].x - sites[j].x, sites[i].z - sites[j].z)).toBeGreaterThan(2 * RULES.proximity);
        }
      }
    }
  });
});
