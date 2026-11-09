/**
 * W3a controller: the ONLY bridge between the camera inference pipeline and
 * the experimental Three.js rig. main.ts stays an orchestrator: it owns the
 * camera session, switches modes and renders status, but holds no rig math
 * and no per-frame Three.js state.
 *
 * The rig shares the EXISTING overlay WebGLRenderer/camera/scene through
 * `OverlayRenderHost`; no second renderer, camera stream or RAF loop is added.
 */
import type { Object3D } from "three";
import type { InferenceFrame } from "../telemetry";
import type { Focus } from "../pose";
import {
  LiveRigTracker, type RigFrame, type RigObservation,
} from "./pose-to-rig";
import { OriginalArticulatedRig } from "./original-rig";

export type OverlayMode = "proxy" | "rig";

export interface OverlayViewport {
  readonly width: number;
  readonly height: number;
}

/** Structural interface implemented by ProxySkeletonRenderer in scene.ts. */
export interface OverlayRenderHost {
  attach(object: Object3D): void;
  detach(object: Object3D): void;
  hideProxy(): void;
  render(): void;
  renderForCapture(): void;
  /** Exact display-space size of the EXISTING orthographic overlay camera. */
  viewport(): OverlayViewport;
}

export interface RigFrameContext {
  readonly session: number;
  readonly nowMs: number;
  readonly mirrored: boolean;
  readonly focus: Focus;
  readonly opacity: number;
  readonly stabilizing: boolean;
}

export interface RigFrameOutcome {
  readonly visibleSegments: number;
  readonly status: RigFrame["status"];
  readonly reasons: readonly string[];
  readonly active: boolean;
}

const inactive = (reasons: readonly string[]): RigFrameOutcome => ({
  visibleSegments: 0, status: "rejected", reasons, active: false,
});

export class LiveRigOverlay {
  private mode: OverlayMode = "proxy";
  private rig?: OriginalArticulatedRig;
  private readonly tracker = new LiveRigTracker();
  /** Last AUTHORITATIVE camera context accepted by this controller. */
  private contextSession: number | undefined;

  constructor(private readonly host: OverlayRenderHost) {}

  get currentMode(): OverlayMode { return this.mode; }
  get authoritativeSession(): number | undefined { return this.contextSession; }

  /** Returns false when the experimental renderer could not be created. */
  setMode(next: OverlayMode): boolean {
    if (next === "proxy") {
      this.tracker.reset();
      this.rig?.hide();
      this.host.hideProxy();
      this.host.render();
      this.mode = "proxy";
      return true;
    }
    try {
      if (!this.rig) {
        this.rig = new OriginalArticulatedRig();
        this.host.attach(this.rig.root);
      }
      this.tracker.reset();
      this.rig.reset();
      this.host.hideProxy();
      this.host.render();
      this.mode = "rig";
      return true;
    } catch (error) {
      // Fail closed: NEVER leave a half-built experimental overlay visible.
      console.error("Original rig renderer unavailable; reverting to proxy", error);
      this.disposeRig();
      this.tracker.reset();
      this.mode = "proxy";
      this.host.hideProxy();
      this.host.render();
      return false;
    }
  }

  /** One validated inference frame -> pure gate -> articulated rig -> render. */
  apply(frame: InferenceFrame, context: RigFrameContext): RigFrameOutcome {
    if (this.mode !== "rig" || !this.rig) return inactive(["PROXY_MODE"]);

    // Review fix (P1): the controller's OWN fail-closed session contract.
    // `context.session` is the authoritative camera session owned by main.ts.
    // A NEWER context must clear previously visible A geometry BEFORE any B
    // frame is drawn, even if main.ts forgot to call reset(). An OLDER context
    // is a late callback and must NOT remove geometry already accepted for B.
    // A stale frame within the current context is rejected without touching
    // the already accepted newer state either.
    if (this.contextSession !== undefined) {
      if (context.session < this.contextSession) {
        return inactive(["OLD_SESSION_CONTEXT"]);
      }
      if (context.session > this.contextSession) {
        this.reset();
        this.contextSession = context.session;
      }
    } else {
      this.contextSession = context.session;
    }

    if (frame.session !== context.session) return inactive(["OLD_SESSION"]);
    this.tracker.setStabilization(context.stabilizing);
    const viewport = this.host.viewport();
    const observation: RigObservation = {
      landmarks: frame.landmarks,
      session: frame.session,
      frameId: frame.frameId,
      capturedAtMs: frame.capturedAtMs,
      nowMs: context.nowMs,
      sourceWidth: frame.width,
      sourceHeight: frame.height,
      viewportWidth: viewport.width,
      viewportHeight: viewport.height,
      mirrored: context.mirrored,
      focus: context.focus,
    };
    const rigFrame = this.tracker.update(observation);
    const visibleSegments = this.rig.apply(rigFrame, context.opacity);
    this.host.render();
    return {
      visibleSegments,
      status: rigFrame.status,
      reasons: rigFrame.reasons,
      active: true,
    };
  }

  pause(): void {
    this.tracker.pause();
    this.rig?.hide();
    this.host.render();
  }

  resume(): void { this.tracker.resume(); }

  /** Tracking loss, stale result, overlay pause or mode switch. */
  hide(): void {
    this.rig?.hide();
    this.host.hideProxy();
    this.host.render();
  }

  /** Camera stop/restart, hidden tab, flip or worker recovery. */
  reset(): void {
    this.tracker.reset();
    this.hide();
  }

  /** Clear only transform history; keeps session/frame ordering intact. */
  clearTransforms(): void { this.tracker.clearTransforms(); }

  /** Explicit UI toggle; `apply` also keeps this in sync every frame. */
  setStabilization(enabled: boolean): void { this.tracker.setStabilization(enabled); }

  renderForCapture(): void { this.host.renderForCapture(); }

  dispose(): void {
    this.tracker.reset();
    this.disposeRig();
    this.mode = "proxy";
    this.contextSession = undefined;
  }

  private disposeRig(): void {
    if (!this.rig) return;
    this.host.detach(this.rig.root);
    this.rig.dispose();
    this.rig = undefined;
  }
}
