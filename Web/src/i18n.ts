/** Original MagicMirror Web UI copy; no external localization service. */
export type Locale = "zh" | "en";

const en: Record<string, string> = {
  // Camera, status and controls
  "准备就绪": "Ready",
  "开启摄像头": "Start camera",
  "暂停叠加": "Pause overlay",
  "恢复叠加": "Resume overlay",
  "切换镜头": "Flip camera",
  "关闭摄像头": "Stop camera",
  "保存画面": "Save image",
  "本地推理 · 尚未运行": "On-device inference · Not started",
  "观察区域": "Body region",
  "全身": "Whole",
  "手臂": "Arms",
  "腿部": "Legs",
  "参考透明度": "Reference opacity",
  "解剖图层": "Anatomy layers",
  "隐私与来源": "Privacy & credits",
  "ANATOMIA IN MOTU": "ANATOMIA IN MOTU",
  "让人体结构": "Discover the anatomy",
  "随着动作显现": "in motion",
  "在浏览器中启用摄像头，观察跟随可见身体部位的半透明 3D 教学示意骨架。":
    "Turn on your camera to see an illustrative 3D reference follow visible body movements.",
  "无需账号 · 本地姿态推理 · 需要摄像头权限":
    "No account · On-device pose inference · Camera permission required",
  "将相机对准一人；双肩和髋部可见时能获得更完整的参考。":
    "Point the camera at one person; shoulders and hips improve torso coverage.",
  "3D 示意模型": "Illustrative 3D proxy",
  "点击骨骼参考段学习基础解剖；并非真实骨骼、X 光或医学诊断。":
    "Tap reference segments to learn anatomy; not actual bones, X-ray or medical diagnosis.",
  "教学示意 ≠ 真实骨骼扫描 · 非医疗诊断":
    "Educational reference ≠ actual bone scan · Not a medical diagnosis",
  "局部解剖学习卡片": "Anatomy learning note",
  "关闭解剖学习卡片": "Close learning note",
  // Camera dynamic states and errors
  "相机已关闭": "Camera closed",
  "相机已关闭，已关闭摄像头": "Camera closed",
  "页面进入后台，已关闭摄像头": "Camera stopped when the page was hidden",
  "页面已离开": "Page unloaded",
  "摄像头设备已断开，请重新开启": "Camera disconnected; restart to recover",
  "设备断开或权限被撤销，请检查摄像头权限后重试。":
    "Camera disconnected or permission revoked. Check browser permission and restart.",
  "进入本地模型研究模式": "Entering local model study mode",
  "需要 HTTPS 或 localhost 才能使用摄像头": "Camera requires HTTPS or localhost",
  "请使用 HTTPS 地址或本机 localhost 打开网页。":
    "Open the page using HTTPS or localhost.",
  "正在请求摄像头权限…": "Requesting camera permission…",
  "加载本地模型…": "Loading local pose model…",
  "寻找人体姿态": "Searching for body pose",
  "请将一人移入镜头。局部手臂或腿部也可开始识别。":
    "Move one person into frame. A visible arm or leg can start partial tracking.",
  "摄像头权限已拒绝，请在浏览器设置中开启":
    "Camera permission denied; enable it in browser settings",
  "未检测到可用摄像头": "No camera was found",
  "无法启动：检查浏览器摄像头、WASM 和本地模型资源":
    "Cannot start: check camera, WASM and local model files",
  "将一个人移入画面；上半身或可见手臂均可尝试。":
    "Frame one person, with the upper body or a visible arm.",
  "已识别 · 躯干稳定": "Tracking · Torso visible",
  "已识别 · 局部姿态": "Tracking · Partial body",
  "当前区域不可见": "Selected region not visible",
  "参考叠加已暂停": "Reference overlay paused",
  "正在追踪": "Tracking",
  "姿态已丢失 · 自动重新识别": "Pose lost · Reacquiring",
  "检测结果过期，正在重新识别": "Stale pose discarded · Reacquiring",
  "当前设备处理较慢，已隐藏不可靠的叠加模型。":
    "Processing is slow. Unreliable overlay is hidden.",
  "请保持关键部位可见，或调整取景。":
    "Keep key body parts visible or adjust framing.",
  "局部参考已启动。双肩与髋部可见时才有完整躯干参考。":
    "Partial pose active. Show shoulders and hips for full torso reference.",
  "姿态引擎发生错误": "Pose engine error",
  "请重新开启摄像头；若多次失败，请检查 WASM/模型文件和浏览器兼容性。":
    "Restart camera. If it fails repeatedly, check WASM, model files and browser compatibility.",
  "无法保存 PNG。请确认相机正常，并检查浏览器的下载权限。":
    "Cannot save PNG. Check camera and browser download permissions.",
  "此设备不支持 WebGL 渲染": "WebGL rendering is not supported on this device",
  "姿态检测失败，请重试": "Pose detection failed. Please retry.",
  // Local anatomy folio and other static UI
  "关闭图层": "Close layers",
  "只有原创程序生成的三维示意骨架可用。Z-Anatomy 的真实骨骼、肌肉与器官尚未通过授权、绑定和配准验收。":
    "Only the original procedural proxy is camera-tracked. Real Z-Anatomy bones, muscles and organs still require rights, rigging and registration review.",
  "稳定显示示意骨架（无关节预测）": "Stabilize proxy display (no joint prediction)",
  "导入本地 FBX / GLB 解剖模型": "Load local FBX / GLB anatomy file",
  "仅在本设备预览你主动选择的文件，模型不会上传。导入的是静态研究模型，尚未与人体姿态绑定。":
    "Preview a file you select only on this device; it is never uploaded. The imported model is static and not linked to live human pose.",
  "◉ 参考骨架 / Proxy": "◉ Procedural skeleton / Proxy",
  "已实现": "Available",
  "待审核": "Requires review",
  "规划中": "Planned",
  "骨骼 / Anatomy atlas": "Bones / Anatomy atlas",
  "肌肉 / Muscles": "Muscles",
  "器官 / Organs": "Organs",
  "横断 / 矢状 / 冠状剖面": "Axial / Sagittal / Coronal sections",
  "关闭说明": "Close information",
  "相机帧在浏览器内交给 MediaPipe 进行姿态估算；本项目代码不会自动上传、录制或保存摄像头画面。仅当你主动点击“保存画面”，浏览器才会在本地生成 PNG 并提供下载。MediaPipe SDK 可能按其隐私声明处理使用指标，正式公开部署前仍需单独核查。":
    "Camera frames are processed by MediaPipe in this browser. MagicMirror never automatically saves, records or uploads them. Saving a PNG happens only after you press Save image. The SDK may collect operational metrics, subject to a separate privacy review.",
  "推理模型来自 Google MediaPipe，首次开发准备阶段下载并校验哈希；WASM 与模型需通过本地静态服务器提供。首次启用和站点部署需要 HTTPS（localhost 例外）。":
    "The pose model comes from Google MediaPipe and is SHA-verified during developer setup. WASM and model files are served locally. Public hosting requires HTTPS (localhost is exempt).",
  "目前可见的是 MagicMirror 原创程序生成的三维示意骨架，":
    "The current 3D proxy is generated by MagicMirror original code.",
  "没有使用或分发任何未经审核的 Z-Anatomy 网格":
    "No unreviewed Z-Anatomy meshes are shipped",
  "。真实解剖模型及其署名将按资产来源逐项审核。":
    "Real anatomy models and attribution require source-by-source review.",
  "绑定与动画诊断": "Rig and authored animation diagnostics",
  "尚未载入骨骼模型。仅检查模型内实际存在的关节、顶点权重及动画，不进行人体实时跟随。":
    "No rigged model loaded. Only genuine imported joints, vertex weights and animation clips are inspected; no live body retargeting.",
  "模型内置动画": "Authored model animation",
  "无可预览动画": "No previewable animation",
  "播放": "Play",
  "暂停": "Pause",
  "仅播放导入文件自带的动作；不是 MediaPipe 身体动作驱动，也不是已校准的解剖骨骼绑定。":
    "Only original clips from the imported model are played. This is not MediaPipe body-motion tracking or calibrated anatomy rigging.",
  "人工姿态映射草稿 · 非实际骨骼绑定": "Manual pose segment mapping · No bone rig",
  "请根据原始网格名称与实际模型，自行标记对应的 MediaPipe 体表参考段。映射未经过解剖、骨骼绑定或相机校准审核。":
    "Assign each source mesh to a coarse MediaPipe surface-reference segment yourself. This is not anatomically reviewed, rigged or camera calibrated.",
  "未映射任何原始网格": "No source meshes mapped",
  "导出映射草稿": "Export mapping draft",
  "导入本地映射 JSON": "Import local mapping JSON",
  "清空映射": "Clear mappings",
  "多部件运动链 · 原模型虚拟预览": "Multi-mesh virtual chain · Original-model study",
  "选择至少两个已标记 A/B 的普通来源网格，手动指定父部件。运动以独立金色线框副本呈现，原始网格完全不修改。模型坐标轴和端点未经过医学、相机或真实关节校准。":
    "Select at least two original plain meshes with A/B points and manually assign parents. Gold wireframe ghosts move while all source geometry stays unchanged. Model axes and clicked points are NOT medically, camera or joint calibrated.",
  "加入选中部件": "Add selected mesh",
  "移除选中部件": "Remove selected mesh",
  "当前选中部件的父节点": "Parent of selected source mesh",
  "无父节点": "No parent",
  "预览运动链": "Preview virtual chain",
  "停止并恢复": "Stop and restore",
  "当前节点旋转轴": "Selected node rotation axis",
  "当前节点角度": "Selected node angle",
  "所有角度归零": "Zero all angles",
  "请选择真实来源网格建立 2–12 节人工运动链；不执行人体追踪。":
    "Choose 2–12 real source meshes for a manual virtual chain; no human pose tracking.",
  "单部件刚体旋转实验 · 本地预览": "Single-mesh rigid rotation · Local experiment",
  "选择已映射且有 A/B 端点的普通网格，以原始模型的 A 点为支点，绕模型 X/Y/Z 轴旋转。B 点仅表示运动参考方向；不生成骨骼关节、权重或人体实时动画。带 SkinnedMesh 或内置动画的模型不可使用此模式。":
    "Select a mapped, ordinary mesh with A/B endpoints. Rotate around A using the SOURCE model X/Y/Z axis. B is a movement reference, not a bone joint. No rig, weights or human-driven animation is generated. Models containing SkinnedMesh or authored clips are excluded.",
  "开启局部运动预览": "Start local rigid preview",
  "原模型旋转轴": "Source-model rotation axis",
  "旋转角度": "Rotation angle",
  "恢复原始姿态": "Restore original pose",
  "未开始。需要一个普通可见网格、人工映射和两个不同的模型空间端点。":
    "Not started. Select a visible ordinary mesh with manual mapping and two distinct original-model points.",
  "模型空间端点草稿": "Original model-space point drafts",
  "先在部件列表中选定并映射一个网格，再点“标记起点/终点”，最后在 3D 视图中点击同一网格表面。遮挡时请先独显。坐标来自原始模型，并非解剖关节、已校准姿态或动态骨骼。":
    "First select and map a source mesh, then choose Mark A/B and click the SAME source mesh in the 3D viewer. Isolate if occluded. These are original-model coordinates, not anatomical joints, calibrated pose or a live skeletal rig.",
  "标记起点 A": "Mark point A",
  "标记终点 B": "Mark point B",
  "清除此网格端点": "Clear selected points",
  "导出端点草稿": "Export point draft",
  "导入端点 JSON": "Import point JSON",
  "尚未标记任何模型空间端点": "No original model-space points marked",
  "原始部件与层级": "Original meshes and hierarchy",
  "尚未导入模型": "No model loaded",
  "按原始网格名称或层级路径搜索": "Search original mesh names or hierarchy paths",
  "显示全部": "Show all",
  "退出独立显示": "Exit isolate",
  "重置视角": "Reset view",
  "导出来源清单 JSON": "Export source inventory JSON",
  "已导入模型的来源部件列表": "Imported original source mesh list",
  "显示更多匹配部件": "Show more matching meshes",
  "例如 Femur / Pelvis / 左侧名称": "e.g. Femur / Pelvis / left source name",
  "解剖模型研究台": "Anatomy study viewer",
  "关闭本地模型查看器": "Close local anatomy viewer",
  "仅本地查看。导入模型不会发送到服务器，也不会用于公共下载或自动授权；它":
    "Local inspection only. The model is never sent to a server or used for public distribution. It",
  "不能跟随人体动作": "cannot follow a person's movement",
  "，剖面沿模型坐标轴而非真实医学解剖轴。":
    "; section planes follow model axes, not medically registered anatomical axes.",
  "选择本机 .fbx 或 .glb（≤75MB，建议电脑使用）":
    "Choose a local .fbx or .glb (up to 75 MB; desktop recommended)",
  "可以拖动旋转、滚轮缩放、点击查看原始部件名称的三维模型":
    "Drag to rotate, scroll to zoom and click to inspect original mesh names",
  "模型空间切面": "Model-space section",
  "关闭": "Off",
  "横向 / Y 轴": "Horizontal / Y axis",
  "左右 / X 轴": "Left–right / X axis",
  "前后 / Z 轴": "Front–back / Z axis",
  "剖面位置": "Slice position",
  "透明度": "Opacity",
  "显示网格": "Show wireframe",
  "拖动旋转，滚轮缩放，点击部件查看源网格名称。":
    "Drag to rotate, scroll to zoom, click a mesh to inspect its original name.",
  "注意：即使可以导入 Z-Anatomy，本地静态浏览也不证明模型已绑定动画、逐网格许可合规或可公开商用。":
    "Even if Z-Anatomy loads, a local static preview does not establish skinning, component-by-component rights or commercial redistribution permission.",
};
export function translate(copy: string, locale: Locale): string {
  return locale === "en" ? en[copy] ?? copy : copy;
}

