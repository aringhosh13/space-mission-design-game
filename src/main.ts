import './style.css';
import { engine } from './engine';
import { DEFAULT_CONFIG } from './shared/catalog';
import type { MissionAction, MissionConfig } from './shared/types';
import { createWorld } from './ui/world';

let config = { ...DEFAULT_CONFIG };
let seed = 42;
let state = engine.createMission(config, seed);
const app = document.querySelector<HTMLDivElement>('#app')!;
app.innerHTML = `
  <header><a class="brand" href="./"><span class="brand-icon">◒</span> BLUE HORIZON</a><div class="header-detail">LUNAR EXPEDITION / 001</div><span class="status"><i></i> MISSION CONTROL</span></header>
  <main><section class="intro"><div><p class="eyebrow">EXPLORE WITH PURPOSE</p><h1>A foothold in the unknown.</h1><p>Build your expedition. Follow the evidence. Make every watt count.</p></div><span class="prototype">PLAYABLE FOUNDATION<br><b>Fictional simulation · v0.1</b></span></section>
  <div class="workspace"><aside id="planning"></aside><section class="surface"><div class="map-heading"><div><span class="eyebrow">SURFACE OPERATIONS</span><h2>South polar survey</h2></div><span id="phase"></span></div><div id="world"><div class="map-tag">SHADED TERRAIN <span>← WEST</span></div><div class="legend"><span>◯ Unknown signal</span><span>◯ Scanned evidence</span></div></div><div class="navigation"><div class="direction-pad"><button data-move="0,-1" aria-label="Move north">↑</button><button data-move="-1,0" aria-label="Move west">←</button><button data-move="0,1" aria-label="Move south">↓</button><button data-move="1,0" aria-label="Move east">→</button></div><span>WASD / arrow keys <b id="coordinates"></b></span></div><div id="actions"></div></section><aside id="telemetry"></aside></div><section id="report" hidden></section><footer>EDUCATIONAL PROTOTYPE · Equipment values, resources and terrain are illustrative. NASA data integration is pending.</footer></main>`;
