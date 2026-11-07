# MagicMirror iOS — reviewed anatomy learning notes

The installed iPhone app can now display source-specific explanatory
copy in the live 3D anatomy selection card. All data remains offline
in the signed application bundle. No model, image, body landmarks,
selection or personalized health information is sent to a service.

## Standalone, independently reviewed educational text

Each anatomical system may optionally supply a
\`<resourceBase>.education.json\` file directly inside the native
MagicMirror bundle (e.g. \`skeleton_atlas.education.json\`,
\`muscles_atlas.education.json\`, \`organs_atlas.education.json\`).
Only add files that an actual human expert or qualified editor has
reviewed for factual accuracy and publishing rights.

Start from \`Mobile/iOS/Scripts/anatomy_education.review.template.json\`.
The template has deliberately false approval and placeholder content
and must **not** be redistributed as published reference text.

\`\`\`json
{
  "schemaVersion": 1,
  "anatomicalSystem": "skeleton",
  "sourceRevision": "PINNED_ORIGINAL_MODEL_COMMIT",
  "reviewedForEducationalDisplay": true,
  "authorCredit": "Actual editor, source and license for the text",
  "entries": [{
    "sourceHierarchyPath": "EXACT_APPROVED_MODEL_NODE_PATH",
    "title": "Reviewed English anatomical structure name",
    "titleZh": "审核过的中文名称",
    "summary": "An accurate, reviewed educational explanation.",
    "summaryZh": "经过审核的中文教学说明。",
    "functionalNote": "Optional validated structure/function context.",
    "functionalNoteZh": "可选的已审核功能介绍。"
  }]
}
\`\`\`

The loader is intentionally narrow. It refuses a sidecar larger than
512 KB, the wrong source revision or system, false review flag,
missing author credit, duplicate or unsafe source hierarchy paths,
empty or excessive text, and unknown names. English is required;
Chinese language fields are optional and fall back individually to
English. No language model generates or guesses anatomy text.

The on-camera part-selection result is obtained exclusively from a
verified model's **actual** named mesh triangles. Notes are attached
only if the source revision, anatomical system and exact named mesh
part all match. The fallback card still identifies the 3D geometry as
an educational reference, **not a scan or measurement of the viewer's
internal skeleton**. Lack of educational text never unlocks an
unreviewed atlas.

These are source and UI implementations, not signoff on clinical
content, external textbook rights, the Z-Anatomy geometry, camera/body
registration, or iPhone runtime performance. The actual release still
requires the separate human review and phone acceptance gates.
