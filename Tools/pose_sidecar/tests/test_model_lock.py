"""Model integrity lock tests; run without MediaPipe, camera or model download."""
import hashlib
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch
import unittest

from Tools.pose_sidecar.download_model import (
    EXPECTED_MODEL_SHA256, EXPECTED_MODEL_BYTES,
    MAX_MODEL_BYTES, verify_model_bytes, verify_local_model
)
from Tools.pose_sidecar.smoke_runtime import verify_video_runtime


class ModelLockTests(unittest.TestCase):
    def test_verified_lite_manifest_is_well_formed(self):
        self.assertEqual(EXPECTED_MODEL_BYTES["lite"], 5777746)
        self.assertEqual(len(EXPECTED_MODEL_SHA256["lite"]), 64)
        int(EXPECTED_MODEL_SHA256["lite"], 16)

    def test_accepts_exact_matching_digest_and_rejects_tamper(self):
        payload = b"model-test-payload" * 6000
        expected_sha = hashlib.sha256(payload).hexdigest()
        with (patch.dict(EXPECTED_MODEL_SHA256, {"lite": expected_sha}),
              patch.dict(EXPECTED_MODEL_BYTES, {"lite": len(payload)})):
            verify_model_bytes("lite", payload)
            with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
                verify_model_bytes("lite", payload[:-1] + b"X")

    def test_rejects_changed_size_even_when_sha_is_present(self):
        payload = b"a" * 100_001
        with patch.dict(EXPECTED_MODEL_BYTES, {"lite": len(payload) + 1}):
            with self.assertRaisesRegex(ValueError, "size changed"):
                verify_model_bytes("lite", payload)

    def test_rejects_missing_tiny_or_oversized_model(self):
        with self.assertRaises(ValueError):
            verify_model_bytes("full", b"short")
        with self.assertRaises(ValueError):
            verify_model_bytes("full", b"x" * (MAX_MODEL_BYTES + 1))
        with self.assertRaisesRegex(ValueError, "Unknown"):
            verify_model_bytes("another-model", b"x" * 100_001)

    def test_full_and_heavy_still_unpinned(self):
        for profile in ("full", "heavy"):
            self.assertNotIn(profile, EXPECTED_MODEL_SHA256)
            verify_model_bytes(profile, b"x" * 100_001)

    def test_real_runtime_missing_model_fails_before_mediapipe_import(self):
        with TemporaryDirectory() as tmp:
            missing = Path(tmp) / "not-a-model.task"
            with self.assertRaises(FileNotFoundError):
                verify_video_runtime(missing, frames=2)

    def test_real_runtime_invalid_frame_count_precedes_heavy_import(self):
        with TemporaryDirectory() as tmp:
            fake = Path(tmp) / "placeholder.task"
            fake.write_bytes(b"not-a-model")
            with self.assertRaisesRegex(ValueError, "frames"):
                verify_video_runtime(fake, frames=0)


if __name__ == "__main__":
    unittest.main()
