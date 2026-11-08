#!/usr/bin/env python3
"""Stage a verifiable, human-readable in-app attribution and model download.

Use after actually publishing the separately licensed public model ZIP
and updating paid-app-clearance.json. A staged notice is NOT permission
to ship; the Release asset/rights gate checks it independently.
"""
import argparse
import json
from pathlib import Path

from paid_release_gate import (_approval, _json, _nonempty, _require,
                               CommercialReleaseError, CLEARANCE_NAME,
                               DEFAULT_ROOT)


def notice_from_clearance(clearance):
    _approval(clearance)
    publications = clearance.get("shareAlikePublications")
    _require(isinstance(publications, list) and publications,
             "No separate CC BY-SA model publications have been approved")
    result = []
    for pub in publications:
        _require(isinstance(pub, dict) and
                 _nonempty(pub.get("id")) and
                 _nonempty(pub.get("modelFile")) and
                 _nonempty(pub.get("publicURL")) and
                 _nonempty(pub.get("publicArchiveSHA256")),
                 "Incomplete public download information")
        result.append({
            "id": pub["id"],
            "modelFile": pub["modelFile"],
            "licenseId": "CC-BY-SA-4.0",
            "authorCredits": "Z-Anatomy and BodyParts3D",
            "publicURL": pub["publicURL"],
            "publicArchiveSHA256": pub["publicArchiveSHA256"],
        })
    return {"schemaVersion": 1, "publicModels": result}


def stage(root=DEFAULT_ROOT):
    root = Path(root)
    notice = notice_from_clearance(_json(root / CLEARANCE_NAME))
    output = root / "Resources" / "CCModelAttribution.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(notice, indent=2, ensure_ascii=False) + "\n"
    if output.exists() and output.read_text(encoding="utf-8") != payload:
        raise CommercialReleaseError(
            "CCModelAttribution.json exists with different contents. "
            "Remove it only after independent rights and public URL review."
        )
    output.write_text(payload, encoding="utf-8")
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    args = parser.parse_args()
    try:
        output = stage(args.root)
    except (OSError, ValueError) as exc:
        parser.exit(1, f"NOTICE BLOCKED: {exc}\n")
    print(f"Staged disclosure only (release not approved): {output}")


if __name__ == "__main__":
    main()
