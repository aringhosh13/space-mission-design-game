import type { MissionConfig } from './types';
export const DEFAULT_CONFIG: MissionConfig = { battery: 'compact', power: 'solar', instrument: 'scanner' };
/** Fictional balancing values, not specifications of real flight hardware. */
export const EQUIPMENT = {
  compact: { label: 'Compact battery', cost: 15, mass: 12, capacity: 70 },
  extended: { label: 'Extended battery', cost: 30, mass: 28, capacity: 120 },
  solar: { label: 'Solar array', cost: 20, mass: 15 },
  'fuel-cell': { label: 'Fuel cell pack', cost: 30, mass: 24 },
  scanner: { label: 'Surface scanner', cost: 15, mass: 10 },
  drill: { label: 'Scanner + sample drill', cost: 35, mass: 30 }
} as const;
