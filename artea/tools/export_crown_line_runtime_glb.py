"""Export a draw-call-efficient Crown Line GLB while preserving the source Blend.

Run with Blender using the authored crown_line_lego_train.blend as the input.
The static 13,000-piece construction is joined into one multi-material render
surface. Named moving mechanisms remain separate so Godot can animate them.
"""

import os
import bpy


PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT = os.path.join(
    PROJECT_DIR, "assets3D", "crown_line_train", "crown_line_runtime_textured.glb"
)
MECHANISM_MARKERS = (
    "Engine_SpeedMechanismBand_",
    "Engine_SpeedMechanismRotor_",
    "Engine_ETCS_ActualSpeedNeedle",
    "Engine_Bogie_Wheel_",
    "Engine_Bogie_WheelGold_",
    "Engine_Bogie_Tyre_",
    "Engine_Bogie_RailFlange_",
    "Engine_Bogie_BrakeDisc_",
    "Engine_ReactorEmitter_",
    "Engine_ReactorValveCore_",
    "Engine_NoseCrystal_InnerLightCore",
    "Engine_SteamDriveGear_",
    "Engine_SteamValveGear_",
    "Engine_SteamGovernorGear_",
    "Engine_SteamGearHub_",
    "Engine_SteamGearEnergyRing_",
    "Engine_SteamConnectingRod_",
    "Engine_SteamPressureOrb_",
    "Engine_SteamPressureHalo_",
    "Engine_SteamPipeValve_",
    "Engine_SteamChimneyEnergyRing",
    "Engine_CelestialHaloOuterMechanism",
    "Engine_CelestialHaloInnerMechanism",
    "Engine_BrakeGaugeNeedle_",
)


def is_mechanism(obj):
    return any(marker in obj.name for marker in MECHANISM_MARKERS)


