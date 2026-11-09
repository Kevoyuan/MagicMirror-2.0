/** Tested screen-space hit testing for the educational procedural proxy. */
export interface PickableSegment {
  fromIndex: number;
  toIndex: number;
  start: { x: number; y: number };
  end: { x: number; y: number };
}
export function pointToSegmentDistance(
  x: number, y: number, segment: PickableSegment
): number {
  const a = segment.start, b = segment.end;
  if (![x, y, a.x, a.y, b.x, b.y].every(Number.isFinite)) return Infinity;
  const dx = b.x - a.x, dy = b.y - a.y;
  const denominator = dx * dx + dy * dy;
  const fraction = denominator < 1e-8 ? 0 :
    Math.max(0, Math.min(1, ((x - a.x) * dx + (y - a.y) * dy) / denominator));
  return Math.hypot(x - a.x - fraction * dx, y - a.y - fraction * dy);
}

export function pickSegment(
  x: number, y: number, segments: readonly PickableSegment[], radiusPx = 22
): PickableSegment | null {
  if (![x, y, radiusPx].every(Number.isFinite) || radiusPx < 0) return null;
  let best: PickableSegment | null = null;
  let bestDistance = radiusPx;
  for (const segment of segments) {
    const distance = pointToSegmentDistance(x, y, segment);
    if (distance <= bestDistance) {
      bestDistance = distance;
      best = segment;
    }
  }
  return best;
}
