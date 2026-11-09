import {
  AmbientLight, AnimationMixer, Box3, Color, DirectionalLight, DoubleSide, Group,
  LoadingManager, Matrix4, Mesh, MeshBasicMaterial, MeshStandardMaterial, PerspectiveCamera, Plane, Raycaster,
  Scene, SphereGeometry, Vector2, Vector3, WebGLRenderer, type AnimationAction,
  type AnimationClip, type Object3D,
} from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { inspectLocalAtlasFile, normalizeSlice, sliceNormal,
  type SliceOrientation } from "./atlas-source";
import { effectivePartVisibility, sourcePathForPart, type AtlasPart } from "./atlas-catalog";
import { buildLocalAtlasInventory, type AtlasInventory } from "./atlas-inventory";
import { inspectRigSamples, usableAnimationStudyClip, type AnimationStudyClip } from "./rig-diagnostics";
import { validSourcePoint, type AnchorEndpoint, type SourcePoint3 } from "./atlas-anchors";
import {
  previewMeshLocalMatrix, transformedSourceEnd, validRigidSource,
  type SourceAxis,
} from "./rigid-preview";

interface LocalRigidPreview {
  readonly id: number;
  readonly originalMatrix: Matrix4;
  readonly originalAutoUpdate: boolean;
  readonly originalRootWorld: Matrix4;
  readonly originalParentWorld: Matrix4;
  readonly originalMeshWorld: Matrix4;
  readonly start: SourcePoint3;
  readonly end: SourcePoint3;
  axis: SourceAxis;
  angleDegrees: number;
}

interface LocalMeshEntry {
  readonly id: number;
  readonly mesh: Mesh;
  readonly name: string;
  readonly path: string;
  readonly triangles: number;
  userVisible: boolean;
}

export interface LocalAtlasStats {
  file: string;
  importedMeshes: number;
  triangles: number;
  skinnedMeshes: number;
  authoredJoints: number;
  hasUsableGeometry: boolean;
  rigSampledVertices: number;
  rigUnweightedSamples: number;
  rigInvalidWeightSamples: number;
  rigInvalidJointReferences: number;
  rigSuspiciousWeightSums: number;
  skinnedMeshesWithoutWeightAttributes: number;
  animationClips: number;
}

/**
 * Private educational model inspector. Does not retarget human poses,
 * upload source bytes, license models, or imply an anatomical coordinate frame.
 * Local files are never added to the Web distribution or network requests.
 */
export class LocalAtlasViewer {
  private readonly renderer: WebGLRenderer;
  private readonly scene = new Scene();
  private readonly camera = new PerspectiveCamera(40, 1, 0.01, 400);
  private readonly controls: OrbitControls;
  private readonly group = new Group();
  private readonly material = new MeshStandardMaterial({
    color: new Color("#d2c49e"), side: DoubleSide,
    metalness: 0.06, roughness: 0.62, transparent: true,
    opacity: 0.88, wireframe: false, clippingPlanes: [],
  });
  private readonly highlightMaterial = this.material.clone();
  private readonly slicePlane = new Plane(new Vector3(0, 1, 0), 0);
  private readonly raycaster = new Raycaster();
  private readonly mouse = new Vector2();
  private readonly anchorMarkerGeometry = new SphereGeometry(1, 12, 9);
  private readonly anchorMarkerMaterials = [
    new MeshBasicMaterial({ color: "#f0ba6d", depthTest: false }),
    new MeshBasicMaterial({ color: "#91d9b8", depthTest: false }),
  ];
  private readonly anchorMarkers: Mesh[] = [];
  private animationMixer?: AnimationMixer;
  private animationClips: AnimationClip[] = [];
  private activeAnimation?: AnimationAction;
  private animationPlaying = false;
  private lastAnimationFrameMs = 0;
  private frame = 0;
  private loaded = false;
  private loadGeneration = 0;
  private disposed = false;
  private lastLoaded?: Object3D;
  private parts: LocalMeshEntry[] = [];
  private isolatedPartId: number | null = null;
  private selectedPartId: number | null = null;
  private anchorPickTarget: { id: number; endpoint: AnchorEndpoint } | null = null;
  private displayedAnchorPoints: { start: SourcePoint3 | null; end: SourcePoint3 | null } | null = null;
  private rigidPreview: LocalRigidPreview | null = null;
  private sourceIdentity: {
    fileName: string;
    fileSizeBytes: number;
    sourceSHA256: string;
    importedMeshes: number;
    triangles: number;
    skinnedMeshes: number;
    authoredJoints: number;
    rigSamples?: {
      sampledVertices: number;
      unweightedVertices: number;
      invalidWeightSamples: number;
      invalidJointReferences: number;
      suspiciousWeightSums: number;
      skinnedMeshesWithoutWeightAttributes: number;
      previewableAnimationClips: number;
    };
  } | null = null;
  private previousPointer?: { x: number; y: number };
  onPartSelected: ((part: AtlasPart) => void) | undefined;
  onAnchorPicked: ((sample: {
    sourceMeshId: number;
    endpoint: AnchorEndpoint;
    originalRootLocalPoint: SourcePoint3;
  }) => void) | undefined;

