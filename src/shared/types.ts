/** Contract v2. Joint ownership: agree on changes before editing this file. */
export type SiteKind = 'ice' | 'minerals' | 'geology';
export interface Position { x: number; z: number }
/**
 * What the evidence currently says about a signal. Transitions only move forward:
 * unconfirmed (orbital signal) → probable (after a scan) → confirmed | ruled-out (after a sample).
 */
export type SiteFinding = 'unconfirmed' | 'probable' | 'confirmed' | 'ruled-out';
export interface Site extends Position {
  id: string; name: string; kind: SiteKind; scanned: boolean; sampled: boolean;
  /** Integer 0–100: certainty in the current `finding`, not the probability that the resource exists. */
  confidence: number;
  finding: SiteFinding;
}
export interface MissionConfig {
  battery: 'compact' | 'extended';
  power: 'solar' | 'fuel-cell';
  instrument: 'scanner' | 'drill';
}
export interface DesignReview {
  cost: number; budget: number; mass: number; massLimit: number; warnings: string[];
}
export interface MissionState {
  seed: number; phase: 'planning' | 'surface' | 'complete'; config: MissionConfig;
  position: Position; energy: number; maxEnergy: number; turns: number;
  scienceCollected: number; scienceReturned: number; outpostDeployed: boolean;
  /** null until deployment, then the rover's position at deployment. Later rover moves do not change it. */
  outpostPosition: Position | null;
  fuelCells: number; sites: Site[]; log: string[];
}
export type MissionAction =
  | { type: 'launch' }
  | { type: 'move'; dx: number; dz: number }
  | { type: 'scan' | 'sample' | 'recharge' | 'transmit' | 'deploy' | 'finish' };
export interface MissionReport {
  score: number; returnedScience: number; investigatedSites: number;
  /** Sites whose finding is 'confirmed'. */
  confirmedSites: number;
  outpostOperational: boolean; feedback: string[];
}
export interface MissionEngine {
  createMission(config: MissionConfig, seed: number): MissionState;
  reviewDesign(config: MissionConfig): DesignReview;
  step(state: MissionState, action: MissionAction): MissionState;
  getReport(state: MissionState): MissionReport;
}
