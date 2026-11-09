/**
 * Search and pagination for user-selected LOCAL source meshes.
 * Labels come from imported geometry; they are NOT anatomy classification,
 * licensing decisions, or medically validated part names.
 */
export interface AtlasPart {
  readonly id: number;
  readonly name: string;
  readonly path: string;
  readonly triangles: number;
  readonly visible: boolean;
}
export interface PartSearchResult {
  readonly matches: AtlasPart[];
  readonly totalMatches: number;
  readonly totalParts: number;
  readonly hiddenParts: number;
  readonly truncated: boolean;
}
export function normalizedPartQuery(query: string): string {
  return query.normalize("NFKC").trim().toLocaleLowerCase().slice(0, 160);
}
export function searchAtlasParts(
  parts: readonly AtlasPart[], query: string, maxResults = 60
): PartSearchResult {
  const needle = normalizedPartQuery(query);
  const take = Math.max(1, Math.min(300, Number.isFinite(maxResults) ? Math.floor(maxResults) : 60));
  const matches: AtlasPart[] = [];
  let totalMatches = 0;
  let hiddenParts = 0;
  for (const part of parts) {
    if (!part.visible) hiddenParts++;
    const source = `${part.name} ${part.path}`.normalize("NFKC").toLocaleLowerCase();
    if (!source.includes(needle)) continue;
    totalMatches++;
    if (matches.length < take) matches.push(part);
  }
  return {
    matches, totalMatches, totalParts: parts.length, hiddenParts,
    truncated: totalMatches > matches.length,
  };
}

export function sourcePathForPart(
  names: readonly string[],
  leaf: string
): string {
  return [...names, leaf].filter((value) => value.trim() !== "").join(" / ");
}

/** User toggles are overridden only temporarily by part isolation. */
export function effectivePartVisibility(
  originalUserVisible: boolean,
  partId: number,
  isolatedPartId: number | null
): boolean {
  return isolatedPartId === null
    ? originalUserVisible
    : partId === isolatedPartId;
}
