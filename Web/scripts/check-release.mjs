/** Fail-closed public site deployment gate; not a replacement for human IP review. */
import { readFile, readdir } from "node:fs/promises";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const clearance = JSON.parse(await readFile(resolve(root, "release-clearance.json"), "utf8"));
const model = clearance.runtimeModel;
const review = clearance.review;
const dep = clearance.thirdPartyRuntime;
const anatomy = clearance.anatomy;
const checked = (
  clearance.schemaVersion === 1 &&
  clearance.distribution === "public-web-static" &&
  clearance.releaseApproved === true &&
  review && review.legalReviewCompleted === true &&
  review.privacyMetricsReviewed === true &&
  typeof review.reviewer === "string" && review.reviewer.trim().length > 0 &&
  typeof review.reviewDate === "string" && /^\d{4}-\d{2}-\d{2}$/.test(review.reviewDate) &&
  !Number.isNaN(Date.parse(review.reviewDate)) &&
  new Date(review.reviewDate).getTime() <= Date.now() &&
  typeof review.evidenceReference === "string" && review.evidenceReference.trim().length > 0 &&
  model && model.file === "models/pose_landmarker_lite.task" &&
  model.sha256 === "59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a" &&
  model.publicWebDistributionReviewed === true &&
  typeof model.redistributionLicenseEvidence === "string" &&
  model.redistributionLicenseEvidence.trim().length > 0 &&
  dep && dep.package === "@mediapipe/tasks-vision" && dep.version === "1.2.2" &&
  dep.license === "Apache-2.0" && dep.dependencyNoticesReviewed === true &&
  anatomy && anatomy.source === "original-procedural-proxy-only" &&
  anatomy.containsExternalMesh === false && anatomy.zAnatomyOriginalMeshesIncluded === false
);
if (!checked) {
  throw new Error("PUBLIC WEB RELEASE BLOCKED: independent PoseLandmarker weight redistribution, privacy/metrics and third-party license checks not approved. Do not alter the booleans to bypass genuine review.");
}
const forbidden = [".fbx", ".obj", ".glb", ".gltf", ".usdz", ".mmgeom"];
async function walk(dir) {
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    if (entry.isSymbolicLink()) throw new Error("No symlinked assets in public release");
    const name = entry.name.toLowerCase();
    if (forbidden.some((ext) => name.endsWith(ext))) {
      throw new Error(`PUBLIC WEB RELEASE BLOCKED: external anatomy asset found: ${name}`);
    }
    if (entry.isDirectory()) await walk(resolve(dir, entry.name));
  }
}
await walk(resolve(root, "public"));
console.log("Public release metadata check passed. Human rights and privacy review must be real.");
