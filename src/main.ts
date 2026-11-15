import './style.css';
import './ui/findings.css';
import { engine } from './engine';
import { DEFAULT_CONFIG } from './shared/catalog';
import type { MissionAction, MissionConfig } from './shared/types';
import { FINDING_LABELS } from './ui/findings';
import { createWorld } from './ui/world';

let config = { ...DEFAULT_CONFIG };
let seed = 42;
let state = engine.createMission(config, seed);
const app = document.querySelector<HTMLDivElement>('#app')!;
app.innerHTML = `
  <header>
    <a class="brand" href="./"><span class="brand-icon">◒</span> BLUE HORIZON</a>
    <div class="header-detail">LUNAR EXPEDITION / 001</div>
    <span class="status"><i></i> MISSION CONTROL</span>
  </header>
  <main>
    <section class="intro">
      <div><p class="eyebrow">EXPLORE WITH PURPOSE</p><h1>A foothold in the unknown.</h1>
      <p>Build your expedition. Follow the evidence. Make every watt count.</p></div>
      <span class="prototype">LUNAR SURVEY<br><b>Fictional simulation · v0.2</b></span>
    </section>
    <div class="workspace">
      <aside id="planning"></aside>
      <section class="surface">
        <div class="map-heading"><div><span class="eyebrow">SURFACE OPERATIONS</span>
          <h2>South polar survey</h2></div><span id="phase"></span></div>
        <div id="world"><div class="map-tag">SHADED TERRAIN <span>← WEST</span></div>
          <div class="legend"><span>◯ Orbital clue</span><span>◯ Preliminary</span><span>◯ Confirmed</span><span>◯ Ruled out</span></div></div>
        <div class="navigation">
          <div class="direction-pad">
            <button data-move="0,-1" aria-label="Move north">↑</button>
            <button data-move="-1,0" aria-label="Move west">←</button>
            <button data-move="0,1" aria-label="Move south">↓</button>
            <button data-move="1,0" aria-label="Move east">→</button>
          </div><span>WASD / arrow keys <b id="coordinates"></b></span>
        </div>
        <div id="nearby" class="nearby" role="status"></div>
        <div id="actions"></div>
        <div class="survey-heading"><p class="eyebrow">ORBITAL SIGNALS / FIELD FINDINGS</p>
          <p>Confidence describes certainty in the current finding. A ruled-out signal is useful science too.</p></div>
        <div id="findings" class="findings"></div>
      </section>
      <aside id="telemetry"></aside>
    </div>
    <section id="report" hidden></section>
    <footer>EDUCATIONAL PROTOTYPE · Equipment values, confidence and terrain are illustrative. NASA data integration is pending.</footer>
  </main>`;

let world: ReturnType<typeof createWorld> | undefined;
try {
  world = createWorld(document.querySelector('#world')!, (dx, dz) => {
    if (state.phase === 'surface') dispatch({ type: 'move', dx, dz });
  });
} catch {
  document.querySelector('#world')!.insertAdjacentHTML('beforeend',
    '<p class="graphics-error">3D graphics are unavailable in this browser. Movement and mission controls below remain usable.</p>');
}

function dispatch(action: MissionAction) {
  state = engine.step(state, action);
  render();
}

const escape = (s: string) => s.replace(/[&<>"']/g,
  c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]!));

function select(name: keyof MissionConfig, label: string, options: [string, string][]) {
  return `<label>${label}<select name="${name}" ${state.phase !== 'planning' ? 'disabled' : ''}>
    ${options.map(([value, text]) => `<option value="${value}" ${config[name] === value ? 'selected' : ''}>${text}</option>`).join('')}
  </select></label>`;
}

