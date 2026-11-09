import { describe, expect, it } from "vitest";
import { buildLocalAtlasInventory } from "./atlas-inventory";
import type { PartAnchorPair } from "./atlas-anchors";
import type { PoseSegmentId } from "./atlas-mapping";
import type { StudyChainNode } from "./kinematic-chain";
import { studyFrameAt } from "./study-timeline";
import {
  makeStudySession, parseStudySession, studyReplayDiagnostics,
  studySessionDownloadName,
} from "./study-session";

const source = buildLocalAtlasInventory({
  fileName: "fixture.glb", fileSizeBytes: 123456,
  sourceSHA256: "c".repeat(64),
  importedMeshes: 3, triangles: 360,
  skinnedMeshes: 0, authoredJoints: 0,
  parts: [
    { id: 0, name: "A", path: "Root / A", triangles: 120, visible: true },
    { id: 1, name: "B", path: "Root / B", triangles: 120, visible: true },
    { id: 2, name: "C", path: "Root / C", triangles: 120, visible: true },
  ],
});
const mappings = new Map<number, PoseSegmentId>([
  [0, "left-upper-arm"], [1, "left-forearm"], [2, "left-forearm"],
]);
const anchors = new Map<number, PartAnchorPair>([
  [0, { start: [0, 0, 0], end: [1, 0, 0] }],
  [1, { start: [1, 0, 0], end: [2, 0, 0] }],
  [2, { start: [2, 0, 0], end: [3, 0, 0] }],
]);
const nodes: StudyChainNode[] = [
  { sourceMeshId: 0, parentMeshId: null, start: [0, 0, 0], end: [1, 0, 0], axis: "z", degrees: 10 },
  { sourceMeshId: 1, parentMeshId: 0, start: [1, 0, 0], end: [2, 0, 0], axis: "z", degrees: -30 },
  { sourceMeshId: 2, parentMeshId: 1, start: [2, 0, 0], end: [3, 0, 0], axis: "y", degrees: 25 },
];
const frames = [
  studyFrameAt(nodes, 0),
  studyFrameAt(nodes.map(node => ({ ...node, degrees: node.degrees + 20 })), 1500),
  studyFrameAt(nodes.map(node => ({ ...node, degrees: 0 })), 3000),
];
const session = () => makeStudySession(source, mappings, anchors, nodes, frames);
/** Parsed JSON is untrusted/untyped; tests deliberately tamper with copies. */
const clone = (value: unknown): any =>
  JSON.parse(JSON.stringify(value)) as any;

