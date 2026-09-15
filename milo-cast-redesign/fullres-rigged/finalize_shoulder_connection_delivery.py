"""Finalize the head-to-shoulder connection delivery using the current gate logic."""
from pathlib import Path

OUT = Path(__file__).resolve().parent
source = (OUT / "finalize_no_visible_neck_delivery.py").read_text()
source = source.replace(
    '("no_visible_neck_scope_verification.json", "visible_neck_mesh_only_change")',
    '("shoulder_connection_scope_verification.json", "head_hierarchy_lowered_only")',
)
source = source.replace("no_visible_neck_regression_summary.json",
                        "shoulder_connection_regression_summary.json")
source = source.replace(
    '"visible_neck_mesh_removed": True,\n    "hidden_neck_and_head_bones_retained": True,',
    '"visible_neck_mesh_removed": True,\n    "head_seated_into_shoulders": True,\n    "head_seat_offset_m": -0.055,\n    "hidden_neck_and_head_bones_retained": True,',
)
source = source.replace(
    '"Local Milo neck pass: the visible Neck_Transition mesh is removed so the head "\n              "seats directly into the high collar. Hidden neck/head bones remain for animation; "\n              "all other geometry, rig data and animation channels are unchanged."',
    '"Local Milo shoulder-connection pass: the visible neck remains removed and the complete "\n              "head hierarchy is seated 5.5 cm lower into the high collar and shoulders. Hidden "\n              "articulation remains; every non-head mesh, bone and animation channel is unchanged."',
)
exec(compile(source, str(OUT / "finalize_no_visible_neck_delivery.py"), "exec"))
