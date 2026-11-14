import type { SiteFinding } from '../shared/types';

/** Presentation of evidence exposed by the engine. Never infer the hidden resource outcome. */
export const FINDING_LABELS: Record<SiteFinding, string> = {
  unconfirmed: 'Unconfirmed', probable: 'Preliminary evidence',
  confirmed: 'Confirmed by sample', 'ruled-out': 'Ruled out by sample'
};
export const FINDING_COLORS: Record<SiteFinding, string> = {
  unconfirmed: '#e9b86b', probable: '#88bce9', confirmed: '#a8e5bb', 'ruled-out': '#d0a4cd'
};
