/**
 * Original concise educational commentary about GENERIC anatomy.
 * Observed limb segments are only 2D pose references; neither
 * location nor size is an actual measurement of an individual's bones.
 */
export interface EducationNote {
  id: string;
  titleZh: string;
  titleEn: string;
  descriptionZh: string;
  descriptionEn: string;
  landmarkWarning: string;
}
const warning = "人体表面姿态参考，不代表个人真实骨骼位置。";
const notes: Record<string, Omit<EducationNote, "id" | "landmarkWarning">> = {
  "11-13": {
    titleZh: "左上臂参考 · 肱骨区域",
    titleEn: "Left upper arm · Humerus region",
    descriptionZh: "肱骨位于上臂，连接肩部与肘部。此处仅显示肩肘表面关键点之间的教学参考段。",
    descriptionEn: "The humerus spans the upper arm between shoulder and elbow. The overlay uses only estimated surface landmarks.",
  },
  "12-14": {
    titleZh: "右上臂参考 · 肱骨区域",
    titleEn: "Right upper arm · Humerus region",
    descriptionZh: "肱骨是上臂的主要长骨。这个 3D 示意段仅跟随可见肩肘姿态。",
    descriptionEn: "The humerus is the main long bone in the upper arm. This proxy follows observed shoulder and elbow pose only.",
  },
  "13-15": {
    titleZh: "左前臂参考 · 桡骨与尺骨区域",
    titleEn: "Left forearm · Radius and ulna region",
    descriptionZh: "前臂由桡骨与尺骨组成，支持旋前与旋后等动作。当前单段示意不能区分两根真实骨头。",
    descriptionEn: "The forearm contains the radius and ulna, involved in pronation and supination. This single proxy does not distinguish them.",
  },
  "14-16": {
    titleZh: "右前臂参考 · 桡骨与尺骨区域",
    titleEn: "Right forearm · Radius and ulna region",
    descriptionZh: "桡骨与尺骨从肘部延伸到腕部；这里仅绘制估计关节间的抽象 3D 示意。",
    descriptionEn: "The radius and ulna extend from elbow to wrist. This is an abstract 3D reference between estimated landmarks.",
  },
  "23-25": {
    titleZh: "左大腿参考 · 股骨区域",
    titleEn: "Left thigh · Femur region",
    descriptionZh: "股骨连接髋部与膝部，是人体最粗壮的长骨之一；这里不是实际股骨影像。",
    descriptionEn: "The femur runs between hip and knee and is one of the body's largest long bones. This is not actual femur imaging.",
  },
  "24-26": {
    titleZh: "右大腿参考 · 股骨区域",
    titleEn: "Right thigh · Femur region",
    descriptionZh: "股骨参与髋部与膝部运动。示意柱体仅用于理解观测到的动作，不反映股骨形状。",
    descriptionEn: "The femur contributes to hip and knee movement. This cylinder illustrates movement, not actual bone morphology.",
  },
  "25-27": {
    titleZh: "左小腿参考 · 胫骨与腓骨区域",
    titleEn: "Left shin · Tibia and fibula",
    descriptionZh: "胫骨主要承担小腿负重，腓骨位于其外侧。当前跟踪只有一条示意段。",
    descriptionEn: "The tibia bears much lower-leg load, while the fibula lies laterally. Only one approximate segment is tracked.",
  },
  "26-28": {
    titleZh: "右小腿参考 · 胫骨与腓骨区域",
    titleEn: "Right shin · Tibia and fibula",
    descriptionZh: "小腿包含胫骨和腓骨，与踝关节稳定性和运动有关。示意线不是两根真实骨骼。",
    descriptionEn: "The lower leg contains tibia and fibula, relevant to ankle stability and movement. This is not a two-bone reconstruction.",
  },
  "11-12": {
    titleZh: "双肩参考线",
    titleEn: "Shoulder reference span",
    descriptionZh: "肩部姿态参考用于估计躯干朝向；它不描绘锁骨、肩胛骨的真实位置或形态。",
    descriptionEn: "This surface shoulder span helps estimate torso orientation; it does not render actual clavicles or scapulae.",
  },
  "11-23": {
    titleZh: "左侧躯干参考",
    titleEn: "Left torso reference",
    descriptionZh: "连接肩髋关键点的参考线帮助观察躯干倾斜，而非脊柱、肋骨或器官。",
    descriptionEn: "A shoulder–hip guide illustrates torso lean, not actual vertebrae, ribs or internal organs.",
  },
  "12-24": {
    titleZh: "右侧躯干参考",
    titleEn: "Right torso reference",
    descriptionZh: "这条线表示人体表面估算姿态中的肩髋关系，不是可见的真实骨架。",
    descriptionEn: "This line shows an estimated surface shoulder-to-hip relationship, not a visible internal skeleton.",
  },
  "23-24": {
    titleZh: "双髋参考线",
    titleEn: "Hip reference span",
    descriptionZh: "髋部是连接躯干和下肢运动的重要区域。此处仅使用两个体表估算关键点。",
    descriptionEn: "The hip region links torso and lower-limb movement. Here only two estimated surface landmarks are used.",
  },
};
export function educationFor(fromIndex: number, toIndex: number): EducationNote | null {
  const id = [fromIndex, toIndex].join("-");
  const content = notes[id];
  return content ? { id, ...content, landmarkWarning: warning } : null;
}
