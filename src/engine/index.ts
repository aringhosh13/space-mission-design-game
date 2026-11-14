// Claude owns this entry point. Implements the MissionEngine contract in src/shared/types.ts (v1).
// Pure and deterministic: no DOM, Three.js, network or wall-clock dependencies.
import type { MissionEngine } from '../shared/types';
import { reviewDesign } from './design';
import { createMission } from './mission';
import { getReport } from './report';
import { step } from './step';

export const engine: MissionEngine = { createMission, reviewDesign, step, getReport };
export { RULES } from './rules';
export { EVIDENCE } from './evidence';
