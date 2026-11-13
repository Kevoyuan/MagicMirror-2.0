import { coverageFor, type Coverage, type Focus } from "./pose";
import { assessWorldPose, type WorldPoseDiagnostic } from "./world-pose";
import { runSyntheticPerspectiveSelfCheck } from "./camera-registration-fixture";
import { reviewCameraEvidence, MAX_CAMERA_EVIDENCE_BYTES, type CameraEvidenceReview } from "./camera-evidence";
import { LivePoseInference } from "./inference";
import { ProcessingWindow, freshResult, type InferenceFrame } from "./telemetry";
import { captureLocalPNG } from "./snapshot";
import { educationFor, type EducationNote } from "./education";
import { translate, translateStaticDOM, type Locale } from "./i18n";
import { TemporalPoseStabilizer } from "./smoothing";
import type { LocalAtlasViewer, LocalAtlasStats } from "./atlas-viewer";
import { searchAtlasParts, type AtlasPart } from "./atlas-catalog";
import { inventoryDownloadName } from "./atlas-inventory";
import {
  makeDraftMapping, mappingDownloadName, parseDraftMapping,
  POSE_SEGMENTS, type PoseSegmentId,
} from "./atlas-mapping";
import {
  completeAnchorPairCount, makeAnchorDraft, parseAnchorDraft,
  sufficientAnchorDistance, type PartAnchorPair, type AnchorEndpoint,
} from "./atlas-anchors";
import type { SliceOrientation } from "./atlas-source";
import type { SourceAxis } from "./rigid-preview";
import {
  ORIGINAL_STUDY_DEMO, createOriginalStudyDemoFile,
} from "./study-demo";
import {
  makeStudyTimelineDraft, parseStudyTimelineDraft,
  sampleStudyTimeline, studyFrameAt, timelineDownloadName,
  type StudyKeyframe,
} from "./study-timeline";
import {
  makeStudySession, parseStudySession, studyReplayDiagnostics,
  studySessionDownloadName, type StudyReplayDiagnostics,
} from "./study-session";
import {
  countLargeStudyGaps, orderStudyChain,
  type StudyChainNode,
} from "./kinematic-chain";
import { ProxySkeletonRenderer } from "./scene";
import { LiveRigOverlay, type OverlayMode } from "./live-rig";
import "./style.css";

let locale: Locale = "zh";
const root = document.querySelector<HTMLDivElement>("#app");
if (!root) throw new Error("Missing application root");

