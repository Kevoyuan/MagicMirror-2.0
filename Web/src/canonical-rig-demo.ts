import {
  AnimationClip, Bone, BufferGeometry, Float32BufferAttribute,
  Group, MeshStandardMaterial, Quaternion, QuaternionKeyframeTrack,
  Skeleton, SkinnedMesh, Uint16BufferAttribute, Vector3,
} from "three";
import {
  auditCanonicalRigRest, CANONICAL_RIG_REST,
  auditProposedWeightSamples, type CanonicalRigJointId,
  type RigWeightObservation,
} from "./canonical-rig";

/**
 * An original, authored, 19-bone, fully skin-weighted GLB with
 * full-body parent hierarchy, blended cylinder surface, and test animation.
 * It is a TECHNICAL mannequin, NOT a licensed anatomical mesh,
 * patient-specific bones, physical skeleton or calibrated camera overlay.
 * No assets or camera data are downloaded.
 */
export async function createOriginalCanonicalRigFile(): Promise<File> {
  const restAudit = auditCanonicalRigRest(CANONICAL_RIG_REST);
  if (restAudit.status !== "plausible-original-fixture") {
    throw new Error("Authored rig topology is invalid");
  }
  const scene = new Group();
  scene.name = "MagicMirror_Original_Canonical_Skinning_Study";
  const points = new Map<string, Vector3>();
  const bones = new Map<CanonicalRigJointId, Bone>();
  const ordered: Bone[] = [];
  const indices = new Map<string, number>();
  for (const joint of CANONICAL_RIG_REST) {
    const p = new Vector3(...joint.position);
    points.set(joint.id, p);
    const bone = new Bone();
    bone.name = joint.id;
    if (joint.parent !== null) {
      const parent = bones.get(joint.parent);
      const parentPoint = points.get(joint.parent);
      if (!parent || !parentPoint) throw new Error("Fixture joint parent missing");
      bone.position.copy(p).sub(parentPoint);
      parent.add(bone);
    } else {
      bone.position.copy(p);
      scene.add(bone);
    }
    bones.set(joint.id, bone);
    indices.set(joint.id, ordered.length);
    ordered.push(bone);
  }
  const geometry = new BufferGeometry();
  const material = new MeshStandardMaterial({
    color: "#b8a47e", roughness: 0.72, metalness: 0.04,
  });
  try {
    const vertices: number[] = [];
    const weights: number[] = [];
    const joints: number[] = [];
    const faces: number[] = [];
    const samples: RigWeightObservation[] = [];
    const ringSides = 8;
    const ringSteps = 4;
    for (const joint of CANONICAL_RIG_REST) {
      if (joint.parent === null) continue;
      const a = points.get(joint.parent)!;
      const b = points.get(joint.id)!;
      const tangent = new Vector3().subVectors(b, a).normalize();
      const helper = Math.abs(tangent.dot(new Vector3(0, 0, 1))) > 0.93
        ? new Vector3(0, 1, 0) : new Vector3(0, 0, 1);
      const basisU = new Vector3().crossVectors(tangent, helper).normalize();
      const basisV = new Vector3().crossVectors(tangent, basisU).normalize();
      const stem = vertices.length / 3;
      const jointA = indices.get(joint.parent)!;
      const jointB = indices.get(joint.id)!;
      const radius = joint.id.includes("hip") || joint.id.includes("knee")
        ? 0.074 : joint.id === "chest" || joint.id === "spine" ? 0.105 : 0.052;
      for (let ring = 0; ring <= ringSteps; ring++) {
        const t = ring / ringSteps;
        const center = new Vector3().lerpVectors(a, b, t);
        for (let side = 0; side < ringSides; side++) {
          const angle = 2 * Math.PI * side / ringSides;
          const q = center.clone()
            .addScaledVector(basisU, Math.cos(angle) * radius)
            .addScaledVector(basisV, Math.sin(angle) * radius);
          vertices.push(q.x, q.y, q.z);
          joints.push(jointA, jointB, 0, 0);
          weights.push(1 - t, t, 0, 0);
          samples.push({
            vertexIndex: samples.length,
            influences: t === 0
              ? [{ joint: joint.parent, weight: 1 }]
              : t === 1
                ? [{ joint: joint.id, weight: 1 }]
                : [
                  { joint: joint.parent, weight: 1 - t },
                  { joint: joint.id, weight: t },
                ],
          });
        }
        if (ring > 0) {
          const first = stem + (ring - 1) * ringSides;
          const second = stem + ring * ringSides;
          for (let side = 0; side < ringSides; side++) {
            const next = (side + 1) % ringSides;
            faces.push(
              first + side, second + side, first + next,
              first + next, second + side, second + next,
            );
          }
        }
      }
    }
    const audit = auditProposedWeightSamples(samples.length, samples);
    if (audit.badIndices || audit.unweighted ||
        audit.badNormalization || audit.badJointReferences ||
        audit.tooManyInfluences) {
      throw new Error("Generated original skin influences failed source checks");
    }
    geometry.setAttribute("position", new Float32BufferAttribute(vertices, 3));
    geometry.setAttribute("skinIndex", new Uint16BufferAttribute(joints, 4));
    geometry.setAttribute("skinWeight", new Float32BufferAttribute(weights, 4));
    geometry.setIndex(faces);
    geometry.computeVertexNormals();

    const skinned = new SkinnedMesh(geometry, material);
    skinned.name = "MM_ORIGINAL_19_JOINT_SKIN";
    skinned.frustumCulled = false;
    scene.add(skinned);
    scene.updateMatrixWorld(true);
    skinned.bind(new Skeleton(ordered));

    const q0 = [0, 0, 0, 1];
    const clips = [
      ["left_elbow", -0.65],
      ["right_elbow", 0.65],
      ["left_knee", 0.35],
      ["right_knee", -0.35],
    ] as const;
    const axes = new Vector3(0, 0, 1);
    const tracks = clips.map(([name, angle]) => {
      const bend = new Quaternion().setFromAxisAngle(axes, angle).toArray();
      return new QuaternionKeyframeTrack(
        `${name}.quaternion`, [0, 0.95, 1.9],
        [...q0, ...bend, ...q0],
      );
    });
    const motion = new AnimationClip("Original joint-bend study (not human pose)", 1.9, tracks);
    const { GLTFExporter } = await import("three/addons/exporters/GLTFExporter.js");
    const buffer = await new Promise<ArrayBuffer>((resolve, reject) => {
      new GLTFExporter().parse(
        scene,
        gltf => {
          if (gltf instanceof ArrayBuffer) resolve(gltf);
          else reject(new Error("Canonical rig fixture did not export binary GLB"));
        },
        reject,
        { binary: true, trs: true, onlyVisible: true, animations: [motion] },
      );
    });
    if (buffer.byteLength < 512 || buffer.byteLength > 3_000_000) {
      throw new Error("Canonical rig fixture exceeds the local demonstration budget");
    }
    return new File(
      [buffer], "MagicMirror-original-canonical-19-joint-skin.glb",
      { type: "model/gltf-binary" },
    );
  } finally {
    geometry.dispose();
    material.dispose();
  }
}
