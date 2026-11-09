/**
 * Research-only sampling of real authored skin weights.
 * Findings are diagnostic, not a rig correctness, medical or rights
 * authorization. Never invent weights for an unrigged anatomy FBX.
 */
export interface RigSampleSource {
  vertexCount: number;
  jointCount: number;
  influenceSlots: number;
  readWeight(vertex: number, slot: number): number;
  readJoint(vertex: number, slot: number): number;
}
export interface RigSampleResult {
  readonly sampledVertices: number;
  readonly influencedVertices: number;
  readonly unweightedVertices: number;
  readonly invalidWeightSamples: number;
  readonly invalidJointReferences: number;
  readonly suspiciousWeightSums: number;
  readonly maxActiveInfluences: number;
}
export function inspectRigSamples(source: RigSampleSource, maxSamples = 256): RigSampleResult {
  if (![source.vertexCount, source.jointCount, source.influenceSlots].every(
    (n) => Number.isSafeInteger(n) && n >= 0
  )) throw new Error("Invalid imported rig sample dimensions");
  const result = {
    sampledVertices: 0,
    influencedVertices: 0,
    unweightedVertices: 0,
    invalidWeightSamples: 0,
    invalidJointReferences: 0,
    suspiciousWeightSums: 0,
    maxActiveInfluences: 0,
  };
  if (!source.vertexCount || !source.influenceSlots) return result;
  const count = Math.max(1, Math.min(2048, Math.floor(maxSamples) || 256));
  const stride = Math.max(1, Math.ceil(source.vertexCount / count));
  const slots = Math.min(source.influenceSlots, 8);
  for (let vertex = 0; vertex < source.vertexCount; vertex += stride) {
    result.sampledVertices++;
    let active = 0;
    let totalWeight = 0;
    for (let slot = 0; slot < slots; slot++) {
      const weight = source.readWeight(vertex, slot);
      const joint = source.readJoint(vertex, slot);
      if (!Number.isFinite(weight) || weight < 0 || weight > 1) {
        result.invalidWeightSamples++;
        continue;
      }
      if (weight <= 1e-5) continue;
      active++;
      totalWeight += weight;
      if (!Number.isSafeInteger(joint) || joint < 0 || joint >= source.jointCount) {
        result.invalidJointReferences++;
      }
    }
    if (active === 0) result.unweightedVertices++;
    else result.influencedVertices++;
    if (active > 0 && (totalWeight < 0.85 || totalWeight > 1.15)) {
      result.suspiciousWeightSums++;
    }
    result.maxActiveInfluences = Math.max(result.maxActiveInfluences, active);
  }
  return result;
}

export interface AnimationStudyClip {
  readonly id: number;
  readonly name: string;
  readonly durationSeconds: number;
  readonly trackCount: number;
}
export function usableAnimationStudyClip(
  clip: AnimationStudyClip
): boolean {
  // These are preview-only sanity bounds, not retargeting proof.
  return Number.isSafeInteger(clip.id) && clip.id >= 0 &&
    Number.isFinite(clip.durationSeconds) &&
    clip.durationSeconds > 0 && clip.durationSeconds <= 600 &&
    Number.isSafeInteger(clip.trackCount) &&
    clip.trackCount > 0 && clip.trackCount <= 10000;
}
