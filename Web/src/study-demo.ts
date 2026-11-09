import { BoxGeometry, Group, Mesh, MeshStandardMaterial } from "three";
import type { PoseSegmentId } from "./atlas-mapping";
import type { SourcePoint3 } from "./atlas-anchors";

/**
 * ORIGINAL MIT-LICENSED generated fixture, no anatomy asset, no downloadable
 * Z-Anatomy mesh, no real joint or user-specific body measurements.
 * The coordinates are authored alongside THESE boxes, not automatically
 * inferred from any real anatomical source.
 */
export interface DemoSegment {
  readonly sourceName: string;
  readonly intendedSurfaceReference: PoseSegmentId;
  readonly start: SourcePoint3;
  readonly end: SourcePoint3;
  readonly parentSourceName: string | null;
  readonly initialAngle: number;
}
export const ORIGINAL_STUDY_DEMO: readonly DemoSegment[] = [
  {
    sourceName: "MM_DEMO_BAR_A",
    intendedSurfaceReference: "left-upper-arm",
    start: [0, 0.1, 0], end: [0.9, 0.1, 0],
    parentSourceName: null, initialAngle: 30,
  },
  {
    sourceName: "MM_DEMO_BAR_B",
    intendedSurfaceReference: "left-forearm",
    start: [1, 0.1, 0], end: [1.9, 0.1, 0],
    parentSourceName: "MM_DEMO_BAR_A", initialAngle: -45,
  },
  {
    sourceName: "MM_DEMO_BAR_C",
    intendedSurfaceReference: "left-forearm",
    start: [2, 0.1, 0], end: [2.9, 0.1, 0],
    parentSourceName: "MM_DEMO_BAR_B", initialAngle: 25,
  },
];

/**
 * An in-memory self-contained GLB; never a remote fetch or prebundled anatomy
 * asset. This file follows the exact same ordinary user-file SHA and parsing
 * path as any local FBX/GLB. Loading it is an explicit user choice.
 */
export async function createOriginalStudyDemoFile(): Promise<File> {
  const group = new Group();
  group.name = "MagicMirror_Original_3Box_Study";
  const geometry = new BoxGeometry(0.9, 0.2, 0.2);
  const material = new MeshStandardMaterial({
    color: "#bbad8c", roughness: 0.7, metalness: 0.02,
  });
  try {
    for (const [index, info] of ORIGINAL_STUDY_DEMO.entries()) {
      const mesh = new Mesh(geometry, material);
      mesh.name = info.sourceName;
      mesh.position.set(index + 0.45, 0, 0);
      group.add(mesh);
    }
    const { GLTFExporter } = await import("three/addons/exporters/GLTFExporter.js");
    const bytes = await new Promise<ArrayBuffer>((resolve, reject) => {
      new GLTFExporter().parse(
        group,
        (gltf) => {
          if (gltf instanceof ArrayBuffer) resolve(gltf);
          else reject(new Error("Generated study scene is not a binary GLB"));
        },
        reject,
        { binary: true, trs: true, onlyVisible: true },
      );
    });
    if (bytes.byteLength === 0 || bytes.byteLength > 2_000_000) {
      throw new Error("Generated original study scene has an invalid byte size");
    }
    return new File([bytes], "MagicMirror-original-3box-study.glb", {
      type: "model/gltf-binary",
    });
  } finally {
    geometry.dispose();
    material.dispose();
  }
}
