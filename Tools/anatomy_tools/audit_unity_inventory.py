"""Audit the COMPLETE Unity FBX renderer inventory before anatomical binding.

Consumes JSON exported by:
  Unity > MagicMirror > Phase 4 > Full Atlas Setup > Export Hierarchy Inventory

This is metadata validation ONLY. Name-based grouping hints are NEVER marked
reviewed; atlas joints, pivots, licensing, mesh identity and animation quality
require human/Unity inspection of the actual intact Z-Anatomy model.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from collections import defaultdict

from .fetch_atlas import (
    UPSTREAM_COMMIT, EXPECTED_LENGTH, EXPECTED_GIT_BLOB_SHA1
)

ROOT = Path(__file__).resolve().parents[2]
SOURCE_PATH = "Assets/ThirdParty/ZAnatomy/SkeletalSystem100.fbx"
MANIFEST = ROOT / "Assets-Manifest/asset_sources.json"
ALLOWED_GROUPS = frozenset({
    "Head", "Torso",
    "LeftUpperArm", "RightUpperArm", "LeftForearm", "RightForearm",
    "LeftHand", "RightHand", "LeftThigh", "RightThigh", "LeftShin",
    "RightShin", "LeftFoot", "RightFoot",
})
MAX_ENTRIES = 100000


def pinned_source_issues(manifest: dict) -> list[str]:
    """Compare the checked-in provenance manifest with pinned download code."""
    if not isinstance(manifest, dict):
        return ["Asset provenance manifest must be an object"]
    models = manifest.get("models", [])
    if not isinstance(models, list):
        return ["Asset provenance models must be an array"]
    skeletons = [entry for entry in models if isinstance(entry, dict)
                 and entry.get("file") == "SkeletalSystem100.fbx"]
    if len(skeletons) != 1:
        return ["Exactly one complete SkeletalSystem100.fbx record is required"]
    item = skeletons[0]
    expected = {
        "bytes": EXPECTED_LENGTH,
        "sourceRevision": UPSTREAM_COMMIT,
        "expectedGitBlobSha1": EXPECTED_GIT_BLOB_SHA1,
        "preferredLocalPath": "Unity/" + SOURCE_PATH,
        "distributed": False,
        "licenseStatus": "pending-review",
    }
    issues = []
    for field, value in expected.items():
        if type(item.get(field)) is not type(value) or item.get(field) != value:
            issues.append(f"Atlas manifest mismatch: {field}")
    return issues


def validate_inventory(inventory: dict, manifest: dict) -> dict:
    """Validate schema, renderer paths and source policy; produce UNVERIFIED hints."""
    issues = pinned_source_issues(manifest)
    if not isinstance(inventory, dict):
        raise ValueError("Unity inventory must be a JSON object")
    if inventory.get("sourceAssetPath") != SOURCE_PATH:
        issues.append("Inventory must identify the pinned complete Unity FBX path")
    entries = inventory.get("entries")
    declared_count = inventory.get("rendererCount")
    if (not isinstance(entries, list) or
            not 1 <= len(entries) <= MAX_ENTRIES):
        issues.append("Inventory must contain 1..100000 renderer entries")
        entries = []
    if type(declared_count) is not int or declared_count != len(entries):
        issues.append("Renderer count mismatch")

    paths = set()
    by_group = defaultdict(list)
    rigid_count = skinned_count = unknown_count = 0
    for i, entry in enumerate(entries):
        if not isinstance(entry, dict):
            issues.append(f"Entry {i}: must be object")
            continue
        path = entry.get("hierarchyPath")
        name = entry.get("objectName")
        kind = entry.get("rendererType")
        hint = entry.get("suggestedGroup", "")
        verified = entry.get("verified")
        if not isinstance(path, str) or not path or len(path) > 4096 or (
                path.startswith("/") or path.endswith("/") or "//" in path):
            issues.append(f"Entry {i}: invalid relative hierarchy path")
            continue
        if path in paths:
            issues.append(f"Entry {i}: duplicate hierarchy path {path}")
        paths.add(path)
        if not isinstance(name, str) or not name.strip():
            issues.append(f"Entry {i}: missing object name")
        if not isinstance(kind, str) or not kind.endswith("Renderer"):
            issues.append(f"Entry {i}: invalid Unity renderer type")
        if verified is not False:
            issues.append(f"Entry {i}: inventory cannot claim human review")
        if hint and hint not in ALLOWED_GROUPS:
            issues.append(f"Entry {i}: unsupported segment suggestion: {hint}")

        if kind == "MeshRenderer":
            rigid_count += 1
            if hint in ALLOWED_GROUPS:
                by_group[hint].append(path)
            else:
                unknown_count += 1
        elif kind == "SkinnedMeshRenderer":
            skinned_count += 1
        else:
            unknown_count += 1

    conflicts = []
    sorted_paths = sorted(paths)
    # Prefix-overlap detection is non-destructive: a candidate path might
    # contain another renderer under it, so DO NOT auto-create motion groups.
    for i, path in enumerate(sorted_paths):
        ancestor_parts = path.split("/")
        for k in range(1, len(ancestor_parts)):
            parent = "/".join(ancestor_parts[:k])
            if parent in paths:
                conflicts.append([parent, path])

    if issues:
        raise ValueError("Atlas inventory/manifest validation failed:\n- " +
                         "\n- ".join(issues[:40]))

    return {
        "sourceAssetPath": SOURCE_PATH,
        "sourceRevision": UPSTREAM_COMMIT,
        "expectedGitBlobSha1": EXPECTED_GIT_BLOB_SHA1,
        "rendererCount": len(entries),
        "rigidMeshRendererCount": rigid_count,
        "skinnedMeshRendererCountUnsupportedByCurrentRig": skinned_count,
        "unassignedOrUnsupportedRendererCount": unknown_count,
        "potentialParentChildRendererPathConflicts": conflicts,
        "unverifiedCandidates": [
            {
                "segmentHint": group,
                "rendererRootPathCandidates": sorted(path_list),
                "reviewed": False,
                "atlasStartLocal": None,
                "atlasEndLocal": None,
            }
            for group, path_list in sorted(by_group.items())
        ],
        "identityAndAnchorsReviewed": False,
        "licensesReviewed": False,
        "readyForRealAnatomyRig": False,
        "warning": (
            "Name-based candidates only. Check mesh identity, side, center, "
            "rest orientation, source licenses, and non-overlapping subtrees "
            "in Unity before entering a real FullBodyAtlasProfile."
        ),
    }


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="MagicMirror M3 whole-atlas inventory audit")
    p.add_argument("--inventory", type=Path, required=True,
                   help="Real Unity Editor-exported hierarchy inventory JSON")
    p.add_argument("--manifest", type=Path, default=MANIFEST)
    p.add_argument("--report", type=Path)
    args = p.parse_args(argv)
    try:
        inventory = json.loads(args.inventory.read_text(encoding="utf-8"))
        manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
        result = validate_inventory(inventory, manifest)
        encoded = json.dumps(result, indent=2, ensure_ascii=False) + "\n"
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(encoded, encoding="utf-8")
        print(encoded)
        return 0
    except (OSError, ValueError) as error:
        p.error(str(error))


if __name__ == "__main__":
    raise SystemExit(main())