  constructor(private readonly canvas: HTMLCanvasElement) {
    this.renderer = new WebGLRenderer({
      canvas, antialias: true, alpha: false, powerPreference: "low-power",
    });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    this.renderer.setClearColor("#192620");
    this.renderer.localClippingEnabled = true;
    this.highlightMaterial.color.set("#e9ac58");
    this.scene.add(new AmbientLight("#f9eed8", 1.8));
    const light = new DirectionalLight("#ffffff", 2.2);
    light.position.set(-4, 5, 6);
    this.scene.add(light);
    this.scene.add(this.group);
    for (const material of this.anchorMarkerMaterials) {
      const marker = new Mesh(this.anchorMarkerGeometry, material);
      marker.visible = false;
      marker.renderOrder = 999;
      marker.scale.setScalar(0.05);
      this.scene.add(marker);
      this.anchorMarkers.push(marker);
    }
    this.camera.position.set(1, 1.1, 8);
    this.controls = new OrbitControls(this.camera, canvas);
    this.controls.enableDamping = true;
    this.controls.minDistance = 0.08;
    this.controls.maxDistance = 60;
    this.controls.target.set(0, 0, 0);
    this.controls.update();
    canvas.addEventListener("pointerdown", this.onPointerDown);
    canvas.addEventListener("pointerup", this.onPointerUp);
    this.resize();
    this.render();
  }

  resize(): void {
    const width = Math.max(1, this.canvas.clientWidth);
    const height = Math.max(1, this.canvas.clientHeight);
    this.camera.aspect = width / height;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(width, height, false);
    this.render();
  }

  start(): void {
    if (this.frame) return;
    const tick = (nowMs: number) => {
      if (this.animationPlaying && this.animationMixer) {
        const delta = this.lastAnimationFrameMs === 0
          ? 0
          : Math.max(0, Math.min(0.08, (nowMs - this.lastAnimationFrameMs) / 1000));
        this.animationMixer.update(delta);
      }
      this.lastAnimationFrameMs = nowMs;
      this.controls.update();
      this.render();
      this.frame = window.requestAnimationFrame(tick);
    };
    this.frame = window.requestAnimationFrame(tick);
  }

  stop(): void {
    if (this.frame) cancelAnimationFrame(this.frame);
    this.frame = 0;
    this.lastAnimationFrameMs = 0;
  }

  cancelPendingLoad(): void {
    this.loadGeneration++;
    this.anchorPickTarget = null;
    this.resetRigidPreview();
  }

  setWireframe(enabled: boolean): void {
    this.material.wireframe = enabled;
    this.highlightMaterial.wireframe = enabled;
    this.material.needsUpdate = true;
    this.highlightMaterial.needsUpdate = true;
    this.render();
  }

  setOpacity(value: number): void {
    this.material.opacity = Math.max(0.15, Math.min(1, value));
    this.highlightMaterial.opacity = this.material.opacity;
    this.render();
  }

  setSection(orientation: SliceOrientation, percent: number): void {
    const normal = sliceNormal(orientation);
    if (!normal) {
      this.material.clippingPlanes = [];
    } else {
      this.slicePlane.normal.set(...normal);
      // The viewer normalizes its model to a roughly 5-unit bounding box.
      // These slices are in MODEL-SPACE axes, not medically verified planes.
      this.slicePlane.constant = -normalizeSlice(percent) * 2.6;
      this.material.clippingPlanes = [this.slicePlane];
    }
    this.highlightMaterial.clippingPlanes = this.material.clippingPlanes;
    this.material.needsUpdate = true;
    this.highlightMaterial.needsUpdate = true;
    this.render();
  }

