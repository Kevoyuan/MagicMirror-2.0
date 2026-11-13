import { describe, expect, it } from "vitest";
import { reviewCameraEvidence, MAX_CAMERA_EVIDENCE_BYTES } from "./camera-evidence";
import { makeSyntheticCameraEvidence } from "./camera-evidence-fixture";

function sample(): any {
  return JSON.parse(JSON.stringify(makeSyntheticCameraEvidence()));
}
describe("W3d offline camera evidence: source-locked, disjoint holdout, nonapproval", () => {
  it("accepts generated 3D target geometry but NEVER marks calibration approved", () => {
    const result = reviewCameraEvidence(sample());
    expect(result.outcome).toBe("synthetic-consistent");
    expect(result.provenance).toBe("synthetic-fixture");
    expect(result.sourceCaptures).toBe(2);
    expect(result.reference.count).toBe(8);
    expect(result.holdout.count).toBe(8);
    expect(result.reference.rmsePx).toBeLessThan(1e-8);
    expect(result.holdout.rmsePx).toBeLessThan(1e-8);
    expect(result.cameraCalibrationApproved).toBe(false);
    expect(result.anatomyOverlayApproved).toBe(false);
    expect(result.sourceAuthenticityVerified).toBe(false);
  });
  it("keeps claimed external calibration UNVERIFIED, even for perfect coordinates", () => {
    const s = makeSyntheticCameraEvidence("external-unverified");
    const result = reviewCameraEvidence(s);
    expect(result.outcome).toBe("external-consistent-unverified");
    expect(result.cameraCalibrationApproved).toBe(false);
    expect(result.sourceAuthenticityVerified).toBe(false);
  });
  it("detects a mislabeled/wrong holdout observation and reports error without geometry", () => {
    const s = sample();
    s.captures[1].points[0].image[0] += 100;
    const result = reviewCameraEvidence(s);
    expect(result.outcome).toBe("inconsistent");
    expect(result.holdout.p95Px).toBeGreaterThan(99);
    expect(result.cameraCalibrationApproved).toBe(false);
    expect(JSON.stringify(result)).not.toContain("world");
  });
  it("rejects a non-rigid/reflected hypothesis and invalid intrinsics", () => {
    const s = sample();
    s.worldToCamera.rotation[0] = -1;
    expect(() => reviewCameraEvidence(s)).toThrow(/perspective model/);
    s.worldToCamera.rotation[0] = 1;
    s.intrinsics.fx = 0;
    expect(() => reviewCameraEvidence(s)).toThrow(/perspective model/);
  });
  it("rejects bad dimensions, unknown coordinate conventions, or nonnumerical axes", () => {
    const s = sample();
    s.intrinsics.imageWidth = 99999;
    expect(() => reviewCameraEvidence(s)).toThrow();
    s.intrinsics.imageWidth = 800;
    s.intrinsics.fy = "540";
    expect(() => reviewCameraEvidence(s)).toThrow(/numeric/);
    s.intrinsics.fy = 540;
    s.units = "pixels";
    expect(() => reviewCameraEvidence(s)).toThrow(/format/);
  });
  it("refuses untrusted extra PII/camera frame fields throughout evidence schema", () => {
    const s = sample();
    s.deviceId = "hardware-identifier";
    expect(() => reviewCameraEvidence(s)).toThrow(/unsupported fields/);
    delete s.deviceId;
    s.captures[0].points[0].video = "base64-image";
    expect(() => reviewCameraEvidence(s)).toThrow(/unsupported fields/);
    delete s.captures[0].points[0].video;
    s.captures[0].notes = "private-details";
    expect(() => reviewCameraEvidence(s)).toThrow(/unsupported fields/);
  });
  it("rejects false holdout independence and duplicate capture/point identities", () => {
    const s = sample();
    s.captures[1].points[0].id = s.captures[0].points[0].id;
    expect(() => reviewCameraEvidence(s)).toThrow(/disjoint/);
    s.captures[1].points[0].id = "holdout-0";
    s.captures[1].id = s.captures[0].id;
    expect(() => reviewCameraEvidence(s)).toThrow(/identity/);
    s.captures[1].id = "holdout-capture";
    s.captures[0].points[1].id = s.captures[0].points[0].id;
    expect(() => reviewCameraEvidence(s)).toThrow(/point identity/);
  });
  it("refuses planar, degenerate, or truncated 3D evidence", () => {
    const s = sample();
    for (const c of s.captures) for (const p of c.points) p.world[2] = 0;
    expect(() => reviewCameraEvidence(s)).toThrow(/planar/);
    const t = sample();
    t.captures[1].points = t.captures[1].points.slice(0, 4);
    expect(() => reviewCameraEvidence(t)).toThrow(/point count/);
  });
  it("rejects invalid depth for an otherwise rigid camera, without rendering points", () => {
    const s = sample();
    s.worldToCamera.translation[2] = -2.5;
    const result = reviewCameraEvidence(s);
    expect(result.outcome).toBe("invalid-depth");
    expect(result.rejectedDepthPoints).toBe(16);
    expect(result.holdout.count).toBe(0);
    expect(result.cameraCalibrationApproved).toBe(false);
  });
  it("rejects offscreen, nonfinite and malformed measured 2D observations", () => {
    const s = sample();
    s.captures[0].points[0].image[0] = -1;
    expect(() => reviewCameraEvidence(s)).toThrow(/outside/);
    s.captures[0].points[0].image[0] = 400;
    s.captures[0].points[0].world[1] = null;
    expect(() => reviewCameraEvidence(s)).toThrow(/numeric/);
  });
  it("limits capture count and total observations", () => {
    const s = sample();
    s.captures = Array.from({ length: 9 }, (_, i) => ({
      ...s.captures[0], id: "ref-" + i,
    }));
    expect(() => reviewCameraEvidence(s)).toThrow(/2–8/);
    expect(MAX_CAMERA_EVIDENCE_BYTES).toBe(131072);
  });
  it("rejects synthetic fixture forged as an approved status", () => {
    const s = sample();
    s.cameraCalibrationApproved = true;
    expect(() => reviewCameraEvidence(s)).toThrow(/unsupported fields/);
    delete s.cameraCalibrationApproved;
    s.provenance = "device-certified";
    expect(() => reviewCameraEvidence(s)).toThrow(/format/);
  });
});
