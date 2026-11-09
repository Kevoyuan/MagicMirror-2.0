import { coverageFor, type Coverage, type Focus } from "./pose";
import { LivePoseInference } from "./inference";
import { ProcessingWindow, freshResult, type InferenceFrame } from "./telemetry";
import { ProxySkeletonRenderer } from "./scene";
import "./style.css";

const root = document.querySelector<HTMLDivElement>("#app");
if (!root) throw new Error("Missing application root");

root.innerHTML = `
  <main class="mirror-app">
    <header class="topbar">
      <div class="brand">
        <span class="brand-mark" aria-hidden="true">M<span class="brand-leaf">·</span>M</span>
        <div><span class="brand-title">MAGICMIRROR</span><span class="brand-subtitle">Anatomical Field Notes · Web Study 01</span></div>
      </div>
      <div id="tracking-status" class="status-pill is-ready" role="status" aria-live="polite">
        <span class="status-led" aria-hidden="true"></span>
        <span id="status-text">准备就绪</span>
      </div>
    </header>

    <section id="stage" class="camera-stage" aria-label="实时相机与教学参考骨架">
      <video id="video" autoplay muted playsinline aria-label="实时相机预览"></video>
      <canvas id="skeleton" aria-label="Three.js 3D 教学示意骨架"></canvas>
      <div class="stage-vignette" aria-hidden="true"></div>
      <div class="registration-marks" aria-hidden="true"><i></i><i></i><i></i><i></i></div>

      <div class="stage-heading">
        <span class="folio-caption">FIG. 01 / THE HUMAN FORM</span>
        <div class="stage-utilities">
          <span id="frame-metric" class="frame-metric">本地推理 · 尚未运行</span>
          <button id="snapshot" type="button" class="snapshot-button" disabled title="下载当前参考画面为 PNG">保存画面</button>
        </div>
      </div>

      <div id="empty-state" class="empty-state">
        <div class="seal" aria-hidden="true">✺</div>
        <p class="overline">ANATOMIA IN MOTU</p>
        <h1>让人体结构<br/>随着动作显现</h1>
        <p class="empty-detail">在浏览器中启用摄像头，观察跟随可见身体部位的半透明 3D 教学示意骨架。</p>
        <button id="start" class="primary-button" type="button">
          <span aria-hidden="true">◉</span> 开启摄像头
        </button>
        <p class="tiny-note">无需账号 · 本地姿态推理 · 需要摄像头权限</p>
      </div>

      <div id="guidance" class="guidance" hidden>将相机对准一人；双肩和髋部可见时能获得更完整的参考。</div>

      <div class="stage-corner-note" aria-hidden="true">
        <span>ANATOMICAL STUDY</span><span>NOT MEDICAL IMAGING</span>
      </div>
    </section>

    <section class="control-folio" aria-label="镜像与模型控制">
      <div class="folio-rule"><span>FOLIO I</span><span class="line"></span><span>OBSERVATION</span></div>
      <div class="control-row">
        <fieldset class="focus-field" id="focus-field">
          <legend class="field-label">观察区域</legend>
          <div class="segmented" aria-label="观察区域选择">
            <label><input name="focus" type="radio" value="whole" checked><span>全身</span></label>
            <label><input name="focus" type="radio" value="arms"><span>手臂</span></label>
            <label><input name="focus" type="radio" value="legs"><span>腿部</span></label>
          </div>
        </fieldset>
        <div class="opacity-field">
          <label class="field-label" for="opacity">参考透明度 <output id="opacity-value">65%</output></label>
          <input id="opacity" type="range" min="15" max="90" value="65" step="5" />
        </div>
      </div>
      <div class="action-row">
        <button id="toggle-overlay" class="action-button" type="button" disabled>暂停叠加</button>
        <button id="switch-camera" class="action-button" type="button" disabled>切换镜头</button>
        <button id="stop" class="action-button" type="button" disabled>关闭摄像头</button>
        <button id="layers" class="action-button secondary-action" type="button">解剖图层 <span aria-hidden="true">↗</span></button>
      </div>
      <div class="disclaimer"><span aria-hidden="true">ⓘ</span> <strong>3D 示意模型</strong> · 跟随体表估算姿态，不是你的真实骨骼、X 光或医学诊断。</div>
    </section>
    <footer class="footer-links">
      <span>OPEN-SOURCE RESEARCH / THE LEONARDO FOLIO</span>
      <div><a href="https://github.com/Kevoyuan/MagicMirror-2.0" target="_blank" rel="noopener noreferrer">GitHub</a><button id="privacy" type="button">隐私与来源</button></div>
    </footer>
  </main>

  <dialog id="layers-dialog" class="folio-dialog" aria-labelledby="layers-title">
    <div class="dialog-heading"><span>THE ANATOMY FOLIO</span><button class="close-dialog" data-close="layers-dialog" aria-label="关闭图层">×</button></div>
    <h2 id="layers-title">解剖图层</h2>
    <p>只有原创程序生成的三维示意骨架可用。Z-Anatomy 的真实骨骼、肌肉与器官尚未通过授权、绑定和配准验收。</p>
    <div class="layer-row"><strong>◉ 参考骨架 / Proxy</strong><span class="available-label">已实现</span></div>
    <div class="layer-row muted"><strong>骨骼 / Anatomy atlas</strong><span>待审核</span></div>
    <div class="layer-row muted"><strong>肌肉 / Muscles</strong><span>规划中</span></div>
    <div class="layer-row muted"><strong>器官 / Organs</strong><span>规划中</span></div>
    <div class="layer-row muted"><strong>横断 / 矢状 / 冠状剖面</strong><span>规划中</span></div>
  </dialog>

  <dialog id="privacy-dialog" class="folio-dialog" aria-labelledby="privacy-title">
    <div class="dialog-heading"><span>PRIVACY & PROVENANCE</span><button class="close-dialog" data-close="privacy-dialog" aria-label="关闭说明">×</button></div>
    <h2 id="privacy-title">隐私与来源</h2>
    <p>相机帧在浏览器内交给 MediaPipe 进行姿态估算；本项目代码不会自动上传、录制或保存摄像头画面。仅当你主动点击“保存画面”，浏览器才会在本地生成 PNG 并提供下载。MediaPipe SDK 可能按其隐私声明处理使用指标，正式公开部署前仍需单独核查。</p>
    <p>推理模型来自 Google MediaPipe，首次开发准备阶段下载并校验哈希；WASM 与模型需通过本地静态服务器提供。首次启用和站点部署需要 HTTPS（localhost 例外）。</p>
    <p>目前可见的是 MagicMirror 原创程序生成的三维示意骨架，<strong>没有使用或分发任何未经审核的 Z-Anatomy 网格</strong>。真实解剖模型及其署名将按资产来源逐项审核。</p>
    <p><a href="https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker/web_js" target="_blank" rel="noopener noreferrer">MediaPipe Pose Landmarker 文档</a></p>
  </dialog>
`;