root.innerHTML = `
  <main class="mirror-app">
    <header class="topbar">
      <div class="brand">
        <span class="brand-mark" aria-hidden="true">M<span class="brand-leaf">·</span>M</span>
        <div><span class="brand-title">MAGICMIRROR</span><span class="brand-subtitle">Anatomical Field Notes · Web Study 01</span></div>
      </div>
      <button id="language-toggle" class="language-switch" type="button" aria-label="切换中文与英文">EN</button>
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
          <details class="diagnostics-disclosure">
            <summary>诊断</summary>
            <div class="diagnostics-panel">
              <span id="frame-metric" class="frame-metric">本地推理 · 尚未运行</span>
              <span id="world-pose-metric" class="frame-metric world-pose-metric">三维观测 · 未运行（非相机标定）</span>
              <button id="registration-self-check" class="diagnostics-self-check" type="button">运行合成相机自检</button>
              <span id="registration-self-check-status" class="frame-metric registration-self-check-status" role="status">仅合成数据 · 未执行（不代表设备已标定）</span>
              <button id="open-camera-evidence" class="diagnostics-self-check" type="button">检查离线相机证据</button>
            </div>
          </details>
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
      <aside id="part-note" class="part-note" aria-label="局部解剖学习卡片" hidden>
        <div class="part-note-head">
          <span class="part-note-kicker">ANATOMIA · LEARNING NOTE</span>
          <button id="close-part-note" aria-label="关闭解剖学习卡片" type="button">×</button>
        </div>
        <h3 id="part-title">人体参考区域</h3>
        <span id="part-subtitle" class="part-note-subtitle"></span>
        <details id="part-note-more" class="part-note-more">
          <summary>阅读解剖说明</summary>
          <p id="part-description"></p>
          <small>教学示意 ≠ 真实骨骼扫描 · 非医疗诊断</small>
        </details>
      </aside>

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
        <details id="opacity-disclosure" class="opacity-disclosure">
          <summary>透明度 <span aria-hidden="true">⌄</span></summary>
          <div class="opacity-field">
            <label class="field-label" for="opacity">参考透明度 <output id="opacity-value">65%</output></label>
            <input id="opacity" type="range" min="15" max="90" value="65" step="5" />
          </div>
        </details>
      </div>
      <div class="action-row">
        <button id="toggle-overlay" class="action-button" type="button" disabled>暂停叠加</button>
        <button id="switch-camera" class="action-button" type="button" disabled>切换镜头</button>
        <button id="stop" class="action-button" type="button" disabled>关闭摄像头</button>
        <button id="layers" class="action-button secondary-action" type="button">解剖图层 <span aria-hidden="true">↗</span></button>
      </div>
      <div class="disclaimer"><span aria-hidden="true">ⓘ</span> <strong>3D 示意模型</strong> · 点击骨骼参考段学习基础解剖；并非真实骨骼、X 光或医学诊断。</div>
    </section>
    <footer class="footer-links">
      <span>OPEN-SOURCE RESEARCH / THE LEONARDO FOLIO</span>
      <div><a href="https://github.com/Kevoyuan/MagicMirror-2.0" target="_blank" rel="noopener noreferrer">GitHub</a><button id="privacy" type="button">隐私与来源</button></div>
    </footer>
  </main>

  <dialog id="camera-evidence-dialog" class="folio-dialog camera-evidence-dialog" aria-labelledby="camera-evidence-title">
    <div class="dialog-heading">
      <span>FOLIO III · CALIBRATION EVIDENCE</span>
      <button class="close-dialog" data-close="camera-evidence-dialog" aria-label="关闭离线相机证据">×</button>
    </div>
    <h2 id="camera-evidence-title">离线相机几何证据</h2>
    <p>仅检查你主动导入的本地 JSON 中声明的相机内参、刚体变换、三维标靶点和独立保留的 2D 观测点。不会上传、保存或启用摄像头，也不会将模型估计的关节点冒充实测标定点。</p>
    <p><strong>即使误差很低，也不代表真实设备已标定，不能解锁真实解剖叠加。</strong></p>
    <label class="camera-evidence-label" for="camera-evidence-file">选择离线标定证据 JSON（≤128 KB）</label>
    <input id="camera-evidence-file" type="file" accept=".json,application/json" aria-label="选择仅本地读取的标定证据 JSON" />
    <p id="camera-evidence-status" class="camera-evidence-status" role="status" aria-live="polite">尚未检查证据；所有标定和模型授权保持未通过。</p>
    <p class="camera-evidence-note">文件不得包含相机画面、身份信息或网络资源。仅支持两组以上具有不同标靶点身份的参考 / 验证观测，要求明确的三维长度单位和相机坐标约定。<a href="https://github.com/Kevoyuan/MagicMirror-2.0/blob/main/Docs/W3D_CAMERA_EVIDENCE.md" target="_blank" rel="noopener noreferrer">查看格式与局限</a></p>
  </dialog>

  <dialog id="layers-dialog" class="folio-dialog" aria-labelledby="layers-title">
    <div class="dialog-heading"><span>THE ANATOMY FOLIO</span><button class="close-dialog" data-close="layers-dialog" aria-label="关闭图层">×</button></div>
    <h2 id="layers-title">解剖图层</h2>
    <fieldset id="overlay-mode-field" class="rig-mode-field">
      <legend class="field-label">实时叠加模式</legend>
      <div class="rig-mode-options" role="radiogroup" aria-label="实时叠加模式">
        <label class="rig-mode-option">
          <input name="overlay-mode" type="radio" value="proxy" checked>
          <span>参考骨架 / Reference Proxy</span>
        </label>
        <label class="rig-mode-option">
          <input name="overlay-mode" type="radio" value="rig">
          <span>实时原创铰接模型（实验） / Live Original Rig (Experimental)</span>
        </label>
      </div>
      <p id="rig-mode-status" class="rig-mode-status" role="status" aria-live="polite">默认：独立线段参考骨架。未开启实验模式。</p>
      <details class="folio-explainer">
        <summary>实验模式的边界</summary>
        <p>实验模式只使用 MagicMirror 原创程序化几何，把可见的肩—肘—腕组成屏幕对齐的 2.5D 铰接链，前臂继承上臂枢轴。它不是真实骨骼、解剖配准、相机空间 3D 重建或医学成像；导入的 FBX / GLB 模型不会参与实时跟随。</p>
      </details>
    </fieldset>
    <div class="layer-row"><strong>◉ 参考骨架 / Proxy</strong><span class="available-label">已实现</span></div>
    <label class="smooth-control"><input id="stabilize" type="checkbox" checked> <span>稳定显示示意骨架（无关节预测）</span></label>
    <button id="open-atlas-studio" class="primary-button atlas-entry" type="button">导入本地 FBX / GLB 解剖模型</button>
    <p class="local-model-hint">仅在本设备预览你主动选择的文件，模型不会上传。导入的是静态研究模型，尚未与人体姿态绑定。</p>
    <div class="layer-row muted"><strong>骨骼 / Anatomy atlas</strong><span>待审核</span></div>
    <div class="layer-row muted"><strong>肌肉 / Muscles</strong><span>规划中</span></div>
    <div class="layer-row muted"><strong>器官 / Organs</strong><span>规划中</span></div>
    <div class="layer-row muted"><strong>横断 / 矢状 / 冠状剖面</strong><span>规划中</span></div>
    <details class="folio-explainer">
      <summary>图层与许可说明</summary>
      <p>只有原创程序生成的三维示意骨架可用。Z-Anatomy 的真实骨骼、肌肉与器官尚未通过授权、绑定和配准验收。</p>
    </details>
  </dialog>

  <dialog id="privacy-dialog" class="folio-dialog" aria-labelledby="privacy-title">
    <div class="dialog-heading"><span>PRIVACY & PROVENANCE</span><button class="close-dialog" data-close="privacy-dialog" aria-label="关闭说明">×</button></div>
    <h2 id="privacy-title">隐私与来源</h2>
    <p>相机帧在浏览器内交给 MediaPipe 进行姿态估算；本项目代码不会自动上传、录制或保存摄像头画面。仅当你主动点击“保存画面”，浏览器才会在本地生成 PNG 并提供下载。MediaPipe SDK 可能按其隐私声明处理使用指标，正式公开部署前仍需单独核查。</p>
    <p>推理模型来自 Google MediaPipe，首次开发准备阶段下载并校验哈希；WASM 与模型需通过本地静态服务器提供。首次启用和站点部署需要 HTTPS（localhost 例外）。</p>
    <p>目前可见的是 MagicMirror 原创程序生成的三维示意骨架，<strong>没有使用或分发任何未经审核的 Z-Anatomy 网格</strong>。真实解剖模型及其署名将按资产来源逐项审核。</p>
    <p><a href="https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker/web_js" target="_blank" rel="noopener noreferrer">MediaPipe Pose Landmarker 文档</a></p>
  </dialog>
  <dialog id="atlas-dialog" class="atlas-dialog" aria-labelledby="atlas-title">
    <div class="dialog-heading">
      <span>FOLIO II · THE ANATOMY STUDY</span>
      <button class="close-dialog" data-close="atlas-dialog" aria-label="关闭本地模型查看器">×</button>
    </div>
    <h2 id="atlas-title">解剖模型研究台</h2>
    <p class="atlas-disclaimer">仅本地查看。导入模型不会发送到服务器，也不会用于公共下载或自动授权；它<strong>不能跟随人体动作</strong>，剖面沿模型坐标轴而非真实医学解剖轴。</p>
    <label class="atlas-file-picker" for="atlas-file">选择本机 .fbx 或 .glb（≤75MB，建议电脑使用）</label>
    <input id="atlas-file" type="file" accept=".fbx,.glb" aria-label="选择仅本地读取的 FBX 或 GLB 文件"/>
    <button id="atlas-demo" class="atlas-demo-button" type="button">直接体验原创 3D 三连杆示例（无需下载文件）</button>
    <p class="atlas-demo-disclaimer">此示例由 MagicMirror 在浏览器内临时生成，包含三个简单方块及预设参考点；不是 Z-Anatomy、真实骨骼或人体摄像头追踪。</p>
    <div class="atlas-viewport"><canvas id="atlas-canvas" aria-label="可以拖动旋转、滚轮缩放、点击查看原始部件名称的三维模型"></canvas></div>
    <div class="atlas-tools">
      <label>模型空间切面
        <select id="atlas-section" aria-label="选择模型坐标轴切面">
          <option value="none">关闭</option>
          <option value="axial-y">横向 / Y 轴</option>
          <option value="sagittal-x">左右 / X 轴</option>
          <option value="coronal-z">前后 / Z 轴</option>
        </select>
      </label>
      <label>剖面位置 <input id="atlas-level" type="range" min="0" max="100" value="50"></label>
      <label>透明度 <input id="atlas-opacity" type="range" min="15" max="100" value="88"></label>
      <label class="atlas-checkbox"><input id="atlas-wireframe" type="checkbox"> 显示网格</label>
    </div>
    <section class="atlas-rig-panel" aria-labelledby="atlas-rig-heading">
      <div class="atlas-browser-heading">
        <h3 id="atlas-rig-heading">绑定与动画诊断</h3>
        <span class="atlas-rig-tag">STATIC / LOCAL</span>
      </div>
      <p id="atlas-rig-info" class="atlas-rig-info" role="status">
        尚未载入骨骼模型。仅检查模型内实际存在的关节、顶点权重及动画，不进行人体实时跟随。
      </p>
      <div class="atlas-animation-row">
        <label for="atlas-clip">模型内置动画
          <select id="atlas-clip" disabled>
            <option value="">无可预览动画</option>
          </select>
        </label>
        <button id="atlas-play-animation" type="button" disabled>播放</button>
        <button id="atlas-pause-animation" type="button" disabled>暂停</button>
      </div>
      <small>仅播放导入文件自带的动作；不是 MediaPipe 身体动作驱动，也不是已校准的解剖骨骼绑定。</small>
    </section>
    <section class="atlas-browser" aria-labelledby="atlas-browser-title">
      <div class="atlas-browser-heading">
        <h3 id="atlas-browser-title">原始部件与层级</h3>
        <span id="atlas-part-count" class="atlas-part-count">尚未导入模型</span>
      </div>
      <label class="atlas-search-label" for="atlas-search">按原始网格名称或层级路径搜索</label>
      <input id="atlas-search" type="search" autocomplete="off"
        placeholder="例如 Femur / Pelvis / 左侧名称" disabled />
      <div class="atlas-part-actions">
        <button id="atlas-show-all" type="button" disabled>显示全部</button>
        <button id="atlas-restore" type="button" disabled>退出独立显示</button>
        <button id="atlas-reset-camera" type="button" disabled>重置视角</button>
        <button id="atlas-export-inventory" type="button" disabled>导出来源清单 JSON</button>
      </div>
      <div class="atlas-mapping-tools" aria-labelledby="atlas-map-title">
        <h4 id="atlas-map-title">人工姿态映射草稿 · 非实际骨骼绑定</h4>
        <p>请根据原始网格名称与实际模型，自行标记对应的 MediaPipe 体表参考段。映射未经过解剖、骨骼绑定或相机校准审核。</p>
        <div class="atlas-map-actions">
          <span id="atlas-map-count" role="status" aria-live="polite">未映射任何原始网格</span>
          <button id="atlas-map-export" type="button" disabled>导出映射草稿</button>
          <label for="atlas-map-import">导入本地映射 JSON</label>
          <input id="atlas-map-import" type="file" accept=".json,application/json" disabled />
          <button id="atlas-map-clear" type="button" disabled>清空映射</button>
        </div>
        <div id="atlas-map-error" class="atlas-map-message" role="status" aria-live="polite"></div>
      </div>
      <section class="atlas-anchor-tools" aria-labelledby="atlas-anchor-title">
        <h4 id="atlas-anchor-title">模型空间端点草稿</h4>
        <p>先在部件列表中选定并映射一个网格，再点“标记起点/终点”，最后在 3D 视图中点击同一网格表面。遮挡时请先独显。坐标来自原始模型，并非解剖关节、已校准姿态或动态骨骼。</p>
        <div class="atlas-anchor-actions">
          <button id="atlas-anchor-start" type="button" disabled>标记起点 A</button>
          <button id="atlas-anchor-end" type="button" disabled>标记终点 B</button>
          <button id="atlas-anchor-clear" type="button" disabled>清除此网格端点</button>
          <button id="atlas-anchor-export" type="button" disabled>导出端点草稿</button>
          <label for="atlas-anchor-import">导入端点 JSON</label>
          <input id="atlas-anchor-import" type="file" accept=".json,application/json" disabled />
        </div>
        <p id="atlas-anchor-summary" role="status" aria-live="polite">尚未标记任何模型空间端点</p>
        <div id="atlas-anchor-message" class="atlas-anchor-message" role="status" aria-live="polite"></div>
      </section>
      <section class="atlas-rigid-panel" aria-labelledby="atlas-rigid-title">
        <h4 id="atlas-rigid-title">单部件刚体旋转实验 · 本地预览</h4>
        <p>选择已映射且有 A/B 端点的普通网格，以原始模型的 A 点为支点，绕模型 X/Y/Z 轴旋转。B 点仅表示运动参考方向；不生成骨骼关节、权重或人体实时动画。带 SkinnedMesh 或内置动画的模型不可使用此模式。</p>
        <div class="atlas-rigid-controls">
          <button id="atlas-rigid-begin" type="button" disabled>开启局部运动预览</button>
          <label for="atlas-rigid-axis">原模型旋转轴
            <select id="atlas-rigid-axis" disabled>
              <option value="x">X</option>
              <option value="y">Y</option>
              <option value="z" selected>Z</option>
            </select>
          </label>
          <label class="atlas-rigid-range" for="atlas-rigid-angle">旋转角度
            <input id="atlas-rigid-angle" type="range" min="-90" max="90" step="1" value="0" disabled />
          </label>
          <output id="atlas-rigid-degrees" for="atlas-rigid-angle">0°</output>
          <button id="atlas-rigid-reset" type="button" disabled>恢复原始姿态</button>
        </div>
        <p id="atlas-rigid-status" role="status" aria-live="polite">未开始。需要一个普通可见网格、人工映射和两个不同的模型空间端点。</p>
      </section>
      <section class="atlas-chain-panel" aria-labelledby="atlas-chain-title">
        <h4 id="atlas-chain-title">多部件运动链 · 原模型虚拟预览</h4>
        <p>选择至少两个已标记 A/B 的普通来源网格，手动指定父部件。运动以独立金色线框副本呈现，原始网格完全不修改。模型坐标轴和端点未经过医学、相机或真实关节校准。</p>
        <div class="atlas-chain-actions">
          <button id="atlas-chain-add" type="button" disabled>加入选中部件</button>
          <button id="atlas-chain-remove" type="button" disabled>移除选中部件</button>
          <label for="atlas-chain-parent">当前选中部件的父节点
            <select id="atlas-chain-parent" disabled><option value="">无父节点</option></select>
          </label>
          <button id="atlas-chain-start" type="button" disabled>预览运动链</button>
          <button id="atlas-chain-stop" type="button" disabled>停止并恢复</button>
        </div>
        <div id="atlas-chain-list" class="atlas-chain-list" role="list"></div>
        <div class="atlas-chain-pose">
          <label for="atlas-chain-axis">当前节点旋转轴
            <select id="atlas-chain-axis" disabled>
              <option value="x">X</option>
              <option value="y">Y</option>
              <option value="z" selected>Z</option>
            </select>
          </label>
          <label for="atlas-chain-angle">当前节点角度
            <input id="atlas-chain-angle" type="range" min="-90" max="90" step="1" value="0" disabled />
          </label>
          <output id="atlas-chain-degrees" for="atlas-chain-angle">0°</output>
          <button id="atlas-chain-zero" type="button" disabled>所有角度归零</button>
        </div>
        <p id="atlas-chain-status" role="status" aria-live="polite">请选择真实来源网格建立 2–12 节人工运动链；不执行人体追踪。</p>
      </section>
      <section class="atlas-timeline-panel" aria-labelledby="atlas-timeline-title">
        <h4 id="atlas-timeline-title">离线关键帧与循环回放</h4>
        <p>仅对当前原创或本地来源的虚拟运动链记录角度，不包含摄像头画面或真实人体骨骼。每帧绑定原始文件哈希、人工网格父子关系和模型空间端点。</p>
        <div class="atlas-timeline-track">
          <label for="atlas-timeline-time">时间轴（毫秒）
            <input id="atlas-timeline-time" type="range" min="0" max="6000" step="100" value="0" disabled />
          </label>
          <output id="atlas-timeline-display" for="atlas-timeline-time">0.0s</output>
        </div>
        <div class="atlas-timeline-actions">
          <button id="atlas-timeline-capture" type="button" disabled>记录当前角度</button>
          <button id="atlas-timeline-delete" type="button" disabled>删除此关键帧</button>
          <button id="atlas-timeline-play" type="button" disabled>循环播放</button>
          <button id="atlas-timeline-pause" type="button" disabled>暂停</button>
          <button id="atlas-timeline-clear" type="button" disabled>清空帧</button>
          <button id="atlas-timeline-export" type="button" disabled>导出本地动作草稿</button>
          <label for="atlas-timeline-import">导入动作草稿 JSON</label>
          <input id="atlas-timeline-import" type="file" accept=".json,application/json" disabled />
        </div>
        <div id="atlas-timeline-frames" class="atlas-timeline-frames" role="list"></div>
        <p id="atlas-timeline-status" role="status" aria-live="polite">请先预览 2–12 个原始网格，然后记录两个不同时间的关键帧；不执行真实人体追踪。</p>
      </section>
      <section class="atlas-session-panel" aria-labelledby="atlas-session-title">
        <h4 id="atlas-session-title">本地研究会话 · 单文件原子恢复</h4>
        <p>将人工映射、模型空间端点、虚拟运动链与角度关键帧合并为一份显式下载的本地 JSON。导入时先整体核验原始模型哈希与各草稿一致性，全部通过才一次性替换研究状态；不含模型几何、摄像头画面或任何版权授权。</p>
        <div class="atlas-session-actions">
          <button id="atlas-session-export" type="button" disabled>导出研究会话</button>
          <label for="atlas-session-import">导入研究会话 JSON</label>
          <input id="atlas-session-import" type="file" accept=".json,application/json" disabled />
        </div>
        <p id="atlas-session-status" role="status" aria-live="polite">尚未导出或导入研究会话。导入不会改变摄像头或已加载的原始模型。</p>
        <p id="atlas-session-diagnostics" role="status" aria-live="polite"></p>
      </section>
      <div id="atlas-part-list" class="atlas-part-list" role="list"
        aria-label="已导入模型的来源部件列表"></div>
      <button id="atlas-more" class="atlas-more" type="button" hidden>显示更多匹配部件</button>
    </section>
    <div id="atlas-info" class="atlas-info" role="status" aria-live="polite">尚未选择模型。原始 Z-Anatomy 的 FBX 可用于个人研究，但请确认模型来源和版权。</div>
    <div id="atlas-part" class="atlas-part">拖动旋转，滚轮缩放，点击部件查看源网格名称。</div>
    <p class="atlas-disclaimer">注意：即使可以导入 Z-Anatomy，本地静态浏览也不证明模型已绑定动画、逐网格许可合规或可公开商用。</p>
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
const noteCard = element<HTMLElement>("#part-note");
const noteTitle = element<HTMLElement>("#part-title");
const noteSubtitle = element<HTMLElement>("#part-subtitle");
const noteDescription = element<HTMLElement>("#part-description");
const noteExpansion = element<HTMLDetailsElement>("#part-note-more");
const metric = element<HTMLElement>("#frame-metric");
const worldMetric = element<HTMLElement>("#world-pose-metric");
const registrationSelfCheckButton = element<HTMLButtonElement>("#registration-self-check");
const registrationSelfCheckStatus = element<HTMLElement>("#registration-self-check-status");
let lastGeometrySelfCheck = {
  zh: "仅合成数据 · 未执行（不代表设备已标定）",
  en: "Synthetic-only self-check not run · device NOT calibrated",
};
function renderGeometrySelfCheck(): void {
  registrationSelfCheckStatus.textContent = locale === "en"
    ? lastGeometrySelfCheck.en : lastGeometrySelfCheck.zh;
}
registrationSelfCheckButton.addEventListener("click", () => {
  const result = runSyntheticPerspectiveSelfCheck();
  if (result.status === "geometric-candidate" &&
      !result.cameraCalibrationApproved && !result.anatomyOverlayApproved) {
    const rmse = result.rmsePx?.toFixed(3) ?? "—";
    lastGeometrySelfCheck = {
      zh: `仅合成相机：${result.matchedPoints} 点 · 透视重投影 RMSE ${rmse}px · 真实设备未标定`,
      en: `SYNTHETIC ONLY: ${result.matchedPoints} points · reprojection RMSE ${rmse}px · real device NOT calibrated`,
    };
  } else {
    lastGeometrySelfCheck = {
      zh: `合成几何自检未通过（${result.status}）· 未进行真实设备标定`,
      en: `Synthetic geometry self-check failed (${result.status}) · real device NOT calibrated`,
    };
  }
  renderGeometrySelfCheck();
});
let lastWorldMetric = {
  zh: "三维观测 · 未运行（非相机标定）",
  en: "3D observation · inactive (not camera calibration)",
};
const snapshotButton = element<HTMLButtonElement>("#snapshot");
const status = element<HTMLElement>("#tracking-status");
const statusText = element<HTMLElement>("#status-text");
const languageButton = element<HTMLButtonElement>("#language-toggle");
const openCameraEvidence = element<HTMLButtonElement>("#open-camera-evidence");
const cameraEvidenceDialog = element<HTMLDialogElement>("#camera-evidence-dialog");
const cameraEvidenceFile = element<HTMLInputElement>("#camera-evidence-file");
const cameraEvidenceStatus = element<HTMLElement>("#camera-evidence-status");
let lastEvidenceCopy = {
  zh: "尚未检查证据；所有标定和模型授权保持未通过。",
  en: "No evidence checked; camera calibration and model release remain unapproved.",
};
function renderEvidenceCopy(): void {
  cameraEvidenceStatus.textContent = locale === "en" ? lastEvidenceCopy.en : lastEvidenceCopy.zh;
}
openCameraEvidence.addEventListener("click", () => {
  if (!cameraEvidenceDialog.open) cameraEvidenceDialog.showModal();
});
cameraEvidenceFile.addEventListener("change", async () => {
  const file = cameraEvidenceFile.files?.[0];
  if (!file) return;
  // The original file and coordinates are not stored; only formatted summary
  // strings are retained for the active browser page.
  try {
    if (file.size < 1 || file.size > MAX_CAMERA_EVIDENCE_BYTES ||
        !file.name.toLocaleLowerCase().endsWith(".json")) {
      throw new Error("unsupported file");
    }
    const result = reviewCameraEvidence(JSON.parse(await file.text()) as unknown);
    const format = (metric: CameraEvidenceReview["holdout"]) =>
      `${metric.count} / RMSE ${metric.rmsePx.toFixed(2)}px / p95 ${metric.p95Px.toFixed(2)}px`;
    if (result.outcome === "invalid-depth") {
      lastEvidenceCopy = {
        zh: `深度验证失败（${result.rejectedDepthPoints} 个无效点）。未获相机标定或解剖叠加许可。`,
        en: `Invalid projected depth (${result.rejectedDepthPoints} points). Camera and anatomy NOT approved.`,
      };
    } else {
      const candidate = result.outcome === "external-consistent-unverified" ||
        result.outcome === "synthetic-consistent";
      const synthetic = result.provenance === "synthetic-fixture";
      lastEvidenceCopy = {
        zh: `${synthetic ? "合成证据" : "外部来源未核实"} · ${candidate ? "几何一致" : "几何不一致"} · 验证集 ${format(result.holdout)} · 未验证来源/未标定/未授权叠加`,
        en: `${synthetic ? "SYNTHETIC" : "EXTERNAL UNVERIFIED"} · ${candidate ? "geometry consistent" : "inconsistent"} · holdout ${format(result.holdout)} · source NOT verified / NOT calibrated / anatomy NOT approved`,
      };
    }
  } catch {
    lastEvidenceCopy = {
      zh: "证据文件无效或不符合独立标靶/相机坐标要求；未进行任何标定或授权。",
      en: "Invalid or unsupported independent target/camera evidence; no calibration or approval.",
    };
  } finally {
    cameraEvidenceFile.value = "";
    renderEvidenceCopy();
  }
});
const opacitySlider = element<HTMLInputElement>("#opacity");
const opacityValue = element<HTMLOutputElement>("#opacity-value");
const rigModeStatus = element<HTMLElement>("#rig-mode-status");
const rigModeRadios = document.querySelectorAll<HTMLInputElement>(
  'input[name="overlay-mode"]'
);

const RIG_MODE_COPY = {
  proxy: {
    zh: "默认：独立线段参考骨架。未开启实验模式。",
    en: "Default: independent reference segments. Experimental mode is off.",
  },
  rig: {
    zh: "实验模式：屏幕对齐 2.5D 原创铰接链；未进行相机空间 3D 配准。",
    en: "Experimental: screen-aligned 2.5D original articulated chain; no camera-space 3D registration.",
  },
  unavailable: {
    zh: "实验渲染器不可用，已恢复参考骨架。",
    en: "Experimental renderer unavailable; reverted to Reference Proxy.",
  },
} as const;

let lastStatusText = "";
let lastStatusKind: StatusKind = "ready";
let lastGuidanceRaw: string | null = null;
let currentNote: EducationNote | null = null;
let proxy: ProxySkeletonRenderer | undefined;
try {
  proxy = new ProxySkeletonRenderer(canvas);
} catch (error) {
  setStatus("此设备不支持 WebGL 渲染", "error");
  startButton.disabled = true;
  console.error("Three.js initialization failed", error);
}

/**
 * W3a: creation of the experimental rig is the ONLY Three.js ownership in
 * main.ts. All math, session gating and per-frame transforms live in the
 * live-rig modules; the rig shares proxy's existing WebGLRenderer/scene.
 */
let rigOverlay: LiveRigOverlay | undefined;
if (proxy) rigOverlay = new LiveRigOverlay(proxy);
let overlayMode: OverlayMode = "proxy";
let lastInferenceMode: "worker" | "main" | undefined;
let lastRigStatus: { en: string; zh: string } = { ...RIG_MODE_COPY.proxy };

let runner: LivePoseInference | undefined;
const processing = new ProcessingWindow();
const stabilizer = new TemporalPoseStabilizer();
let stabilizingEnabled = true;
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
  if (lastStatusText !== text || lastStatusKind !== kind) {
    statusText.textContent = translate(text, locale);
    lastStatusText = text;
    lastStatusKind = kind;
  }
  status.className = `status-pill is-${kind}`;
}
function hideNote(): void {
  noteCard.hidden = true;
  noteExpansion.open = false;
  currentNote = null;
}
function renderCurrentNote(): void {
  if (!currentNote) return;
  noteTitle.textContent = locale === "en" ? currentNote.titleEn : currentNote.titleZh;
  noteSubtitle.textContent = locale === "en" ? currentNote.titleZh : currentNote.titleEn;
  noteDescription.textContent = locale === "en"
    ? currentNote.descriptionEn : currentNote.descriptionZh;
}
function showGuidance(text: string | null): void {
  lastGuidanceRaw = text;
  guidance.hidden = !text || !noteCard.hidden;
  if (text) guidance.textContent = translate(text, locale);
}
function setLocale(next: Locale): void {
  locale = next;
  document.documentElement.lang = locale === "zh" ? "zh-CN" : "en";
  translateStaticDOM(root!, locale);
  languageButton.textContent = locale === "zh" ? "EN" : "中文";
  languageButton.setAttribute("aria-label",
    locale === "zh" ? "Switch to English" : "切换到中文");
  statusText.textContent = translate(lastStatusText || "准备就绪", locale);
  if (lastGuidanceRaw !== null) guidance.textContent = translate(lastGuidanceRaw, locale);
  overlayButton.textContent = translate(overlayPaused ? "恢复叠加" : "暂停叠加", locale);
  refreshRigModeCopy();
  worldMetric.textContent = locale === "en" ? lastWorldMetric.en : lastWorldMetric.zh;
  renderGeometrySelfCheck();
  renderEvidenceCopy();
  renderCurrentNote();
}
function setCameraButtons(running: boolean): void {
  stopButton.disabled = !running;
  snapshotButton.disabled = !running;
  switchButton.disabled = !running;
  overlayButton.disabled = !running;
  startButton.disabled = running;
  emptyState.hidden = running;
}

/** Dynamic rig status is authored locally in BOTH languages, never machine-translated. */
function setRigModeStatus(en: string, zh: string): void {
  lastRigStatus = { en, zh };
  rigModeStatus.textContent = locale === "en" ? en : zh;
}
function refreshRigModeCopy(): void {
  rigModeStatus.textContent = locale === "en" ? lastRigStatus.en : lastRigStatus.zh;
}
function syncRigModeRadios(): void {
  rigModeRadios.forEach((radio) => { radio.checked = radio.value === overlayMode; });
}

/** W3b diagnostics never drives the overlay or stores/export body observations. */
function setWorldMetric(result: WorldPoseDiagnostic | null): void {
  if (!result) {
    lastWorldMetric = {
      zh: "三维观测 · 不可用（非相机标定）",
      en: "3D model observation unavailable · not camera calibration",
    };
  } else if (result.status === "candidate" || result.status === "inconsistent") {
    const error = result.rmsePx?.toFixed(1) ?? "—";
    const pairs = result.matchedPoints;
    lastWorldMetric = result.status === "candidate" ? {
      zh: `三维模型候选一致 · ${pairs} 点 / 2D 拟合误差 ${error}px · 非相机标定`,
      en: `3D model in-plane candidate · ${pairs} pairs / 2D fit ${error}px · NOT calibrated`,
    } : {
      zh: `三维模型与图像不一致 · ${pairs} 点 / 2D 拟合误差 ${error}px · 不做 3D 叠加`,
      en: `3D model/image inconsistent · ${pairs} pairs / 2D fit ${error}px · no 3D overlay`,
    };
  } else {
    lastWorldMetric = {
      zh: `三维拟合不可用（${result.status} · ${result.matchedPoints} 点）· 非相机标定`,
      en: `3D fit unavailable (${result.status} · ${result.matchedPoints} pairs) · NOT calibrated`,
    };
  }
  worldMetric.textContent = locale === "en" ? lastWorldMetric.en : lastWorldMetric.zh;
}

/** Hide the ACTIVE overlay. In rig mode a stale 3D chain must never remain. */
function hideOverlay(): void {
  if (overlayMode === "rig") rigOverlay?.hide();
  else proxy?.hide();
}

function setOverlayMode(next: OverlayMode): void {
  if (!rigOverlay && next === "rig") {
    overlayMode = "proxy";
    setRigModeStatus(RIG_MODE_COPY.unavailable.en, RIG_MODE_COPY.unavailable.zh);
    syncRigModeRadios();
    return;
  }
  // `setMode` fails closed to "proxy" if the experimental rig cannot be built.
  const applied = next === "proxy" ? (rigOverlay?.setMode("proxy") ?? true)
    : (rigOverlay?.setMode("rig") ?? false);
  overlayMode = applied ? next : "proxy";
  const copy = applied ? RIG_MODE_COPY[overlayMode] : RIG_MODE_COPY.unavailable;
  setRigModeStatus(copy.en, copy.zh);
  hideNote();
  lastFoundAt = -Infinity;
  previousCoverage = "none";
  syncRigModeRadios();
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
  stabilizer.reset();
  lastReceivedFrameId = 0;
  lastFoundAt = -Infinity;
  previousCoverage = "none";
  overlayPaused = false;
  overlayButton.textContent = translate("暂停叠加", locale);
  lastInferenceMode = undefined;
  // Full reset also drops the experimental chain's transform history.
  rigOverlay?.reset();
  hideOverlay();
  hideNote();
  setCameraButtons(false);
  showGuidance(null);
  metric.textContent = "本地推理 · 尚未运行";
  setWorldMetric(null);
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
    setWorldMetric(null);
    rigOverlay?.clearTransforms();
    hideOverlay();
    hideNote();
    previousCoverage = "none";
    setStatus("检测结果过期，正在重新识别", "ready");
    showGuidance("当前设备处理较慢，已隐藏不可靠的叠加模型。");
    return;
  }
  lastReceivedFrameId = frame.frameId;
  // A worker->main fallback must not interpolate across the engine switch.
  if (runner.mode !== lastInferenceMode) {
    if (lastInferenceMode !== undefined) rigOverlay?.clearTransforms();
    lastInferenceMode = runner.mode;
  }
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

  // World points stay local and diagnostic-only: never camera extrinsics.
  setWorldMetric(assessWorldPose(frame.landmarks, frame.worldLandmarks, {
    sourceWidth: frame.width, sourceHeight: frame.height,
    viewportWidth: stage.clientWidth, viewportHeight: stage.clientHeight,
    mirrored,
  }));
  const observed = frame.landmarks ?? undefined;
  const smoothed = stabilizingEnabled
    ? stabilizer.sample(observed, frame.capturedAtMs) ?? undefined
    : observed;
  // The experimental chain owns its OWN bounded stabilization; feeding it the
  // proxy's smoothed points would double-smooth and hide real discontinuities.
  const points = overlayMode === "rig" ? observed : smoothed;
  const coverage = coverageFor(points);
  previousCoverage = coverage;
  if (!points || coverage === "none") {
    rigOverlay?.clearTransforms();
    hideOverlay();
    hideNote();
    setStatus("寻找人体姿态", "ready");
    showGuidance("将一个人移入画面；上半身或可见手臂均可尝试。");
    return;
  }
  lastFoundAt = now;
  if (overlayPaused) {
    hideOverlay();
    setStatus("参考叠加已暂停", "ready");
  } else if (overlayMode === "rig" && rigOverlay) {
    const outcome = rigOverlay.apply(frame, {
      session, nowMs: now, mirrored, focus, opacity,
      stabilizing: stabilizingEnabled,
    });
    if (outcome.visibleSegments > 0) {
      setStatus("实验模式 · 铰接跟随", "active");
      setRigModeStatus(
        `Experimental: ${outcome.visibleSegments} screen-aligned original articulated segment(s); NOT camera-space 3D.`,
        `实验模式：${outcome.visibleSegments} 段屏幕对齐原创铰接示意；不是相机空间 3D。`
      );
    } else {
      setStatus("实验模式 · 本帧已隐藏", "ready");
      const reason = outcome.reasons[0] ?? "NO_SUPPORTED_SEGMENTS";
      setRigModeStatus(
        `Experimental: frame hidden (${reason}). No pose was invented.`,
        `实验模式：本帧已隐藏（${reason}）。未虚构任何姿态。`
      );
    }
  } else {
    const visible = proxy.draw(
      points, frame.width, frame.height, focus, opacity, mirrored
    );
    setStatus(visible > 0
      ? coverage === "torso" ? "已识别 · 躯干稳定" : "已识别 · 局部姿态"
      : "当前区域不可见", visible > 0 ? "active" : "ready");
  }
  showGuidance(coverage === "partial" && overlayMode === "proxy"
    ? "局部参考已启动。双肩与髋部可见时才有完整躯干参考。"
    : null);
}

function tick(now: number): void {
  if (!active || !proxy || !runner) return;
  animationFrame = requestAnimationFrame(tick);
  if (now - lastFoundAt > staleMs && previousCoverage !== "none") {
    setWorldMetric(null);
    rigOverlay?.clearTransforms();
    hideOverlay();
    hideNote();
    previousCoverage = "none";
    setStatus("姿态已丢失 · 自动重新识别", "ready");
    showGuidance("请保持关键部位可见，或调整取景。");
  }
  if (video.readyState < HTMLMediaElement.HAVE_CURRENT_DATA) return;
  runner.submit(video, now, session);
}

canvas.addEventListener("click", (event) => {
  // Learning-note picking targets the W0 independent proxy segments only.
  if (!active || overlayPaused || !proxy || overlayMode === "rig") return;
  const rect = canvas.getBoundingClientRect();
  if (rect.width <= 0 || rect.height <= 0) return;
  const result = proxy.pickAt(event.clientX - rect.left, event.clientY - rect.top);
  const note = result ? educationFor(result.fromIndex, result.toIndex) : null;
  if (!note) {
    hideNote();
    return;
  }
  currentNote = note;
  noteExpansion.open = false;
  renderCurrentNote();
  noteCard.hidden = false;
  guidance.hidden = true;
});
element<HTMLButtonElement>("#close-part-note").addEventListener("click", () => {
  hideNote();
  showGuidance(lastGuidanceRaw);
});
languageButton.addEventListener("click", () => {
  setLocale(locale === "zh" ? "en" : "zh");
  refreshStudySessionCopy();
  if (atlasViewer) refreshAtlasParts();
  else refreshAtlasAnchorStatus();
  if (lastAtlasRigStats) renderAtlasRigInfo();
  atlasChainStatus.textContent = atlasViewer?.getChainPreviewActive()
    ? (locale === "en"
      ? "Local virtual chain preview · NOT a real skeletal or camera retarget."
      : "仅本地虚拟运动链预览 · 非真实骨骼或摄像头动作映射。")
    : (locale === "en"
      ? "Select 2–12 real source meshes with manual A/B points for study."
      : "请选择 2–12 个已人工标记端点的真实来源网格。");
  if (atlasViewer?.getRigidPreviewPartId() !== null &&
      atlasViewer?.getRigidPreviewPartId() !== undefined) {
    atlasRigidStatus.textContent = locale === "en"
      ? "Local single-source-mesh rigid preview only · NOT body tracking."
      : "仅本地单网格刚体运动实验 · 不是人体实时追踪。";
  }
  if (atlasClipSelect.disabled && atlasClipSelect.options.length) {
    atlasClipSelect.options[0].textContent = locale === "en"
      ? "No authored animation clips" : "无模型内置动画";
  }
});
setLocale("zh");

startButton.addEventListener("click", () => void startCamera());
stopButton.addEventListener("click", () => stopCamera());
snapshotButton.addEventListener("click", () => {
  if (!active || !proxy) return;
  void (async () => {
    snapshotButton.disabled = true;
    try {
      // Same single renderer/scene in both modes; draw once for explicit capture.
      if (rigOverlay) rigOverlay.renderForCapture();
      else proxy.renderForCapture();
      const blob = await captureLocalPNG(video, canvas, stage, mirrored);
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = `MagicMirror-reference-${new Date().toISOString().replace(/[:.]/g, "-")}.png`;
      document.body.append(link);
      link.click();
      link.remove();
      window.setTimeout(() => URL.revokeObjectURL(url), 60_000);
    } catch (error) {
      console.error("Explicit local capture failed", error);
      showGuidance("无法保存 PNG。请确认相机正常，并检查浏览器的下载权限。");
    } finally {
      snapshotButton.disabled = !active;
    }
  })();
});
switchButton.addEventListener("click", () => {
  preferredFacing = preferredFacing === "user" ? "environment" : "user";
  void startCamera();
});
overlayButton.addEventListener("click", () => {
  overlayPaused = !overlayPaused;
  overlayButton.textContent = translate(overlayPaused ? "恢复叠加" : "暂停叠加", locale);
  if (overlayPaused) {
    // pause() hides BOTH the rig and the proxy through the shared host.
    if (rigOverlay) rigOverlay.pause();
    else proxy?.hide();
  } else {
    rigOverlay?.resume();
  }
  setStatus(overlayPaused ? "参考叠加已暂停" : "正在追踪", "ready");
});
document.querySelectorAll<HTMLInputElement>('input[name="focus"]').forEach((radio) => {
  radio.addEventListener("change", () => {
    if (radio.checked) {
      focus = radio.value as Focus;
      rigOverlay?.clearTransforms();
      hideOverlay();
      if (overlayMode === "rig" && focus === "legs") {
        setRigModeStatus(
          "Experimental: no original leg chain exists; nothing is drawn for the leg region.",
          "实验模式：没有原创腿部铰接链；腿部区域不显示任何虚构骨骼。"
        );
      }
    }
  });
});
rigModeRadios.forEach((radio) => {
  radio.addEventListener("change", () => {
    if (radio.checked) setOverlayMode(radio.value as OverlayMode);
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
element<HTMLInputElement>("#stabilize").addEventListener("change", (event) => {
  const control = event.currentTarget as HTMLInputElement;
  stabilizingEnabled = control.checked;
  stabilizer.reset();
  rigOverlay?.setStabilization(stabilizingEnabled);
  rigOverlay?.clearTransforms();
  hideOverlay();
  hideNote();
});
const atlasDialog = element<HTMLDialogElement>("#atlas-dialog");
const atlasCanvas = element<HTMLCanvasElement>("#atlas-canvas");
const atlasFile = element<HTMLInputElement>("#atlas-file");
const atlasDemoButton = element<HTMLButtonElement>("#atlas-demo");
const atlasInfo = element<HTMLElement>("#atlas-info");
const atlasPart = element<HTMLElement>("#atlas-part");
const atlasRigInfo = element<HTMLElement>("#atlas-rig-info");
const atlasClipSelect = element<HTMLSelectElement>("#atlas-clip");
const atlasPlayAnimation = element<HTMLButtonElement>("#atlas-play-animation");
const atlasPauseAnimation = element<HTMLButtonElement>("#atlas-pause-animation");
const atlasSearch = element<HTMLInputElement>("#atlas-search");
const atlasPartList = element<HTMLElement>("#atlas-part-list");
const atlasPartCount = element<HTMLElement>("#atlas-part-count");
const atlasShowAll = element<HTMLButtonElement>("#atlas-show-all");
const atlasRestore = element<HTMLButtonElement>("#atlas-restore");
const atlasResetCamera = element<HTMLButtonElement>("#atlas-reset-camera");
const atlasExportInventory = element<HTMLButtonElement>("#atlas-export-inventory");
const atlasMore = element<HTMLButtonElement>("#atlas-more");
const atlasMapExport = element<HTMLButtonElement>("#atlas-map-export");
const atlasMapImport = element<HTMLInputElement>("#atlas-map-import");
const atlasMapClear = element<HTMLButtonElement>("#atlas-map-clear");
const atlasMapCount = element<HTMLElement>("#atlas-map-count");
const atlasMapError = element<HTMLElement>("#atlas-map-error");
const atlasMappings = new Map<number, PoseSegmentId>();
const atlasAnchors = new Map<number, PartAnchorPair>();
const atlasAnchorStart = element<HTMLButtonElement>("#atlas-anchor-start");
const atlasAnchorEnd = element<HTMLButtonElement>("#atlas-anchor-end");
const atlasAnchorClear = element<HTMLButtonElement>("#atlas-anchor-clear");
const atlasAnchorExport = element<HTMLButtonElement>("#atlas-anchor-export");
const atlasAnchorImport = element<HTMLInputElement>("#atlas-anchor-import");
const atlasAnchorSummary = element<HTMLElement>("#atlas-anchor-summary");
const atlasAnchorMessage = element<HTMLElement>("#atlas-anchor-message");
const atlasRigidBegin = element<HTMLButtonElement>("#atlas-rigid-begin");
const atlasRigidAxis = element<HTMLSelectElement>("#atlas-rigid-axis");
const atlasRigidAngle = element<HTMLInputElement>("#atlas-rigid-angle");
const atlasRigidDegrees = element<HTMLOutputElement>("#atlas-rigid-degrees");
const atlasRigidReset = element<HTMLButtonElement>("#atlas-rigid-reset");
const atlasRigidStatus = element<HTMLElement>("#atlas-rigid-status");
const atlasChainAdd = element<HTMLButtonElement>("#atlas-chain-add");
const atlasChainRemove = element<HTMLButtonElement>("#atlas-chain-remove");
const atlasChainParent = element<HTMLSelectElement>("#atlas-chain-parent");
const atlasChainStart = element<HTMLButtonElement>("#atlas-chain-start");
const atlasChainStop = element<HTMLButtonElement>("#atlas-chain-stop");
const atlasChainAxis = element<HTMLSelectElement>("#atlas-chain-axis");
const atlasChainAngle = element<HTMLInputElement>("#atlas-chain-angle");
const atlasChainDegrees = element<HTMLOutputElement>("#atlas-chain-degrees");
const atlasChainZero = element<HTMLButtonElement>("#atlas-chain-zero");
const atlasChainStatus = element<HTMLElement>("#atlas-chain-status");
const atlasChainList = element<HTMLElement>("#atlas-chain-list");
const atlasChainIds = new Set<number>();
const atlasChainParents = new Map<number, number | null>();
const atlasChainAngles = new Map<number, { axis: SourceAxis; degrees: number }>();
const atlasTimelineTime = element<HTMLInputElement>("#atlas-timeline-time");
const atlasTimelineDisplay = element<HTMLOutputElement>("#atlas-timeline-display");
const atlasTimelineCapture = element<HTMLButtonElement>("#atlas-timeline-capture");
const atlasTimelineDelete = element<HTMLButtonElement>("#atlas-timeline-delete");
const atlasTimelinePlay = element<HTMLButtonElement>("#atlas-timeline-play");
const atlasTimelinePause = element<HTMLButtonElement>("#atlas-timeline-pause");
const atlasTimelineClear = element<HTMLButtonElement>("#atlas-timeline-clear");
const atlasTimelineExport = element<HTMLButtonElement>("#atlas-timeline-export");
const atlasTimelineImport = element<HTMLInputElement>("#atlas-timeline-import");
const atlasTimelineFrames = element<HTMLElement>("#atlas-timeline-frames");
const atlasTimelineStatus = element<HTMLElement>("#atlas-timeline-status");
const atlasSessionExport = element<HTMLButtonElement>("#atlas-session-export");
const atlasSessionImport = element<HTMLInputElement>("#atlas-session-import");
const atlasSessionStatus = element<HTMLElement>("#atlas-session-status");
const atlasSessionDiagnostics = element<HTMLElement>("#atlas-session-diagnostics");
const SESSION_IDLE_EN = "No study session exported or imported yet. Import never changes the camera or the loaded original model.";
const SESSION_IDLE_ZH = "尚未导出或导入研究会话。导入不会改变摄像头或已加载的原始模型。";
const SESSION_INVALID_EN = "A different local model is loaded. Previous study session drafts no longer apply.";
const SESSION_INVALID_ZH = "已载入不同的本地模型，先前的研究会话草稿不再适用。";
let lastSessionStatus: { en: string; zh: string } | null = null;
let lastSessionDiagnostics: { en: string; zh: string } = { en: "", zh: "" };
let studyTimelineFrames: StudyKeyframe[] = [];

/** Keep the new session status aligned with the 中文 / EN header switch. */
function refreshStudySessionCopy(): void {
  const status = lastSessionStatus ??
    { en: SESSION_IDLE_EN, zh: SESSION_IDLE_ZH };
  atlasSessionStatus.textContent = locale === "en" ? status.en : status.zh;
  atlasSessionDiagnostics.textContent = locale === "en"
    ? lastSessionDiagnostics.en : lastSessionDiagnostics.zh;
}
function setSessionStatus(en: string, zh: string): void {
  lastSessionStatus = { en, zh };
  refreshStudySessionCopy();
}
function setSessionDiagnostics(en: string, zh: string): void {
  lastSessionDiagnostics = { en, zh };
  refreshStudySessionCopy();
}
function refreshStudySessionControls(): void {
  const ready = Boolean(atlasViewer?.sourceInventory());
  atlasSessionExport.disabled = !ready;
  atlasSessionImport.disabled = !ready;
}
function showSessionReplayDiagnostics(report: StudyReplayDiagnostics): void {
  const tested = report.frameCount > 0 && report.nodeCount >= 2;
  const verdict = !tested ? "NOT TESTED" : report.deterministic ? "YES" : "NO";
  const zhVerdict = !tested ? "未测试" : report.deterministic ? "通过" : "失败";
  setSessionDiagnostics(
    `Synthetic matrix replay: ${report.frameCount} frames / ${report.nodeCount} source nodes / ${report.sampledPoints} samples · deterministic ${verdict} · max drift ${report.maxReplayDrift} · ${report.largeSourceGaps} distant manual endpoints. STUDY ONLY: not camera, anatomy, WebGL or device validation.`,
    `合成矩阵重放：${report.frameCount} 帧 / ${report.nodeCount} 个来源节点 / ${report.sampledPoints} 次采样 · 确定性 ${zhVerdict} · 最大漂移 ${report.maxReplayDrift} · ${report.largeSourceGaps} 处人工端点间距偏大。仅为数值一致性研究，不代表相机、解剖、WebGL 或真机验证。`
  );
}
let studyTimelineFrameId = 0;
let studyTimelineStartedAt = 0;
let studyTimelineStartPositionMs = 0;
let atlasPageLimit = 60;
const atlasSection = element<HTMLSelectElement>("#atlas-section");
const atlasLevel = element<HTMLInputElement>("#atlas-level");
const atlasOpacity = element<HTMLInputElement>("#atlas-opacity");
const atlasWireframe = element<HTMLInputElement>("#atlas-wireframe");
let atlasViewer: LocalAtlasViewer | undefined;
let atlasInit: Promise<LocalAtlasViewer> | undefined;
let lastAtlasRigStats: LocalAtlasStats | null = null;

function renderAtlasRigInfo(): void {
  const stats = lastAtlasRigStats;
  if (!stats) return;
  atlasRigInfo.textContent = stats.skinnedMeshes === 0
    ? (locale === "en"
      ? "No authored SkinnedMesh found: a source model without rig weights cannot follow a body. Static study remains available."
      : "未发现已绑定的 SkinnedMesh：没有实际顶点权重的原始模型无法随人体动作。仍可静态研究。")
    : (locale === "en"
      ? `${stats.skinnedMeshes} bound meshes, ${stats.authoredJoints} joints. Sampled ${stats.rigSampledVertices} vertices: ${stats.rigUnweightedSamples} without weights, ${stats.rigInvalidWeightSamples} invalid weights, ${stats.rigInvalidJointReferences} invalid joint indices, ${stats.rigSuspiciousWeightSums} suspicious sums, ${stats.skinnedMeshesWithoutWeightAttributes} meshes missing attributes. Sample only—not complete rig approval.`
      : `已绑定网格 ${stats.skinnedMeshes} 个、关节 ${stats.authoredJoints} 个。采样检查 ${stats.rigSampledVertices} 顶点：无权重 ${stats.rigUnweightedSamples}、异常权重 ${stats.rigInvalidWeightSamples}、越界关节 ${stats.rigInvalidJointReferences}、权重和异常 ${stats.rigSuspiciousWeightSums}、缺少权重属性网格 ${stats.skinnedMeshesWithoutWeightAttributes}。仅为抽样诊断，非绑定验收。`);
}

async function ensureAtlasViewer(): Promise<LocalAtlasViewer> {
  if (atlasViewer) return atlasViewer;
  atlasInit ??= import("./atlas-viewer").then(({ LocalAtlasViewer }) => {
    const viewer = new LocalAtlasViewer(atlasCanvas);
    viewer.onPartSelected = (part) => {
      displayAtlasPart(part);
      refreshAtlasParts();
    };
    viewer.onAnchorPicked = (sample) => {
      if (!atlasMappings.has(sample.sourceMeshId)) return;
      const existing = atlasAnchors.get(sample.sourceMeshId) ?? {
        start: null, end: null,
      };
      const next: PartAnchorPair = {
        ...existing,
        [sample.endpoint]: sample.originalRootLocalPoint,
      };
      if (next.start && next.end && !sufficientAnchorDistance(next.start, next.end)) {
        atlasAnchorMessage.textContent = locale === "en"
          ? "Two distinct points are required on the SAME source mesh."
          : "请在同一个原始网格上选择两个不同的端点。";
        return;
      }
      resetStudyChainDraft();
      atlasAnchors.set(sample.sourceMeshId, next);
      const triplet = sample.originalRootLocalPoint.map(v => v.toFixed(3)).join(", ");
      atlasAnchorMessage.textContent = locale === "en"
        ? `Stored ${sample.endpoint} point [${triplet}] (source-root local; NOT calibrated).`
        : `已记录${sample.endpoint === "start" ? "起点" : "终点"} [${triplet}]（原始模型局部坐标，未经校准）。`;
      refreshAtlasParts();
    };
    atlasViewer = viewer;
    return viewer;
  }).finally(() => { atlasInit = undefined; });
  return atlasInit;
}
function displayAtlasPart(part: AtlasPart): void {
  // Original names/paths are never interpreted as HTML or medical labels.
  atlasPart.textContent = locale === "en"
    ? `Original source: ${part.path} · ${part.triangles.toLocaleString()} triangles. Static geometry; NOT a tracked bone.`
    : `来源部件：${part.path} · ${part.triangles.toLocaleString()} 个三角形。仅静态网格，不是实时追踪的骨骼。`;
}

function refreshAtlasAnchorStatus(): void {
  const partId = atlasViewer?.getSelectedPartId() ?? null;
  const assigned = partId !== null ? atlasMappings.get(partId) : undefined;
  const selectedPoints = partId !== null ? atlasAnchors.get(partId) : undefined;
  atlasViewer?.showAnchorMarkers(selectedPoints ?? null);
  const count = completeAnchorPairCount(atlasAnchors);
  const inventory = atlasViewer?.sourceInventory();
  atlasAnchorStart.disabled = !assigned;
  atlasAnchorEnd.disabled = !assigned;
  atlasAnchorClear.disabled = !selectedPoints;
  atlasAnchorExport.disabled = !inventory || atlasAnchors.size === 0;
  atlasAnchorImport.disabled = !inventory || atlasMappings.size === 0;
  const selectedStatus = !assigned
    ? (locale === "en"
      ? "Select a mapped original mesh before choosing endpoints."
      : "请先选择一个已人工映射的来源网格。")
    : (locale === "en"
      ? `Selected source #${partId}: A ${selectedPoints?.start ? "✓" : "–"} / B ${selectedPoints?.end ? "✓" : "–"}.`
      : `已选来源网格 #${partId}：起点 A ${selectedPoints?.start ? "✓" : "–"} / 终点 B ${selectedPoints?.end ? "✓" : "–"}。`);
  atlasAnchorSummary.textContent = locale === "en"
    ? `${count} complete / ${atlasAnchors.size} annotated source meshes. ${selectedStatus} NOT calibrated.`
    : `完整端点 ${count} 组 / 共标记 ${atlasAnchors.size} 个网格。 ${selectedStatus} 未经校准。`;
}

