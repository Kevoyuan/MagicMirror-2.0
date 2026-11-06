"""Download official MediaPipe Pose Landmarker task bundles into local gitignored storage.

Google's 'latest' URLs are mutable. Lite is guarded by exact SHA-256 and byte
size verified using a real MediaPipe 0.10.35 VIDEO CI runtime on Ubuntu.
Full and Heavy remain unpinned experiments, NOT release-reproducible assets.
"""
from __future__ import annotations

import argparse
import hashlib
import pathlib
import urllib.request

MODEL_URLS = {
    name: ("https://storage.googleapis.com/mediapipe-models/"
           f"pose_landmarker/pose_landmarker_{name}/float16/latest/"
           f"pose_landmarker_{name}.task")
    for name in ("lite", "full", "heavy")
}
MODEL_DIR = pathlib.Path(__file__).parent / "models"
MAX_MODEL_BYTES = 75_000_000

# Downloaded and executed successfully in GitHub Linux CI on 2026-11-06:
# MediaPipe 0.10.35 + Pose Landmarker Lite (float16).
# The Google URL remains 'latest', so a new upstream blob will be REFUSED
# until its checksum is reviewed and this lock intentionally updated.
EXPECTED_MODEL_SHA256 = {
    "lite": "59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a",
}
EXPECTED_MODEL_BYTES = {"lite": 5_777_746}

# Backwards-compatible aliases for existing Lite setup code.
MODEL_URL = MODEL_URLS["lite"]
DEST = MODEL_DIR / "pose_landmarker_lite.task"


def model_path(profile: str = "lite") -> pathlib.Path:
    if profile not in MODEL_URLS:
        raise ValueError(f"Unknown MediaPipe model profile: {profile!r}")
    return MODEL_DIR / f"pose_landmarker_{profile}.task"


def verify_model_bytes(profile: str, payload: bytes) -> None:
    """Bounded byte validation; cryptographic lock for audited profiles."""
    if profile not in MODEL_URLS:
        raise ValueError(f"Unknown model profile: {profile}")
    if not 100_000 < len(payload) <= MAX_MODEL_BYTES:
        raise ValueError(f"Unexpected {profile} model size: {len(payload)} bytes")
    expected_size = EXPECTED_MODEL_BYTES.get(profile)
    expected_hash = EXPECTED_MODEL_SHA256.get(profile)
    if expected_size is not None and len(payload) != expected_size:
        raise ValueError(f"{profile} model size changed: expected {expected_size}")
    if expected_hash is not None:
        actual = hashlib.sha256(payload).hexdigest()
        if actual != expected_hash:
            raise ValueError(f"{profile} model SHA-256 mismatch: {actual}")


def verify_local_model(profile: str = "lite") -> pathlib.Path:
    destination = model_path(profile)
    if not destination.is_file():
        raise FileNotFoundError(f"Missing model: {destination}")
    verify_model_bytes(profile, destination.read_bytes())
    return destination


def download(profile: str = "lite") -> pathlib.Path:
    destination = model_path(profile)
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        verify_local_model(profile)
        print("Verified model already present:", destination)
        return destination

    url = MODEL_URLS[profile]
    print(f"Fetching {profile} MediaPipe model from:", url, flush=True)
    request = urllib.request.Request(url, headers={"User-Agent": "MagicMirror-Model-Setup/2.0"})
    temporary = destination.with_suffix(".partial")
    try:
        with urllib.request.urlopen(request, timeout=90) as response:
            payload = response.read(MAX_MODEL_BYTES + 1)
        verify_model_bytes(profile, payload)
        temporary.write_bytes(payload)
        temporary.replace(destination)
    finally:
        if temporary.exists():
            temporary.unlink()
    print("Saved model:", destination, "bytes:", len(payload), flush=True)
    return destination


def main(argv=None):
    parser = argparse.ArgumentParser(description="Download official MediaPipe Pose Landmarker bundle(s)")
    parser.add_argument("--profile", choices=tuple(MODEL_URLS), default="lite")
    parser.add_argument("--all", action="store_true", help="Download Lite, Full and Heavy")
    parser.add_argument("--verify-only", action="store_true",
                        help="Verify local model bytes without downloading")
    args = parser.parse_args(argv)
    for profile in (MODEL_URLS if args.all else (args.profile,)):
        if args.verify_only:
            print("Verified local model:", verify_local_model(profile))
        else:
            download(profile)


if __name__ == "__main__":
    main()