function render() {
  const review = engine.reviewDesign(config);
  const active = state.phase === 'surface';
  document.querySelector('#planning')!.innerHTML = `
    <p class="eyebrow">01 / EXPEDITION DESIGN</p><h2>Your mission, your trade-offs.</h2>
    <p class="muted">Choose a package before deploying your rover.</p>
    ${select('battery', 'ENERGY STORAGE', [['compact', 'Compact battery · 70 units'], ['extended', 'Extended battery · 120 units']])}
    ${select('power', 'POWER SOURCE', [['solar', 'Solar array · sunlight required'], ['fuel-cell', 'Fuel cells · 3 refills']])}
    ${select('instrument', 'SCIENCE PAYLOAD', [['scanner', 'Surface scanner'], ['drill', 'Scanner + sample drill']])}
    <div class="design-total"><span>Budget</span><b>${review.cost} / ${review.budget} credits</b></div>
    <div class="design-total"><span>Launch mass</span><b>${review.mass} / ${review.massLimit} kg</b></div>
    ${review.warnings.map(w => `<p class="warning">${escape(w)}</p>`).join('')}
    <button class="primary" id="launch" ${state.phase !== 'planning' || review.warnings.length ? 'disabled' : ''}>
      ${state.phase === 'planning' ? 'Launch expedition ↗' : 'Expedition launched ✓'}</button>
    <button class="secondary" id="restart">New expedition</button>
    <div class="mission-brief"><p class="eyebrow">YOUR OBJECTIVE</p>
      <p>Investigate the orbital clues, return evidence to Earth, and establish a powered research station.</p>
      <small>Move within 2.5 m of a signal to scan it. A drill can confirm or rule it out. Transmit your evidence before ending the mission.</small>
    </div>`;
  document.querySelectorAll<HTMLSelectElement>('select').forEach(el => el.addEventListener('change', () => {
    config = { ...config, [el.name]: el.value };
    state = engine.createMission(config, seed);
    render();
  }));
  document.querySelector('#launch')!.addEventListener('click', () => dispatch({ type: 'launch' }));
  document.querySelector('#restart')!.addEventListener('click', () => {
    seed++;
    state = engine.createMission(config, seed);
    render();
  });
  document.querySelector('#phase')!.textContent = state.phase === 'planning' ? 'AWAITING LAUNCH'
    : state.phase === 'complete' ? 'MISSION CLOSED' : 'ROVER CONNECTED';
  document.querySelector('#coordinates')!.textContent = `X ${state.position.x.toFixed(1)} / Z ${state.position.z.toFixed(1)}`;
  document.querySelectorAll<HTMLButtonElement>('[data-move]').forEach(button => { button.disabled = !active; });

  const distances = state.sites.map(site => ({ site, distance: Math.hypot(site.x - state.position.x, site.z - state.position.z) }))
    .sort((a, b) => a.distance - b.distance);
  const nearest = distances[0];
  // Display hint from contract v2's 2.5-unit convention. The engine decides action eligibility.
  document.querySelector('#nearby')!.textContent = !active ? state.phase === 'complete' ? 'Mission closed. Review your findings below.' : 'Launch to begin exploring.'
    : nearest && nearest.distance <= 2.5 ? `In range: ${nearest.site.name} · ${nearest.distance.toFixed(1)} m`
      : nearest ? `Nearest signal: ${nearest.site.name} · ${nearest.distance.toFixed(1)} m. Move within 2.5 m to investigate.`
        : 'No orbital signals in this survey.';
  document.querySelector('#actions')!.innerHTML = ([
    ['scan', '⌖', 'Scan signal'], ['sample', '◇', 'Analyse sample'], ['recharge', '↯', 'Restore power'],
    ['transmit', '↗', 'Transmit data'], ['deploy', '⊞', 'Deploy station'], ['finish', '✓', 'End mission']
  ] as const).map(([action, icon, label]) => `<button data-action="${action}" ${!active ? 'disabled' : ''}>
    <span>${icon}</span>${label}</button>`).join('');

  document.querySelector('#findings')!.innerHTML = state.sites.map(site => {
    const distance = Math.hypot(site.x - state.position.x, site.z - state.position.z);
    return `<article class="finding-card" data-finding="${site.finding}" data-site="${escape(site.id)}">
      <div class="finding-title"><h3>${escape(site.name)}</h3><span>${site.id.toUpperCase()}</span></div>
      <p class="finding-state">${FINDING_LABELS[site.finding]}</p>
      <div class="confidence-value"><span>Confidence in this finding</span><b>${site.confidence}%</b></div>
      <meter min="0" max="100" value="${site.confidence}" aria-label="${escape(site.name)} finding confidence">${site.confidence}%</meter>
      <p class="site-location">X ${site.x.toFixed(1)} / Z ${site.z.toFixed(1)} · ${distance.toFixed(1)} m away</p>
      <p class="site-stage">${site.sampled ? 'Sample analysed' : site.scanned ? config.instrument === 'drill' ? 'Ready for a sample' : 'A drill is needed to settle this signal' : 'Scan to investigate this orbital clue'}</p>
    </article>`;
  }).join('');

  const stationPosition = state.outpostPosition;
  document.querySelector('#telemetry')!.innerHTML = `
    <p class="eyebrow">02 / LIVE TELEMETRY</p>
    <div class="energy"><span>ROVER POWER</span><strong>${state.energy}<small> / ${state.maxEnergy}</small></strong>
      <meter min="0" max="${state.maxEnergy}" value="${state.energy}" aria-label="Rover power">${state.energy}</meter></div>
    <div class="metrics">
      <div><span>DATA ONBOARD</span><b>${state.scienceCollected - state.scienceReturned}<small> units</small></b></div>
      <div><span>DATA RETURNED</span><b>${state.scienceReturned}<small> units</small></b></div>
      <div><span>MISSION ACTIONS</span><b>${state.turns}</b></div>
      <div><span>RESEARCH STATION</span><b class="station-status">${state.outpostDeployed ? 'Operational' : 'Not deployed'}</b>
        ${stationPosition ? `<small>X ${stationPosition.x.toFixed(1)} / Z ${stationPosition.z.toFixed(1)}</small>` : ''}</div>
      ${config.power === 'fuel-cell' ? `<div><span>FUEL CELL SUPPLIES</span><b>${state.fuelCells}</b></div>` : ''}
    </div>
    <p class="eyebrow log-title">MISSION LOG</p><div class="log" aria-live="polite">
      ${state.log.map(line => `<p>${escape(line)}</p>`).join('')}</div>`;

  const report = document.querySelector<HTMLElement>('#report')!;
  report.hidden = state.phase !== 'complete';
  if (!report.hidden) {
    const result = engine.getReport(state);
    report.innerHTML = `<p class="eyebrow">EXPEDITION DEBRIEF</p><h2>${result.score}<span> / 100 mission score</span></h2>
      <p>${result.returnedScience} science returned · ${result.investigatedSites} signals investigated · ${result.confirmedSites} findings confirmed by sample</p>
      <p class="muted">Finding counts include onboard investigations. Only transmitted science contributes to the science score.</p>
      ${result.feedback.map(line => `<p class="muted">${escape(line)}</p>`).join('')}`;
  }
  world?.update(state);
}

document.querySelector('#actions')!.addEventListener('click', event => {
  const button = (event.target as HTMLElement).closest<HTMLButtonElement>('button[data-action]');
  if (button && !button.disabled) dispatch({ type: button.dataset.action as Exclude<MissionAction['type'], 'move' | 'launch'> });
});
document.querySelectorAll<HTMLButtonElement>('[data-move]').forEach(button => button.addEventListener('click', () => {
  const [dx, dz] = button.dataset.move!.split(',').map(Number);
  dispatch({ type: 'move', dx, dz });
}));
render();
