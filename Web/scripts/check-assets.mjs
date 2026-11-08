import { createHash } from "node:crypto";
import { readFile, stat } from "node:fs/promises";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const sha = (b) => createHash("sha256").update(b).digest("hex");
const model = resolve(root, "public/models/pose_landmarker_lite.task");
const expected = "59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a";
let data;
try {
  data = await readFile(model);
  const wasmJS = await stat(resolve(root, "public/wasm/vision_wasm_internal.js"));
  const wasm = await stat(resolve(root, "public/wasm/vision_wasm_internal.wasm"));
  if (!wasmJS.isFile() || !wasm.isFile() || wasm.size === 0) throw new Error("Invalid MediaPipe WASM files");
} catch {
  throw new Error("Runtime assets not staged. Run 'npm run stage:assets' first.");
}
if (data.length !== 5_777_746 || sha(data) !== expected) throw new Error("Pose model digest mismatch");
console.log("Local development assets verified. This does NOT confer model redistribution rights.");
