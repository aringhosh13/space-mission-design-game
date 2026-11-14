// Claude owns this entry point. Replace the preview export with the real engine.
// Preserve the MissionEngine interface in src/shared/types.ts.
export { previewEngine as engine } from '../preview/engine';
