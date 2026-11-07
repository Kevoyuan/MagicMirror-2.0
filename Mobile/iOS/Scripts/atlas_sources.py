"""Pinned source model catalog for offline Z-Anatomy developer exports.

Only files verified in the upstream git tree at SOURCE_COMMIT are listed.
This map is not evidence of redistributability, correctness of anatomical
attachments or reviewed skinning; those require human signoff.
"""
SOURCE_REPOSITORY = "https://github.com/LluisV/Z-Anatomy"
SOURCE_COMMIT = "6c7f9016bd5899ac8edafd31b9900c151df42ed6"

# Each entry: relative source path, exact original byte length, git blob SHA1.
SYSTEM_SOURCES = {
    "skeleton": (
        "Resources/Models/FBX/SkeletalSystem100.fbx",
        41339660, "7c62e45211bf3992bb7239170343e06e2b073865",
    ),
    "muscles": (
        "Resources/Models/FBX/MuscularSystem100.fbx",
        37343180, "2477e1b6caf97d7174762b5eec6cf1c80db64eed",
    ),
    "organs": (
        "Resources/Models/FBX/VisceralSystem100.fbx",
        18401708, "355770ae46123044c85deca03de3fb880b8f7301",
    ),
    "vessels": (
        "Resources/Models/FBX/CardioVascular41.fbx",
        64889388, "aa5bbcb63ae6e9ace8051111b3a85ea87f00c4f3",
    ),
    "nerves": (
        "Resources/Models/FBX/NervousSystem100.fbx",
        53887724, "4ec6e3cb2a1ba821aca02c1d523ac614fdf41a02",
    ),
    "joints": (
        "Resources/Models/FBX/Joints100.fbx",
        9804796, "9db06d20217f4f42999dcfdf31b1f6af78dc7794",
    ),
}


def resource_base(system):
    if system not in SYSTEM_SOURCES:
        raise ValueError(f"Unsupported anatomical system: {system}")
    return f"{'skeleton' if system == 'skeleton' else system}_atlas"
