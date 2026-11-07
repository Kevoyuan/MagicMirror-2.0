#!/usr/bin/env bash
set -euo pipefail

# Development/build-time model acquisition ONLY; phone inference is offline.
# This exact bundle was verified by existing Linux MediaPipe model CI.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$ROOT/Resources/pose_landmarker_lite.task"
URL="https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/latest/pose_landmarker_lite.task"
SHA="59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a"
EXPECTED_BYTES=5777746

mkdir -p "$ROOT/Resources"
TMP="$(mktemp "${TMPDIR:-/tmp}/magicmirror-model.XXXXXX")"
trap 'rm -f "$TMP"' EXIT

check_model() {
  local file="$1"
  local bytes sha
  bytes="$(wc -c < "$file" | tr -d '[:space:]')"
  sha="$(shasum -a 256 "$file" | awk '{print $1}')"
  if [[ "$bytes" != "$EXPECTED_BYTES" || "$sha" != "$SHA" ]]; then
    echo "Model verification FAILED: size=$bytes sha256=$sha" >&2
    return 1
  fi
}

if [[ -f "$TARGET" ]]; then
  check_model "$TARGET"
  echo "Verified bundled Lite model: $TARGET"
  exit 0
fi

echo "Downloading MediaPipe Lite model for LOCAL app bundling ..."
curl --fail --location --silent --show-error --retry 3 "$URL" --output "$TMP"
check_model "$TMP"
mv "$TMP" "$TARGET"
echo "Pinned Lite model verified and staged: $TARGET"