  /**
   * Stable original source hierarchy, with no inferred bone names. Returned
   * objects contain no source geometry, and are only used for local UI.
   */
  getParts(): AtlasPart[] {
    return this.parts.map((part) => ({
      id: part.id,
      name: part.name,
      path: part.path,
      triangles: part.triangles,
      visible: part.mesh.visible,
    }));
  }

  sourceInventory(): AtlasInventory | null {
    if (!this.sourceIdentity || !this.loaded) return null;
    return buildLocalAtlasInventory({
      ...this.sourceIdentity,
      parts: this.getParts(),
    });
  }

  getIsolatedPartId(): number | null { return this.isolatedPartId; }
  getSelectedPartId(): number | null { return this.selectedPartId; }

  /**
   * Purely local click-based model-space reference point selection.
   * Does not generate joints, skin weights, rest-pose truth or camera calibration.
   */
  beginAnchorPick(id: number, endpoint: AnchorEndpoint): boolean {
    this.resetRigidPreview();
    const entry = this.findPart(id);
    if (!entry || !entry.mesh.visible || this.animationPlaying ||
        (endpoint !== "start" && endpoint !== "end")) return false;
    this.anchorPickTarget = { id, endpoint };
    this.selectPart(id);
    return true;
  }

  cancelAnchorPick(): void { this.anchorPickTarget = null; }

  /** Visual markers are overlay UI, not imported source geometry or a real joint. */
  showAnchorMarkers(points: {
    start: SourcePoint3 | null;
    end: SourcePoint3 | null;
  } | null): void {
    this.displayedAnchorPoints = points;
    this.lastLoaded?.updateWorldMatrix(true, false);
    for (const [index, point] of [points?.start ?? null, points?.end ?? null].entries()) {
      const marker = this.anchorMarkers[index];
      if (!marker) continue;
      marker.visible = Boolean(point && this.lastLoaded);
      if (point && this.lastLoaded) {
        const movingEnd = index === 1 && this.rigidPreview
          ? transformedSourceEnd(
            this.rigidPreview.start, this.rigidPreview.end,
            this.rigidPreview.axis, this.rigidPreview.angleDegrees
          ) : null;
        const position = movingEnd ?? point;
        marker.position.copy(this.lastLoaded.localToWorld(
          new Vector3(position[0], position[1], position[2])
        ));
      }
    }
    this.render();
  }

  /** Only ONE non-skinned, unanimated original mesh can be previewed. */
  beginRigidPreview(id: number, points: {
    start: SourcePoint3 | null;
    end: SourcePoint3 | null;
  }): boolean {
    const entry = this.findPart(id);
    if (!entry || !entry.mesh.visible || !this.lastLoaded ||
        (entry.mesh as import("three").SkinnedMesh).isSkinnedMesh ||
        this.animationClips.length > 0 || this.animationPlaying ||
        !validRigidSource(points.start, points.end)) return false;
    this.resetRigidPreview();
    const mesh = entry.mesh;
    mesh.updateWorldMatrix(true, false);
    const parent = mesh.parent;
    if (!parent) return false;
    this.lastLoaded.updateWorldMatrix(true, false);
    this.rigidPreview = {
      id,
      originalMatrix: mesh.matrix.clone(),
      originalAutoUpdate: mesh.matrixAutoUpdate,
      originalRootWorld: this.lastLoaded.matrixWorld.clone(),
      originalParentWorld: parent.matrixWorld.clone(),
      originalMeshWorld: mesh.matrixWorld.clone(),
      start: [...points.start],
      end: [...points.end!],
      axis: "z",
      angleDegrees: 0,
    };
    this.showAnchorMarkers(points);
    return true;
  }

  getRigidPreviewPartId(): number | null { return this.rigidPreview?.id ?? null; }

