import type { MissionReport, MissionState } from '../shared/types';
import { MAX_SCIENCE_PER_SITE, RULES } from './rules';

const list = (names: string[]) => names.join(', ');

export function getReport(s: MissionState): MissionReport {
  const scanned = s.sites.filter(site => site.scanned);
  const notScanned = s.sites.filter(site => !site.scanned);
  const scannedNotSampled = s.sites.filter(site => site.scanned && !site.sampled);
  const maxScience = s.sites.length * MAX_SCIENCE_PER_SITE;
  const onboard = Math.max(0, s.scienceCollected - s.scienceReturned);

  const scienceShare = maxScience > 0 ? Math.min(1, s.scienceReturned / maxScience) : 0;
  const rawScore = scienceShare * RULES.scoreScienceWeight + (s.outpostDeployed ? RULES.scoreStationPoints : 0);
  const score = Math.round(Math.max(0, Math.min(100, rawScore)));

  const feedback: string[] = [];

  if (s.phase === 'planning') {
    feedback.push('The expedition never launched, so no science was gathered.');
  } else {
    if (s.phase === 'surface') feedback.push('Mission still in progress. This report is provisional.');

    feedback.push(`${s.scienceReturned} of ${maxScience} possible science units reached Earth.`);

    if (onboard > 0) {
      feedback.push(s.phase === 'complete'
        ? `${onboard} science units were collected but never transmitted, and were lost.`
        : `${onboard} science units are still onboard. Transmit them before closing the mission.`);
    } else if (s.scienceCollected > 0) {
      feedback.push('All collected evidence was returned to Earth.');
    }

    if (notScanned.length) feedback.push(`Signals not investigated: ${list(notScanned.map(site => site.name))}.`);

    if (s.config.instrument === 'drill') {
      if (scannedNotSampled.length) feedback.push(`Scanned but not sampled: ${list(scannedNotSampled.map(site => site.name))}.`);
    } else if (scanned.length) {
      feedback.push(`Without a drill, ${scanned.length * RULES.sampleScience} science units from samples were out of reach.`);
    }

    feedback.push(s.outpostDeployed ? 'A powered research station was established.' : 'No research station was established.');

    const supplies = s.config.power === 'fuel-cell' ? ` and ${s.fuelCells} fuel cell supplies` : '';
    feedback.push(`Rover finished with ${s.energy} / ${s.maxEnergy} energy${supplies} after ${s.turns} actions.`);
  }

  feedback.push('Scores and equipment values are fictional balancing rules, not NASA data.');

  return {
    score,
    returnedScience: s.scienceReturned,
    investigatedSites: scanned.length,
    outpostOperational: s.outpostDeployed,
    feedback
  };
}
