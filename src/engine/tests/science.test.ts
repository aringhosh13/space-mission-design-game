import { describe, expect, it } from 'vitest';
import { engine, RULES } from '../index';
import { at, DRILL, launched, run, SCANNER, site, withEnergy, withoutLog } from './helpers';

/** A launched drill mission parked on the (sunlit) minerals site. */
const atMinerals = (config = DRILL) => {
  const s = launched(config);
  return at(s, site(s, 'minerals'));
};

describe('scanning', () => {
  it('requires the rover to be within proximity range', () => {
    const s = launched();
    const target = site(s, 'minerals');
    const outside = at(s, { x: target.x - RULES.proximity - 0.1, z: target.z });
    const after = engine.step(outside, { type: 'scan' });
    expect(withoutLog(after)).toEqual(withoutLog(outside));
    expect(after.log[0]).toMatch(/Move within/);
  });

  it('works at the edge of the proximity range', () => {
    const s = launched();
    const target = site(s, 'minerals');
    const edge = at(s, { x: target.x - RULES.proximity, z: target.z });
    expect(site(engine.step(edge, { type: 'scan' }), 'minerals').scanned).toBe(true);
  });

  it('records evidence, adds science and spends energy', () => {
    const before = atMinerals();
    const s = engine.step(before, { type: 'scan' });
    expect(site(s, 'minerals').scanned).toBe(true);
    expect(s.scienceCollected).toBe(RULES.scanScience);
    expect(s.energy).toBe(before.energy - RULES.scanEnergy);
    expect(s.turns).toBe(before.turns + 1);
  });

  it('never rewards the same scan twice', () => {
    const once = engine.step(atMinerals(), { type: 'scan' });
    const twice = engine.step(once, { type: 'scan' });
    expect(withoutLog(twice)).toEqual(withoutLog(once));
    expect(twice.log[0]).toMatch(/already been scanned/);
  });

  it('records nothing when power is insufficient', () => {
    const low = withEnergy(atMinerals(), RULES.scanEnergy - 1);
    const after = engine.step(low, { type: 'scan' });
    expect(withoutLog(after)).toEqual(withoutLog(low));
  });
});

describe('sampling', () => {
  it('needs a drill', () => {
    const scanned = engine.step(atMinerals(SCANNER), { type: 'scan' });
    const after = engine.step(scanned, { type: 'sample' });
    expect(withoutLog(after)).toEqual(withoutLog(scanned));
    expect(after.log[0]).toMatch(/requires a drill/);
  });

  it('needs the site to be scanned first', () => {
    const before = atMinerals();
    const after = engine.step(before, { type: 'sample' });
    expect(withoutLog(after)).toEqual(withoutLog(before));
    expect(after.log[0]).toMatch(/Scan .* before/);
  });

  it('adds sample science once', () => {
    const scanned = engine.step(atMinerals(), { type: 'scan' });
    const sampled = engine.step(scanned, { type: 'sample' });
    expect(site(sampled, 'minerals').sampled).toBe(true);
    expect(sampled.scienceCollected).toBe(RULES.scanScience + RULES.sampleScience);
    expect(sampled.energy).toBe(scanned.energy - RULES.sampleEnergy);

    const again = engine.step(sampled, { type: 'sample' });
    expect(withoutLog(again)).toEqual(withoutLog(sampled));
    expect(again.log[0]).toMatch(/already analysed/);
  });

  it('caps total science at three sites with no duplicates however often actions repeat', () => {
    let s = launched();
    for (const kind of ['ice', 'minerals', 'geology'] as const) {
      s = at(withEnergy(s, s.maxEnergy), site(s, kind));
      s = run(s, [{ type: 'scan' }, { type: 'scan' }, { type: 'sample' }, { type: 'sample' }, { type: 'scan' }]);
    }
    expect(s.scienceCollected).toBe(3 * (RULES.scanScience + RULES.sampleScience));
    expect(s.sites.every(x => x.scanned && x.sampled)).toBe(true);
  });
});

describe('transmission', () => {
  it('rejects transmitting when nothing new is onboard', () => {
    const before = launched();
    const after = engine.step(before, { type: 'transmit' });
    expect(withoutLog(after)).toEqual(withoutLog(before));
    expect(after.log[0]).toMatch(/No new evidence/);
  });

  it('returns all onboard science once and spends energy', () => {
    const scanned = engine.step(atMinerals(), { type: 'scan' });
    const sent = engine.step(scanned, { type: 'transmit' });
    expect(sent.scienceReturned).toBe(scanned.scienceCollected);
    expect(sent.energy).toBe(scanned.energy - RULES.transmitEnergy);
    const again = engine.step(sent, { type: 'transmit' });
    expect(withoutLog(again)).toEqual(withoutLog(sent));
  });

  it('keeps science onboard when power is insufficient', () => {
    const scanned = withEnergy(engine.step(atMinerals(), { type: 'scan' }), RULES.transmitEnergy - 1);
    const after = engine.step(scanned, { type: 'transmit' });
    expect(after.scienceReturned).toBe(0);
    expect(withoutLog(after)).toEqual(withoutLog(scanned));
  });
});

describe('station deployment', () => {
  it('needs a sunlit site', () => {
    const shaded = at(launched(), { x: -5, z: 0 });
    const after = engine.step(shaded, { type: 'deploy' });
    expect(withoutLog(after)).toEqual(withoutLog(shaded));
    expect(after.log[0]).toMatch(/sunlit/);
  });

  it('deploys once and spends the deployment cost', () => {
    const before = launched();
    const s = engine.step(before, { type: 'deploy' });
    expect(s.outpostDeployed).toBe(true);
    expect(s.energy).toBe(before.energy - RULES.deployEnergy);
    const again = engine.step(s, { type: 'deploy' });
    expect(withoutLog(again)).toEqual(withoutLog(s));
    expect(again.log[0]).toMatch(/already deployed/);
  });

  it('cannot deploy without enough power', () => {
    const low = withEnergy(launched(), RULES.deployEnergy - 1);
    const after = engine.step(low, { type: 'deploy' });
    expect(after.outpostDeployed).toBe(false);
    expect(withoutLog(after)).toEqual(withoutLog(low));
  });
});