const storedText = new WeakMap<Text, string>();
const storedAttributes = new WeakMap<Element, Map<string, string>>();

/** Translate literal DOM text in place, never user-generated model names. */
export function translateStaticDOM(root: Element, locale: Locale): void {
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  while (walker.nextNode()) {
    const node = walker.currentNode as Text;
    if (node.parentElement?.closest(
      "#tracking-status,#guidance,#part-note,#atlas-info,#atlas-part,#frame-metric,#opacity-value,#atlas-map-count,#atlas-map-error,#atlas-anchor-summary,#atlas-anchor-message,#atlas-rig-info,#atlas-part-count,#atlas-chain-status"
    )) continue;
    const original = storedText.get(node) ?? node.textContent ?? "";
    if (!storedText.has(node)) storedText.set(node, original);
    const match = /^(\s*)(.*?)(\s*)$/s.exec(original);
    if (!match) continue;
    node.textContent = match[1] + translate(match[2], locale) + match[3];
  }
  root.querySelectorAll("[aria-label],[title],[placeholder]").forEach((element) => {
    const old = storedAttributes.get(element) ?? new Map<string, string>();
    for (const attr of ["aria-label", "title", "placeholder"]) {
      const current = element.getAttribute(attr);
      if (current === null) continue;
      if (!old.has(attr)) old.set(attr, current);
      element.setAttribute(attr, translate(old.get(attr)!, locale));
    }
    storedAttributes.set(element, old);
  });
}
