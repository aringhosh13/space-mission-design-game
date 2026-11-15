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

  describe('rounding regression (PR #1 review)', () => {
    it('angled move { dx: 1, dz: 1.5 } stays within one unit and costs 2', () => {
      const s = engine.step(launched(), { type: 'move', dx: 1, dz: 1.5 });
      expect(s.position).toEqual({ x: 0.554, z: 0.832 });
      expect(Math.hypot(s.position.x, s.position.z)).toBeLessThanOrEqual(1);
      expect(s.energy).toBe(70 - 2);
    });

    it('a rover with exactly 2 energy can make that angled move', () => {
      const s = engine.step(withEnergy(launched(), 2), { type: 'move', dx: 1, dz: 1.5 });
      expect(s.position).toEqual({ x: 0.554, z: 0.832 });
      expect(s.energy).toBe(0);
      expect(s.turns).toBe(1);
    });

    it('never exceeds one unit or 2 energy for a full move in any direction, from grid and off-integer starts', () => {
      const starts = [{ x: 0, z: 0 }, { x: 2.3, z: -4.7 }, { x: -6.123, z: 3.457 }, { x: 0.555, z: 0.832 }];
      for (const start of starts) {
        for (let deg = 0; deg < 360; deg += 0.5) {
          const rad = (deg * Math.PI) / 180;
          for (const magnitude of [1, 1.8, 25]) {
            const before = withEnergy(at(launched(), start), 2);
            const after = engine.step(before, { type: 'move', dx: Math.cos(rad) * magnitude, dz: Math.sin(rad) * magnitude });
            const moved = Math.hypot(after.position.x - start.x, after.position.z - start.z);
            expect(moved).toBeLessThanOrEqual(1 + 1e-9);
            expect(moved).toBeGreaterThan(0.998);
            expect(after.energy).toBe(0);
          }
        }
      }
    });

    it('keeps axis-aligned unit moves exact from non-integer positions (no 0.999 drift)', () => {
      let s = at(launched(), { x: 2.3, z: -4.7 });
      for (let i = 0; i < 5; i++) s = engine.step(s, { type: 'move', dx: 1, dz: 0 });
      s = engine.step(s, { type: 'move', dx: 0, dz: 1 });
      expect(s.position).toEqual({ x: 7.3, z: -3.7 });
      expect(s.energy).toBe(70 - 12);
    });

    it('charges an angled move clipped by the map edge only for the distance travelled', () => {
      const near = at(launched(), { x: 9.8, z: 0 });
      const s = engine.step(near, { type: 'move', dx: 1, dz: 1 });
      expect(s.position).toEqual({ x: 10, z: 0.707 });
      expect(s.energy).toBe(70 - 2); // travelled ≈ 0.735 → ceil(1.47) = 2

      const corner = at(launched(), { x: 9.7, z: 9.9 });
      const c = engine.step(corner, { type: 'move', dx: 1, dz: 1 });
      expect(c.position).toEqual({ x: 10, z: 10 });
      expect(c.energy).toBe(70 - 1); // travelled ≈ 0.316 → 1
    });

    it('rejects a move smaller than the position resolution without spending energy', () => {
      const before = launched();
      const after = engine.step(before, { type: 'move', dx: 0.0004, dz: 0 });
      expect(withoutLog(after)).toEqual(withoutLog(before));
      expect(after.log[0]).toMatch(/resolution/);
    });
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