  /**
   * Always derive from baseline matrices. Never mutate source geometry or
   * attempt joint hierarchy/skin deformation. This is a reversible study
   * transform in ORIGINAL model-root space, unrelated to camera pose.
   */
  setRigidPreview(axis: SourceAxis, degrees: number): boolean {
    const state = this.rigidPreview;
    const entry = state ? this.findPart(state.id) : undefined;
    if (!state || !entry || !entry.mesh.visible || !this.lastLoaded ||
        this.animationPlaying) return false;
    const nextMatrix = previewMeshLocalMatrix(
      state.originalRootWorld, state.originalParentWorld,
      state.originalMeshWorld, state.start, state.end,
      axis, degrees
    );
    if (!nextMatrix) return false;
    state.axis = axis;
    state.angleDegrees = degrees;
    entry.mesh.matrixAutoUpdate = false;
    entry.mesh.matrix.copy(nextMatrix);
    entry.mesh.matrixWorldNeedsUpdate = true;
    entry.mesh.updateWorldMatrix(true, true);
    this.showAnchorMarkers(this.displayedAnchorPoints);
    return true;
  }

  resetRigidPreview(): void {
    const state = this.rigidPreview;
    this.rigidPreview = null;
    if (!state) return;
    const entry = this.findPart(state.id);
    if (entry) {
      entry.mesh.matrix.copy(state.originalMatrix);
      entry.mesh.matrixAutoUpdate = state.originalAutoUpdate;
      entry.mesh.matrixWorldNeedsUpdate = true;
      entry.mesh.updateWorldMatrix(true, true);
    }
    this.showAnchorMarkers(this.displayedAnchorPoints);
  }

  getAnimationClips(): AnimationStudyClip[] {
    return this.animationClips.map((clip, id) => ({
      id,
      name: clip.name || `Clip ${id + 1}`,
      durationSeconds: clip.duration,
      trackCount: clip.tracks.length,
    }));
  }

  selectAnimation(id: number): boolean {
    const clip = this.animationClips[id];
    if (!clip || !this.animationMixer || !Number.isSafeInteger(id)) return false;
    this.animationMixer.stopAllAction();
    this.activeAnimation = this.animationMixer.clipAction(clip);
    this.activeAnimation.reset().play();
    this.activeAnimation.paused = true;
    this.animationPlaying = false;
    this.lastAnimationFrameMs = 0;
    this.render();
    return true;
  }

  setAnimationPlaying(playing: boolean): boolean {
    if (!this.activeAnimation || (playing && this.rigidPreview)) return false;
    this.activeAnimation.paused = !playing;
    this.animationPlaying = playing;
    this.lastAnimationFrameMs = 0;
    return true;
  }

  private findPart(id: number): LocalMeshEntry | undefined {
    return Number.isSafeInteger(id) && id >= 0 ? this.parts[id] : undefined;
  }

  private clearSelection(): void {
    if (this.selectedPartId !== null) {
      const selected = this.findPart(this.selectedPartId);
      if (selected) selected.mesh.material = this.material;
    }
    this.selectedPartId = null;
  }

  selectPart(id: number): AtlasPart | null {
    const selected = this.findPart(id);
    if (!selected || !selected.mesh.visible) return null;
    if (this.rigidPreview && this.rigidPreview.id !== id) this.resetRigidPreview();
    this.clearSelection();
    this.selectedPartId = id;
    selected.mesh.material = this.highlightMaterial;
    this.render();
    return { id, name: selected.name, path: selected.path,
      triangles: selected.triangles, visible: true };
  }

  private applyVisibility(): void {
    if (this.rigidPreview &&
        !this.findPart(this.rigidPreview.id)?.mesh.visible) {
      this.resetRigidPreview();
    }
    for (const part of this.parts) {
      part.mesh.visible = effectivePartVisibility(
        part.userVisible, part.id, this.isolatedPartId
      );
    }
    if (this.rigidPreview &&
        !this.findPart(this.rigidPreview.id)?.mesh.visible) this.resetRigidPreview();
    if (this.selectedPartId !== null &&
        !this.findPart(this.selectedPartId)?.mesh.visible) this.clearSelection();
    this.render();
  }

  setPartVisibility(id: number, visible: boolean): boolean {
    const entry = this.findPart(id);
    if (!entry) return false;
    // A manual show/hide leaves single-part isolation mode.
    this.isolatedPartId = null;
    entry.userVisible = visible;
    this.applyVisibility();
    return true;
  }

  isolatePart(id: number): boolean {
    if (!this.findPart(id)) return false;
    this.isolatedPartId = id;
    this.applyVisibility();
    return true;
  }

  showAllParts(): void {
    this.isolatedPartId = null;
    for (const part of this.parts) part.userVisible = true;
    this.applyVisibility();
  }

