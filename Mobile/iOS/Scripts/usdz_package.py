"""Deterministic, 64-byte-aligned OpenUSD USDZ packing and structural checks.

Offline developer-only utility; NO Python, FBX, USD or network is used
by the installed MagicMirror iPhone app.

OpenUSD USDZ requires an uncompressed unencrypted ZIP, 64-byte aligned
file contents, and a native USD stage as the first file. A normal zip
archive (zipfile.is_zipfile alone) is NOT proof of valid USDZ.
This utility packages ONE self-contained Blender-exported .usdc stage.
It cannot certify real mesh anatomy, USD scene semantics, iOS support,
source licenses, or reviewed human joint definitions.
"""
from pathlib import Path
import os
import struct
import zipfile

USD_HEADER = b"PXR-USDC"
USD_ROOT = "defaultLayer.usdc"
LOCAL_FILE_HEADER = struct.Struct("<IHHHHHIIIHH")
ALIGNMENT = 64
ZIP_STORED = zipfile.ZIP_STORED


class USDZPackageError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise USDZPackageError(message)


def verify_usdz(path):
    """Validate portable USDZ ZIP rules AND reject empty/fake USD stages."""
    path = Path(path)
    require(path.is_file(), "USDZ file absent")
    try:
        with zipfile.ZipFile(path, "r") as archive:
            entries = archive.infolist()
            require(len(entries) == 1, "expected exactly one self-contained USD stage")
            stage = entries[0]
            require(stage.filename == USD_ROOT, "incorrect USD default layer")
            require(stage.compress_type == ZIP_STORED, "USDZ cannot be compressed")
            require(stage.flag_bits & (1 | 8) == 0,
                    "encrypted or streamed ZIP entry is unsupported")
            require(not stage.is_dir() and stage.file_size > len(USD_HEADER),
                    "empty USD stage")
            with path.open("rb") as raw:
                raw.seek(stage.header_offset)
                header = raw.read(LOCAL_FILE_HEADER.size)
                require(len(header) == LOCAL_FILE_HEADER.size,
                        "missing local ZIP file header")
                (signature, _needed, flags, method, _time, _date,
                 crc, compressed, uncompressed, name_length,
                 extra_length) = LOCAL_FILE_HEADER.unpack(header)
                require(signature == 0x04034B50, "incorrect local ZIP signature")
                require(method == ZIP_STORED and flags & (1 | 8) == 0,
                        "invalid local ZIP method or flags")
                require(crc == stage.CRC and compressed == stage.compress_size
                        and uncompressed == stage.file_size,
                        "local/central ZIP header size or checksum mismatch")
                name = raw.read(name_length)
                require(name == USD_ROOT.encode("ascii"),
                        "local ZIP filename mismatch")
                payload_offset = (stage.header_offset +
                                  LOCAL_FILE_HEADER.size +
                                  name_length + extra_length)
                require(payload_offset % ALIGNMENT == 0,
                        "USD payload is not 64-byte aligned")
                raw.seek(payload_offset)
                require(raw.read(len(USD_HEADER)) == USD_HEADER,
                        "stage is not a Blender USD crate")
            require(archive.testzip() is None, "USD stage checksum invalid")
    except (OSError, zipfile.BadZipFile, struct.error) as exc:
        raise USDZPackageError("invalid USDZ/ZIP package") from exc
    return {"stage": USD_ROOT, "bytes": path.stat().st_size}


def pack_usdc_as_usdz(stage_path, output_path):
    """Wrap a standalone USD crate as an aligned, uncompressed USDZ.

    Uses ZIP's permitted local extra field as explicit alignment padding.
    Writes atomically, then verifies bytes BEFORE exposing them as an
    approved model. No third-party usdzip or external process required.
    """
    stage_path = Path(stage_path)
    output_path = Path(output_path)
    require(stage_path != output_path, "source and destination must differ")
    require(stage_path.is_file(), "Blender USD crate missing")
    with stage_path.open("rb") as f:
        require(f.read(len(USD_HEADER)) == USD_HEADER,
                "Blender must output binary .usdc, not an ASCII or fake stage")
    require(output_path.suffix == ".usdz", "destination must end in .usdz")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    temp = output_path.with_name(output_path.name + ".partial")
    try:
        with zipfile.ZipFile(temp, "w", allowZip64=False) as archive:
            info = zipfile.ZipInfo(USD_ROOT, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = ZIP_STORED
            info.create_system = 3
            info.flag_bits = 0
            # The first local header starts at file offset zero. A
            # correctly formed ZIP extra field needs four bytes of its
            # own ID/length before any 64-byte alignment padding.
            offset = LOCAL_FILE_HEADER.size + len(USD_ROOT.encode("ascii"))
            padding = (-offset) % ALIGNMENT
            if padding < 4:
                padding += ALIGNMENT
            info.extra = struct.pack("<HH", 0xCAFE, padding - 4) + (
                b"\0" * (padding - 4)
            )
            archive.writestr(info, stage_path.read_bytes())
        verify_usdz(temp)
        os.replace(temp, output_path)
    finally:
        temp.unlink(missing_ok=True)
    return verify_usdz(output_path)
