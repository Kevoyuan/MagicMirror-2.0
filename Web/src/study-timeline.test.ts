import { describe, expect, it } from "vitest";
import { buildLocalAtlasInventory } from "./atlas-inventory";
import type { StudyChainNode } from "./kinematic-chain";
import {
  makeStudyTimelineDraft, parseStudyTimelineDraft, sampleStudyTimeline,
  studyFrameAt, timelineDownloadName,
} from "./study-timeline";

const source = buildLocalAtlasInventory({
  fileName: "fixture.glb", fileSizeBytes: 123456,
  sourceSHA256: "c".repeat(64),
  importedMeshes: 2, triangles: 240,
  skinnedMeshes: 0, authoredJoints: 0,
  parts: [
    {id:0,name:"A",path:"Root / A",triangles:120,visible:true},
    {id:1,name:"B",path:"Root / B",triangles:120,visible:true},
  ],
});
const nodes: StudyChainNode[] = [
  { sourceMeshId: 0, parentMeshId: null, start:[0,0,0],
    end:[1,0,0], axis:"z", degrees:10 },
  { sourceMeshId: 1, parentMeshId: 0, start:[1,0,0],
    end:[2,0,0], axis:"z", degrees:-30 },
];
const at0 = studyFrameAt(nodes, 0);
const at2000 = studyFrameAt([
  {...nodes[0],degrees:50}, {...nodes[1],degrees:30},
], 2000);

describe("W2i original-source timeline with fail-closed input and interpolation", () => {
  it("roundtrips one exact SHA/mesh/parent/point/axis source graph", () => {
    const draft = makeStudyTimelineDraft(source,nodes,[at0,at2000]);
    expect(draft).toMatchObject({
      cameraRetargeting:false, commercialReuseStatus:"NOT_REVIEWED",
      motionType:"AUTHOR_SELECTED_TEST_ANGLES",
      space:"ORIGINAL_MODEL_UNCALIBRATED",
    });
    expect(parseStudyTimelineDraft(draft,source,nodes))
      .toEqual([at0,at2000]);
  });
  it("linearly interpolates exact authored test angles, with bound holds", () => {
    const frames=[at0,at2000];
    expect(sampleStudyTimeline(frames, -100)?.map(j=>j.degrees)).toEqual([10,-30]);
    expect(sampleStudyTimeline(frames, 1000)?.map(j=>j.degrees)).toEqual([30,0]);
    expect(sampleStudyTimeline(frames, 5000)?.map(j=>j.degrees)).toEqual([50,30]);
    expect(sampleStudyTimeline(frames, NaN)).toBeNull();
  });
  it("rejects user replay from other model or edited parent/pivot assignments", () => {
    const draft=makeStudyTimelineDraft(source,nodes,[at0,at2000]);
    expect(()=>parseStudyTimelineDraft({
      ...draft,source:{...draft.source,sha256:"d".repeat(64)},
    },source,nodes)).toThrow(/SHA-256/);
    expect(()=>parseStudyTimelineDraft(draft,source,[
      nodes[0],{...nodes[1],parentMeshId:null},
    ])).toThrow(/graph|parent/);
    expect(()=>parseStudyTimelineDraft(draft,source,[
      nodes[0],{...nodes[1],start:[1,1,0]},
    ])).toThrow(/anchor/);
  });
  it("rejects duplicates, missing frames, extreme angles and different frame axes", () => {
    expect(()=>makeStudyTimelineDraft(source,nodes,[at0,at0])).toThrow();
    expect(()=>makeStudyTimelineDraft(source,nodes,[])).toThrow();
    expect(()=>makeStudyTimelineDraft(source,nodes,[
      at0,{timeMs:2000,joints:[{...at0.joints[0],degrees:99},at0.joints[1]]},
    ])).toThrow();
    expect(()=>makeStudyTimelineDraft(source,nodes,[
      at0,{timeMs:2000,joints:[{...at0.joints[0],axis:"x"},at0.joints[1]]},
    ])).toThrow();
    expect(()=>studyFrameAt(nodes,10001)).toThrow();
  });
  it("blocks extra rights/medical approval and unknown timeline fields", () => {
    const draft=makeStudyTimelineDraft(source,nodes,[at0,at2000]);
    expect(()=>parseStudyTimelineDraft({
      ...draft,commercialReuseStatus:"APPROVED"
    },source,nodes)).toThrow();
    expect(()=>parseStudyTimelineDraft({
      ...draft,clinicalTracking:true
    },source,nodes)).toThrow(/forged/);
  });
  it("bounds export name and does not leak raw file paths", () => {
    expect(timelineDownloadName("../../Original Atlas.FBX")).toBe(
      "MagicMirror-Original_Atlas-virtual-frames.json"
    );
  });
});