# Blender's procedural node graphs are intentionally richer than what Godot's
# glTF importer can reproduce. Collapse the runtime train families to explicit
# stylized PBR values. The editable .blend retains every authored component,
# while the playable export receives one coherent child-friendly spectrum on
# every vehicle: midnight-blue technology, teal/cyan energy, violet magic,
# living green leaves, and warm sandstone structural trim.
RUNTIME_KID_PALETTE = {
    # A calm deep-blue foundation lets all three world colours coexist.
    "Train_Navy": ((0.075, 0.180, 0.480, 1.0), .08, .42),
    "Seat_Navy": ((0.260, 0.200, 0.550, 1.0), .03, .54),
    "Rail_Dark": ((0.055, 0.105, 0.185, 1.0), .25, .48),
    "Cab_Control_Rubber": ((0.075, 0.110, 0.170, 1.0), .02, .78),
    "Energy_Cyan": ((0.370, 0.950, 1.000, 1.0), .04, .24),
    "Energy_Glass": ((0.120, 0.580, 0.720, 1.0), .06, .28),
    "Cab_Clear_Cyan_Glass": ((0.320, 0.840, 0.920, 1.0), .01, .22),
    "Cab_Warning_Red": ((0.920, 0.060, 0.080, 1.0), .10, .32),
    "Cab_Warning_Amber": ((1.000, 0.420, 0.060, 1.0), .10, .32),
    "Cab_Signal_Green": ((0.060, 0.820, 0.300, 1.0), .08, .30),
    "Engine_Rainbow_Red": ((1.000, 0.120, 0.240, 1.0), .10, .32),
    "Engine_Rainbow_Orange": ((1.000, 0.380, 0.060, 1.0), .10, .32),
    "Engine_Rainbow_Yellow": ((1.000, 0.820, 0.080, 1.0), .08, .34),
    "Engine_Rainbow_Green": ((0.120, 0.820, 0.340, 1.0), .08, .32),
    "Engine_Rainbow_Blue": ((0.060, 0.320, 1.000, 1.0), .12, .27),
    "Engine_Rainbow_Indigo": ((0.220, 0.120, 0.720, 1.0), .10, .30),
    "Engine_Rainbow_Violet": ((0.720, 0.200, 1.000, 1.0), .08, .28),
    "Engine_Tank_PearlWhite": ((0.985, 0.965, 0.900, 1.0), .08, .24),
    # Nature: fresh mint, leaf green and warm living-root tones.
    "Leaf_Teal": ((0.100, 0.600, 0.340, 1.0), .02, .48),
    "Leaf_Inner_Light": ((0.480, 0.820, 0.340, 1.0), .01, .44),
    "Planter_Green": ((0.150, 0.560, 0.270, 1.0), .01, .58),
    "Living_Root": ((0.460, 0.300, 0.170, 1.0), .03, .66),
    "Root_Highlight": ((0.760, 0.500, 0.255, 1.0), .04, .56),
    "Root_Bronze_Band": ((0.820, 0.555, 0.275, 1.0), .14, .44),
    # Magic: lavender and berry accents stay sparse but clearly visible.
    "Crystal_Purple": ((0.750, 0.420, 1.000, 1.0), .02, .22),
    "Flower_Pink": ((1.000, 0.450, 0.760, 1.0), .01, .40),
    # This legacy material is deliberately sandstone, not metallic gold.
    "Crown_Gold": ((0.900, 0.700, 0.400, 1.0), .01, .58),
    "Warm_Ivory": ((0.960, 0.890, 0.720, 1.0), .01, .66),
    "Coach_Cream": ((0.980, 0.930, 0.780, 1.0), .01, .70),
    # Front-cover spectrum: nature crown, technology cheeks, magical socket.
    "Cover_Crown_DeepTeal": ((0.080, 0.500, 0.600, 1.0), .03, .46),
    "Cover_Crown_Patina": ((0.320, 0.860, 0.750, 1.0), .01, .42),
    "Cover_Side_HammeredTeal": ((0.100, 0.700, 0.720, 1.0), .03, .40),
    "Cover_Side_BlueSteel": ((0.180, 0.420, 0.760, 1.0), .07, .38),
    "Cover_Rib_EngravedGold": ((0.900, 0.700, 0.400, 1.0), .01, .58),
    "Cover_Vent_Ceramic": ((0.075, 0.130, 0.220, 1.0), .04, .72),
    "Cover_Jaw_WarmIvory": ((0.960, 0.890, 0.720, 1.0), .01, .66),
}
for material_name, (base_color, metallic, roughness) in RUNTIME_KID_PALETTE.items():
    material = bpy.data.materials.get(material_name)
    if material is None:
        continue
    material.diffuse_color = base_color
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    if bsdf is None:
        continue
    for socket_name in ("Base Color", "Metallic", "Roughness", "Normal"):
        socket = bsdf.inputs.get(socket_name)
        if socket is not None:
            for link in list(socket.links):
                links.remove(link)
    bsdf.inputs["Base Color"].default_value = base_color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if material_name in {"Crown_Gold", "Cover_Rib_EngravedGold", "Engine_Tank_PearlWhite"}:
        # Clear source-preview illumination so runtime sandstone and pearl-white
        # surfaces stay physically shaded in the bright station lighting.
        for socket_name in ("Emission Color", "Emission Strength"):
            socket = bsdf.inputs.get(socket_name)
            if socket is not None:
                for link in list(socket.links):
                    links.remove(link)
        emission_color = bsdf.inputs.get("Emission Color")
        emission_strength = bsdf.inputs.get("Emission Strength")
        if emission_color is not None:
            emission_color.default_value = (0.0, 0.0, 0.0, 1.0)
        if emission_strength is not None:
            emission_strength.default_value = 0.0
    for node in list(nodes):
        if node.type in {"TEX_IMAGE", "TEX_NOISE", "VALTORGB", "BUMP", "NORMAL_MAP"}:
            nodes.remove(node)
    material["runtime_surface_style"] = "Artea child-friendly magic-tech-nature flat PBR"


