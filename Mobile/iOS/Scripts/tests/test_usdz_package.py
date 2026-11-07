"""Synthetic USDZ binary structure tests; never a real reviewed anatomy stage."""
from pathlib import Path
import struct
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from usdz_package import (  # noqa: E402
    USDZPackageError, pack_usdc_as_usdz, verify_usdz,
)


class AlignedUSDZPackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.stage = self.root / "fixture.usdc"
        self.stage.write_bytes(b"PXR-USDC" + b"\0" * 1024)
        self.archive = self.root / "anatomy_atlas.usdz"

    def test_constructs_valid_uncompressed_aligned_default_layer(self):
        details = pack_usdc_as_usdz(self.stage, self.archive)
        self.assertEqual(details["stage"], "defaultLayer.usdc")
        with zipfile.ZipFile(self.archive, "r") as z:
            self.assertEqual(z.namelist(), ["defaultLayer.usdc"])
            info = z.infolist()[0]
            self.assertEqual(info.compress_type, zipfile.ZIP_STORED)
            self.assertEqual(info.flag_bits & 9, 0)
            with self.archive.open("rb") as handle:
                handle.seek(info.header_offset + 26)
                name_length, extra_length = struct.unpack("<HH", handle.read(4))
                data_start = (info.header_offset + 30 +
                              name_length + extra_length)
                self.assertEqual(data_start % 64, 0)
            self.assertEqual(z.read("defaultLayer.usdc"), self.stage.read_bytes())

    def test_standard_unaligned_zip_is_not_usdz(self):
        with zipfile.ZipFile(
            self.archive, "w", compression=zipfile.ZIP_STORED
        ) as z:
            z.writestr("defaultLayer.usdc", self.stage.read_bytes())
        self.assertTrue(zipfile.is_zipfile(self.archive))
        with self.assertRaisesRegex(USDZPackageError, "64-byte aligned"):
            verify_usdz(self.archive)

    def test_compressed_zip_is_not_usdz(self):
        with zipfile.ZipFile(
            self.archive, "w", compression=zipfile.ZIP_DEFLATED
        ) as z:
            z.writestr("defaultLayer.usdc", self.stage.read_bytes())
        with self.assertRaisesRegex(USDZPackageError, "compressed"):
            verify_usdz(self.archive)

    def test_rejects_fake_crate_or_missing_stage(self):
        self.stage.write_bytes(b"not-a-usd-crate" + b"\0" * 128)
        with self.assertRaisesRegex(USDZPackageError, "binary .usdc"):
            pack_usdc_as_usdz(self.stage, self.archive)
        self.assertFalse(self.archive.exists())
        self.stage.unlink()
        with self.assertRaisesRegex(USDZPackageError, "missing"):
            pack_usdc_as_usdz(self.stage, self.archive)

    def test_rejects_bad_default_layer_and_multiple_entries(self):
        with zipfile.ZipFile(self.archive, "w") as archive:
            archive.writestr("scene.usda", b"#usda 1.0\n" + b" " * 512)
        with self.assertRaisesRegex(USDZPackageError, "default layer"):
            verify_usdz(self.archive)
        with zipfile.ZipFile(self.archive, "a") as archive:
            archive.writestr("second.usdc", self.stage.read_bytes())
        with self.assertRaisesRegex(USDZPackageError, "exactly one"):
            verify_usdz(self.archive)

    def test_rejects_crc_tampering_even_after_correct_magic(self):
        pack_usdc_as_usdz(self.stage, self.archive)
        blob = bytearray(self.archive.read_bytes())
        magic_position = blob.index(b"PXR-USDC")
        blob[magic_position + 10] ^= 0x34
        self.archive.write_bytes(blob)
        with self.assertRaises((USDZPackageError, zipfile.BadZipFile)):
            verify_usdz(self.archive)

    def test_invalid_destination_never_creates_partial_zip(self):
        with self.assertRaisesRegex(USDZPackageError, "end in .usdz"):
            pack_usdc_as_usdz(self.stage, self.root / "bad.zip")
        self.assertFalse((self.root / "bad.zip.partial").exists())


if __name__ == "__main__":
    unittest.main()