function element<T extends HTMLElement>(selector: string): T {
  const value = document.querySelector<T>(selector);
  if (!value) throw new Error(`Missing UI element: ${selector}`);
  return value;
}

const video = element<HTMLVideoElement>("#video");
const canvas = element<HTMLCanvasElement>("#skeleton");
const stage = element<HTMLElement>("#stage");
const startButton = element<HTMLButtonElement>("#start");
const stopButton = element<HTMLButtonElement>("#stop");
const overlayButton = element<HTMLButtonElement>("#toggle-overlay");
const switchButton = element<HTMLButtonElement>("#switch-camera");
const emptyState = element<HTMLElement>("#empty-state");
const guidance = element<HTMLElement>("#guidance");
const metric = element<HTMLElement>("#frame-metric");
const snapshotButton = element<HTMLButtonElement>("#snapshot");
const status = element<HTMLElement>("#tracking-status");
const statusText = element<HTMLElement>("#status-text");
const opacitySlider = element<HTMLInputElement>("#opacity");
const opacityValue = element<HTMLOutputElement>("#opacity-value");

let lastStatusText = "";
let proxy: ProxySkeletonRenderer | undefined;
try {
  proxy = new ProxySkeletonRenderer(canvas);
} catch (error) {
  setStatus("此设备不支持 WebGL 渲染", "error");
  startButton.disabled = true;
  console.error("Three.js initialization failed", error);
}

let runner: LivePoseInference | undefined;
const processing = new ProcessingWindow();
let stream: MediaStream | undefined;
let session = 0;
let animationFrame = 0;
let mirrored = false;
let preferredFacing: "user" | "environment" = "environment";
let active = false;
let overlayPaused = false;
let focus: Focus = "whole";
let opacity = 0.65;
let lastFoundAt = -Infinity;
let previousCoverage: Coverage = "none";
let lastReceivedFrameId = 0;
const staleMs = 350;

