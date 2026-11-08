import { createHash } from "node:crypto";
import { copyFile, mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import { resolve, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const wasmRoot = resolve(root, "node_modules/@mediapipe/tasks-vision/wasm");
const outWasm = resolve(root, "public/wasm");
const outModel = resolve(root, "public/models/pose_landmarker_lite.task");
const url = "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/latest/pose_landmarker_lite.task";
const expectedSize = 5_777_746;
const expectedSHA = "59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a";
const sha256 = (buf) => createHash("sha256").update(buf).digest("hex");

await mkdir(outWasm, { recursive: true });
await mkdir(dirname(outModel), { recursive: true });
const wasmNames = (await readdir(wasmRoot)).filter((name) =>
  /^vision_wasm_(internal|nothreads|simd).+\.(js|wasm)$/.test(name) ||
  /^vision_wasm_internal\.(js|wasm)$/.test(name)
);
if (!wasmNames.includes("vision_wasm_internal.js") ||
    !wasmNames.includes("vision_wasm_internal.wasm")) {
  throw new Error("MediaPipe WASM loader layout changed. Check the pinned package before distributing.");
}
for (const name of wasmNames) await copyFile(join(wasmRoot, name), join(outWasm, name));
console.log("Staged local MediaPipe WASM from pinned package:", wasmNames.join(", "));

let data;
try {
  data = await readFile(outModel);
} catch {
  console.log("Downloading a pinned developer-only model (license review still required) …");
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Pose model download failed: HTTP ${response.status}`);
  data = Buffer.from(await response.arrayBuffer());
}
if (data.length !== expectedSize || sha256(data) !== expectedSHA) {
  throw new Error(`Model bytes changed: got ${data.length}B, sha256=${sha256(data)}. Refusing to stage.`);
}
await writeFile(outModel, data);
console.log(`Validated model: ${data.length} B / SHA-256 ${expectedSHA}`);
console.log("IMPORTANT: developer testing only; release needs independent model-weight rights/privacy review.");