describe("W2l one-file local study session, all-or-nothing restore", () => {
  it("roundtrips mapping, anchors, chain and keyframes for the exact source", () => {
    const bundle = session();
    expect(bundle).toMatchObject({
      schemaVersion: 1, kind: "magicmirror-local-study-session",
      space: "ORIGINAL_MODEL_UNCALIBRATED",
      retargetingStatus: "NOT_READY",
      commercialReuseStatus: "NOT_REVIEWED",
      cameraRetargeting: false,
    });
    expect(bundle.timeline?.frames).toEqual(frames);
    expect(bundle.source).toEqual({
      sha256: "c".repeat(64), fileSizeBytes: 123456, sourceMeshCount: 3,
    });
    const restored = parseStudySession(clone(bundle), source);
    expect([...restored.mappings]).toEqual([...mappings]);
    expect([...restored.anchors]).toEqual([...anchors]);
    expect(restored.chain).toEqual(nodes);
    expect(restored.frames).toEqual(frames);
    // No source geometry, camera frames or rights approval is serialized.
    const text = JSON.stringify(bundle);
    expect(text).not.toContain("positions");
    expect(text).not.toContain("imageData");
    expect(text).not.toContain("APPROVED");
  });

  it("can restore an early session with no chain and no keyframes", () => {
    const bundle = makeStudySession(source, mappings, anchors, [], []);
    expect(bundle.chain).toEqual([]);
    expect(bundle.timeline).toBeNull();
    const restored = parseStudySession(clone(bundle), source);
    expect(restored.chain).toEqual([]);
    expect(restored.frames).toEqual([]);
    expect([...restored.mappings]).toEqual([...mappings]);
  });

  it("refuses keyframes without a chain and a timeline without a chain", () => {
    expect(() => makeStudySession(source, mappings, anchors, [], frames))
      .toThrow(/2–12 authored source chain/);
    const bundle = clone(session());
    bundle.chain = [];
    expect(() => parseStudySession(bundle, source)).toThrow(/without a source chain/);
  });

  it("rejects a different original model at every nested draft level", () => {
    const other = buildLocalAtlasInventory({
      fileName: "other.glb", fileSizeBytes: 999,
      sourceSHA256: "d".repeat(64),
      importedMeshes: 3, triangles: 360,
      skinnedMeshes: 0, authoredJoints: 0,
      parts: [
        { id: 0, name: "A", path: "Root / A", triangles: 120, visible: true },
        { id: 1, name: "B", path: "Root / B", triangles: 120, visible: true },
        { id: 2, name: "C", path: "Root / C", triangles: 120, visible: true },
      ],
    });
    expect(() => parseStudySession(clone(session()), other)).toThrow(/SHA-256|mismatch/);
    const wrongTop = clone(session());
    wrongTop.source.sha256 = "d".repeat(64);
    expect(() => parseStudySession(wrongTop, source)).toThrow(/SHA-256/);
    const wrongMap = clone(session());
    wrongMap.mapping.source.fileSizeBytes = 1;
    expect(() => parseStudySession(wrongMap, source)).toThrow(/SHA-256|size/);
    const wrongAnchors = clone(session());
    wrongAnchors.anchors.source.sourceMeshCount = 2;
    expect(() => parseStudySession(wrongAnchors, source)).toThrow(/mesh count/);
  });

  it("blocks forged approval, unknown fields and tampered original mesh names", () => {
    const approved = clone(session());
    approved.commercialReuseStatus = "APPROVED";
    expect(() => parseStudySession(approved, source)).toThrow();
    const medical = clone(session());
    medical.cameraRetargeting = true;
    expect(() => parseStudySession(medical, source)).toThrow();
    const extra: Record<string, unknown> = clone(session());
    extra.clinicalTracking = true;
    expect(() => parseStudySession(extra, source)).toThrow(/forged|Unexpected/);
    const renamed = clone(session());
    renamed.mapping.assignments[0].originalMeshName = "RENAMED_BONE";
    expect(() => parseStudySession(renamed, source)).toThrow(/altered|Duplicate/);
    const fakeRight = clone(session());
    fakeRight.anchors.anchors[0].reviewStatus = "REVIEWED_CALIBRATED";
    expect(() => parseStudySession(fakeRight, source)).toThrow(/reviewed|Anchor|mesh/);
  });

  it("rejects chain points that disagree with the validated anchor draft", () => {
    const moved = clone(session());
    moved.chain[1].start = [1, 5, 0];
    expect(() => parseStudySession(moved, source)).toThrow(/disagree|anchor|timeline/i);
  });

  it("rejects cycles, unselected parents, duplicates, one node and 13 nodes", () => {
    const cycle = clone(session());
    cycle.chain[0].parentMeshId = 2;
    expect(() => parseStudySession(cycle, source)).toThrow(/cycle|parent/i);
    const orphan = clone(session());
    orphan.chain[1].parentMeshId = 9;
    expect(() => parseStudySession(orphan, source)).toThrow(/parent|unselected/i);
    const duplicate = clone(session());
    duplicate.chain[2].sourceMeshId = 0;
    expect(() => parseStudySession(duplicate, source)).toThrow(/duplicate|Unknown/i);
    const single = clone(session());
    single.chain = [single.chain[0]];
    expect(() => parseStudySession(single, source)).toThrow(/0 or 2–12/);
    const tooMany = clone(session());
    tooMany.chain = Array.from({ length: 13 }, (_, index) => ({
      ...clone(session()).chain[0], sourceMeshId: index,
    }));
    expect(() => parseStudySession(tooMany, source)).toThrow(/0 or 2–12/);
  });

  it("rejects extreme angles, unknown axes and unmapped chain meshes", () => {
    const extreme = clone(session());
    extreme.chain[0].degrees = 91;
    expect(() => parseStudySession(extreme, source)).toThrow(/angle/i);
    const badAxis = clone(session());
    badAxis.chain[0].axis = "patient";
    expect(() => parseStudySession(badAxis, source)).toThrow(/axis/i);
    const unmappedMappings = new Map(mappings);
    unmappedMappings.delete(2);
    expect(() => makeStudySession(source, unmappedMappings, anchors, nodes, []))
      .toThrow(/unmapped/);
  });

  it("leaves the bundle reusable after failed imports (pure, non-mutating)", () => {
    const bundle = clone(session());
    const snapshot = clone(bundle);
    for (let attempt = 0; attempt < 3; attempt++) {
      const broken = clone(bundle);
      broken.chain[0].degrees = 500;
      expect(() => parseStudySession(broken, source)).toThrow();
    }
    expect(bundle).toEqual(snapshot);
    expect(parseStudySession(bundle, source).frames).toEqual(frames);
  });

  it("reports a bounded, deterministic synthetic matrix replay with no drift", () => {
    const report = studyReplayDiagnostics(nodes, frames);
    expect(report.scope).toBe("SYNTHETIC_SOURCE_MATRIX_REPLAY_ONLY");
    expect(report.frameCount).toBe(3);
    expect(report.nodeCount).toBe(3);
    expect(report.sampledPoints).toBe(5);
    expect(report.deterministic).toBe(true);
    expect(report.maxReplayDrift).toBe(0);
    expect(report.maxAngleStepDegrees).toBe(45);
    expect(report.minAngleDegrees).toBe(-30);
    expect(report.maxAngleDegrees).toBe(45);
    expect(report.largeSourceGaps).toBe(0);
    expect(studyReplayDiagnostics(nodes, []).deterministic).toBe(false);
    expect(studyReplayDiagnostics([], frames).deterministic).toBe(false);
  });

  it("refuses non-ascending or extreme replay frames", () => {
    expect(() => studyReplayDiagnostics(nodes, [frames[1], frames[0]]))
      .toThrow(/strictly ascend/);
    expect(() => studyReplayDiagnostics(nodes, [
      { timeMs: 0, joints: nodes.map(node => ({
        sourceMeshId: node.sourceMeshId, axis: node.axis, degrees: 180,
      })) },
    ])).toThrow(/extreme angle/);
  });

  it("sanitizes the local download filename", () => {
    expect(studySessionDownloadName("../../My Atlas.FBX")).toBe(
      "MagicMirror-My_Atlas-study-session.json"
    );
  });
});
