/** Pure generated perspective target for W3d tests; no camera or user data. */
import type { CameraEvidenceFile, EvidenceSource } from "./camera-evidence";

export function makeSyntheticCameraEvidence(
  provenance: EvidenceSource = "synthetic-fixture",
): CameraEvidenceFile {
  const fx = 560, fy = 540, cx = 400, cy = 300, depth = 3;
  const captures = ["reference", "holdout"].map((split, index) => ({
    id: split + "-capture",
    split: split as "reference" | "holdout",
    points: Array.from({ length: 8 }, (_, j) => {
      const n = index * 8 + j;
      const x = (n % 4 - 1.5) * 0.28;
      const y = (Math.floor(n / 4) - 1.5) * 0.28;
      const z = (n % 3 - 1) * 0.18;
      return {
        id: split + "-" + j,
        world: [x, y, z] as [number, number, number],
        // Independently authored synthetic pinhole truth, not a call
        // to the evaluator under test.
        image: [
          cx + fx * x / (depth + z),
          cy + fy * y / (depth + z),
        ] as [number, number],
      };
    }),
  }));
  return {
    schemaVersion: 1,
    kind: "magicmirror.camera-evidence",
    provenance,
    cameraModel: "pinhole-no-distortion",
    units: "meters-declared",
    intrinsics: {
      imageWidth: 800, imageHeight: 600, fx, fy, cx, cy,
    },
    worldToCamera: {
      rotation: [1, 0, 0, 0, 1, 0, 0, 0, 1],
      translation: [0, 0, depth],
    },
    captures,
  };
}