  restorePartVisibility(): void {
    this.isolatedPartId = null;
    this.applyVisibility();
  }

  /** Focus the original selected mesh; do not infer anatomical coordinates. */
  focusPart(id: number): boolean {
    const part = this.findPart(id);
    if (!part || !part.mesh.visible) return false;
    const bounds = new Box3().setFromObject(part.mesh);
    const center = bounds.getCenter(new Vector3());
    const radius = bounds.getSize(new Vector3()).length() / 2;
    if (!Number.isFinite(radius) || radius < 1e-7 ||
        ![center.x, center.y, center.z].every(Number.isFinite)) return false;
    const direction = this.camera.position.clone().sub(this.controls.target);
    if (direction.lengthSq() < 1e-8) direction.set(1, 1, 2);
    direction.normalize();
    const distance = Math.max(0.16, radius / Math.tan(this.camera.fov * Math.PI / 360) * 1.9);
    this.controls.target.copy(center);
    this.camera.position.copy(center).addScaledVector(direction, distance);
    this.camera.near = Math.max(0.001, distance / 3000);
    this.camera.updateProjectionMatrix();
    this.controls.update();
    this.render();
    return true;
  }

  resetView(): void {
    if (!this.loaded) return;
    this.camera.position.set(1, 1, 8);
    this.camera.near = 0.01;
    this.camera.updateProjectionMatrix();
    this.controls.target.set(0, 0, 0);
    this.controls.update();
    this.render();
  }

  private localOnlyLoaderManager(): LoadingManager {
    const manager = new LoadingManager();
    // Untrusted FBX/GLB files may refer to remote textures/resources.
    // Reject actual network fetches: use a harmless 1x1 pixel instead.
    // Keep embedded local data/blob URIs, never expose original bytes.
    const pixel = "data:image/png;base64," +
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAF" +
      "gAI/ScLttAAAAABJRU5ErkJggg==";
    manager.setURLModifier((url) =>
      /^(data:|blob:)/i.test(url) ? url : pixel
    );
    return manager;
  }