# A deliberately small true-gold detail family clarifies important silhouettes
# without replacing the sandstone frame. Only thin rails, crystal settings and
# instrument bezels receive it.
accent_gold = bpy.data.materials.get("Crown_AccentGold") or bpy.data.materials.new("Crown_AccentGold")
accent_gold.diffuse_color = (1.000, 0.690, 0.180, 1.0)
accent_gold.use_nodes = True
accent_bsdf = accent_gold.node_tree.nodes.get("Principled BSDF")
if accent_bsdf is not None:
    accent_bsdf.inputs["Base Color"].default_value = accent_gold.diffuse_color
    accent_bsdf.inputs["Metallic"].default_value = 0.34
    accent_bsdf.inputs["Roughness"].default_value = 0.34
accent_gold["runtime_surface_style"] = "restrained gold readability accent"

GOLD_DETAIL_TOKENS = (
    "PerimeterRail_", "HeartRing", "ColumnOuterGold_", "RoofEaveGold_",
    "CabRoofGoldBlade", "WindowFrame_", "ApolloFrameGold_",
    "CrystalRocketCollar_", "DriverGaugeRing_", "NavigationHeartRing_",
    "DriverSeatCrownRing", "ETCS_DMI_GoldFrame", "EmergencyBrakeGuardRing",
)
accent_gold_parts = 0
for obj in bpy.data.objects:
    if obj.type != "MESH" or not obj.name.startswith("TRAIN_"):
        continue
    if not any(token in obj.name for token in GOLD_DETAIL_TOKENS):
        continue
    for slot in obj.material_slots:
        if slot.material is not None and slot.material.name.startswith("Crown_Gold"):
            slot.material = accent_gold
            accent_gold_parts += 1


# Remove render-only camera, lights and the short presentation rail. The live
# game supplies its own continuous monorail and lighting.
for obj in list(bpy.data.objects):
    if obj.name.startswith("RENDER_"):
        bpy.data.objects.remove(obj, do_unlink=True)


def consolidate_halo_mechanism(part_marker, mechanism_name):
    """Join one editable halo layer while retaining its centre-ring pivot."""
    parts = [obj for obj in bpy.data.objects if obj.type == "MESH" and part_marker in obj.name]
    if not parts:
        return
    ring = next((obj for obj in parts if obj.name.endswith("_Ring")), parts[0])
    world_matrices = {obj: obj.matrix_world.copy() for obj in parts}
    for obj in parts:
        obj.parent = None
        obj.matrix_world = world_matrices[obj]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = ring
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.join()
    ring.name = mechanism_name


consolidate_halo_mechanism(
    "Engine_CelestialHaloOuterPart_", "TRAIN_Engine_CelestialHaloOuterMechanism"
)
consolidate_halo_mechanism(
    "Engine_CelestialHaloInnerPart_", "TRAIN_Engine_CelestialHaloInnerMechanism"
)

meshes = [obj for obj in bpy.data.objects if obj.type == "MESH" and obj.name.startswith("TRAIN_")]
mechanisms = [obj for obj in meshes if is_mechanism(obj)]
static_parts = [obj for obj in meshes if not is_mechanism(obj)]

# Detach the construction hierarchy while retaining world-space placement.
for obj in meshes:
    world = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = world

# Apply per-piece bevels and other authored modifiers before consolidation.
bpy.ops.object.select_all(action="DESELECT")
for obj in static_parts:
    obj.select_set(True)
bpy.context.view_layer.objects.active = static_parts[0]
bpy.ops.object.convert(target="MESH")

# One object with material submeshes retains the complete textured appearance
# while replacing thousands of runtime nodes/draw calls.
bpy.context.view_layer.objects.active = static_parts[0]
bpy.ops.object.join()
runtime_surface = bpy.context.view_layer.objects.active
runtime_surface.name = "CrownLineRuntimeTexturedSurface"

bpy.ops.object.select_all(action="DESELECT")
runtime_surface.select_set(True)
for obj in mechanisms:
    obj.select_set(True)
bpy.context.view_layer.objects.active = runtime_surface
bpy.ops.export_scene.gltf(
    filepath=OUTPUT,
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    export_extras=True,
)

print(
    "CROWN_LINE_RUNTIME_EXPORT: PASS static_source_parts=%d runtime_surface=1 mechanisms=%d gold_detail_parts=%d output=%s"
    % (len(static_parts), len(mechanisms), accent_gold_parts, OUTPUT)
)
