/** Contract v1. Joint ownership: agree on changes before editing this file. */
export type SiteKind = 'ice' | 'minerals' | 'geology';
export interface Position { x: number; z: number }
export interface Site extends Position {
  id: string; name: string; kind: SiteKind; scanned: boolean; sampled: boolean;
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
  fuelCells: number; sites: Site[]; log: string[];
}
export type MissionAction =
  | { type: 'launch' }
  | { type: 'move'; dx: number; dz: number }
  | { type: 'scan' | 'sample' | 'recharge' | 'transmit' | 'deploy' | 'finish' };
export interface MissionReport {
  score: number; returnedScience: number; investigatedSites: number;
  outpostOperational: boolean; feedback: string[];
}
export interface MissionEngine {
  createMission(config: MissionConfig, seed: number): MissionState;
  reviewDesign(config: MissionConfig): DesignReview;
  step(state: MissionState, action: MissionAction): MissionState;
  getReport(state: MissionState): MissionReport;
}