  async load(file: File): Promise<LocalAtlasStats> {
    if (this.disposed) throw new Error("Model inspector was closed.");
    const generation = ++this.loadGeneration;
    const checkActive = () => {
      if (this.disposed || generation !== this.loadGeneration) {
        throw new Error("Local model import canceled.");
      }
    };
    const format = inspectLocalAtlasFile(file);
    // Read the file once and parse locally; no fetch(URL.createObjectURL)
    // which could accidentally leak the file to a remote worker/CDN.
    const bytes = await file.arrayBuffer();
    checkActive();
    if (!crypto.subtle) {
      throw new Error("Secure-context SHA-256 is required for local source provenance.");
    }
    const digestBytes = new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
    const sourceSHA256 = Array.from(digestBytes, (value) =>
      value.toString(16).padStart(2, "0")
    ).join("");
    checkActive();
    let object: Object3D;
    let sourceAnimations: AnimationClip[] = [];
    if (format === "fbx") {
      const { FBXLoader } = await import("three/addons/loaders/FBXLoader.js");
      checkActive();
      object = new FBXLoader(this.localOnlyLoaderManager()).parse(bytes, "");
      sourceAnimations = object.animations ?? [];
    } else {
      const { GLTFLoader } = await import("three/addons/loaders/GLTFLoader.js");
      checkActive();
      const parsed = await new Promise<{
        scene: Object3D;
        animations: AnimationClip[];
      }>((resolve, reject) => {
        new GLTFLoader(this.localOnlyLoaderManager()).parse(
          bytes, "", (gltf) => resolve({
            scene: gltf.scene, animations: gltf.animations,
          }), reject
        );
      });
      object = parsed.scene;
      sourceAnimations = parsed.animations;
    }
    checkActive();

    let importedMeshes = 0, triangles = 0, skinnedMeshes = 0;
    const parsedParts: LocalMeshEntry[] = [];
    const jointNames = new Set<string>();
    object.traverse((node) => {
      const maybeMesh = node as Mesh;
      if (!maybeMesh.isMesh) return;
      importedMeshes++;
      const geometry = maybeMesh.geometry;
      const positions = geometry.getAttribute("position");
      const vertices = geometry.index ? geometry.index.count : positions?.count ?? 0;
      const partTriangles = Math.floor(vertices / 3);
      triangles += partTriangles;
      const ancestorNames: string[] = [];
      let parent = node.parent;
      while (parent && parent !== object) {
        if (parent.name.trim()) ancestorNames.unshift(parent.name.trim());
        parent = parent.parent;
      }
      const name = node.name.trim() || `Mesh ${importedMeshes}`;
      parsedParts.push({
        id: importedMeshes - 1,
        mesh: maybeMesh,
        name,
        path: sourcePathForPart(ancestorNames, name),
        triangles: partTriangles,
        userVisible: maybeMesh.visible,
      });
      const maybeSkinned = node as import("three").SkinnedMesh;
      if (maybeSkinned.isSkinnedMesh && maybeSkinned.skeleton?.bones) {
        skinnedMeshes++;
        maybeSkinned.skeleton.bones.forEach((bone) => jointNames.add(bone.uuid));
      }
    });
    if (!importedMeshes || !Number.isFinite(triangles) || triangles === 0) {
      throw new Error("File has no readable triangle meshes.");
    }
    // Cap just before integrating GPU-heavy high-detail external models.
    // The known ~1.1m-triangle Z-Anatomy source fits for desktop research,
    // but phones may be too slow. Never silently decimate source meshes.
    if (triangles > 2_000_000 || importedMeshes > 5_000) {
      throw new Error("Model exceeds the 2 million-triangle / 5,000-mesh research preview limits. Simplify offline first.");
    }
    let rigSampledVertices = 0, rigUnweightedSamples = 0;
    let rigInvalidWeightSamples = 0, rigInvalidJointReferences = 0;
    let rigSuspiciousWeightSums = 0, skinnedMeshesWithoutWeightAttributes = 0;
    for (const part of parsedParts) {
      const skinned = part.mesh as import("three").SkinnedMesh;
      if (!skinned.isSkinnedMesh || !skinned.skeleton?.bones) continue;
      const weights = skinned.geometry.getAttribute("skinWeight");
      const joints = skinned.geometry.getAttribute("skinIndex");
      if (!weights || !joints || !weights.count || weights.count !== joints.count) {
        skinnedMeshesWithoutWeightAttributes++;
        continue;
      }
      const sample = inspectRigSamples({
        vertexCount: Math.min(weights.count, joints.count),
        jointCount: skinned.skeleton.bones.length,
        influenceSlots: Math.min(weights.itemSize, joints.itemSize),
        readWeight: (v, slot) => weights.getComponent(v, slot),
        readJoint: (v, slot) => joints.getComponent(v, slot),
      }, Math.max(16, Math.min(256, Math.floor(24000 / Math.max(1, skinnedMeshes)))));
      rigSampledVertices += sample.sampledVertices;
      rigUnweightedSamples += sample.unweightedVertices;
      rigInvalidWeightSamples += sample.invalidWeightSamples;
      rigInvalidJointReferences += sample.invalidJointReferences;
      rigSuspiciousWeightSums += sample.suspiciousWeightSums;
    }
    const validClips = sourceAnimations.filter((clip, id) =>
      usableAnimationStudyClip({
        id,
        name: clip.name,
        durationSeconds: clip.duration,
        trackCount: clip.tracks.length,
      })
    ).slice(0, 40);
    const bounds = new Box3().setFromObject(object);
    const size = bounds.getSize(new Vector3());
    const center = bounds.getCenter(new Vector3());
    const longest = Math.max(size.x, size.y, size.z);
    if (!Number.isFinite(longest) || longest < 1e-8) {
      throw new Error("Model dimensions cannot be normalized.");
    }
    checkActive();
    this.clearModel();
    this.parts = parsedParts;
    this.isolatedPartId = null;
    this.group.add(object);
    const scale = 4.8 / longest;
    this.group.scale.setScalar(scale);
    this.group.position.copy(center).multiplyScalar(-scale);
    object.traverse((node) => {
      const mesh = node as Mesh;
      if (mesh.isMesh) mesh.material = this.material;
    });
    this.loaded = true;
    this.lastLoaded = object;
    this.animationClips = validClips;
    this.animationMixer = validClips.length ? new AnimationMixer(object) : undefined;
    this.sourceIdentity = {
      fileName: file.name, fileSizeBytes: file.size, sourceSHA256,
      importedMeshes, triangles, skinnedMeshes,
      authoredJoints: jointNames.size,
      rigSamples: {
        sampledVertices: rigSampledVertices,
        unweightedVertices: rigUnweightedSamples,
        invalidWeightSamples: rigInvalidWeightSamples,
        invalidJointReferences: rigInvalidJointReferences,
        suspiciousWeightSums: rigSuspiciousWeightSums,
        skinnedMeshesWithoutWeightAttributes,
        previewableAnimationClips: validClips.length,
      },
    };
    this.resetView();
    return {
      file: file.name, importedMeshes, triangles, skinnedMeshes,
      authoredJoints: jointNames.size, hasUsableGeometry: true,
      rigSampledVertices, rigUnweightedSamples,
      rigInvalidWeightSamples, rigInvalidJointReferences,
      rigSuspiciousWeightSums, skinnedMeshesWithoutWeightAttributes,
      animationClips: validClips.length,
    };
  }