function stopLocalRigidPreview(): void {
  atlasViewer?.resetRigidPreview();
  atlasRigidAngle.value = "0";
  atlasRigidDegrees.textContent = "0°";
  atlasRigidStatus.textContent = locale === "en"
    ? "Original mesh pose restored. This study is not anatomical retargeting."
    : "已恢复来源网格的原始位置；该实验不构成人体动作重定向。";
}

function refreshAtlasRigidControls(): void {
  const selectedId = atlasViewer?.getSelectedPartId() ?? null;
  const points = selectedId !== null ? atlasAnchors.get(selectedId) : undefined;
  const candidate = selectedId !== null && atlasMappings.has(selectedId) &&
    Boolean(points && atlasViewer?.canRigidPreview(selectedId, points));
  const existing = atlasViewer?.getRigidPreviewPartId() ?? null;
  if (existing !== null && (!candidate || existing !== selectedId)) {
    stopLocalRigidPreview();
  }
  const active = atlasViewer?.getRigidPreviewPartId() !== null &&
    atlasViewer?.getRigidPreviewPartId() !== undefined;
  atlasRigidBegin.disabled = !candidate || active;
  atlasRigidAxis.disabled = !active;
  atlasRigidAngle.disabled = !active;
  atlasRigidReset.disabled = !active;
  if (!active) {
    atlasRigidAngle.value = "0";
    atlasRigidDegrees.textContent = "0°";
  }
}

