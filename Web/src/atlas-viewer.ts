import {
  AmbientLight, Box3, Color, DirectionalLight, DoubleSide, Group,
  LoadingManager, Mesh, MeshStandardMaterial, PerspectiveCamera, Plane, Raycaster,
  Scene, Vector2, Vector3, WebGLRenderer, type Object3D,
} from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { inspectLocalAtlasFile, normalizeSlice, sliceNormal,
  type SliceOrientation } from "./atlas-source";
import { sourcePathForPart, type AtlasPart } from "./atlas-catalog";

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
  private frame = 0;
  private loaded = false;
  private lastLoaded?: Object3D;
  private parts: LocalMeshEntry[] = [];
  private isolatedPartId: number | null = null;
  private selectedPartId: number | null = null;
  private previousPointer?: { x: number; y: number };
  onPartSelected: ((part: AtlasPart) => void) | undefined;

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
    const tick = () => {
      this.controls.update();
      this.render();
      this.frame = window.requestAnimationFrame(tick);
    };
    this.frame = window.requestAnimationFrame(tick);
  }

  stop(): void {
    if (this.frame) cancelAnimationFrame(this.frame);
    this.frame = 0;
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

  getIsolatedPartId(): number | null { return this.isolatedPartId; }

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
    this.clearSelection();
    this.selectedPartId = id;
    selected.mesh.material = this.highlightMaterial;
    this.render();
    return { id, name: selected.name, path: selected.path,
      triangles: selected.triangles, visible: true };
  }

  private applyVisibility(): void {
    for (const part of this.parts) {
      part.mesh.visible = this.isolatedPartId === null
        ? part.userVisible : part.id === this.isolatedPartId;
    }
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
    const format = inspectLocalAtlasFile(file);
    // Read the file once and parse locally; no fetch(URL.createObjectURL)
    // which could accidentally leak the file to a remote worker/CDN.
    const bytes = await file.arrayBuffer();
    let object: Object3D;
    if (format === "fbx") {
      const { FBXLoader } = await import("three/addons/loaders/FBXLoader.js");
      object = new FBXLoader(this.localOnlyLoaderManager()).parse(bytes, "");
    } else {
      const { GLTFLoader } = await import("three/addons/loaders/GLTFLoader.js");
      const parsed = await new Promise<Object3D>((resolve, reject) => {
        new GLTFLoader(this.localOnlyLoaderManager()).parse(
          bytes, "", (gltf) => resolve(gltf.scene), reject
        );
      });
      object = parsed;
    }

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
    if (triangles > 2_000_000) {
      throw new Error("More than 2 million triangles: please simplify offline first.");
    }
    const bounds = new Box3().setFromObject(object);
    const size = bounds.getSize(new Vector3());
    const center = bounds.getCenter(new Vector3());
    const longest = Math.max(size.x, size.y, size.z);
    if (!Number.isFinite(longest) || longest < 1e-8) {
      throw new Error("Model dimensions cannot be normalized.");
    }
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
    this.resetView();
    return {
      file: file.name, importedMeshes, triangles, skinnedMeshes,
      authoredJoints: jointNames.size, hasUsableGeometry: true,
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
      const selected = this.selectPart(entry.id);
      if (selected) this.onPartSelected?.(selected);
      break;
    }
  };

  private render(): void { this.renderer.render(this.scene, this.camera); }

  private clearModel(): void {
    this.clearSelection();
    this.parts = [];
    this.isolatedPartId = null;
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
    this.stop();
    this.canvas.removeEventListener("pointerdown", this.onPointerDown);
    this.canvas.removeEventListener("pointerup", this.onPointerUp);
    this.clearModel();
    this.controls.dispose();
    this.material.dispose();
    this.highlightMaterial.dispose();
    this.renderer.dispose();
  }
}