  private onPointerDown = (event: PointerEvent): void => {
    this.previousPointer = { x: event.clientX, y: event.clientY };
  };

  private onPointerUp = (event: PointerEvent): void => {
    const p = this.previousPointer;
    this.previousPointer = undefined;
    if (!p || Math.hypot(p.x - event.clientX, p.y - event.clientY) > 5 ||
        !this.loaded) return;
    const rect = this.canvas.getBoundingClientRect();
    this.mouse.set(
      ((event.clientX - rect.left) / rect.width) * 2 - 1,
      -((event.clientY - rect.top) / rect.height) * 2 + 1
    );
    this.raycaster.setFromCamera(this.mouse, this.camera);
    const intersections = this.raycaster.intersectObjects(this.group.children, true);
    for (const hit of intersections) {
      const entry = this.parts.find((part) => part.mesh === hit.object);
      if (!entry || !entry.mesh.visible) continue;
      if (this.anchorPickTarget) {
        // Explicitly avoid choosing a point on a DIFFERENT source mesh,
        // which could silently corrupt the manually authored relation.
        if (entry.id !== this.anchorPickTarget.id || !this.lastLoaded) return;
        this.lastLoaded.updateWorldMatrix(true, false);
        const local = this.lastLoaded.worldToLocal(hit.point.clone());
        const xyz: SourcePoint3 = [local.x, local.y, local.z];
        if (!validSourcePoint(xyz)) return;
        const pick = this.anchorPickTarget;
        this.anchorPickTarget = null;
        this.onAnchorPicked?.({
          sourceMeshId: pick.id, endpoint: pick.endpoint,
          originalRootLocalPoint: xyz,
        });
      }
      const selected = this.selectPart(entry.id);
      if (selected) this.onPartSelected?.(selected);
      break;
    }
  };

  private render(): void { this.renderer.render(this.scene, this.camera); }

  private clearModel(): void {
    this.anchorPickTarget = null;
    this.resetRigidPreview();
    this.showAnchorMarkers(null);
    this.animationPlaying = false;
    this.activeAnimation = undefined;
    this.animationMixer?.stopAllAction();
    if (this.animationMixer && this.lastLoaded) {
      this.animationMixer.uncacheRoot(this.lastLoaded);
    }
    this.animationMixer = undefined;
    this.animationClips = [];
    this.lastAnimationFrameMs = 0;
    this.clearSelection();
    this.parts = [];
    this.isolatedPartId = null;
    this.sourceIdentity = null;
    if (!this.lastLoaded) return;
    const geometries = new Set<Mesh["geometry"]>();
    this.lastLoaded.traverse((node) => {
      const mesh = node as Mesh;
      if (mesh.isMesh) geometries.add(mesh.geometry);
    });
    for (const geometry of geometries) geometry.dispose();
    this.group.remove(this.lastLoaded);
    this.lastLoaded = undefined;
    this.loaded = false;
    this.group.scale.setScalar(1);
    this.group.position.set(0, 0, 0);
  }

  dispose(): void {
    this.disposed = true;
    this.cancelPendingLoad();
    this.stop();
    this.canvas.removeEventListener("pointerdown", this.onPointerDown);
    this.canvas.removeEventListener("pointerup", this.onPointerUp);
    this.clearModel();
    this.controls.dispose();
    this.material.dispose();
    this.highlightMaterial.dispose();
    this.anchorMarkerGeometry.dispose();
    for (const material of this.anchorMarkerMaterials) material.dispose();
    this.renderer.dispose();
  }
}
