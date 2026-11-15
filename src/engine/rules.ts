/**
 * Blue Horizon engine rules, milestone 1.
 *
 * Every number here is a FICTIONAL BALANCING VALUE chosen for gameplay. None is a NASA
 * measurement, flight specification or validated engineering figure. Values match the
 * temporary preview engine so the existing UI copy (refills, 2.5 m range, x = -3 shade line)
 * stays accurate.
 */
export const RULES = {
  /** Fixed rover chassis, lander integration and operations overhead. */
  baseCost: 35,
  baseMass: 30,
  budget: 110,
  massLimit: 100,

  /** Survey square is [-mapLimit, mapLimit] on x and z. */
  mapLimit: 10,
  /** A commanded move travels at most this many map units. */
  maxMoveDistance: 1,
  /** Energy per map unit travelled, rounded up to a whole unit (minimum 1 per move). */
  moveEnergyPerUnit: 2,

  /** Rover must be within this distance of a site to scan or sample it. */
  proximity: 2.5,
  scanEnergy: 8,
  scanScience: 15,
  sampleEnergy: 15,
  sampleScience: 25,

  /** Simple shade model: everything west of this x is shaded. x = -3 itself is lit. */
  shadeBoundaryX: -3,
  rechargeAmount: 35,
  /** Fuel-cell designs carry this many single-use recharge supplies. Solar designs carry none. */
  fuelCellSupplies: 3,

  transmitEnergy: 5,
  deployEnergy: 20,

  /** Number of log lines kept, newest first. */
  maxLogLines: 8,

  /** Scoring: returned science is worth up to 70 points, an operational station 30. */
  scoreScienceWeight: 70,
  scoreStationPoints: 30
} as const;

/** Maximum science available in a mission with three sites and a drill. */
export const MAX_SCIENCE_PER_SITE = RULES.scanScience + RULES.sampleScience;