function chainNodesForCurrentStudy(): StudyChainNode[] {
  const result: StudyChainNode[] = [];
  for (const id of atlasChainIds) {
    const pair = atlasAnchors.get(id);
    const poseSegment = atlasMappings.get(id);
    if (!pair?.start || !pair.end || !poseSegment ||
        !sufficientAnchorDistance(pair.start, pair.end)) {
      throw new Error("Chain references an unanchored or unmapped source mesh");
    }
    const pose = atlasChainAngles.get(id) ?? { axis: "z" as SourceAxis, degrees: 0 };
    result.push({
      sourceMeshId: id, parentMeshId: atlasChainParents.get(id) ?? null,
      start: pair.start, end: pair.end,
      axis: pose.axis, degrees: pose.degrees,
    });
  }
  return orderStudyChain(result);
}

function pauseStudyTimeline(): void {
  if (studyTimelineFrameId) window.cancelAnimationFrame(studyTimelineFrameId);
  studyTimelineFrameId = 0;
  studyTimelineStartedAt = 0;
}

function clearStudyTimeline(): void {
  pauseStudyTimeline();
  studyTimelineFrames = [];
  atlasTimelineTime.value = "0";
  atlasTimelineDisplay.textContent = "0.0s";
}

function applyStudyTimelineSample(timeMs: number): boolean {
  if (!atlasViewer?.getChainPreviewActive()) return false;
  const sampled = sampleStudyTimeline(studyTimelineFrames, timeMs);
  if (!sampled || !atlasViewer.setChainPose(sampled)) return false;
  for (const point of sampled) {
    atlasChainAngles.set(point.sourceMeshId, {
      axis: point.axis, degrees: point.degrees,
    });
  }
  const selected = atlasViewer.getSelectedPartId();
  const joint = selected !== null ? sampled.find(p => p.sourceMeshId === selected) : null;
  if (joint) {
    atlasChainAxis.value = joint.axis;
    atlasChainAngle.value = String(Math.round(joint.degrees));
    atlasChainDegrees.textContent = `${Math.round(joint.degrees)}°`;
  }
  atlasTimelineTime.value = String(timeMs);
  atlasTimelineDisplay.textContent = `${(timeMs / 1000).toFixed(1)}s`;
  return true;
}

