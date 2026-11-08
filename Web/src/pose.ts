/** Strict browser-image-space tracking primitives. Never infer internal bones. */
export interface PosePoint {
  x: number;
  y: number;
  z: number;
  visibility?: number;
  presence?: number;
}

export type Focus = "whole" | "arms" | "legs";
export type Coverage = "none" | "partial" | "torso";

export interface PoseSegment {
  fromIndex: number;
  toIndex: number;
  group: Exclude<Focus, "whole"> | "torso";
  start: PosePoint;
  end: PosePoint;
}

export const SKELETON_CONNECTIONS: ReadonlyArray<
  readonly [number, number, PoseSegment["group"]]
> = [
  [11, 13, "arms"], [13, 15, "arms"],
  [12, 14, "arms"], [14, 16, "arms"],
  [23, 25, "legs"], [25, 27, "legs"],
  [24, 26, "legs"], [26, 28, "legs"],
  [11, 12, "torso"], [11, 23, "torso"],
  [12, 24, "torso"], [23, 24, "torso"],
];

export function usable(point: PosePoint | undefined, threshold = 0.55): point is PosePoint {
  if (!point) return false;
  if (![point.x, point.y, point.z].every(Number.isFinite)) return false;
  // MediaPipe is allowed a small overshoot at image borders.
  if (point.x < -0.1 || point.x > 1.1 || point.y < -0.1 || point.y > 1.1) {
    return false;
  }
  const confidence = point.visibility ?? point.presence ?? 0;
  return Number.isFinite(confidence) && confidence >= threshold;
}

export function coverageFor(points: readonly PosePoint[] | undefined): Coverage {
  if (!points || points.length !== 33) return "none";
  const torso = [11, 12, 23, 24].every((i) => usable(points[i]));
  if (torso) return "torso";
  const partial = SKELETON_CONNECTIONS.some(([a, b, group]) =>
    group !== "torso" && usable(points[a]) && usable(points[b])
  );
  return partial ? "partial" : "none";
}

export function visibleSegments(
  points: readonly PosePoint[] | undefined,
  focus: Focus
): PoseSegment[] {
  if (!points || points.length !== 33) return [];
  return SKELETON_CONNECTIONS.flatMap(([a, b, group]) => {
    if (focus !== "whole" && group !== focus) return [];
    const start = points[a], end = points[b];
    return usable(start) && usable(end)
      ? [{ fromIndex: a, toIndex: b, group, start, end }]
      : [];
  });
}

/** Mirrors image space after the same object-fit:cover crop as the video element. */
export function mapImageToViewport(
  p: Pick<PosePoint, "x" | "y">,
  sourceWidth: number,
  sourceHeight: number,
  viewportWidth: number,
  viewportHeight: number,
  mirrored: boolean
): { x: number; y: number } | null {
  if (![p.x, p.y, sourceWidth, sourceHeight, viewportWidth, viewportHeight].every(Number.isFinite) ||
      sourceWidth <= 0 || sourceHeight <= 0 || viewportWidth <= 0 || viewportHeight <= 0) {
    return null;
  }
  const scale = Math.max(viewportWidth / sourceWidth, viewportHeight / sourceHeight);
  const xOffset = (viewportWidth - sourceWidth * scale) / 2;
  const yOffset = (viewportHeight - sourceHeight * scale) / 2;
  const cropX = p.x * sourceWidth * scale + xOffset;
  const cropY = p.y * sourceHeight * scale + yOffset;
  return { x: mirrored ? viewportWidth - cropX : cropX, y: cropY };
}
