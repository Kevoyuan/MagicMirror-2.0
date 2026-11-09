import { usable, type PosePoint } from "./pose";

/**
 * Adaptive visual smoothing for the PROCEDURAL proxy only.
 *
 * Never predicts hidden joints or carries stale points forward.
 * The current MediaPipe confidence is always preserved, and a
 * sudden impossible teleport is hidden for one frame instead
 * of fabricating a smooth internal bone reconstruction.
 */
export class TemporalPoseStabilizer {
  private previous: Array<PosePoint | undefined> = Array(33).fill(undefined);
  private lastTimeMs = -Infinity;
  private readonly maxGapMs = 350;
  private readonly tauMs = 85;

  reset(): void {
    this.previous = Array(33).fill(undefined);
    this.lastTimeMs = -Infinity;
  }

  sample(points: readonly PosePoint[] | null | undefined, timestampMs: number): PosePoint[] | null {
    if (!points || points.length !== 33 || !Number.isFinite(timestampMs)) {
      this.reset();
      return null;
    }
    if (timestampMs <= this.lastTimeMs) return null;
    const gap = timestampMs - this.lastTimeMs;
    if (gap > this.maxGapMs) {
      this.previous = Array(33).fill(undefined);
    }
    this.lastTimeMs = timestampMs;
    const result: PosePoint[] = [];
    const dt = Number.isFinite(gap) && gap > 0 ? gap : this.tauMs;
    const baseAlpha = 1 - Math.exp(-dt / this.tauMs);

    for (let i = 0; i < 33; i++) {
      const current = points[i];
      if (!usable(current)) {
        this.previous[i] = undefined;
        result.push({ x: 0, y: 0, z: 0, visibility: 0, presence: 0 });
        continue;
      }
      const last = this.previous[i];
      if (!last) {
        result.push({ ...current });
        this.previous[i] = { ...current };
        continue;
      }
      const movement = Math.hypot(current.x - last.x, current.y - last.y);
      const allowedJump = Math.max(0.27, dt * 0.004);
      if (movement > allowedJump) {
        // A teleported keypoint should disappear briefly rather than
        // move an apparently real bone across the visible person.
        this.previous[i] = undefined;
        result.push({ ...current, visibility: 0, presence: 0 });
        continue;
      }
      // Larger *plausible* movement gets less lag. Slow movement remains
      // gently smoothed for the illustrated proxy's visual stability.
      const adaptiveAlpha = Math.min(1, Math.max(0.10,
        baseAlpha + Math.min(0.35, movement * 1.8)
      ));
      const smoothed: PosePoint = {
        x: last.x + adaptiveAlpha * (current.x - last.x),
        y: last.y + adaptiveAlpha * (current.y - last.y),
        z: last.z + adaptiveAlpha * (current.z - last.z),
        visibility: current.visibility,
        presence: current.presence,
      };
      this.previous[i] = smoothed;
      result.push(smoothed);
    }
    return result;
  }
}
