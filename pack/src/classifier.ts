import { createHash } from 'node:crypto';
export const classifierLabels = ['credentials','money','action','pressure','bait'] as const;
export interface ClassifierEnvelope { payload: string; version: string; release?: Record<string, any> }
export function validateClassifier(artifact: ClassifierEnvelope): void {
  const hash = createHash('sha256').update(artifact.payload).digest('hex');
  if (artifact.version !== hash) throw new Error('Classifier hash mismatch');
  const p = JSON.parse(artifact.payload);
  if (p.schema !== 1 || p.preprocessing !== 'query-l2-v1' || !Number.isInteger(p.dimension) || p.dimension < 1 || p.dimension > 4096 ||
    !/^sha256:[a-f0-9]{64}:[a-f0-9]{64}$/.test(p.fingerprint)) throw new Error('Incompatible classifier');
  if (Object.keys(p.heads).length !== 5) throw new Error('Invalid classifier heads');
  for (const label of classifierLabels) {
    const h = p.heads[label];
    if (!h || !Array.isArray(h.weights) || h.weights.length !== p.dimension || h.weights.some((v: unknown)=>typeof v !== 'number' || !Number.isFinite(v)) ||
      !Number.isFinite(h.bias) || !Number.isFinite(h.threshold) || h.threshold <= 0 || h.threshold > 1) throw new Error('Invalid classifier head');
  }
  const r = artifact.release;
  const metrics = ['regression_scams','regression_detected','final_scams','final_ordinary','final_detected','baseline_detected','additional_ordinary_warnings'];
  if (!r || metrics.some(k=>!Number.isSafeInteger(r[k]) || r[k] < 0) || r.regression_detected > r.regression_scams || r.final_detected > r.final_scams || r.baseline_detected > r.final_scams) throw new Error('Classifier release gate has invalid metrics');
  if (!r || r.artifact_version !== hash || r.evaluation_passed !== true || r.phone_verified !== true ||
    r.regression_scams !== 20 || r.regression_detected < 13 || r.final_scams < 20 || r.final_ordinary < 100 ||
    !(r.final_detected > r.baseline_detected) || r.additional_ordinary_warnings !== 0 || !/^[a-f0-9]{64}$/.test(r.report_sha256) ||
    !['offline','responsive','resumable','fallback'].every(k=>r.phone_checks?.[k] === true)) throw new Error('Classifier release gate incomplete');
}