function refreshStudyTimelineControls(): void {
  const chainReady = atlasChainIds.size >= 2 &&
    Boolean(atlasViewer?.sourceInventory());
  const active = atlasViewer?.getChainPreviewActive() ?? false;
  const playing = studyTimelineFrameId !== 0;
  atlasTimelineCapture.disabled = !active ||
    studyTimelineFrames.length >= 32;
  atlasTimelinePlay.disabled = !active || playing ||
    studyTimelineFrames.length < 2;
  atlasTimelinePause.disabled = !playing;
  atlasTimelineTime.disabled = !active ||
    studyTimelineFrames.length < 1;
  atlasTimelineExport.disabled = !chainReady || !studyTimelineFrames.length;
  atlasTimelineImport.disabled = !chainReady;
  atlasTimelineClear.disabled = !studyTimelineFrames.length;
  atlasTimelineDelete.disabled = !studyTimelineFrames.some(frame =>
    frame.timeMs === Number(atlasTimelineTime.value)
  );
  atlasTimelineTime.max = String(Math.max(6000,
    studyTimelineFrames.at(-1)?.timeMs ?? 0));
  const nodes = document.createDocumentFragment();
  for (const frame of studyTimelineFrames) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "atlas-timeline-frame";
    button.setAttribute("role", "listitem");
    button.textContent = `${(frame.timeMs / 1000).toFixed(1)}s`;
    button.title = locale === "en"
      ? "Show manually authored frame" : "查看人工创建的角度关键帧";
    button.addEventListener("click", () => {
      pauseStudyTimeline();
      atlasTimelineTime.value = String(frame.timeMs);
      if (active) applyStudyTimelineSample(frame.timeMs);
      else {
        atlasTimelineStatus.textContent = locale === "en"
          ? "Start virtual chain preview before scrubbing frame angles."
          : "请先开启虚拟运动链预览再查看关键帧姿态。";
      }
      refreshStudyTimelineControls();
    });
    nodes.append(button);
  }
  atlasTimelineFrames.replaceChildren(nodes);
}

function stopLocalStudyChain(): void {
  pauseStudyTimeline();
  atlasViewer?.resetChainPreview();
  atlasChainStatus.textContent = locale === "en"
    ? "Virtual chain stopped. Original geometry and transforms were never modified."
    : "虚拟运动链已停止；原始网格和变换始终未被修改。";
}

function resetStudyChainDraft(): void {
  clearStudyTimeline();
  stopLocalStudyChain();
  atlasChainIds.clear();
  atlasChainParents.clear();
  atlasChainAngles.clear();
}

function refreshAtlasChainControls(): void {
  const selected = atlasViewer?.getSelectedPartId() ?? null;
  const included = selected !== null && atlasChainIds.has(selected);
  const points = selected !== null ? atlasAnchors.get(selected) : undefined;
  const eligible = selected !== null && Boolean(
    atlasMappings.has(selected) && points &&
    atlasViewer?.canRigidPreview(selected, points)
  );
  const active = atlasViewer?.getChainPreviewActive() ?? false;
  atlasChainAdd.disabled = active || !eligible ||
    included || atlasChainIds.size >= 12;
  atlasChainRemove.disabled = active || !included;
  atlasChainParent.disabled = active || !included;
  atlasChainStart.disabled = active || atlasChainIds.size < 2;
  atlasChainStop.disabled = !active;
  atlasChainAxis.disabled = !active || !included;
  atlasChainAngle.disabled = !active || !included;
  atlasChainZero.disabled = !active;

  atlasChainParent.replaceChildren();
  atlasChainParent.add(new Option(
    locale === "en" ? "Independent root" : "独立根节点", ""
  ));
  const parts = atlasViewer?.getParts() ?? [];
  if (included) {
    for (const id of atlasChainIds) {
      if (id === selected) continue;
      const name = parts[id]?.name ?? `Source #${id}`;
      atlasChainParent.add(new Option(`#${id} ${name}`, String(id)));
    }
    const parent = atlasChainParents.get(selected!) ?? null;
    atlasChainParent.value = parent === null ? "" : String(parent);
  }

  const current = included ? atlasChainAngles.get(selected!) : undefined;
  atlasChainAxis.value = current?.axis ?? "z";
  atlasChainAngle.value = String(current?.degrees ?? 0);
  atlasChainDegrees.textContent = `${current?.degrees ?? 0}°`;

  const list = document.createDocumentFragment();
  for (const id of atlasChainIds) {
    const item = document.createElement("button");
    item.type = "button";
    item.className = "atlas-chain-node";
    item.setAttribute("role", "listitem");
    if (id === selected) item.setAttribute("aria-current", "true");
    const parent = atlasChainParents.get(id) ?? null;
    item.textContent = `#${id} ${parts[id]?.name ?? "Source mesh"} · ${parent === null ? "ROOT" : `← #${parent}`}`;
    item.addEventListener("click", () => {
      const chosen = atlasViewer?.selectPart(id);
      if (chosen) {
        displayAtlasPart(chosen);
        refreshAtlasParts();
      }
    });
    list.append(item);
  }
  atlasChainList.replaceChildren(list);
}