let world: ReturnType<typeof createWorld> | undefined;
try { world = createWorld(document.querySelector('#world')!, (dx, dz) => dispatch({ type: 'move', dx, dz })); }
catch { document.querySelector('#world')!.insertAdjacentHTML('beforeend', '<p class="graphics-error">3D graphics are unavailable in this browser. Movement and mission controls below remain usable.</p>'); }
function dispatch(action: MissionAction) { state = engine.step(state, action); render(); }
const escape = (s: string) => s.replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]!));
function select(name: keyof MissionConfig, label: string, options: [string, string][]) {
  return `<label>${label}<select name="${name}" ${state.phase !== 'planning' ? 'disabled' : ''}>${options.map(([value, text]) => `<option value="${value}" ${config[name] === value ? 'selected' : ''}>${text}</option>`).join('')}</select></label>`;
}
function render() {
  const review = engine.reviewDesign(config);
  const active = state.phase === 'surface';
  document.querySelector('#planning')!.innerHTML = `<p class="eyebrow">01 / EXPEDITION DESIGN</p><h2>Your mission, your trade-offs.</h2><p class="muted">Choose a package before deploying your rover.</p>${select('battery', 'ENERGY STORAGE', [['compact', 'Compact battery · 70 units'], ['extended', 'Extended battery · 120 units']])}${select('power', 'POWER SOURCE', [['solar', 'Solar array · sunlight required'], ['fuel-cell', 'Fuel cells · 3 refills']])}${select('instrument', 'SCIENCE PAYLOAD', [['scanner', 'Surface scanner'], ['drill', 'Scanner + sample drill']])}<div class="design-total"><span>Budget</span><b>${review.cost} / ${review.budget} credits</b></div><div class="design-total"><span>Launch mass</span><b>${review.mass} / ${review.massLimit} kg</b></div>${review.warnings.map(w => `<p class="warning">${escape(w)}</p>`).join('')}<button class="primary" id="launch" ${state.phase !== 'planning' || review.warnings.length ? 'disabled' : ''}>${state.phase === 'planning' ? 'Launch expedition ↗' : 'Expedition launched ✓'}</button><button class="secondary" id="restart">New expedition</button><div class="mission-brief"><p class="eyebrow">YOUR OBJECTIVE</p><p>Investigate the three orbital signals, return the evidence to Earth, and establish a powered research station.</p><small>Gold rings mark uncertain signals. Move within 2.5 m to investigate.</small></div>`;
  document.querySelectorAll<HTMLSelectElement>('select').forEach(el => el.addEventListener('change', () => {
    config = { ...config, [el.name]: el.value }; state = engine.createMission(config, seed); render();
  }));
  document.querySelector('#launch')!.addEventListener('click', () => dispatch({ type: 'launch' }));
  document.querySelector('#restart')!.addEventListener('click', () => { seed++; state = engine.createMission(config, seed); render(); });
  document.querySelector('#phase')!.textContent = state.phase === 'planning' ? 'AWAITING LAUNCH' : state.phase === 'complete' ? 'MISSION CLOSED' : 'ROVER CONNECTED';
  document.querySelector('#coordinates')!.textContent = `X ${state.position.x.toFixed(1)} / Z ${state.position.z.toFixed(1)}`;
  document.querySelectorAll<HTMLButtonElement>('[data-move]').forEach(button => { button.disabled = !active; });
  document.querySelector('#actions')!.innerHTML = ([['scan', '⌖', 'Scan signal'], ['sample', '◇', 'Analyse sample'], ['recharge', '↯', 'Restore power'], ['transmit', '↗', 'Transmit data'], ['deploy', '⊞', 'Deploy station'], ['finish', '✓', 'End mission']] as const).map(([action, icon, label]) => `<button data-action="${action}" ${!active ? 'disabled' : ''}><span>${icon}</span>${label}</button>`).join('');
  document.querySelectorAll<HTMLButtonElement>('[data-action]').forEach(button => button.addEventListener('click', () => dispatch({ type: button.dataset.action as Exclude<MissionAction['type'], 'move' | 'launch'> })));
  document.querySelector('#telemetry')!.innerHTML = `<p class="eyebrow">02 / LIVE TELEMETRY</p><div class="energy"><span>ROVER POWER</span><strong>${state.energy}<small> / ${state.maxEnergy}</small></strong><meter min="0" max="${state.maxEnergy}" value="${state.energy}">${state.energy}</meter></div><div class="metrics"><div><span>DATA ONBOARD</span><b>${state.scienceCollected - state.scienceReturned}<small> units</small></b></div><div><span>DATA RETURNED</span><b>${state.scienceReturned}<small> units</small></b></div><div><span>MISSION ACTIONS</span><b>${state.turns}</b></div><div><span>RESEARCH STATION</span><b class="station-status">${state.outpostDeployed ? 'Operational' : 'Not deployed'}</b></div></div><p class="eyebrow log-title">MISSION LOG</p><div class="log" aria-live="polite">${state.log.map((line, i) => `<p><span>${String(state.log.length - i).padStart(2, '0')}</span>${escape(line)}</p>`).join('')}</div>`;
  const report = document.querySelector<HTMLElement>('#report')!;
  report.hidden = state.phase !== 'complete';
  if (!report.hidden) { const result = engine.getReport(state); report.innerHTML = `<p class="eyebrow">EXPEDITION DEBRIEF</p><h2>${result.score}<span> / 100 preview score</span></h2><p>${result.returnedScience} science returned · ${result.investigatedSites} signals investigated · Station ${result.outpostOperational ? 'operational' : 'not established'}</p>${result.feedback.map(line => `<p class="muted">${escape(line)}</p>`).join('')}`; }
  world?.update(state);
}
document.querySelectorAll<HTMLButtonElement>('[data-move]').forEach(button => button.addEventListener('click', () => { const [dx, dz] = button.dataset.move!.split(',').map(Number); dispatch({ type: 'move', dx, dz }); }));
render();
