import { describe, expect, it } from 'vitest';
import type { MissionConfig } from '../../shared/types';
import { engine, RULES } from '../index';
import { DRILL, FUEL_DRILL, OVERWEIGHT, SCANNER, withoutLog } from './helpers';

describe('design review', () => {
  it('totals base, component cost and mass for the default design', () => {
    expect(engine.reviewDesign(SCANNER)).toEqual({ cost: 85, budget: 110, mass: 67, massLimit: 100, warnings: [] });
  });

  it('flags over-budget and over-mass designs with the size of the overrun', () => {
    const review = engine.reviewDesign(OVERWEIGHT);
    expect(review.cost).toBe(130);
    expect(review.mass).toBe(112);
    expect(review.warnings).toHaveLength(2);
    expect(review.warnings[0]).toContain('20 credits');
    expect(review.warnings[1]).toContain('12 kg');
  });

  it('allows a design exactly on the budget limit', () => {
    const review = engine.reviewDesign({ battery: 'extended', power: 'fuel-cell', instrument: 'scanner' });
    expect(review.cost).toBe(RULES.budget);
    expect(review.warnings).toEqual([]);
  });

  it('flags a design that is over budget but within mass', () => {
    const review = engine.reviewDesign(FUEL_DRILL);
    expect(review.cost).toBe(115);
    expect(review.mass).toBe(96);
    expect(review.warnings).toHaveLength(1);
  });

  it('rejects unknown components at runtime', () => {
    const bogus = { battery: 'nuclear', power: 'solar', instrument: 'scanner' } as unknown as MissionConfig;
    expect(engine.reviewDesign(bogus).warnings.some(w => w.includes('energy storage'))).toBe(true);
    const state = engine.createMission(bogus, 1);
    expect(state.maxEnergy).toBe(0);
    expect(engine.step(state, { type: 'launch' }).phase).toBe('planning');
  });
});

describe('mission creation and launch', () => {
  it('starts in planning with a full battery sized by the design', () => {
    const compact = engine.createMission(SCANNER, 1);
    expect(compact).toMatchObject({ phase: 'planning', energy: 70, maxEnergy: 70, turns: 0, position: { x: 0, z: 0 } });
    expect(engine.createMission({ ...SCANNER, battery: 'extended' }, 1).maxEnergy).toBe(120);
  });

  it('gives fuel-cell designs finite supplies and solar designs none', () => {
    expect(engine.createMission({ ...SCANNER, power: 'fuel-cell' }, 1).fuelCells).toBe(RULES.fuelCellSupplies);
    expect(engine.createMission(SCANNER, 1).fuelCells).toBe(0);
  });

  it('copies the config so later edits to it cannot change the mission', () => {
    const config = { ...DRILL };
    const state = engine.createMission(config, 1);
    config.instrument = 'scanner';
    expect(state.config.instrument).toBe('drill');
  });

  it('launches a valid design', () => {
    const state = engine.step(engine.createMission(DRILL, 1), { type: 'launch' });
    expect(state.phase).toBe('surface');
  });

  it('blocks launch of an invalid design and changes nothing but the log', () => {
    const planned = engine.createMission(OVERWEIGHT, 1);
    const after = engine.step(planned, { type: 'launch' });
    expect(after.phase).toBe('planning');
    expect(withoutLog(after)).toEqual(withoutLog(planned));
    expect(after.log[0]).toMatch(/Launch blocked/);
  });

  it('rejects a duplicate launch', () => {
    const surface = engine.step(engine.createMission(DRILL, 1), { type: 'launch' });
    const again = engine.step(surface, { type: 'launch' });
    expect(withoutLog(again)).toEqual(withoutLog(surface));
    expect(again.log[0]).toMatch(/already launched/);
  });

  it('rejects surface actions before launch', () => {
    const planned = engine.createMission(DRILL, 1);
    for (const action of [{ type: 'move', dx: 1, dz: 0 }, { type: 'scan' }, { type: 'recharge' }, { type: 'finish' }] as const) {
      const after = engine.step(planned, action);
      expect(withoutLog(after)).toEqual(withoutLog(planned));
    }
  });
});
