import { describe, expect, it } from 'vitest';
import type { MissionAction } from '../../shared/types';
import { engine, RULES } from '../index';
import { createRandom } from '../random';
import { at, launched, SCANNER, withEnergy, withoutLog } from './helpers';

describe('movement', () => {
  it('moves one unit and spends movement energy', () => {
    const s = engine.step(launched(), { type: 'move', dx: 1, dz: 0 });
    expect(s.position).toEqual({ x: 1, z: 0 });
    expect(s.energy).toBe(70 - 2);
    expect(s.turns).toBe(1);
  });

  it('limits a commanded move to one map unit', () => {
    const s = engine.step(launched(), { type: 'move', dx: 5, dz: 0 });
    expect(s.position).toEqual({ x: 1, z: 0 });
    const diagonal = engine.step(launched(), { type: 'move', dx: 3, dz: 3 });
    expect(Math.hypot(diagonal.position.x, diagonal.position.z)).toBeLessThanOrEqual(1.001);
    expect(diagonal.energy).toBe(68);
  });

  it('charges short moves proportionally, at least one unit', () => {
    const s = engine.step(launched(), { type: 'move', dx: 0.25, dz: 0 });
    expect(s.position).toEqual({ x: 0.25, z: 0 });
    expect(s.energy).toBe(69);
  });

  it.each([
    { dx: Number.NaN, dz: 0 },
    { dx: Number.POSITIVE_INFINITY, dz: 0 },
    { dx: 0, dz: Number.NEGATIVE_INFINITY },
    { dx: 0, dz: 0 }
  ])('rejects invalid move %o without spending energy', move => {
    const before = launched();
    const after = engine.step(before, { type: 'move', ...move });
    expect(withoutLog(after)).toEqual(withoutLog(before));
    expect(after.log[0]).toMatch(/Move rejected/);
  });

  it('stops at the map boundary without charging for a blocked move', () => {
    const edge = at(launched(), { x: RULES.mapLimit, z: 0 });
    const blocked = engine.step(edge, { type: 'move', dx: 1, dz: 0 });
    expect(withoutLog(blocked)).toEqual(withoutLog(edge));
    expect(blocked.log[0]).toMatch(/boundary/);
  });

  it('clamps a partial move at the boundary and charges only the distance travelled', () => {
    const near = at(launched(), { x: 9.5, z: -10 });
    const s = engine.step(near, { type: 'move', dx: 1, dz: -1 });
    expect(s.position).toEqual({ x: 10, z: -10 });
    expect(s.energy).toBe(69);
  });

  it('refuses to move without enough power', () => {
    const low = withEnergy(launched(), 1);
    const s = engine.step(low, { type: 'move', dx: 1, dz: 0 });
    expect(withoutLog(s)).toEqual(withoutLog(low));
    expect(s.log[0]).toMatch(/Insufficient power/);
  });

  it('keeps the rover in bounds and energy a non-negative integer over a long seeded random walk', () => {
    const random = createRandom(7);
    let s = launched(SCANNER, 7);
    for (let i = 0; i < 1000; i++) {
      const roll = random();
      const action: MissionAction = roll < 0.1 ? { type: 'recharge' }
        : roll < 0.15 ? { type: 'scan' }
        : { type: 'move', dx: random() * 4 - 2, dz: random() * 4 - 2 };
      s = engine.step(s, action);
      expect(Math.abs(s.position.x)).toBeLessThanOrEqual(RULES.mapLimit);
      expect(Math.abs(s.position.z)).toBeLessThanOrEqual(RULES.mapLimit);
      expect(s.energy).toBeGreaterThanOrEqual(0);
      expect(s.energy).toBeLessThanOrEqual(s.maxEnergy);
      expect(Number.isInteger(s.energy)).toBe(true);
    }
  });
});

describe('recharging', () => {
  it('refuses solar charging in the shaded zone', () => {
    const shaded = withEnergy(at(launched(), { x: -3.1, z: 0 }), 20);
    const s = engine.step(shaded, { type: 'recharge' });
    expect(withoutLog(s)).toEqual(withoutLog(shaded));
    expect(s.log[0]).toMatch(/shaded/);
  });

  it('allows solar charging on the shade boundary and caps at battery capacity', () => {
    const lit = withEnergy(at(launched(), { x: -3, z: 0 }), 60);
    const s = engine.step(lit, { type: 'recharge' });
    expect(s.energy).toBe(70);
    expect(s.turns).toBe(lit.turns + 1);
  });

  it('adds the recharge amount when there is room', () => {
    const s = engine.step(withEnergy(launched(), 10), { type: 'recharge' });
    expect(s.energy).toBe(10 + RULES.rechargeAmount);
  });

  it('does not recharge or spend a fuel cell when the battery is full', () => {
    const full = launched({ ...SCANNER, power: 'fuel-cell' });
    const s = engine.step(full, { type: 'recharge' });
    expect(withoutLog(s)).toEqual(withoutLog(full));
    expect(s.log[0]).toMatch(/already full/);
  });

  it('uses finite fuel-cell supplies, which also work in shade', () => {
    let s = at(launched({ ...SCANNER, power: 'fuel-cell' }), { x: -8, z: 0 });
    for (let used = 1; used <= RULES.fuelCellSupplies; used++) {
      s = engine.step(withEnergy(s, 0), { type: 'recharge' });
      expect(s.energy).toBe(RULES.rechargeAmount);
      expect(s.fuelCells).toBe(RULES.fuelCellSupplies - used);
    }
    const empty = withEnergy(s, 0);
    const after = engine.step(empty, { type: 'recharge' });
    expect(withoutLog(after)).toEqual(withoutLog(empty));
    expect(after.log[0]).toMatch(/No fuel cell/);
  });

  it('never consumes fuel cells on a solar design', () => {
    let s = launched();
    for (let i = 0; i < 5; i++) s = engine.step(withEnergy(s, 0), { type: 'recharge' });
    expect(s.fuelCells).toBe(0);
    expect(s.energy).toBe(RULES.rechargeAmount);
  });
});