function refreshAtlasParts(): void {
  const parts = atlasViewer?.getParts() ?? [];
  const { matches, totalMatches, totalParts, hiddenParts, truncated } =
    searchAtlasParts(parts, atlasSearch.value, atlasPageLimit);
  const isolated = atlasViewer?.getIsolatedPartId() ?? null;
  atlasPartCount.textContent = locale === "en"
    ? `${totalMatches.toLocaleString()} matches / ${totalParts.toLocaleString()} parts · ${hiddenParts} hidden`
    : `匹配 ${totalMatches.toLocaleString()} / ${totalParts.toLocaleString()} 个部件 · 隐藏 ${hiddenParts} 个`;
  atlasRestore.disabled = isolated === null;
  atlasMore.hidden = !truncated;
  atlasMore.disabled = atlasPageLimit >= 300;
  atlasMapCount.textContent = locale === "en"
    ? `${atlasMappings.size} mapped / ${totalParts} source meshes · uncalibrated manual draft`
    : `人工映射 ${atlasMappings.size} / ${totalParts} 个来源网格 · 未经校准`;
  atlasMapExport.disabled = totalParts === 0;
  atlasMapImport.disabled = totalParts === 0;
  atlasMapClear.disabled = atlasMappings.size === 0;
  refreshAtlasAnchorStatus();
  refreshAtlasRigidControls();
  refreshAtlasChainControls();
  refreshStudyTimelineControls();
  refreshStudySessionControls();

  const fragment = document.createDocumentFragment();
  let lastGroup = "";
  for (const part of matches) {
    const sourceParent = part.path.includes(" / ")
      ? part.path.slice(0, part.path.lastIndexOf(" / "))
      : (locale === "en" ? "Model root" : "模型根目录");
    if (sourceParent !== lastGroup) {
      lastGroup = sourceParent;
      const heading = document.createElement("h4");
      heading.className = "atlas-group-heading";
      heading.textContent = sourceParent;
      fragment.append(heading);
    }

    const entry = document.createElement("div");
    entry.className = "atlas-part-row";
    entry.setAttribute("role", "listitem");
    const caption = document.createElement("button");
    caption.type = "button";
    caption.className = "atlas-part-name";
    caption.textContent = part.name;
    caption.title = part.path;
    caption.setAttribute("aria-label", (locale === "en" ? "Select source part: " : "选择来源部件：") + part.path);
    caption.disabled = !part.visible;
    caption.addEventListener("click", () => {
      const selected = atlasViewer?.selectPart(part.id);
      if (selected) {
        displayAtlasPart(selected);
        refreshAtlasParts();
      }
    });

    const count = document.createElement("span");
    count.className = "atlas-triangle-count";
    count.textContent = part.triangles.toLocaleString() + " △";

    const visibilityLabel = document.createElement("label");
    visibilityLabel.className = "atlas-part-visibility";
    const visibility = document.createElement("input");
    visibility.type = "checkbox";
    visibility.checked = part.visible;
    visibility.setAttribute("aria-label", (locale === "en" ? "Show " : "显示 ") + part.path);
    visibility.addEventListener("change", () => {
      atlasViewer?.setPartVisibility(part.id, visibility.checked);
      refreshAtlasParts();
    });
    visibilityLabel.append(visibility);

    const isolate = document.createElement("button");
    isolate.type = "button";
    isolate.className = "atlas-part-isolate";
    isolate.textContent = isolated === part.id ? "●" : "◎";
    isolate.title = locale === "en" ? "Show only this part" : "仅显示此部件";
    isolate.setAttribute("aria-label", isolate.title + " " + part.path);
    isolate.addEventListener("click", () => {
      if (atlasViewer?.isolatePart(part.id)) {
        const selected = atlasViewer.selectPart(part.id);
        if (selected) displayAtlasPart(selected);
        refreshAtlasParts();
      }
    });

    const focus = document.createElement("button");
    focus.type = "button";
    focus.className = "atlas-part-focus";
    focus.textContent = "⌕";
    focus.title = locale === "en" ? "Focus camera on part" : "聚焦此部件";
    focus.setAttribute("aria-label", focus.title + " " + part.path);
    focus.addEventListener("click", () => {
      if (atlasViewer?.focusPart(part.id)) {
        const selected = atlasViewer.selectPart(part.id);
        if (selected) displayAtlasPart(selected);
        refreshAtlasParts();
      }
    });

    const mapping = document.createElement("select");
    mapping.className = "atlas-map-segment";
    mapping.setAttribute("aria-label", (locale === "en"
      ? "Draft MediaPipe surface segment for " : "为来源网格选择体表参考段：") + part.path);
    mapping.title = locale === "en" ? "Draft only · no physical bone rig" : "仅人工草稿 · 非骨骼绑定";
    mapping.add(new Option(locale === "en" ? "Unassigned" : "未映射", ""));
    for (const segment of POSE_SEGMENTS) {
      mapping.add(new Option(locale === "en" ? segment.en : segment.zh, segment.id));
    }
    mapping.value = atlasMappings.get(part.id) ?? "";
    mapping.addEventListener("change", () => {
      const former = atlasMappings.get(part.id);
      if (mapping.value === "") atlasMappings.delete(part.id);
      else if (POSE_SEGMENTS.some((segment) => segment.id === mapping.value)) {
        atlasMappings.set(part.id, mapping.value as PoseSegmentId);
      }
      if (former !== atlasMappings.get(part.id)) {
        resetStudyChainDraft();
        atlasAnchors.delete(part.id);
        atlasViewer?.cancelAnchorPick();
        atlasAnchorMessage.textContent = locale === "en"
          ? "Changing a surface mapping cleared that part's old anchor points."
          : "已清除该部件以前的端点，因为体表映射发生了变化。";
      }
      atlasMapError.textContent = "";
      refreshAtlasParts();
    });
    entry.append(caption, count, mapping, visibilityLabel, isolate, focus);
    fragment.append(entry);
  }
  atlasPartList.replaceChildren(fragment);
}
atlasSearch.addEventListener("input", () => {
  atlasPageLimit = 60;
  refreshAtlasParts();
});
atlasMore.addEventListener("click", () => {
  atlasPageLimit = Math.min(atlasPageLimit + 60, 300);
  refreshAtlasParts();
});
atlasShowAll.addEventListener("click", () => {
  atlasViewer?.showAllParts();
  refreshAtlasParts();
});
atlasRestore.addEventListener("click", () => {
  atlasViewer?.restorePartVisibility();
  refreshAtlasParts();
});
atlasResetCamera.addEventListener("click", () => atlasViewer?.resetView());
atlasExportInventory.addEventListener("click", () => {
  const manifest = atlasViewer?.sourceInventory();
  if (!manifest) return;
  try {
    const payload = JSON.stringify(manifest, null, 2) + "\n";
    const blob = new Blob([payload], { type: "application/json;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = inventoryDownloadName(manifest.fileName);
    document.body.append(link);
    link.click();
    link.remove();
    window.setTimeout(() => URL.revokeObjectURL(url), 60_000);
    atlasPart.textContent = locale === "en"
      ? "Downloaded a LOCAL geometry inventory (not a rights clearance)."
      : "已在本地导出网格来源清单（不构成版权授权证明）。";
  } catch (error) {
    atlasPart.textContent = locale === "en"
      ? "Could not export the local JSON inventory."
      : "无法导出本地 JSON 清单。";
    console.error("Local inventory export failed", error);
  }
});

atlasMapClear.addEventListener("click", () => {
  resetStudyChainDraft();
  atlasMappings.clear();
  atlasAnchors.clear();
  atlasViewer?.cancelAnchorPick();
  atlasAnchorMessage.textContent = "";
  atlasMapError.textContent = "";
  refreshAtlasParts();
});
atlasMapExport.addEventListener("click", () => {
  const inventory = atlasViewer?.sourceInventory();
  if (!inventory) return;
  try {
    const draft = makeDraftMapping(inventory, atlasMappings);
    const blob = new Blob([JSON.stringify(draft, null, 2) + "\n"],
      { type: "application/json;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = mappingDownloadName(inventory.fileName);
    document.body.append(link);
    link.click();
    link.remove();
    window.setTimeout(() => URL.revokeObjectURL(url), 60_000);
    atlasMapError.textContent = locale === "en"
      ? "Downloaded a LOCAL, UNCALIBRATED source-to-surface-segment draft. No assets or rights are cleared."
      : "已在本地导出未经校准的网格-体表映射草稿；不包含模型、不构成授权。";
  } catch (error) {
    atlasMapError.textContent = String(error);
  }
});
atlasMapImport.addEventListener("change", () => {
  const file = atlasMapImport.files?.[0];
  atlasMapImport.value = "";
  const originalInventory = atlasViewer?.sourceInventory();
  if (!file || !originalInventory) return;
  if (file.size < 1 || file.size > 2_000_000) {
    atlasMapError.textContent = locale === "en"
      ? "Mapping JSON must be 1–2 MB." : "映射 JSON 大小必须为 1–2 MB。";
    return;
  }
  atlasMapImport.disabled = true;
  void file.text().then((source) => {
    const current = atlasViewer?.sourceInventory();
    if (!current ||
        current.sourceSHA256 !== originalInventory.sourceSHA256 ||
        current.fileSizeBytes !== originalInventory.fileSizeBytes) {
      throw new Error("Local source model changed during mapping import.");
    }
    const parsed: unknown = JSON.parse(source);
    const validated = parseDraftMapping(parsed, current);
    resetStudyChainDraft();
    // An incoming mapping may have changed every semantic part assignment;
    // clear prior anchor pairs instead of silently attaching them to a new one.
    atlasAnchors.clear();
    atlasViewer?.cancelAnchorPick();
    // Atomic update only after EVERY input/source field has passed checks.
    atlasMappings.clear();
    for (const [id, segment] of validated) atlasMappings.set(id, segment);
    atlasMapError.textContent = locale === "en"
      ? `Loaded ${validated.size} manually assigned parts. Source hash verified; no rig calibration or license validation.`
      : `已载入 ${validated.size} 项人工映射；原始模型哈希匹配，但未校准或完成版权审核。`;
    refreshAtlasParts();
  }).catch((error) => {
    atlasMapError.textContent = locale === "en"
      ? `Mapping import refused: ${String(error)}`
      : `映射导入被拒绝：${String(error)}`;
  }).finally(() => {
    atlasMapImport.disabled = !atlasViewer?.sourceInventory();
  });
});

atlasRigidBegin.addEventListener("click", () => {
  const id = atlasViewer?.getSelectedPartId() ?? null;
  const points = id !== null ? atlasAnchors.get(id) : undefined;
  if (id === null || !points || !atlasMappings.has(id) ||
      !atlasViewer?.beginRigidPreview(id, points)) {
    atlasRigidStatus.textContent = locale === "en"
      ? "Preview unavailable. Use a visible NON-SKINNED mesh, valid A/B points and a model without authored animation clips."
      : "无法预览：需要可见的非 SkinnedMesh 网格、有效 A/B 端点，且模型不能含内置动画。";
    refreshAtlasRigidControls();
    return;
  }
  atlasViewer.setRigidPreview("z", 0);
  atlasRigidAxis.value = "z";
  atlasRigidAngle.value = "0";
  atlasRigidDegrees.textContent = "0°";
  atlasRigidStatus.textContent = locale === "en"
    ? "LOCAL rigid preview active. Point A is the manual pivot; B is a moving reference, not an anatomical joint."
    : "已开启本地刚体预览。A 是人工旋转支点，B 是运动参考点，均非真实解剖关节。";
  refreshAtlasRigidControls();
});
function applyRigidAngle(): void {
  const axis = atlasRigidAxis.value as SourceAxis;
  const degrees = Number(atlasRigidAngle.value);
  if (!atlasViewer?.setRigidPreview(axis, degrees)) {
    stopLocalRigidPreview();
    refreshAtlasRigidControls();
    atlasRigidStatus.textContent = locale === "en"
      ? "Invalid or stale source preview: original pose restored."
      : "模型数据无效或过期：已恢复来源网格原始位置。";
    return;
  }
  atlasRigidDegrees.textContent = `${degrees}°`;
  atlasRigidStatus.textContent = locale === "en"
    ? `Previewing one original mesh around manual pivot A · source-${axis.toUpperCase()} ${degrees}° · NOT calibrated.`
    : `仅当前原始网格绕人工 A 点运动 · 模型 ${axis.toUpperCase()} 轴 ${degrees}° · 未经校准。`;
}
atlasRigidAxis.addEventListener("change", applyRigidAngle);
atlasRigidAngle.addEventListener("input", applyRigidAngle);
atlasRigidReset.addEventListener("click", () => {
  stopLocalRigidPreview();
  refreshAtlasRigidControls();
});

atlasChainAdd.addEventListener("click", () => {
  const id = atlasViewer?.getSelectedPartId() ?? null;
  const points = id !== null ? atlasAnchors.get(id) : undefined;
  if (id === null || atlasChainIds.size >= 12 || !points ||
      !atlasMappings.has(id) || !atlasViewer?.canRigidPreview(id, points)) return;
  clearStudyTimeline();
  atlasChainIds.add(id);
  atlasChainParents.set(id, null);
  atlasChainAngles.set(id, { axis: "z", degrees: 0 });
  refreshAtlasChainControls();
});
atlasChainRemove.addEventListener("click", () => {
  const id = atlasViewer?.getSelectedPartId() ?? null;
  if (id === null || !atlasChainIds.has(id)) return;
  clearStudyTimeline();
  atlasChainIds.delete(id);
  atlasChainParents.delete(id);
  atlasChainAngles.delete(id);
  for (const [child, parent] of atlasChainParents) {
    if (parent === id) atlasChainParents.set(child, null);
  }
  refreshAtlasChainControls();
});
atlasChainParent.addEventListener("change", () => {
  const id = atlasViewer?.getSelectedPartId() ?? null;
  if (id === null || !atlasChainIds.has(id) ||
      atlasViewer?.getChainPreviewActive()) return;
  const nextParent = atlasChainParent.value === ""
    ? null : Number(atlasChainParent.value);
  const old = atlasChainParents.get(id) ?? null;
  atlasChainParents.set(id, nextParent);
  try {
    if (atlasChainIds.size >= 2) chainNodesForCurrentStudy();
    if (old !== nextParent) clearStudyTimeline();
    atlasChainStatus.textContent = locale === "en"
      ? "Manual source hierarchy updated. Not a human anatomical joint tree."
      : "已更新人工来源部件父子关系，尚非真实人体解剖关节层级。";
  } catch (error) {
    atlasChainParents.set(id, old);
    atlasChainStatus.textContent = locale === "en"
      ? `Invalid hierarchy: ${String(error)}` : `层级无效：${String(error)}`;
  }
  refreshAtlasChainControls();
});
atlasChainStart.addEventListener("click", () => {
  try {
    const nodes = chainNodesForCurrentStudy();
    if (!atlasViewer?.beginChainPreview(nodes)) {
      throw new Error("Selected original source meshes are not safe for non-skinned virtual preview");
    }
    const gaps = countLargeStudyGaps(nodes);
    atlasChainStatus.textContent = locale === "en"
      ? `Virtual chain active: ${nodes.length} ghost meshes, ${gaps} disconnected-looking source endpoints. Original source unchanged. NOT medical tracking.`
      : `已预览 ${nodes.length} 个虚拟网格，其中 ${gaps} 个父子端点距离偏大。原模型未更改，非人体骨骼追踪。`;
    refreshAtlasRigidControls();
    refreshStudyTimelineControls();
  } catch (error) {
    atlasChainStatus.textContent = locale === "en"
      ? `Cannot preview: ${String(error)}` : `无法预览：${String(error)}`;
  }
  refreshAtlasChainControls();
});
atlasChainStop.addEventListener("click", () => {
  stopLocalStudyChain();
  refreshAtlasChainControls();
  refreshStudyTimelineControls();
});
function applyStudyJointAngle(): void {
  const id = atlasViewer?.getSelectedPartId() ?? null;
  if (id === null || !atlasChainIds.has(id)) return;
  pauseStudyTimeline();
  const axis = atlasChainAxis.value as SourceAxis;
  const degrees = Number(atlasChainAngle.value);
  if (!atlasViewer?.setChainJoint(id, axis, degrees)) {
    stopLocalStudyChain();
    atlasChainStatus.textContent = locale === "en"
      ? "Invalid source chain. Preview stopped safely."
      : "来源网格运动链无效，已安全停止预览。";
    refreshAtlasChainControls();
    return;
  }
  const previously = atlasChainAngles.get(id);
  if (previously && previously.axis !== axis) clearStudyTimeline();
  atlasChainAngles.set(id, { axis, degrees });
  atlasChainDegrees.textContent = `${degrees}°`;
  refreshStudyTimelineControls();
  atlasChainStatus.textContent = locale === "en"
    ? `Source #${id}: ${axis.toUpperCase()} ${degrees}°. Descendant ghost geometry follows its parent. No skinning or camera retargeting.`
    : `来源节点 #${id}：${axis.toUpperCase()} ${degrees}°。子部件虚拟网格继承父部件运动；无皮肤权重或摄像头动作映射。`;
}
atlasChainAxis.addEventListener("change", applyStudyJointAngle);
atlasChainAngle.addEventListener("input", applyStudyJointAngle);
atlasChainZero.addEventListener("click", () => {
  if (!atlasViewer?.getChainPreviewActive()) return;
  for (const id of atlasChainIds) {
    const pose = atlasChainAngles.get(id) ?? { axis: "z" as SourceAxis, degrees: 0 };
    if (!atlasViewer.setChainJoint(id, pose.axis, 0)) break;
    atlasChainAngles.set(id, { axis: pose.axis, degrees: 0 });
  }
  refreshAtlasChainControls();
});

atlasTimelineCapture.addEventListener("click", () => {
  if (!atlasViewer?.getChainPreviewActive()) return;
  pauseStudyTimeline();
  try {
    const atMs = Number(atlasTimelineTime.value);
    const frame = studyFrameAt(chainNodesForCurrentStudy(), atMs);
    const candidate = studyTimelineFrames
      .filter(existing => existing.timeMs !== atMs)
      .concat(frame).sort((a, b) => a.timeMs - b.timeMs);
    const source = atlasViewer.sourceInventory();
    if (!source) throw new Error("Original model source has not been identified");
    makeStudyTimelineDraft(source, chainNodesForCurrentStudy(), candidate);
    studyTimelineFrames = candidate;
    atlasTimelineStatus.textContent = locale === "en"
      ? `Captured ${candidate.length} manual joint-angle frames, no camera frames.`
      : `已记录 ${candidate.length} 个人工角度关键帧，不包含摄像头图像。`;
  } catch (error) {
    atlasTimelineStatus.textContent = locale === "en"
      ? `Frame capture rejected: ${String(error)}` : `关键帧记录被拒绝：${String(error)}`;
  }
  refreshStudyTimelineControls();
});
atlasTimelineDelete.addEventListener("click", () => {
  pauseStudyTimeline();
  const atMs = Number(atlasTimelineTime.value);
  studyTimelineFrames = studyTimelineFrames.filter(f => f.timeMs !== atMs);
  refreshStudyTimelineControls();
});
atlasTimelineClear.addEventListener("click", () => {
  clearStudyTimeline();
  atlasTimelineStatus.textContent = locale === "en"
    ? "Cleared original-model keyframe draft."
    : "已清空本地原模型角度关键帧草稿。";
  refreshStudyTimelineControls();
});
atlasTimelineTime.addEventListener("input", () => {
  pauseStudyTimeline();
  const time = Number(atlasTimelineTime.value);
  if (!applyStudyTimelineSample(time)) {
    atlasTimelineStatus.textContent = locale === "en"
      ? "Cannot scrub: preview a compatible virtual chain first."
      : "无法拖动时间轴：请先预览兼容的虚拟运动链。";
  }
  refreshStudyTimelineControls();
});
atlasTimelinePlay.addEventListener("click", () => {
  if (!atlasViewer?.getChainPreviewActive() || studyTimelineFrames.length < 2) return;
  pauseStudyTimeline();
  studyTimelineStartPositionMs = Number(atlasTimelineTime.value);
  studyTimelineStartedAt = 0;
  const first = studyTimelineFrames[0].timeMs;
  const last = studyTimelineFrames[studyTimelineFrames.length - 1].timeMs;
  const duration = last - first;
  if (duration <= 0) return;
  const tick = (now: number): void => {
    if (!atlasDialog.open || document.visibilityState === "hidden" ||
        !atlasViewer?.getChainPreviewActive()) {
      pauseStudyTimeline();
      refreshStudyTimelineControls();
      return;
    }
    if (studyTimelineStartedAt === 0) studyTimelineStartedAt = now;
    const played = Math.max(0, now - studyTimelineStartedAt);
    const time = first + ((studyTimelineStartPositionMs - first + played) % duration + duration) % duration;
    if (!applyStudyTimelineSample(time)) {
      pauseStudyTimeline();
      atlasTimelineStatus.textContent = locale === "en"
        ? "Replay stopped because the source virtual chain became invalid."
        : "来源运动链状态变化，已安全停止回放。";
      refreshStudyTimelineControls();
      return;
    }
    studyTimelineFrameId = window.requestAnimationFrame(tick);
  };
  studyTimelineFrameId = window.requestAnimationFrame(tick);
  atlasTimelineStatus.textContent = locale === "en"
    ? "Looping authored local test angles; not a captured human pose."
    : "正在循环播放本地合成角度；不是人体采集的姿态。";
  refreshStudyTimelineControls();
});
atlasTimelinePause.addEventListener("click", () => {
  pauseStudyTimeline();
  refreshStudyTimelineControls();
});
atlasTimelineExport.addEventListener("click", () => {
  const source = atlasViewer?.sourceInventory();
  if (!source) return;
  try {
    const draft = makeStudyTimelineDraft(source,
      chainNodesForCurrentStudy(), studyTimelineFrames);
    const blob = new Blob([JSON.stringify(draft, null, 2) + "\n"],
      {type: "application/json;charset=utf-8"});
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = timelineDownloadName(source.fileName);
    document.body.append(link);
    link.click();
    link.remove();
    window.setTimeout(() => URL.revokeObjectURL(url), 60_000);
    atlasTimelineStatus.textContent = locale === "en"
      ? "Exported LOCAL uncalibrated source-keyframe JSON. Original model not included."
      : "已导出本地未经校准的角度 JSON；不包含模型数据。";
  } catch (error) {
    atlasTimelineStatus.textContent = `Export refused: ${String(error)}`;
  }
});
atlasTimelineImport.addEventListener("change", () => {
  const file = atlasTimelineImport.files?.[0];
  atlasTimelineImport.value = "";
  if (!file || !atlasViewer?.sourceInventory()) return;
  if (file.size < 1 || file.size > 1_000_000) {
    atlasTimelineStatus.textContent = locale === "en"
      ? "Timeline JSON must be 1–1,000,000 bytes."
      : "时间轴 JSON 大小须在 1 到 1,000,000 字节之间。";
    return;
  }
  atlasTimelineImport.disabled = true;
  void file.text().then(text => {
    const source = atlasViewer?.sourceInventory();
    if (!source) throw new Error("Original local model is unavailable");
    const raw: unknown = JSON.parse(text);
    const checked = parseStudyTimelineDraft(raw, source,
      chainNodesForCurrentStudy());
    // Replace only after the ENTIRE source/graph/frame draft validates.
    pauseStudyTimeline();
    studyTimelineFrames = checked;
    atlasTimelineTime.value = String(checked[0].timeMs);
    atlasTimelineStatus.textContent = locale === "en"
      ? `Imported ${checked.length} local angle frames for exact source identity. NOT calibrated.`
      : `已导入 ${checked.length} 个与原模型严格对应的本地角度帧（未经校准）。`;
    if (atlasViewer?.getChainPreviewActive()) {
      applyStudyTimelineSample(checked[0].timeMs);
    }
  }).catch(error => {
    atlasTimelineStatus.textContent = locale === "en"
      ? `Timeline import rejected: ${String(error)}`
      : `时间轴导入被拒绝：${String(error)}`;
  }).finally(() => refreshStudyTimelineControls());
});

/** W2l: ONE explicit local file replaces the separate W2d/W2e/W2i downloads. */
atlasSessionExport.addEventListener("click", () => {
  const source = atlasViewer?.sourceInventory();
  if (!source) return;
  try {
    let chain: StudyChainNode[] = [];
    if (atlasChainIds.size === 1) {
      throw new Error(locale === "en"
        ? "Add a second source mesh to the virtual chain, or clear the one-node draft before exporting."
        : "请先添加第二个来源网格，或清空只有一个节点的运动链草稿后再导出。");
    }
    if (atlasChainIds.size >= 2) chain = chainNodesForCurrentStudy();
    const bundle = makeStudySession(source, atlasMappings, atlasAnchors,
      chain, studyTimelineFrames);
    const blob = new Blob([JSON.stringify(bundle, null, 2) + "\n"],
      { type: "application/json;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = studySessionDownloadName(source.fileName);
    document.body.append(link);
    link.click();
    link.remove();
    window.setTimeout(() => URL.revokeObjectURL(url), 60_000);
    showSessionReplayDiagnostics(studyReplayDiagnostics(chain, studyTimelineFrames));
    const mappings = bundle.mapping.assignments.length;
    const pairs = bundle.anchors.anchors.length;
    const keyframes = bundle.timeline?.frames.length ?? 0;
    setSessionStatus(
      `Downloaded ONE local study session: ${mappings} mappings, ${pairs} anchor pairs, ${bundle.chain.length} chain nodes, ${keyframes} keyframes. UNCALIBRATED; no geometry, camera frames or rights approval.`,
      `已下载一份本地研究会话：${mappings} 项映射、${pairs} 组端点、${bundle.chain.length} 个运动链节点、${keyframes} 个关键帧。未经校准；不含模型几何、摄像头画面或版权授权。`
    );
  } catch (error) {
    setSessionStatus(`Export refused: ${String(error)}`,
      `导出被拒绝：${String(error)}`);
    setSessionDiagnostics("", "");
  }
});

atlasSessionImport.addEventListener("change", () => {
  const file = atlasSessionImport.files?.[0];
  atlasSessionImport.value = "";
  const originalInventory = atlasViewer?.sourceInventory();
  if (!file || !originalInventory) return;
  if (file.size < 1 || file.size > 2_000_000) {
    setSessionStatus("Study session JSON must be 1–2 MB.",
      "研究会话 JSON 大小须在 1–2 MB 之间。");
    setSessionDiagnostics("", "");
    return;
  }
  atlasSessionImport.disabled = true;
  void file.text().then(text => {
    const current = atlasViewer?.sourceInventory();
    if (!current ||
        current.sourceSHA256 !== originalInventory.sourceSHA256 ||
        current.fileSizeBytes !== originalInventory.fileSizeBytes) {
      throw new Error("Local source model changed during study session import.");
    }
    const raw: unknown = JSON.parse(text);
    const state = parseStudySession(raw, current);
    // Viewer-side fail-closed pre-pass BEFORE any live state is touched:
    // the restored chain must still be plain, visible, unanimated source meshes.
    for (const node of state.chain) {
      const pair = state.anchors.get(node.sourceMeshId);
      if (!pair || !atlasViewer?.canRigidPreview(node.sourceMeshId, pair)) {
        throw new Error("Restored chain mesh is hidden, skinned or has authored animation; show plain visible parts and retry.");
      }
    }
    // Atomic replace only after the ENTIRE bundle and viewer state validate.
    resetStudyChainDraft();
    atlasMappings.clear();
    for (const [id, segment] of state.mappings) atlasMappings.set(id, segment);
    atlasAnchors.clear();
    for (const [id, pair] of state.anchors) atlasAnchors.set(id, pair);
    atlasViewer?.cancelAnchorPick();
    for (const node of state.chain) {
      atlasChainIds.add(node.sourceMeshId);
      atlasChainParents.set(node.sourceMeshId, node.parentMeshId);
      atlasChainAngles.set(node.sourceMeshId,
        { axis: node.axis, degrees: node.degrees });
    }
    studyTimelineFrames = state.frames;
    const firstTime = state.frames[0]?.timeMs ?? 0;
    atlasTimelineTime.value = String(firstTime);
    atlasTimelineDisplay.textContent = `${(firstTime / 1000).toFixed(1)}s`;
    atlasMapError.textContent = "";
    atlasAnchorMessage.textContent = "";
    showSessionReplayDiagnostics(
      studyReplayDiagnostics(state.chain, state.frames));
    setSessionStatus(
      `Atomically restored ${state.mappings.size} mappings, ${state.anchors.size} anchor pairs, ${state.chain.length} chain nodes and ${state.frames.length} keyframes. Click Preview virtual chain to see ghosts; NOT calibrated or rights reviewed.`,
      `已原子恢复 ${state.mappings.size} 项映射、${state.anchors.size} 组端点、${state.chain.length} 个运动链节点与 ${state.frames.length} 个关键帧。点击「预览运动链」查看虚拟网格；未经校准，也未完成版权审核。`
    );
    refreshAtlasParts();
  }).catch(error => {
    setSessionStatus(`Session import rejected: ${String(error)}`,
      `研究会话导入被拒绝：${String(error)}`);
    setSessionDiagnostics("", "");
  }).finally(() => refreshStudySessionControls());
});

function beginLocalAnchor(endpoint: AnchorEndpoint): void {
  const id = atlasViewer?.getSelectedPartId() ?? null;
  if (id === null || !atlasMappings.has(id) ||
      !atlasViewer?.beginAnchorPick(id, endpoint)) {
    atlasAnchorMessage.textContent = locale === "en"
      ? "Select a mapped, visible source mesh and pause any authored animation before marking."
      : "请先选择并映射一个可见原始网格，并暂停模型动画后再标记。";
    return;
  }
  atlasAnchorMessage.textContent = locale === "en"
    ? `Click the selected source mesh #${id} in the 3D viewer to mark the ${endpoint} point. Isolate it if occluded.`
    : `请在 3D 模型视图点击选中的来源网格 #${id}，标记${endpoint === "start" ? "起点 A" : "终点 B"}；如被遮挡，请先独显。`;
}
atlasAnchorStart.addEventListener("click", () => beginLocalAnchor("start"));
atlasAnchorEnd.addEventListener("click", () => beginLocalAnchor("end"));
atlasAnchorClear.addEventListener("click", () => {
  resetStudyChainDraft();
  const id = atlasViewer?.getSelectedPartId();
  if (id !== null && id !== undefined) atlasAnchors.delete(id);
  atlasViewer?.cancelAnchorPick();
  atlasAnchorMessage.textContent = locale === "en"
    ? "Cleared anchor points for the selected mesh."
    : "已清除当前选中来源网格的两个端点。";
  refreshAtlasAnchorStatus();
  refreshAtlasRigidControls();
});
atlasAnchorExport.addEventListener("click", () => {
  const inventory = atlasViewer?.sourceInventory();
  if (!inventory) return;
  try {
    const manifest = makeAnchorDraft(inventory, atlasMappings, atlasAnchors);
    const filename = mappingDownloadName(inventory.fileName)
      .replace("-manual-pose-map.json", "-source-anchor-draft.json");
    const blob = new Blob([JSON.stringify(manifest, null, 2) + "\n"],
      { type: "application/json;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = filename;
    document.body.append(link);
    link.click();
    link.remove();
    window.setTimeout(() => URL.revokeObjectURL(url), 60_000);
    atlasAnchorMessage.textContent = locale === "en"
      ? "Saved LOCAL uncalibrated model-coordinate points. No weights, rights or camera calibration included."
      : "已在本地保存未经校准的原始模型端点。不包含权重、授权或相机标定。";
  } catch (error) {
    atlasAnchorMessage.textContent = `Export refused: ${String(error)}`;
  }
});
atlasAnchorImport.addEventListener("change", () => {
  const file = atlasAnchorImport.files?.[0];
  atlasAnchorImport.value = "";
  const originalInventory = atlasViewer?.sourceInventory();
  if (!file || !originalInventory) return;
  if (file.size < 1 || file.size > 2_000_000) {
    atlasAnchorMessage.textContent = locale === "en"
      ? "Anchor JSON must be 1–2 MB." : "端点 JSON 文件大小必须为 1–2 MB。";
    return;
  }
  atlasAnchorImport.disabled = true;
  void file.text().then((text) => {
    const current = atlasViewer?.sourceInventory();
    if (!current ||
        current.sourceSHA256 !== originalInventory.sourceSHA256 ||
        current.fileSizeBytes !== originalInventory.fileSizeBytes) {
      throw new Error("The local original model changed during anchor import.");
    }
    const raw: unknown = JSON.parse(text);
    const checked = parseAnchorDraft(raw, current, atlasMappings);
    resetStudyChainDraft();
    atlasAnchors.clear();
    atlasViewer?.cancelAnchorPick();
    for (const [id, pair] of checked) atlasAnchors.set(id, pair);
    atlasAnchorMessage.textContent = locale === "en"
      ? `Loaded ${checked.size} LOCAL anchor drafts (not calibrated or legally cleared).`
      : `已导入 ${checked.size} 组本地端点草稿（未经校准或版权审核）。`;
    refreshAtlasAnchorStatus();
    refreshAtlasRigidControls();
  }).catch((error) => {
    atlasAnchorMessage.textContent = locale === "en"
      ? `Anchor import refused: ${String(error)}`
      : `端点导入被拒绝：${String(error)}`;
  }).finally(() => {
    refreshAtlasAnchorStatus();
  });
});

element<HTMLButtonElement>("#open-atlas-studio").addEventListener("click", () => {
  // W3a isolation: local static FBX/GLB study NEVER becomes live retargeting.
  stopCamera("进入本地模型研究模式");
  if (overlayMode === "rig") {
    setRigModeStatus(
      "Experimental rig paused for local model study; imported FBX/GLB files are never camera-retargeted.",
      "实验模式在本地模型研究期间暂停；导入的 FBX / GLB 不会用于摄像头实时跟随。"
    );
  }
  element<HTMLDialogElement>("#layers-dialog").close();
  atlasDialog.showModal();
  void ensureAtlasViewer().then((viewer) => {
    if (!atlasDialog.open) return;
    viewer.resize();
    viewer.start();
  }).catch((error) => {
    atlasInfo.textContent = "WebGL 模型查看器无法启动：" + String(error);
  });
});
atlasDialog.addEventListener("close", () => {
  stopLocalStudyChain();
  stopLocalRigidPreview();
  atlasViewer?.cancelPendingLoad();
  atlasViewer?.cancelAnchorPick();
  atlasViewer?.setAnimationPlaying(false);
  atlasViewer?.stop();
  atlasPlayAnimation.disabled = atlasClipSelect.disabled;
  atlasPauseAnimation.disabled = true;
  setSessionDiagnostics("", "");
});
function loadAtlasFile(file: File, builtInDemo = false): void {
  atlasFile.disabled = true;
  atlasDemoButton.disabled = true;
  atlasInfo.textContent = "正在本地解析模型；大体积 FBX 可能导致浏览器暂时变慢…";
  void ensureAtlasViewer().then((viewer) => viewer.load(file)).then((stats) => {
    resetStudyChainDraft();
    atlasInfo.textContent = stats.file + " · " +
      stats.importedMeshes.toLocaleString() + " 网格 · " +
      stats.triangles.toLocaleString() + " 三角形 · " +
      stats.skinnedMeshes + " SkinnedMesh / " +
      stats.authoredJoints + " 绑定关节。 " +
      (stats.skinnedMeshes > 0 ? "模型具有骨骼绑定数据，尚未验证动画对齐。" :
        "未发现可直接用于人体跟随的绑定网格；仅支持静态研究。");
    atlasViewer?.setWireframe(atlasWireframe.checked);
    atlasViewer?.setOpacity(Number(atlasOpacity.value) / 100);
    atlasViewer?.setSection(atlasSection.value as SliceOrientation, Number(atlasLevel.value));
    const clips = atlasViewer?.getAnimationClips() ?? [];
    atlasClipSelect.replaceChildren();
    for (const clip of clips) {
      const label = clip.name + " · " + clip.durationSeconds.toFixed(1) + "s";
      atlasClipSelect.add(new Option(label, String(clip.id)));
    }
    if (!clips.length) atlasClipSelect.add(new Option(
      locale === "en" ? "No authored animation clips" : "无模型内置动画", ""
    ));
    atlasClipSelect.disabled = clips.length === 0;
    atlasPlayAnimation.disabled = clips.length === 0;
    atlasPauseAnimation.disabled = true;
    if (clips.length) atlasViewer?.selectAnimation(clips[0].id);

    lastAtlasRigStats = stats;
    renderAtlasRigInfo();
    atlasSearch.disabled = false;
    atlasShowAll.disabled = false;
    atlasResetCamera.disabled = false;
    atlasExportInventory.disabled = false;
    resetStudyChainDraft();
    stopLocalRigidPreview();
    atlasMappings.clear();
    atlasAnchors.clear();
    atlasViewer?.cancelAnchorPick();
    atlasAnchorMessage.textContent = "";
    atlasMapError.textContent = "";
    setSessionStatus(SESSION_INVALID_EN, SESSION_INVALID_ZH);
    setSessionDiagnostics("", "");
    atlasPageLimit = 60;
    atlasPart.textContent = locale === "en"
      ? "Select a source mesh to examine its original name and geometry."
      : "点击或搜索来源网格，查看其原始名称和几何结构。";
    refreshAtlasParts();
    if (builtInDemo) initializeOriginalDemoStudy();
  }).catch((error) => {
    if (!atlasDialog.open) return;
    atlasInfo.textContent = "无法导入：" + (error instanceof Error ? error.message : String(error));
    console.warn("Local model parsing failed (no upload attempted)", error);
  }).finally(() => {
    atlasFile.disabled = false;
    atlasDemoButton.disabled = false;
    atlasFile.value = "";
  });
}
function initializeOriginalDemoStudy(): void {
  const viewer = atlasViewer;
  if (!viewer) throw new Error("Original demo viewer not initialized");
  const parts = viewer.getParts();
  const byName = new Map(parts.map(part => [part.name, part.id]));
  // No guessed identifier/index: check all expected original fixture names.
  if (parts.length !== ORIGINAL_STUDY_DEMO.length ||
      ORIGINAL_STUDY_DEMO.some(info => !byName.has(info.sourceName))) {
    throw new Error("The generated original study GLB did not match its authored source metadata");
  }
  resetStudyChainDraft();
  atlasMappings.clear();
  atlasAnchors.clear();
  for (const info of ORIGINAL_STUDY_DEMO) {
    const id = byName.get(info.sourceName)!;
    atlasMappings.set(id, info.intendedSurfaceReference);
    atlasAnchors.set(id, { start: info.start, end: info.end });
    atlasChainIds.add(id);
    atlasChainAngles.set(id, { axis: "z", degrees: info.initialAngle });
    const parent = info.parentSourceName === null
      ? null : byName.get(info.parentSourceName);
    if (parent === undefined) throw new Error("Original demo parent mesh missing");
    atlasChainParents.set(id, parent);
  }
  const nodes = chainNodesForCurrentStudy();
  if (!viewer.beginChainPreview(nodes)) {
    resetStudyChainDraft();
    throw new Error("Original demo chain cannot be previewed");
  }
  const firstId = byName.get(ORIGINAL_STUDY_DEMO[0].sourceName)!;
  viewer.selectPart(firstId);
  atlasChainStatus.textContent = locale === "en"
    ? "Original 3-box DEMO is ready: select a chain node and adjust its angle. Not human bones or camera tracking."
    : "原创三方块示例已就绪：点击运动链节点并拖动角度。此模型不是人体骨骼或摄像头追踪。";
  atlasInfo.textContent = locale === "en"
    ? "Original procedural training fixture (3 generated source meshes). No external anatomy data or download."
    : "原创程序生成的训练示例（3 个来源网格），没有外部解剖资源、无需下载。";
  studyTimelineFrames = [
    studyFrameAt(nodes.map(node => ({ ...node, degrees: 0 })), 0),
    studyFrameAt(nodes, 1500),
    studyFrameAt(nodes.map(node => ({ ...node, degrees: 0 })), 3000),
  ];
  atlasTimelineTime.value = "1500";
  atlasTimelineStatus.textContent = locale === "en"
    ? "The ORIGINAL demo includes 3 synthetic keyframes. Press Loop to see motion."
    : "原创示例已配置 3 个合成角度关键帧，点击循环播放即可观察运动。";
  refreshAtlasParts();
  refreshAtlasChainControls();
  refreshStudyTimelineControls();
}
atlasFile.addEventListener("change", () => {
  const file = atlasFile.files?.[0];
  if (file) loadAtlasFile(file);
});
atlasDemoButton.addEventListener("click", () => {
  atlasDemoButton.disabled = true;
  atlasInfo.textContent = locale === "en"
    ? "Generating an original, self-contained local GLB in this browser…"
    : "正在浏览器内生成原创独立 GLB 示例…";
  void createOriginalStudyDemoFile().then(file => {
    if (!atlasDialog.open) {
      atlasDemoButton.disabled = false;
      return;
    }
    loadAtlasFile(file, true);
  }).catch(error => {
    atlasDemoButton.disabled = false;
    atlasInfo.textContent = locale === "en"
      ? `Could not generate the original demo: ${String(error)}`
      : `无法生成原创示例：${String(error)}`;
    console.error("Local original demo generation failed", error);
  });
});
atlasClipSelect.addEventListener("change", () => {
  const clipId = Number(atlasClipSelect.value);
  if (atlasClipSelect.disabled || !Number.isSafeInteger(clipId)) return;
  const selected = atlasViewer?.selectAnimation(clipId) ?? false;
  atlasPlayAnimation.disabled = !selected;
  atlasPauseAnimation.disabled = true;
});
atlasPlayAnimation.addEventListener("click", () => {
  if (atlasViewer?.setAnimationPlaying(true)) {
    atlasPlayAnimation.disabled = true;
    atlasPauseAnimation.disabled = false;
  }
});
atlasPauseAnimation.addEventListener("click", () => {
  if (atlasViewer?.setAnimationPlaying(false)) {
    atlasPlayAnimation.disabled = false;
    atlasPauseAnimation.disabled = true;
  }
});

function applyAtlasSection(): void {
  atlasViewer?.setSection(atlasSection.value as SliceOrientation, Number(atlasLevel.value));
}
atlasSection.addEventListener("change", applyAtlasSection);
atlasLevel.addEventListener("input", applyAtlasSection);
atlasOpacity.addEventListener("input", () =>
  atlasViewer?.setOpacity(Number(atlasOpacity.value) / 100)
);
atlasWireframe.addEventListener("change", () =>
  atlasViewer?.setWireframe(atlasWireframe.checked)
);
window.addEventListener("resize", () => {
  if (atlasDialog.open) atlasViewer?.resize();
});

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
document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "hidden") {
    pauseStudyTimeline();
    refreshStudyTimelineControls();
  }
});
window.addEventListener("pagehide", () => {
  pauseStudyTimeline();
  stopCamera("页面已离开");
  observer.disconnect();
  runner?.close();
  runner = undefined;
  rigOverlay?.dispose();
  proxy?.dispose();
  atlasViewer?.dispose();
  atlasViewer = undefined;
});