type StatusKind = "ready" | "active" | "error";
function setStatus(text: string, kind: StatusKind): void {
  if (lastStatusText !== text) {
    statusText.textContent = text;
    lastStatusText = text;
  }
  status.className = `status-pill is-${kind}`;
}
function showGuidance(text: string | null): void {
  guidance.hidden = !text;
  if (text) guidance.textContent = text;
}
function setCameraButtons(running: boolean): void {
  stopButton.disabled = !running;
  snapshotButton.disabled = !running;
  switchButton.disabled = !running;
  overlayButton.disabled = !running;
  startButton.disabled = running;
  emptyState.hidden = running;
}

function modelUrl(path: string): string {
  return new URL(`${import.meta.env.BASE_URL}${path}`, document.baseURI).toString();
}


function stopCamera(message = "相机已关闭"): void {
  session++;
  active = false;
  if (animationFrame) cancelAnimationFrame(animationFrame);
  animationFrame = 0;
  runner?.close();
  runner = undefined;
  stream?.getTracks().forEach((track) => track.stop());
  stream = undefined;
  video.pause();
  video.srcObject = null;
  processing.reset();
  lastReceivedFrameId = 0;
  lastFoundAt = -Infinity;
  previousCoverage = "none";
  overlayPaused = false;
  overlayButton.textContent = "暂停叠加";
  proxy?.hide();
  setCameraButtons(false);
  showGuidance(null);
  metric.textContent = "本地推理 · 尚未运行";
  setStatus(message, "ready");
}

async function startCamera(): Promise<void> {
  if (!proxy) return;
  stopCamera();
  const currentSession = session;
  if (!window.isSecureContext || !navigator.mediaDevices?.getUserMedia) {
    setStatus("需要 HTTPS 或 localhost 才能使用摄像头", "error");
    showGuidance("请使用 HTTPS 地址或本机 localhost 打开网页。");
    return;
  }
  startButton.disabled = true;
  setStatus("正在请求摄像头权限…", "ready");
  try {
    const opened = await navigator.mediaDevices.getUserMedia({
      audio: false,
      video: {
        facingMode: { ideal: preferredFacing },
        width: { ideal: 1280 }, height: { ideal: 720 },
        frameRate: { ideal: 30, max: 30 },
      },
    });
    if (currentSession !== session) {
      opened.getTracks().forEach((t) => t.stop());
      return;
    }
    stream = opened;
    opened.getVideoTracks().forEach((track) => {
      track.addEventListener("ended", () => {
        if (currentSession === session) {
          stopCamera("摄像头设备已断开，请重新开启");
          showGuidance("设备断开或权限被撤销，请检查摄像头权限后重试。");
        }
      }, { once: true });
    });
    video.srcObject = opened;
    const actualFacing = opened.getVideoTracks()[0]?.getSettings().facingMode;
    mirrored = actualFacing === "user" || (!actualFacing && preferredFacing === "user");
    video.classList.toggle("mirror-video", mirrored);
    await video.play();
    if (currentSession !== session) return;
    setStatus("加载本地模型…", "ready");
    const engine = new LivePoseInference({
      modelURL: modelUrl("models/pose_landmarker_lite.task"),
      wasmURL: modelUrl("wasm").replace(/\/$/, ""),
      onFrame: handlePoseFrame,
      onFatal: (error) => {
        console.error("Pose engine failed", error);
        if (currentSession !== session) return;
        stopCamera("姿态引擎发生错误");
        showGuidance("请重新开启摄像头；若多次失败，请检查 WASM/模型文件和浏览器兼容性。");
      },
    });
    runner = engine;
    const mode = await engine.initialize();
    if (currentSession !== session) {
      engine.close();
      return;
    }
    active = true;
    metric.textContent = mode === "worker"
      ? "Worker 推理 · 等待首帧" : "主线程降级 · 等待首帧";
    setCameraButtons(true);
    showGuidance("请将一人移入镜头。局部手臂或腿部也可开始识别。");
    setStatus("寻找人体姿态", "ready");
    animationFrame = requestAnimationFrame(tick);
  } catch (error) {
    if (currentSession !== session) return;
    console.error("Camera or local model failed", error);
    const text = error instanceof DOMException && error.name === "NotAllowedError"
      ? "摄像头权限已拒绝，请在浏览器设置中开启"
      : error instanceof DOMException && error.name === "NotFoundError"
        ? "未检测到可用摄像头"
        : "无法启动：检查浏览器摄像头、WASM 和本地模型资源";
    stopCamera();
    setStatus(text, "error");
    showGuidance(text);
  } finally {
    if (currentSession === session && !active) startButton.disabled = false;
  }
}

