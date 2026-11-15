/** TEMPORARY UI PREVIEW. Fictional rules, no NASA data or validated simulation. */
import { EQUIPMENT } from '../shared/catalog';
import type { MissionEngine, MissionState, Site } from '../shared/types';
const distance = (a: { x: number; z: number }, b: { x: number; z: number }) => Math.hypot(a.x - b.x, a.z - b.z);
export const previewEngine: MissionEngine = {
  reviewDesign(config) {
    const parts = [EQUIPMENT[config.battery], EQUIPMENT[config.power], EQUIPMENT[config.instrument]];
    const cost = 35 + parts.reduce((n, p) => n + p.cost, 0);
    const mass = 30 + parts.reduce((n, p) => n + p.mass, 0);
    const warnings = [];
    if (cost > 110) warnings.push('Over budget. Try a lighter equipment package.');
    if (mass > 100) warnings.push('Over launch mass limit. Remove a heavier component.');
    return { cost, budget: 110, mass, massLimit: 100, warnings };
  },
  createMission(config, seed) {
    const shift = (Math.abs(seed) % 3) - 1;
    const sites: Site[] = [
      { id: 'a', name: 'Shackleton signal', x: -6 + shift, z: -5, kind: 'ice', scanned: false, sampled: false, confidence: 0, finding: 'unconfirmed' },
      { id: 'b', name: 'Ridge anomaly', x: 6, z: -3 + shift, kind: 'minerals', scanned: false, sampled: false, confidence: 0, finding: 'unconfirmed' },
      { id: 'c', name: 'Exposed formation', x: 3 + shift, z: 7, kind: 'geology', scanned: false, sampled: false, confidence: 0, finding: 'unconfirmed' }
    ];
    const capacity = EQUIPMENT[config.battery].capacity;
    return { seed, phase: 'planning', config: { ...config }, position: { x: 0, z: 0 },
      energy: capacity, maxEnergy: capacity, fuelCells: 3, turns: 0,
      scienceCollected: 0, scienceReturned: 0, outpostDeployed: false, outpostPosition: null, sites,
      log: ['Orbital survey received. Three unconfirmed signals await investigation.'] };
  },
  step(original, action) {
    const s: MissionState = structuredClone(original);
    const log = (message: string) => { s.log = [message, ...s.log].slice(0, 8); };
    if (s.phase === 'complete') return s;
    if (action.type === 'launch') {
      if (s.phase !== 'planning' || this.reviewDesign(s.config).warnings.length) return s;
      s.phase = 'surface'; log('Landing confirmed. Rover ready for surface operations.'); return s;
    }
    if (s.phase !== 'surface') return s;
    if (action.type === 'finish') { s.phase = 'complete'; log('Mission closed. Assessing returned evidence.'); return s; }
    const consume = (amount: number) => {
      if (s.energy < amount) { log('Insufficient power. Recharge or close the mission.'); return false; }
      s.energy -= amount; s.turns++; return true;
    };
    const nearest = s.sites.find(site => distance(s.position, site) <= 2.5);
    switch (action.type) {
      case 'move': {
        if (!Number.isFinite(action.dx) || !Number.isFinite(action.dz)) return s;
        const length = Math.hypot(action.dx, action.dz);
        if (length === 0) return s;
        const next = { x: Math.max(-10, Math.min(10, s.position.x + action.dx / length)), z: Math.max(-10, Math.min(10, s.position.z + action.dz / length)) };
        if (distance(next, s.position) < 0.01) { log('Survey boundary reached.'); return s; }
        if (consume(2)) s.position = next;
        break;
      }
      case 'scan':
        if (!nearest) log('Move within 2.5 m of an orbital signal.');
        else if (nearest.scanned) log('This signal has already been scanned.');
        else if (consume(8)) { nearest.scanned = true; s.scienceCollected += 15; log(`${nearest.name}: ${nearest.kind} evidence recorded. Signal remains unconfirmed.`); }
        break;
      case 'sample':
        if (s.config.instrument !== 'drill') log('Sampling requires a drill selected before launch.');
        else if (!nearest?.scanned) log('Scan a nearby signal before taking a sample.');
        else if (nearest.sampled) log('Sample already analysed.');
        else if (consume(15)) { nearest.sampled = true; s.scienceCollected += 25; log('Sample analysed. Stronger evidence added to onboard storage.'); }
        break;
      case 'recharge':
        if (s.config.power === 'solar' && s.position.x < -3) log('This area is shaded. Move east of x = -3 to use solar power.');
        else if (s.config.power === 'fuel-cell' && s.fuelCells === 0) log('No fuel cell supplies remain.');
        else if (s.energy === s.maxEnergy) log('Battery is already full.');
        else { if (s.config.power === 'fuel-cell') s.fuelCells--; s.energy = Math.min(s.maxEnergy, s.energy + 35); s.turns++; log('Energy restored by up to 35 units.'); }
        break;
      case 'transmit':
        if (s.scienceCollected === s.scienceReturned) log('No new evidence to transmit.');
        else if (consume(5)) { s.scienceReturned = s.scienceCollected; log('Evidence received on Earth.'); }
        break;
      case 'deploy':
        if (s.outpostDeployed) log('Research station is already deployed.');
        else if (s.position.x < -3) log('Find a sunlit site east of x = -3 for the station.');
        else if (consume(20)) { s.outpostDeployed = true; log('Research station deployed with a dedicated solar supply.'); }
        break;
    }
    return s;
  },
  getReport(s) {
    return { score: Math.round(Math.min(100, s.scienceReturned / 120 * 70 + (s.outpostDeployed ? 30 : 0))),
      returnedScience: s.scienceReturned, investigatedSites: s.sites.filter(p => p.scanned).length, confirmedSites: 0,
      outpostOperational: s.outpostDeployed,
      feedback: [s.scienceCollected > s.scienceReturned ? 'Some collected evidence was never transmitted.' : 'All collected evidence was returned to Earth.',
        s.outpostDeployed ? 'A powered research station was established.' : 'No research station was established.',
        'Preview scoring only. Scientific confidence, communication windows and efficiency are planned engine work.'] };
  }
};
