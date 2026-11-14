import { EQUIPMENT } from '../shared/catalog';
import type { DesignReview, MissionConfig } from '../shared/types';
import { RULES } from './rules';

const SLOTS = {
  battery: ['compact', 'extended'],
  power: ['solar', 'fuel-cell'],
  instrument: ['scanner', 'drill']
} as const satisfies { [K in keyof MissionConfig]: readonly MissionConfig[K][] };

type Slot = keyof typeof SLOTS;
const SLOT_NAMES: Record<Slot, string> = { battery: 'energy storage', power: 'power source', instrument: 'science payload' };

/** True when every slot holds a recognised catalogue component. Guards against malformed runtime input. */
export function isKnownConfig(config: MissionConfig | null | undefined): config is MissionConfig {
  if (!config || typeof config !== 'object') return false;
  return (Object.keys(SLOTS) as Slot[]).every(slot => (SLOTS[slot] as readonly string[]).includes(config[slot]));
}

export function reviewDesign(config: MissionConfig): DesignReview {
  const warnings: string[] = [];
  let cost = RULES.baseCost;
  let mass = RULES.baseMass;

  for (const slot of Object.keys(SLOTS) as Slot[]) {
    const choice = config?.[slot];
    if (!(SLOTS[slot] as readonly string[]).includes(choice as string)) {
      warnings.push(`Choose a valid ${SLOT_NAMES[slot]} before launch.`);
      continue;
    }
    const part = EQUIPMENT[choice as keyof typeof EQUIPMENT];
    cost += part.cost;
    mass += part.mass;
  }

  if (cost > RULES.budget) {
    warnings.push(`Over budget by ${cost - RULES.budget} credits. Try a lighter equipment package.`);
  }
  if (mass > RULES.massLimit) {
    warnings.push(`Over launch mass limit by ${mass - RULES.massLimit} kg. Remove a heavier component.`);
  }

  return { cost, budget: RULES.budget, mass, massLimit: RULES.massLimit, warnings };
}

export function batteryCapacity(config: MissionConfig): number {
  return isKnownConfig(config) ? EQUIPMENT[config.battery].capacity : 0;
}