function handlePoseFrame(frame: InferenceFrame): void {
  if (!active || !proxy || !runner) return;
  const now = performance.now();
  if (frame.frameId <= lastReceivedFrameId) return;
  if (!freshResult(frame, session, now, staleMs)) {
    proxy.hide();
    previousCoverage = "none";
    setStatus("检测结果过期，正在重新识别", "ready");
    showGuidance("当前设备处理较慢，已隐藏不可靠的叠加模型。");
    return;
  }
  lastReceivedFrameId = frame.frameId;
  processing.record({
    observedAtMs: now,
    inferenceMs: frame.inferredInMs,
    deliveryMs: now - frame.capturedAtMs,
  });
  const p = processing.summary();
  metric.textContent = `${runner.mode === "worker" ? "Worker" : "主线程"} ·
    ${p.outputHz.toFixed(1)} 结果/秒 ·
    推理 p95 ${p.inferenceP95Ms.toFixed(0)}ms ·
    交付 p95 ${p.deliveryP95Ms.toFixed(0)}ms`.replace(/\s+/g, " ").trim();

  const points = frame.landmarks ?? undefined;
  const coverage = coverageFor(points);
  previousCoverage = coverage;
  if (!points || coverage === "none") {
    proxy.hide();
    setStatus("寻找人体姿态", "ready");
    showGuidance("将一个人移入画面；上半身或可见手臂均可尝试。");
    return;
  }
  lastFoundAt = now;
  if (overlayPaused) {
    proxy.hide();
    setStatus("参考叠加已暂停", "ready");
  } else {
    const visible = proxy.draw(
      points, frame.width, frame.height, focus, opacity, mirrored
    );
    setStatus(visible > 0
      ? coverage === "torso" ? "已识别 · 躯干稳定" : "已识别 · 局部姿态"
      : "当前区域不可见", visible > 0 ? "active" : "ready");
  }
  showGuidance(coverage === "partial"
    ? "局部参考已启动。双肩与髋部可见时才有完整躯干参考。"
    : null);
}

function tick(now: number): void {
  if (!active || !proxy || !runner) return;
  animationFrame = requestAnimationFrame(tick);
  if (now - lastFoundAt > staleMs && previousCoverage !== "none") {
    proxy.hide();
    previousCoverage = "none";
    setStatus("姿态已丢失 · 自动重新识别", "ready");
    showGuidance("请保持关键部位可见，或调整取景。");
  }
  if (video.readyState < HTMLMediaElement.HAVE_CURRENT_DATA) return;
  runner.submit(video, now, session);
}

startButton.addEventListener("click", () => void startCamera());
stopButton.addEventListener("click", () => stopCamera());
switchButton.addEventListener("click", () => {
  preferredFacing = preferredFacing === "user" ? "environment" : "user";
  void startCamera();
});
overlayButton.addEventListener("click", () => {
  overlayPaused = !overlayPaused;
  overlayButton.textContent = overlayPaused ? "恢复叠加" : "暂停叠加";
  if (overlayPaused) proxy?.hide();
  setStatus(overlayPaused ? "参考叠加已暂停" : "正在追踪", "ready");
});
document.querySelectorAll<HTMLInputElement>('input[name="focus"]').forEach((radio) => {
  radio.addEventListener("change", () => {
    if (radio.checked) {
      focus = radio.value as Focus;
      proxy?.hide();
    }
  });
});
opacitySlider.addEventListener("input", () => {
  opacity = Number(opacitySlider.value) / 100;
  opacityValue.textContent = `${Math.round(opacity * 100)}%`;
});
for (const [buttonId, dialogId] of [
  ["#layers", "#layers-dialog"],
  ["#privacy", "#privacy-dialog"],
] as const) {
  element<HTMLButtonElement>(buttonId).addEventListener("click", () => {
    element<HTMLDialogElement>(dialogId).showModal();
  });
}
document.querySelectorAll<HTMLButtonElement>("[data-close]").forEach((button) => {
  button.addEventListener("click", () => {
    const id = button.dataset.close;
    if (id) element<HTMLDialogElement>(`#${id}`).close();
  });
});
const observer = new ResizeObserver(() => {
  proxy?.resize(stage.clientWidth, stage.clientHeight);
});
observer.observe(stage);
document.addEventListener("visibilitychange", () => {
  if (document.hidden && (active || stream)) {
    stopCamera("页面进入后台，已关闭摄像头");
  }
});
window.addEventListener("pagehide", () => {
  stopCamera("页面已离开");
  observer.disconnect();
  runner?.close();
  runner = undefined;
  proxy?.dispose();
});
