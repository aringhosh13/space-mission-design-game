import type { MissionAction, MissionConfig, MissionState, Position, SiteKind } from '../../shared/types';
import { engine } from '../index';

export const SCANNER: MissionConfig = { battery: 'compact', power: 'solar', instrument: 'scanner' };
export const DRILL: MissionConfig = { battery: 'compact', power: 'solar', instrument: 'drill' };
export const FUEL_DRILL: MissionConfig = { battery: 'compact', power: 'fuel-cell', instrument: 'drill' };
export const OVERWEIGHT: MissionConfig = { battery: 'extended', power: 'fuel-cell', instrument: 'drill' };

export function launched(config: MissionConfig = DRILL, seed = 42): MissionState {
  const state = engine.step(engine.createMission(config, seed), { type: 'launch' });
  if (state.phase !== 'surface') throw new Error('test setup: launch failed');
  return state;
}

/** Return a copy with a different rover position (step is pure, so tests may build states directly). */
export const at = (state: MissionState, position: Position): MissionState => ({ ...state, position: { ...position } });
export const withEnergy = (state: MissionState, energy: number): MissionState => ({ ...state, energy });
export const site = (state: MissionState, kind: SiteKind) => state.sites.find(s => s.kind === kind)!;

export function run(state: MissionState, actions: MissionAction[]): MissionState {
  return actions.reduce((s, a) => engine.step(s, a), state);
}

/** Everything except the log, for asserting that a rejected action changed nothing else. */
export function withoutLog(state: MissionState) {
  const { log: _log, ...rest } = state;
  return rest;
}

export function deepFreeze<T>(value: T): T {
  if (value && typeof value === 'object' && !Object.isFrozen(value)) {
    Object.freeze(value);
    for (const key of Object.keys(value)) deepFreeze((value as Record<string, unknown>)[key]);
  }
  return value;
}

/**
 * Simple autopilot used by end-to-end tests: drives with real unit moves, topping the battery up
 * whenever it stands in sunlight (solar design), until within `within` of the target.
 */
export function driveTo(start: MissionState, target: Position, within = 0.5): MissionState {
  let s = start;
  for (let guard = 0; guard < 500; guard++) {
    const dx = target.x - s.position.x;
    const dz = target.z - s.position.z;
    if (Math.hypot(dx, dz) <= within) return s;
    while (s.config.power === 'solar' && s.position.x >= -3 && s.energy < s.maxEnergy) s = engine.step(s, { type: 'recharge' });
    const next = engine.step(s, { type: 'move', dx, dz });
    if (next.position.x === s.position.x && next.position.z === s.position.z) throw new Error(`stuck: ${next.log[0]}`);
    s = next;
  }
  throw new Error('autopilot did not arrive');
}
