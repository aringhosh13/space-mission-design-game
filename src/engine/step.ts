import type { MissionAction, MissionState, Position, Site } from '../shared/types';
import { reviewDesign } from './design';
import { RULES } from './rules';

const ACTION_TYPES = new Set(['launch', 'move', 'scan', 'sample', 'recharge', 'transmit', 'deploy', 'finish']);

const distance = (a: Position, b: Position) => Math.hypot(a.x - b.x, a.z - b.z);
const clamp = (n: number, min: number, max: number) => Math.max(min, Math.min(max, n));
const round3 = (n: number) => Math.round(n * 1000) / 1000;

/** Runtime guard: the UI is typed, but the engine must not trust malformed input. */
function isAction(action: unknown): action is MissionAction {
  if (!action || typeof action !== 'object') return false;
  const type = (action as { type?: unknown }).type;
  return typeof type === 'string' && ACTION_TYPES.has(type);
}

export function isLit(position: Position): boolean {
  return position.x >= RULES.shadeBoundaryX;
}

/** The single site within proximity range, choosing the closest if several ever overlap. */
export function siteInRange(position: Position, sites: Site[]): Site | undefined {
  let best: Site | undefined;
  let bestDistance = Infinity;
  for (const site of sites) {
    const d = distance(position, site);
    if (d <= RULES.proximity && d < bestDistance) { best = site; bestDistance = d; }
  }
  return best;
}

/** Energy for a move of the given length: whole units, at least 1 for any non-zero move. */
export function moveEnergy(travelled: number): number {
  return Math.max(1, Math.ceil(travelled * RULES.moveEnergyPerUnit - 1e-9));
}

/**
 * Pure transition. The input state is never mutated: a deep copy is taken first and every
 * change is made to the copy. Rejected actions return a copy with an explanatory log line and
 * no resource change. Completed missions are returned unchanged.
 */
export function step(state: MissionState, action: MissionAction): MissionState {
  const s: MissionState = structuredClone(state);
  if (s.phase === 'complete') return s;

  const log = (message: string) => { s.log = [message, ...s.log].slice(0, RULES.maxLogLines); };

  /** Spend energy for a completed action. Returns false (and spends nothing) when power is insufficient. */
  const consume = (amount: number): boolean => {
    if (s.energy < amount) {
      log(`Insufficient power: ${amount} units needed, ${s.energy} available. Recharge or close the mission.`);
      return false;
    }
    s.energy -= amount;
    s.turns += 1;
    return true;
  };

  if (!isAction(action)) { log('Unrecognised command ignored.'); return s; }

  if (action.type === 'launch') {
    if (s.phase !== 'planning') { log('The expedition has already launched.'); return s; }
    const review = reviewDesign(s.config);
    if (review.warnings.length) { log(`Launch blocked. ${review.warnings.join(' ')}`); return s; }
    s.phase = 'surface';
    log('Landing confirmed. Rover ready for surface operations.');
    return s;
  }

  if (s.phase !== 'surface') { log('Launch the expedition before surface operations.'); return s; }

  switch (action.type) {
    case 'move': {
      const { dx, dz } = action;
      if (typeof dx !== 'number' || typeof dz !== 'number' || !Number.isFinite(dx) || !Number.isFinite(dz)) {
        log('Move rejected: direction must be finite numbers.');
        break;
      }
      const length = Math.hypot(dx, dz);
      if (length === 0) { log('Move rejected: no direction given.'); break; }
      const scale = Math.min(1, RULES.maxMoveDistance / length);
      const limit = RULES.mapLimit;
      const next = {
        x: round3(clamp(s.position.x + dx * scale, -limit, limit)),
        z: round3(clamp(s.position.z + dz * scale, -limit, limit))
      };
      const travelled = distance(s.position, next);
      if (travelled < 1e-6) { log('Survey boundary reached.'); break; }
      if (consume(moveEnergy(travelled))) s.position = next;
      break;
    }

    case 'scan': {
      const site = siteInRange(s.position, s.sites);
      if (!site) log(`Move within ${RULES.proximity} m of an orbital signal to scan.`);
      else if (site.scanned) log(`${site.name} has already been scanned. No new evidence.`);
      else if (consume(RULES.scanEnergy)) {
        site.scanned = true;
        s.scienceCollected += RULES.scanScience;
        log(`${site.name}: ${site.kind} evidence recorded. Signal remains unconfirmed.`);
      }
      break;
    }

    case 'sample': {
      const site = siteInRange(s.position, s.sites);
      if (s.config.instrument !== 'drill') log('Sampling requires a drill selected before launch.');
      else if (!site) log(`Move within ${RULES.proximity} m of an orbital signal to sample.`);
      else if (!site.scanned) log(`Scan ${site.name} before taking a sample.`);
      else if (site.sampled) log(`${site.name} sample already analysed. No new evidence.`);
      else if (consume(RULES.sampleEnergy)) {
        site.sampled = true;
        s.scienceCollected += RULES.sampleScience;
        log(`${site.name}: sample analysed. Stronger evidence added to onboard storage.`);
      }
      break;
    }

    case 'recharge': {
      if (s.energy >= s.maxEnergy) log('Battery is already full.');
      else if (s.config.power === 'solar' && !isLit(s.position)) {
        log(`This area is shaded. Move east of x = ${RULES.shadeBoundaryX} to use solar power.`);
      } else if (s.config.power === 'fuel-cell' && s.fuelCells <= 0) log('No fuel cell supplies remain.');
      else {
        if (s.config.power === 'fuel-cell') s.fuelCells -= 1;
        const before = s.energy;
        s.energy = Math.min(s.maxEnergy, s.energy + RULES.rechargeAmount);
        s.turns += 1;
        const source = s.config.power === 'fuel-cell' ? `Fuel cell used (${s.fuelCells} left)` : 'Solar charge';
        log(`${source}: +${s.energy - before} energy.`);
      }
      break;
    }

    case 'transmit': {
      const pending = s.scienceCollected - s.scienceReturned;
      if (pending <= 0) log('No new evidence to transmit.');
      else if (consume(RULES.transmitEnergy)) {
        s.scienceReturned = s.scienceCollected;
        log(`${pending} science units received on Earth.`);
      }
      break;
    }

    case 'deploy': {
      if (s.outpostDeployed) log('Research station is already deployed.');
      else if (!isLit(s.position)) log(`Find a sunlit site east of x = ${RULES.shadeBoundaryX} for the station.`);
      else if (consume(RULES.deployEnergy)) {
        s.outpostDeployed = true;
        log('Research station deployed with a dedicated solar supply.');
      }
      break;
    }

    case 'finish': {
      s.phase = 'complete';
      log('Mission closed. Assessing returned evidence.');
      break;
    }
  }

  return s;
}
