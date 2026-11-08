import {
  AmbientLight, Color, CylinderGeometry, DirectionalLight,
  Mesh, MeshStandardMaterial, OrthographicCamera, Scene, SphereGeometry,
  Vector3, WebGLRenderer,
} from "three";
import {
  mapImageToViewport, visibleSegments,
  type Focus, type PosePoint,
} from "./pose";

/**
 * GPU-rendered 3D CYLINDERS projected onto 2D observed landmarks.
 * This is an illustrated screen-space proxy, NOT a calibrated 3D atlas,
 * medical scan, depth measurement or individual person's anatomy.
 */
export class ProxySkeletonRenderer {
  private readonly renderer: WebGLRenderer;
  private readonly scene = new Scene();
  private readonly camera = new OrthographicCamera(0, 1, 0, 1, 0.01, 500);
  private readonly boneGeometry = new CylinderGeometry(0.5, 0.5, 1, 10);
  private readonly jointGeometry = new SphereGeometry(1, 10, 8);
  private readonly material = new MeshStandardMaterial({
    color: new Color("#e6d8b7"),
    metalness: 0.13,
    roughness: 0.45,
    transparent: true,
    opacity: 0.65,
    depthWrite: false,
  });
  private readonly bonePool: Mesh[] = [];
  private readonly jointPool: Mesh[] = [];
  private readonly yAxis = new Vector3(0, 1, 0);
  private readonly a = new Vector3();
  private readonly b = new Vector3();
  private readonly axis = new Vector3();
  private width = 1;
  private height = 1;

  constructor(canvas: HTMLCanvasElement) {
    this.renderer = new WebGLRenderer({
      canvas,
      alpha: true,
      antialias: true,
      powerPreference: "low-power",
      preserveDrawingBuffer: false,
    });
    this.renderer.setClearColor(0, 0);
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    this.scene.add(new AmbientLight("#fff3d5", 1.3));
    const light = new DirectionalLight("#ffffff", 2);
    light.position.set(-100, -100, 120);
    this.scene.add(light);
    this.camera.position.z = 100;
    this.camera.lookAt(0, 0, 0);
    this.resize(canvas.clientWidth || 1, canvas.clientHeight || 1);
    this.hide();
  }

  resize(width: number, height: number): void {
    this.width = Math.max(1, width);
    this.height = Math.max(1, height);
    this.camera.left = 0;
    this.camera.right = this.width;
    this.camera.top = 0;
    this.camera.bottom = this.height;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(this.width, this.height, false);
  }

  private boneAt(index: number): Mesh {
    if (!this.bonePool[index]) {
      const mesh = new Mesh(this.boneGeometry, this.material);
      this.scene.add(mesh);
      this.bonePool[index] = mesh;
    }
    return this.bonePool[index];
  }

  private jointAt(index: number): Mesh {
    if (!this.jointPool[index]) {
      const mesh = new Mesh(this.jointGeometry, this.material);
      this.scene.add(mesh);
      this.jointPool[index] = mesh;
    }
    return this.jointPool[index];
  }

  draw(
    points: readonly PosePoint[], sourceWidth: number, sourceHeight: number,
    focus: Focus, opacity: number, mirrored: boolean
  ): number {
    const segments = visibleSegments(points, focus);
    const radius = Math.max(3, Math.min(this.width, this.height) * 0.009);
    const seenJointIndices = new Set<number>();
    let i = 0, j = 0;
    this.material.opacity = Math.max(0.1, Math.min(0.9, opacity)) * 0.8;

    for (const segment of segments) {
      const a = mapImageToViewport(
        segment.start, sourceWidth, sourceHeight, this.width, this.height, mirrored
      );
      const b = mapImageToViewport(
        segment.end, sourceWidth, sourceHeight, this.width, this.height, mirrored
      );
      if (!a || !b) continue;
      // Depth is a tiny visual shading cue, NOT a measured camera coordinate.
      const aZ = Math.max(-3, Math.min(3, segment.start.z * 4));
      const bZ = Math.max(-3, Math.min(3, segment.end.z * 4));
      this.a.set(a.x, a.y, aZ);
      this.b.set(b.x, b.y, bZ);
      this.axis.subVectors(this.b, this.a);
      const length = this.axis.length();
      if (!Number.isFinite(length) || length < 3) continue;
      const bone = this.boneAt(i++);
      bone.visible = true;
      bone.position.copy(this.a).add(this.b).multiplyScalar(0.5);
      bone.quaternion.setFromUnitVectors(this.yAxis, this.axis.normalize());
      bone.scale.set(radius * 2, length, radius * 2);

      for (const [idx, center] of [
        [segment.fromIndex, a],
        [segment.toIndex, b],
      ] as const) {
        if (seenJointIndices.has(idx)) continue;
        seenJointIndices.add(idx);
        const joint = this.jointAt(j++);
        joint.visible = true;
        joint.position.set(center.x, center.y, 2);
        joint.scale.setScalar(radius * 0.8);
      }
    }
    this.bonePool.slice(i).forEach((mesh) => { mesh.visible = false; });
    this.jointPool.slice(j).forEach((mesh) => { mesh.visible = false; });
    this.renderer.render(this.scene, this.camera);
    return i;
  }

  hide(): void {
    for (const mesh of this.bonePool) mesh.visible = false;
    for (const mesh of this.jointPool) mesh.visible = false;
    this.renderer.render(this.scene, this.camera);
  }

  dispose(): void {
    this.boneGeometry.dispose();
    this.jointGeometry.dispose();
    this.material.dispose();
    this.renderer.dispose();
  }
}
