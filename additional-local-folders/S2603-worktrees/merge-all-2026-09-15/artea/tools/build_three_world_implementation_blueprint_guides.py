from __future__ import annotations

from copy import deepcopy
from pathlib import Path
import sys

from docx import Document
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.shared import Inches, Pt
from docx.text.paragraph import Paragraph


ROOT = Path("/Users/davidsovann/S2603/artea")
DOCS = Path("/Users/davidsovann/Documents")
PACK = ROOT / "artifacts" / "implementation_blueprint_pack"

sys.path.insert(0, str(ROOT / "tools"))
from build_mind_spark_design_document import (  # noqa: E402
    DEEP_CYAN,
    GOLD,
    INK,
    MIDNIGHT,
    MUTED,
    VIOLET,
    add_bullet,
    add_callout,
    add_caption,
    add_check,
    add_section_intro,
    format_cell_text,
    picture_with_alt,
    prevent_row_split,
    set_repeat_table_header,
    set_table_borders,
    set_table_geometry,
    set_run,
    shade_cell,
)


SOURCES = {
    "mind": DOCS / "World_One_Mind_Spark_Concise_Developer_Guide_with_Identity_System.docx",
    "heart": DOCS / "World_Two_Heart_Melody_Concise_Developer_Guide.docx",
    "creator": DOCS / "World_Three_Creators_Light_Concise_Developer_Guide.docx",
}

OUTPUTS = {
    "mind": DOCS / "World_One_Mind_Spark_Concise_Developer_Guide_Implementation_Blueprints.docx",
    "heart": DOCS / "World_Two_Heart_Melody_Concise_Developer_Guide_Implementation_Blueprints.docx",
    "creator": DOCS / "World_Three_Creators_Light_Concise_Developer_Guide_Implementation_Blueprints.docx",
}

ACTUAL_IMAGES = {
    "mind": ROOT / "artifacts" / "galaxy_worlds_birdseye" / "mind_spark_birdseye.png",
    "heart": ROOT / "artifacts" / "galaxy_worlds_birdseye" / "heart_melody_birdseye.png",
    "creator": ROOT / "artifacts" / "galaxy_worlds_birdseye" / "creators_light_birdseye.png",
}

ARCH_IMAGES = {
    "mind": PACK / "mind_spark_architecture_blueprint_v1.png",
    "heart": PACK / "heart_melody_architecture_blueprint_v1.png",
    "creator": PACK / "creators_light_architecture_blueprint_v1.png",
}

ENTITY_IMAGES = {
    "mind": PACK / "mind_spark_entities_combat_blueprint_v1.png",
    "heart": PACK / "heart_melody_entities_combat_blueprint_v1.png",
    "creator": PACK / "creators_light_entities_combat_blueprint_v1.png",
}

BUILDING_KIT_IMAGES = {
    "heart": PACK / "heart_melody_world_building_kit_v1.png",
    "creator": PACK / "creators_light_world_building_kit_v1.png",
}

QUEST_KIT_IMAGES = {
    "heart": PACK / "heart_melody_quest_magic_kit_v1.png",
    "creator": PACK / "creators_light_quest_creation_kit_v1.png",
}

PLAYER_CONTINUITY_IMAGE = PACK / "shared_player_character_gear_blueprint_v1.png"
MILO_CONTINUITY_IMAGE = PACK / "shared_mayor_milo_continuity_blueprint_v1.png"
GUARDIAN_CONTINUITY_IMAGE = PACK / "unified_female_guardian_angel_blueprint_v3_lighter_skin.png"

TRAIN_IMAGE = PACK / "shared_crown_train_monorail_blueprint_v2.png"
TRAIN_RUNTIME = ROOT / "artifacts" / "rainbow_station_bio_magitech_hero.png"

FUNCTIONAL_OBJECT_IMAGES = {
    "mind": PACK / "mind_spark_functional_quest_objects_v2.png",
    "heart": PACK / "heart_melody_functional_quest_objects_v2.png",
    "creator": PACK / "creators_light_functional_quest_objects_v2.png",
}


COMMON_ASSETS = {
    "player": "res://scenes/player_3d.tscn + res://player_3d.gd (current fox, sword hitbox, health, block, take_damage)",
    "milo": "res://scenes/milo_animations.tscn + res://meshy ai/Milo_Animations.glb (current Milo mesh/animation source)",
    "guardian": "res://scenes/shared/guardian_angel.tscn (one new female Mother Guardian scene instanced unchanged in every world)",
    "world": "res://scenes/art_castle_floating_world.tscn + res://scripts/art_castle_floating_world.gd (current world geometry/material source)",
    "rail": "res://scripts/art_castle_story_railway.gd (current Crown Line stations, train, route and unlock logic)",
    "nature": "res://assets3D/kkNatureForest/gltf/ and res://assets3D/stylizedNature/ (trees, plants, grass, rocks)",
    "houses": "res://assets3D/house scenes/ and res://assets3D/houses/gltf/ (castle, market, homes, well, windmill, props)",
    "sign": "res://assets3D/house scenes/artéa_signpost.tscn (wayfinding base)",
}


SUPPLEMENTAL_KITS = {
    "heart": {
        "building_title": "Heart Melody — World Building & Dressing Kit",
        "building_alt": "Twelve-panel Heart Melody Godot blueprint showing the valley island, petal paths, vine bridge, inactive and active station beacon, water channels, plants, rocks, benches, signs, lamps, temple arches, arena pieces, world-state swap, collision and LOD examples.",
        "building_rows": [
            ("01", "Valley island shell", "Main floating terrain and safe outer silhouette.", "StaticBody3D + low-poly mesh modules + recovery Area3D."),
            ("02", "Petal path kit", "Straight, curved, junction and round performance floors.", "BoxMesh/CylinderMesh modules on a shared snap grid."),
            ("03", "Vine bridge", "Crosses water gaps without hiding the safe walking deck.", "StaticBody3D deck + Curve3D vines + simple rail collision."),
            ("04", "Station beacon skin", "Shows inactive before completion and active for optional travel afterward.", "Node3D child skin + AnimationPlayer + OmniLight3D; shared station collision."),
            ("05", "Water channel kit", "Builds river edges, waterfalls, water lifts and plaza pools.", "PlaneMesh water + stone modules + particles; no fluid simulation."),
            ("06", "Plant clusters", "Three flower colours and reusable meadow grouping.", "Imported low-poly glTF plants or MultiMeshInstance3D."),
            ("07", "Rock/crystal family", "Edge dressing, quest focus and harmony-light accents.", "Existing rock meshes + primitive crystal variants; simple collision only where needed."),
            ("08", "Bench/sign/note lamp", "Rest, wayfinding and interaction readability.", "Reuse house props and signpost; Area3D only on usable objects."),
            ("09", "Temple arch kit", "Frames gates, guardian areas and large landmarks.", "BoxMesh/CylinderMesh arch pieces with shared ivory/gold materials."),
            ("10", "Ground/arena modules", "Round dais, arena edge, stairs and small performance pads.", "StaticBody3D modular kit; fixed navigation-safe dimensions."),
            ("11", "Silent/harmony states", "Same world changes from muted to living without duplicate scenes.", "Material, audio-stem, light and particle state swap from saved progress."),
            ("12", "Collision and LOD", "Keeps mobile performance and player scale consistent.", "Primitive collision; LOD0/1/2 mesh variants; no collision on small dressing."),
        ],
        "quest_title": "Heart Melody — Quest, Music & Magic Kit",
        "quest_alt": "Twelve-panel Heart Melody Godot blueprint showing drum flowers, rhythm stage, waterfall organ, rain boat, warning bells, peace flowers, hope stage, MelodyPads, phrase gate, song anchors, Harmony Jewel and Silent Conductor arena props.",
        "quest_rows": [
            ("01", "Drum flowers", "Three-beat frustration puzzle and visible input feedback.", "Area3D pads + AnimationPlayer + AudioStreamPlayer3D."),
            ("02", "Rhythm platform", "Creates a solid safe floor after the correct short pattern.", "StaticBody3D toggled by quest state; glow material and completion signal."),
            ("03", "Waterfall organ", "Turns sadness notes into lifts, gates and flowing colour.", "CylinderMesh pipes + audio nodes + AnimatableBody3D lifts."),
            ("04", "Rain Boat", "Carries the player along one authored safe river path.", "AnimatableBody3D + PathFollow3D + boarding Area3D."),
            ("05", "Warning bells", "Communicates safe, warning and needs-care routes.", "Area3D trigger + icon plane + light + sound; never colour alone."),
            ("06", "Peace checkpoint", "Slows hazards, saves progress and creates a calm pause.", "Area3D checkpoint + flower growth animation + low-cost particles."),
            ("07", "Hope stage", "Holds the hopeful melody choice and sunrise state.", "StaticBody3D dais + MelodyPads + lighting AnimationPlayer."),
            ("08", "MelodyPads/sockets", "Reusable note input, placement and quest-state display.", "Area3D + Resource note type + AnimationPlayer; same input API."),
            ("09", "Feeling note/phrase gate", "Collects and combines restored song layers.", "Collectible Area3D + socket array + saved phrase Resource."),
            ("10", "Song anchors", "Three boss-phase objectives with instrument variants.", "Area3D anchors + explicit phase signals; harp, drum and ring visuals."),
            ("11", "Harmony Jewel", "Final treasure reveal and Gallery collection object.", "MeshInstance3D + reward Area3D + light/fade AnimationPlayer."),
            ("12", "Boss arena props", "Telegraph rings, exposed-core marker and safe lanes.", "StaticBody3D arena + decal/mesh telegraphs + Marker3D anchors."),
        ],
    },
    "creator": {
        "building_title": "Creator’s Light — World Building & Dressing Kit",
        "building_alt": "Twelve-panel Creator's Light Godot blueprint showing the canvas island, painted paths, bridge skins, inactive and active station, glass seeds, silver pipes, studio modules, furniture, frame arches, pencil lamps, ambient props, world states, collision and LOD examples.",
        "building_rows": [
            ("01", "Canvas island shell", "Blank floating base that gains colour as the story progresses.", "StaticBody3D low-poly modules + recovery Area3D."),
            ("02", "Painted path kit", "Straight, curved, junction and splash-shaped safe routes.", "Fixed collision modules + visual material overlays; collision never changes with paint."),
            ("03", "Created bridge skins", "One bridge collision with ivory, cyan and violet visual recipes.", "PackedScene with fixed StaticBody3D collision and swappable child meshes."),
            ("04", "Creator Station skin", "Inactive before completion and active for optional travel afterward.", "ThemeSkinCreator child + AnimationPlayer; shared station collision/boarding."),
            ("05", "Glass-seed family", "Crystal pods wake into approved plants and colour effects.", "Node3D prefab + low-poly crystal + scale/open AnimationPlayer."),
            ("06", "Silver-pipe kit", "Straight, elbow, junction and valve pieces carry colour-light.", "CylinderMesh modules + emissive core; no simulated liquid."),
            ("07", "Studio modules", "Floor, wall, stairs, round plinth and display frame.", "StaticBody3D room kit on fixed snap dimensions."),
            ("08", "Studio furniture", "Easel, art table, pedestal and shelf for readable interaction zones.", "Reuse house props or simple BoxMesh assemblies; Area3D only when usable."),
            ("09", "Frame/Dream Door kit", "Builds portal frames, gallery arches and creation sockets.", "BoxMesh/CylinderMesh frame pieces + Area3D socket + AnimationPlayer."),
            ("10", "Pencil/brush lamps", "Wayfinding lights and world-specific signs.", "CylinderMesh/BoxMesh props + shared cyan/violet/gold materials."),
            ("11", "Ambient creation life", "Origami birds, colour motes, flowers, rocks and small beacons.", "PathFollow3D or AnimationPlayer; no damage or blocking collision."),
            ("12", "World states and LOD", "Blank, colour-returning and living-studio versions share geometry.", "Material/particle state swap; LOD0/1/2 meshes and primitive collision."),
        ],
        "quest_title": "Creator’s Light — Quest & Creation Kit",
        "quest_alt": "Twelve-panel Creator's Light Godot blueprint showing Creation Frame workstation, four-button tool console, stamp tokens, spawn pedestal, bridge, door, tree and light scenes, glass-seed and pipe interactions, colour anchors, unfinished picture, Perfect Blank arena and Creator's Light reward.",
        "quest_rows": [
            ("01", "Creation Frame", "Opens the simple creation tool and previews an approved recipe.", "Node3D + Area3D + Control/SubViewport + AnimationPlayer."),
            ("02", "Four-button console", "Large bridge, door, tree and light choices; no free drawing required.", "Control buttons mapped to recipe IDs; accessible focus order."),
            ("03", "Stamp tokens", "Shows selected recipe, colour and completion state.", "Resource-backed icons and physical token meshes; no arbitrary geometry."),
            ("04", "Spawn pedestal", "Safe authored place where the selected PackedScene appears.", "Marker3D socket + Area3D clearance check + reset action."),
            ("05", "Bridge creations", "Three visual variants sharing one traversal collision.", "PackedScene recipe with fixed StaticBody3D and swappable visual children."),
            ("06", "Door creations", "Three visual variants sharing one doorway interaction.", "PackedScene + Area3D + open/close AnimationPlayer."),
            ("07", "Tree creations", "Approved pine, violet and pink tree results.", "Existing glTF tree scenes selected by recipe Resource."),
            ("08", "Light creations", "Crystal lamp variants that activate paths and pipes.", "Node3D + OmniLight3D + emissive material; capped light distance."),
            ("09", "Glass-seed awakening", "Transforms a dormant pod after the correct tree creation.", "AnimationPlayer + saved state + GPUParticles3D burst."),
            ("10", "Pipe colour flow", "Moves a simple emissive colour state through authored pipe segments.", "Material parameter/tween sequence; no liquid physics."),
            ("11", "Colour anchors/picture", "Three boss objectives and final unfinished-idea interaction.", "Area3D anchors + picture pedestal + BossController signals."),
            ("12", "Boss arena/reward", "Erase-wave lanes, exposed core marker and Creator’s Light pedestal.", "StaticBody3D arena + telegraph meshes + reward Area3D."),
        ],
    },
}


FUNCTIONAL_OBJECTS = {
    "mind": {
        "title": "Mind Spark — Thinking Tools and Puzzle Objects",
        "alt": "Twelve numbered Mind Spark functional objects showing a Thought Spark Socket, Evidence Scanner, Perspective Lens, Memory Constellation Board, Logic Gate, Truth Bridge Tile, Focus Beacon, Warden Anchor, Calm Rain Basin, Identity Mirror, Checkpoint Server Root and Clear Path Projector.",
        "rows": [
            ("01", "Thought Spark Socket", "Place one found Spark.", "Shows 0/3, 1/3, 2/3, then opens the linked task.", "Node3D + Area3D + three MeshInstance3D pips + AnimationPlayer.", "Big count, icon and sound."),
            ("02", "Evidence Scanner", "Scan one clue, then choose FACT or FEAR.", "Saves one evidence result and updates the gate.", "Area3D + two large buttons + Label3D/icon planes + Resource data.", "Star/check and cloud/warning; colour is extra."),
            ("03", "Perspective Lens", "Turn the lens to one of three fixed angles.", "Reveals one hidden path beam.", "StaticBody3D + Area3D + three saved rotation steps + Tween.", "Clicks at each step; reset button."),
            ("04", "Memory Constellation Board", "Connect three large nodes in order.", "Restores one memory and gives a Spark.", "Area3D sockets + Array order + thin link meshes + AnimationPlayer.", "Wrong link gently clears; no score loss."),
            ("05", "Logic Gate Arch", "Place the correct evidence pair.", "Gate opens and the next path lights.", "StaticBody3D + two socket Area3D nodes + AnimatableBody3D door.", "Lock icon, 0/2 count and open sound."),
            ("06", "Truth Bridge Tile", "Choose the true statement at a nearby prompt.", "The ghost tile becomes a safe solid tile.", "StaticBody3D collision toggled from quest state + material tween.", "Solid shape change plus glow and tone."),
            ("07", "Focus Bell Beacon", "Ask for help or wait 45 seconds with no progress.", "Points to the current required object only.", "Area3D + Timer + Label3D arrow + AudioStreamPlayer3D.", "Hint can be off; never solves the puzzle."),
            ("08", "Warden Anchor", "Dodge, then strike the open crystal ring.", "Breaks one boss shield layer.", "StaticBody3D + Hurtbox Area3D + state enum + crack animation.", "Large telegraph, safe arrow and long recovery."),
            ("09", "Calm Rain Basin", "Place the final Spark after the boss stops.", "Changes the storm into gentle rain.", "Area3D + AnimationPlayer + particle and audio state swap.", "Clear HOLD prompt; no timed input."),
            ("10", "Identity Reflection Mirror", "Choose one short answer after the quest.", "Adds evidence to the 16-identity tracker; no identity is chosen yet.", "Area3D + simple Control choice + PlayerIdentityTracker signal.", "Private, skip and replay options; no right answer."),
            ("11", "Checkpoint Server Root", "Use it to save, heal or read the current task.", "Stores progress and gives a safe pause.", "Area3D + SaveManager call + heal signal + quest text panel.", "One action button and clear three-item menu."),
            ("12", "Clear Path Projector", "Turn on an optional ground guide.", "Draws a dotted route to the next task.", "Area3D + Path3D/Line3D-style mesh + goal Marker3D.", "Can be turned off; route uses dots and a star."),
        ],
    },
    "heart": {
        "title": "Heart Melody — Feeling, Rhythm and Harmony Objects",
        "alt": "Twelve numbered Heart Melody functional objects showing a Feeling Seed Planter, Echo Drum Flower, Water Organ Valve, Rain Boat Bell, Harmony Bridge Chime, Hush Vine Knot, Comfort Lantern, Song Memory Bench, Warning Bell, Peace Flower Checkpoint, Beat Anchor and Harmony Jewel Altar.",
        "rows": [
            ("01", "Feeling Seed Planter", "Choose one safe feeling icon.", "The seed blooms and adds one song note.", "Area3D + three icon choices + growth AnimationPlayer + Resource type.", "No wrong feeling; text and icon name each choice."),
            ("02", "Echo Drum Flower", "Repeat a short three-beat pattern.", "Builds one rhythm platform.", "Three Area3D petals + short Array pattern + AudioStreamPlayer3D.", "Easy mode removes strict timing; replay button."),
            ("03", "Water Organ Valve", "Turn three large valves to match the note icons.", "Starts one water lift or gate.", "Three fixed-step Area3D valves + AnimationPlayer + audio stems.", "Shape icons, note sound and 0/3 count."),
            ("04", "Rain Boat Call Bell", "Ring the bell after the river phrase is complete.", "Calls one safe boat to the dock.", "Area3D + Path3D/PathFollow3D boat + scripted stop markers.", "Boat waits; no jump timing is needed."),
            ("05", "Harmony Bridge Chime", "Restore three phrase parts.", "Each part adds one solid bridge section.", "Area3D chime + three AnimatableBody3D bridge parts + saved count.", "Shows 0/3 to 3/3 with shape and sound."),
            ("06", "Hush Vine Release Knot", "Strike or touch the three open bulbs.", "Releases the path without hurting a living feeling.", "Node3D + three Hurtbox/Interact Area3D nodes + opening animation.", "Open bulbs pulse slowly and show a weak-point ring."),
            ("07", "Comfort Lantern", "Use it for a heal and one-line task recap.", "Creates a short safe rest point.", "Area3D + heal signal + Label3D/Control recap + warm light tween.", "No cost and no hidden cooldown."),
            ("08", "Song Memory Bench", "Replay the last melody or ask for a Guardian hint.", "Lets the player hear the clue again.", "Area3D + audio playlist + simple two-button Control panel.", "Subtitles and note icons appear with sound."),
            ("09", "Fear Warning Bell", "Read the bell before choosing a route.", "Shows SAFE, WARNING or NEEDS CARE.", "Area3D + icon mesh + bell AnimationPlayer + audio cue.", "Check, triangle and heart shapes; not colour alone."),
            ("10", "Peace Flower Checkpoint", "Touch the flower to save and calm the area.", "Saves progress and slows new enemy spawns nearby.", "Area3D + SaveManager + spawn-zone flag + bloom animation.", "Safe-zone ring and quiet music tell the player."),
            ("11", "Silent Conductor Beat Anchor", "Strike during one broad pulse after a dodge.", "Opens the boss harmony core.", "Hurtbox Area3D + Timer + large ring tween + boss phase signal.", "Wide timing window; separate puzzle/combat help settings."),
            ("12", "Harmony Jewel Altar", "Place the full song after the boss is free.", "Restores the Jewel and unlocks the Harmony Shield.", "Area3D + reward animation + save flags + World Gate signal.", "Hold prompt, clear reward card and next-step arrow."),
        ],
    },
    "creator": {
        "title": "Creator’s Light — Making, Courage and Repair Objects",
        "alt": "Twelve numbered Creator's Light functional objects showing a Blank Canvas Frame, Colour Bowl, Pattern Stamp Table, Bridge Sketch Easel, Glass Seed Kiln, Silver Pipe Switch, Dream Door Keyframe, Courage Lamp, Eraser Patch Station, Crack Seal, Sentinel Weak Frame and Creator Star Altar.",
        "rows": [
            ("01", "Blank Canvas Frame", "Choose one of three starter shapes.", "Starts a safe authored creation recipe.", "Area3D + three large Control buttons + recipe Resource.", "No free drawing check and no wrong art."),
            ("02", "Colour Mixing Bowl", "Place two colour stones.", "Makes one planned result used by the next object.", "Two socket Area3D nodes + lookup Resource + material AnimationPlayer.", "Each stone also has its own shape icon."),
            ("03", "Pattern Stamp Table", "Place three chunky stamps in the shown order.", "Completes one pattern part.", "Three sockets + short Array order + reusable stamp scenes.", "Undo and replay are always available."),
            ("04", "Bridge Sketch Easel", "Finish three large outline points.", "Builds one fixed safe bridge scene.", "Area3D points + PackedScene bridge + AnimationPlayer reveal.", "No handwriting or drawing recognition."),
            ("05", "Glass Seed Kiln", "Collect, charge, then plant one seed.", "Grows one approved plant needed for the route.", "Area3D + three-state enum + plant PackedScene + particles.", "One step is shown at a time."),
            ("06", "Silver Pipe Flow Switch", "Turn each pipe in fixed 90-degree steps.", "Routes light to a door or seed.", "StaticBody3D pieces + Area3D + four rotations + connection check.", "Lit start/end icons and reset button."),
            ("07", "Dream Door Keyframe", "Choose one of three door frames.", "Opens the same safe doorway with a chosen look.", "Area3D + three child meshes + open AnimationPlayer.", "All choices work; choice is visual only."),
            ("08", "Courage Lamp", "Ask for the current task or an optional hint.", "Shows the next small action.", "Area3D + Label3D/Control + Timer + goal Marker3D.", "Simple sentence, picture icon and spoken line."),
            ("09", "Eraser Patch Station", "Undo the last puzzle choice.", "Returns only one step, not the whole quest.", "Area3D + one-step command history + friendly animation.", "Always confirms what will change."),
            ("10", "Perfect Blank Crack Seal", "Place a finished patch on one arena crack.", "Closes one erase-wave lane.", "Area3D socket + AnimatableBody3D cover + boss signal.", "Crack, patch and safe lane use different shapes."),
            ("11", "Blank Sentinel Weak Frame", "Wait for the large frame to open, then strike.", "Breaks the Sentinel shield or one boss armour layer.", "Hurtbox Area3D + Timer + open/close AnimationPlayer.", "Long telegraph, sound cue and clear recovery."),
            ("12", "Creator Star Altar", "Place one unfinished idea after the boss stops.", "Restores Creator’s Light and unlocks the Creator Star skill.", "Area3D + reward animation + save flags + finale signal.", "No quality score; skip/private reflection option."),
        ],
    },
}


GUARDIAN_WORLD_HELP = {
    "mind": {
        "voice": "‘A thought can feel strong without being a fact. Let us look for one clear sign.’",
        "puzzle": "She points to the active clue, but she does not choose FACT or FEAR for the player.",
        "boss": "‘The storm is hurt and confused. Break the dark anchors, then help it become rain.’",
        "reflection": "‘What helped you move forward when the path was not clear?’",
    },
    "heart": {
        "voice": "‘Every feeling may speak here. We can listen without judging it.’",
        "puzzle": "She replays the sound and shows the next active flower, valve or bell.",
        "boss": "‘The silence is the blight. The feeling is not your enemy. Wait for the wide beat, then act.’",
        "reflection": "‘Which feeling was easier to hear today?’",
    },
    "creator": {
        "voice": "‘An idea does not need to be perfect before it can begin.’",
        "puzzle": "She shows the next open socket or step. She never judges the player’s art choice.",
        "boss": "‘The blank armour is the blight. Make one safe opening, then strike the weak frame.’",
        "reflection": "‘What did you make even when you were not fully ready?’",
    },
}


RESEARCH_LINKS = [
    ("Godot Area3D", "https://docs.godotengine.org/en/stable/classes/class_area3d.html", "Use for player entry, interaction, sockets, hitboxes and safe zones."),
    ("Godot AnimatableBody3D", "https://docs.godotengine.org/en/stable/classes/class_animatablebody3d.html", "Use for simple moving doors, bridge parts and platforms."),
    ("Godot Path3D", "https://docs.godotengine.org/en/stable/classes/class_path3d.html", "Use for the shared train, Rain Boat and simple guided movement."),
    ("Godot NavigationAgent3D", "https://docs.godotengine.org/en/stable/classes/class_navigationagent3d.html", "Use for basic enemy movement inside a clear combat area."),
    ("Godot Resource", "https://docs.godotengine.org/en/stable/classes/class_resource.html", "Store small puzzle, enemy and reward data without making many scripts."),
    ("Godot MultiMeshInstance3D", "https://docs.godotengine.org/en/stable/classes/class_multimeshinstance3d.html", "Reuse many trees, flowers, grass or crystals with lower cost."),
    ("Xbox clear goals", "https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/109", "Show the current goal, progress, task list and optional help."),
    ("Xbox more than colour", "https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/103", "Use shape, icon, text and sound with colour for important information."),
    ("Xbox difficulty help", "https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/108", "Let puzzle help and combat help be changed separately."),
]


WORLD_DATA = {
    "mind": {
        "number": "WORLD ONE",
        "name": "MIND SPARK",
        "tag": "Technology/Science dominant • angular networks • cyan, violet, silver and wisdom gold",
        "identity": "A living computer forest where thoughts grow like stars and wisdom reorganizes the path.",
        "runtime": "The current game already builds Mind Spark at (-600, 0, 1640) with low-poly primitives, circuit tiles, logic gates, server trees, the Thought Storm and the Oldest Tree sanctuary.",
        "arch_alt": "Twelve-panel Mind Spark architecture blueprint showing island, circuit paths, bridge, server trees, three logic gates, constellation court, Thought Sparks, beacon, Thought Storm arena and Oldest Tree sanctuary.",
        "entity_alt": "Ten-panel Mind Spark combat blueprint showing the current fox hero, elder Mayor Milo, legacy guardian placeholder, five Static Blight enemy families and the Thought Storm Warden; shared character sheets supersede the three character placeholders.",
        "arch": [
            ("01", "Floating island shell", "Reuse current faceted island; BoxMesh/CylinderMesh cliff modules over a StaticBody3D floor.", "StaticBody3D + MeshInstance3D + CollisionShape3D; perimeter recovery Area3D.", "REUSE", "art_castle_floating_world.gd island primitives"),
            ("02", "Circuit path kit", "3–4 m modular straight/corner/T/plaza/ramp pieces; cyan line stays visible.", "StaticBody3D; BoxMesh floor; thin emissive MeshInstance3D; snap on 1 m grid.", "MODIFY", "current 8×8 rune tiles and circuit routes"),
            ("03", "Arrival/root bridge", "One 4 m clear bridge with 1.1 m rails, root lamps and aligned end sockets.", "StaticBody3D + 3 BoxMesh pieces; optional root Curve3D/MeshInstance3D.", "MODIFY", "current procedural bridge helpers"),
            ("04", "Server-tree family", "Short/medium/tall tower-tree; dark glass trunk, cyan data seam, violet canopy, fibre roots.", "Node3D prefab; BoxMesh/CylinderMesh; MultiMeshInstance3D for repeated canopies; no trunk animation.", "REUSE", "current ServerTree nodes + nature tree meshes"),
            ("05", "Fear Gate", "Triangular gate with one Spark socket; teaches fear versus fact.", "StaticBody3D frame + Area3D socket + AnimationPlayer + Label3D/icon plane.", "REUSE", "current FearGate geometry"),
            ("06", "Proof/Truth gates", "Proof uses three evidence sockets; Truth uses safe turning rings and gold success state.", "Node3D + Area3D sockets + AnimationPlayer; TorusMesh rings; signal puzzle_completed.", "REUSE", "ProofGate + WhatElseIsTrueGate"),
            ("07", "Truth-ring / Hope path", "Rotating truth rings unlock staged gold/cyan path tiles and flowers.", "TorusMesh + Tween; path StaticBody3D toggled by quest state; GPUParticles3D for growth.", "MODIFY", "current logic gate/path helpers"),
            ("08", "Constellation Court", "Round readable puzzle court with movable thought nodes and link lines.", "StaticBody3D dais; Area3D drag/sockets; ImmediateMesh or thin cylinders for links.", "REUSE", "current ConstellationCourt cubes/links"),
            ("09", "Thought Sparks", "One shared collectible with shape/material variants for fear, fact, proof, hope and wisdom.", "Area3D + MeshInstance3D + AnimationPlayer + OmniLight3D; Resource for type/state.", "MODIFY", "current constellation cubes and Star material"),
            ("10", "Mayor beacon/checkpoint", "Safe hint, save, retry and Milo briefing point; never blocks the path.", "Node3D + Area3D + Label3D + OmniLight3D + AudioStreamPlayer3D.", "NEW", "use current beacon/light primitives"),
            ("11", "Thought Storm arena", "Circular arena, three anchors, layered storm rings, core lane and gentle-rain completion state.", "StaticBody3D arena; Node3D boss anchors; TorusMesh rings; GPUParticles3D; checkpoint Marker3D.", "MODIFY", "current ThoughtStorm cloud rings"),
            ("12", "Oldest Tree sanctuary", "Tallest landmark; ramp/stairs, glowing roots, Guardian mark and Star pedestal.", "StaticBody3D platform; tree prefab; Area3D reward; AnimationPlayer; rain particles.", "REUSE", "current OldestTree/Star sanctuary"),
        ],
        "entities": [
            ("01", "Fox player", "One green-hooded fox and one permanent outfit; only earned equipment appears on sockets.", "player_3d.tscn; existing hitbox/health/block + EquipmentSocket children.", "Current", "25 base / 30 Wisdom", "—", COMMON_ASSETS["player"]),
            ("02", "Mayor Milo", "One elder cream cat with white moustache, gold glasses and permanent navy mayor coat.", "One guide scene + AnimationTree + dialogue Area3D; no world skins.", "Guide", "No combat", "—", COMMON_ASSETS["milo"]),
            ("03", "Guardian Angel", "One mature Mother Guardian: kind face, leaf-panel gown, branch halo and three-panel wings.", "Shared humanoid rig + wing bones + AnimationPlayer + reward Area3D.", "Guardian", "No combat", "—", COMMON_ASSETS["guardian"]),
            ("04", "Static Mite", "Small cube/sphere circuit insect; lunge then long pause.", "CharacterBody3D + NavigationAgent3D + capsule + Timer.", "Enemy", "25 HP", "10 XP", "NEW low-poly prefab; shared EnemyBase"),
            ("05", "Glitch Sprout", "Rooted crystal plant; telegraphed seed bolt.", "CharacterBody3D/Node3D + projectile Marker3D + Timer.", "Enemy", "50 HP", "15 XP", "NEW; reuse plant/crystal meshes"),
            ("06", "Circuit Wisp", "Floating orb with three fins; bolt can be deflected.", "CharacterBody3D + sphere + height spring + projectile.", "Enemy", "50 HP", "20 XP", "NEW; primitive spheres/cones"),
            ("07", "Root Stalker", "Low charging root beast with rear weak point.", "CharacterBody3D + NavigationAgent3D + RayCast3D + rear Area3D.", "Enemy", "75 HP", "30 XP", "NEW; reuse root/rock meshes"),
            ("08", "Blight Sentinel", "Tall angular elite; front shield, exposed cyan chest.", "CharacterBody3D + NavigationAgent3D + shield bool + chest Hurtbox.", "Elite", "150 HP", "60 XP", "NEW; primitive modular armour"),
            ("09", "Thought Storm Warden", "Ring-and-crystal storm body; three anchor phases, then calm rain.", "CharacterBody3D/Node3D boss + phase enum + core/anchors + arena signals.", "Boss", "300 HP", "150 XP", "NEW boss using current storm rings"),
            ("10", "Ambient life", "Spark friend, firefly, moth and small bird; non-blocking.", "Node3D + PathFollow3D/AnimationPlayer; no navigation or damage.", "Dressing", "No combat", "—", "reuse simple meshes/animated animal pack where suitable"),
        ],
        "inventory": [
            ("Traversal", "Island shell; circuit straight/corner/T/plaza; stairs; ramp; arrival/root bridge; arena edge; recovery volume", "Reuse/MODIFY procedural primitives; one collision kit"),
            ("Technology forest", "3 server-tree sizes; fibre root; data monolith; console; root lamp; status crystal", "Reuse current runtime forms; MultiMesh repeated dressing"),
            ("Puzzle", "Fear Gate; Proof Gate; Truth Gate; Spark socket; constellation node/link; reset; hint beacon", "One PuzzleBase script plus Resources for rules"),
            ("Quest/magic", "Thought Spark variants; Hope tile; memory seed; thought flower; wisdom flower; Star pedestal", "One collect/place state machine; colour + icon, never colour alone"),
            ("Combat", "Five enemies; boss; focus anchor; telegraph decal; projectile; checkpoint; rain-complete VFX", "Shared EnemyBase/BossController and object pools"),
            ("Characters", "One fox; one permanent Mayor Milo; one unified female Guardian Angel; dialogue/photo/safe-zone markers", "Shared scenes only; no world costume variants; earned player gear is attached as child meshes"),
            ("Dressing", "Lavender tree; pine; fern; grass; rock; crystal; bench; sign; edge lamp; firefly/moth/bird", "Reuse installed nature and house libraries"),
            ("World states", "Sleeping; waking; gentle rain", "Same geometry; swap materials, lights, particles and saved state"),
        ],
        "lock": [
            ("Lead force", "Technology / Science, about 55–60% of a gameplay view"),
            ("Shape rule", "Angles, grids, lines, nodes and clear circles; nature grows through the network"),
            ("Must read from distance", "Server-tree skyline, storm rings and Oldest Tree"),
            ("Do not borrow", "No Heart instruments/water-organ language; no Creator canvas/frame/stamp language"),
        ],
    },
    "heart": {
        "number": "WORLD TWO",
        "name": "HEART MELODY",
        "tag": "Nature dominant • round living instruments • green, aqua, coral, violet and harmony gold",
        "identity": "A living music valley where every feeling becomes a safe sound and every sound helps the path grow.",
        "runtime": "Current Heart Melody at (0, 0, 2290) includes the Melody Stage, seven pads, temple arches, Drum Garden, Rain Boat, Warning Bells, Peace Flowers and Hope Stage.",
        "arch_alt": "Twelve-panel Heart Melody architecture blueprint showing island, petal paths, vine bridge, station, drum garden, waterfall organ, rain boat, bell grove, peace flowers, hope stage, amphitheatre and the Guardian Angel's Harmony Jewel sanctuary.",
        "entity_alt": "Nine-panel Heart Melody combat blueprint showing legacy character placeholders, Echo Moth, Hush Vine, Rhythm Golem, Silent Conductor, ambient animals and the shared enemy rig; shared character sheets supersede the placeholders.",
        "arch": [
            ("01", "Valley island shell", "Round terraced green island with water channels, flower banks and ivory rock underside.", "StaticBody3D terrain modules; CylinderMesh terraces; PlaneMesh water; recovery Area3D.", "MODIFY", "current Heart island + nature libraries"),
            ("02", "Petal path kit", "2.5–3.5 m organic curves, petal stepping pads, small plazas and safe rhythm lanes.", "StaticBody3D modules; Curve3D visual guide; CylinderMesh/BoxMesh collision.", "MODIFY", "current heart paths and MelodyPads"),
            ("03", "Vine bridge", "Single clear deck wrapped by roots; flowers wake when a phrase is restored.", "StaticBody3D deck; Curve3D vines; MultiMesh flowers; AnimationPlayer growth.", "NEW", "reuse procedural bridge + nature vines"),
            ("04", "Heart Melody Station", "Leaf-petal canopy, water-note columns and living instrument sign around the shared dock.", "Shared station collision/boarding; child ThemeSkinHeart meshes only.", "MODIFY", "art_castle_story_railway.gd station pavilion"),
            ("05", "Frustration Drum Garden", "Three playable drum flowers create solid rhythm platforms.", "Area3D drum pads + AnimationPlayer + AudioStreamPlayer3D; platform quest signals.", "NEW", "reuse music_minigame timing/audio logic"),
            ("06", "Sadness Waterfall Organ", "Water columns and organ pipes turn a phrase into lifts/gates.", "PlaneMesh/particles for water; pipe CylinderMesh; AudioStreamPlayer3D; moving AnimatableBody3D.", "NEW", "procedural primitives + music_minigame"),
            ("07", "Rain Boat", "Small leaf boat follows a safe river path after the sadness phrase.", "AnimatableBody3D + PathFollow3D + collision deck; boarding Area3D.", "NEW", "primitive hull + leaf canopy"),
            ("08", "Fear Warning Bells", "Bell arches show safe, warning and needs-care routes with sound, icon and light.", "StaticBody3D arch; Area3D bell triggers; AnimationPlayer; Label3D/icon planes.", "NEW", "reuse current arch helpers"),
            ("09", "Peace Flowers", "Calm checkpoint plants that slow machines and show feeling colours.", "MultiMeshInstance3D + Area3D checkpoint + shader wind + light.", "MODIFY", "current PeaceFlowers + nature library"),
            ("10", "Hope Morning Stage", "Small sunrise performance stage and optional duet/reflection space.", "StaticBody3D dais; MelodyPads; light rig; dialogue Marker3D.", "REUSE", "current HopeMorningStage"),
            ("11", "Personal Song Amphitheatre", "Final readable arena with three song anchors and safe combat lanes.", "StaticBody3D rings; Area3D anchors; telegraph decals; checkpoint Marker3D.", "MODIFY", "current PersonalSongAmphitheatre/MelodyStage"),
            ("12", "Guardian/Jewel sanctuary", "Open organic arch, unified Mother Guardian mark and Harmony Jewel reward pedestal.", "Node3D arch + reward Area3D + AnimationPlayer + jewel light.", "MODIFY", "current HarmonyJewel and temple arches"),
        ],
        "entities": [
            ("01", "Fox player", "Same green outfit and Wisdom Blade; Harmony Shield appears only after this world is complete.", "player_3d.tscn + EquipmentSocket; existing attack/block timing.", "Current", "30 Wisdom attack", "—", COMMON_ASSETS["player"]),
            ("02", "Mayor Milo", "Same elder face, white moustache, glasses and permanent navy mayor outfit.", "One guide scene + AnimationTree + dialogue Area3D; no world skins.", "Guide", "No combat", "—", COMMON_ASSETS["milo"]),
            ("03", "Guardian Angel", "Same mature Mother Guardian with kind face, leaf gown, branch halo and luminous wings.", "One shared humanoid scene + wing bones + AnimationPlayer + reward Area3D.", "Guardian", "No combat", "—", COMMON_ASSETS["guardian"]),
            ("04", "Echo Moth", "Petal-wing moth; hover, sound-pulse telegraph, one dash, pause.", "CharacterBody3D + sphere + height spring + Timer.", "Enemy", "25 HP", "5 XP", "NEW; low-poly wing planes"),
            ("05", "Hush Vine", "Rooted mouth/flower; ground-grab, then core opens.", "Node3D/CharacterBody3D + ground telegraph Area3D + core Hurtbox.", "Enemy", "50 HP", "10 XP", "NEW; nature meshes + shared EnemyBase"),
            ("06", "Rhythm Golem", "Round stone-and-drum body; slow stomp circle and long recovery.", "CharacterBody3D + NavigationAgent3D + slam Area3D + Timer.", "Enemy", "75 HP", "15 XP", "NEW; stylized rocks + drum top"),
            ("07", "Silent Conductor", "Masked leaf-robed conductor; armour, baton, silent wave and exposed harmony core.", "CharacterBody3D boss + phase enum + wave Area3D + core Hurtbox + anchors.", "Boss", "220 HP", "70 XP", "NEW; primitive armour over humanoid rig"),
            ("08", "Ambient life", "Butterfly, blue bird, water sprite and flower firefly; never targetable.", "PathFollow3D/AnimationPlayer; no damage layers or blocking collision.", "Dressing", "No combat", "—", "reuse simple animal/nature assets"),
            ("09", "Shared combat rig", "Visible weak core, ground telegraph, hit flash and gentle dissolve.", "EnemyBase Resource/state enum reused by all three normal enemies.", "System", "Varies", "Varies", "NEW shared code/material once"),
        ],
        "inventory": [
            ("Traversal", "Valley shell; petal straight/corner/T/plaza; stairs; vine bridge; river edge; arena ring; recovery volume", "One organic modular kit; same collision dimensions as campaign"),
            ("Music landmarks", "Drum flowers; rhythm platform; waterfall pipes; water lift; rain boat; warning bells; MelodyPads", "Reuse music_minigame timing/audio and current MelodyPads"),
            ("Feeling gardens", "Joy flowers; Frustration drums; Sadness rain; Fear bells; Peace plants; Hope stage", "Each feeling gets colour + icon + sound; never colour only"),
            ("Quest/magic", "Phrase note; note gate; song anchor; feeling colour; Jewel pedestal; unified Guardian mark", "One phrase Resource, one socket script, saved quest state"),
            ("Combat", "Echo Moth; Hush Vine; Rhythm Golem; Silent Conductor; wave; grab decal; stomp decal; checkpoint", "Shared EnemyBase and BossController"),
            ("Characters", "One fox; one permanent Mayor Milo; one unified female Guardian Angel; dialogue/performance markers", "Shared character scenes only; no world-specific costume or guardian model"),
            ("Dressing", "Willow; flower tree; reeds; grass; lily; rock; bench; sign; note lamp; butterfly; bird; water sprite", "Reuse installed nature/animal libraries and simple planes"),
            ("World states", "Silent; voices returning; full harmony", "Same geometry; audio stems, flower growth, water and light change"),
        ],
        "lock": [
            ("Lead force", "Nature, about 55% of a gameplay view; magic 30%, technology 15%"),
            ("Shape rule", "Round terraces, petals, arches, waves and instruments grown from living plants"),
            ("Must read from distance", "Waterfall Organ, bell grove and circular Harmony Stage"),
            ("Do not borrow", "No black server towers/circuit grids; no blank canvas/frame/stamp architecture"),
        ],
    },
    "creator": {
        "number": "WORLD THREE",
        "name": "CREATOR’S LIGHT",
        "tag": "Magic/Creativity dominant • frames and asymmetric forms • ivory, gold, cyan and living pastel colour",
        "identity": "A living studio kingdom where unfinished ideas become real paths and courage gives creation its light.",
        "runtime": "Current Creator’s Light at (600, 0, 1640) already includes the studio, easels, art table, sun rune, Dream Door, glass seeds, silver pipes, Perfect Blank sanctuary and final reward.",
        "arch_alt": "Twelve-panel Creator's Light architecture blueprint showing blank island, painted paths, bridge variants, station, Creation Frame, Dream Door, spawned creations, glass seeds, silver pipes, studio, Perfect Blank arena and the Guardian Angel's Creator's Light sanctuary.",
        "entity_alt": "Ten-panel Creator's Light combat blueprint showing legacy character placeholders, Ink Sprite, Smudge Hopper, Blank Sentinel, Perfect Blank, creation stamps, glass-seed ambient life and the shared enemy rig; shared character sheets supersede the placeholders.",
        "arch": [
            ("01", "Blank canvas island", "Ivory asymmetric island with folded-paper cliffs, empty plinths and colour spreading by progress.", "StaticBody3D modular shell; BoxMesh/Wedge-style meshes; recovery Area3D.", "MODIFY", "current Creator island/studio primitives"),
            ("02", "Painted path kit", "2.5–4 m straight/corner/splash/plaza/ramp pieces; safe collision never changes with paint.", "StaticBody3D base + emissive overlay; shader/material swap by quest state.", "NEW", "use current floor tiles and sun-rune materials"),
            ("03", "Created bridge variants", "One collision bridge with bridge/leaf/light visual recipes and three colour variants.", "PackedScene with fixed StaticBody3D collision; child visual recipe selected by Resource.", "NEW", "reuse current bridge helper and drawing stamps"),
            ("04", "Creator Station", "Asymmetric frame canopy, pencil/leaf spires and colour-light panels on shared dock.", "Shared station collision/boarding; child ThemeSkinCreator meshes only.", "MODIFY", "art_castle_story_railway.gd station pavilion"),
            ("05", "Creation Frame", "Readable portal/workstation that converts four-button UI choices into approved 3D scenes.", "Node3D + Area3D + SubViewport/Control + spawn Marker3D + recipe Resource.", "NEW", "reuse drawing_tool.tscn UI/stamps"),
            ("06", "Dream Door workshop", "Tall frame door, easels and test wall; teaches door placement.", "StaticBody3D frame; Area3D socket; AnimationPlayer; saved open/closed state.", "REUSE", "current DreamDoorWorkshop and frame helper"),
            ("07", "Creation set", "Bridge, door, tree and light are prebuilt—not arbitrary geometry—with three visual variants each.", "Four PackedScenes; stable collision; recipe ID, colour ID, rotation and slot ID.", "NEW", "reuse nature trees, bridge helper and lamps"),
            ("08", "Glass Seed garden", "Faceted seed pods wake into trees/flowers after the correct creation.", "Node3D prefab; low-poly crystal; AnimationPlayer scale/open; GPUParticles3D.", "REUSE", "current GlassSeed_* nodes"),
            ("09", "Silver river pipes", "Simple pipe network carries light/colour and opens a route.", "CylinderMesh segments/elbows; emissive core; Area3D valves; AnimationPlayer.", "REUSE", "current SilverPipe_* nodes"),
            ("10", "Creator Studio", "Easels, art table, stamp shelf, gallery plinths and a private/answer/skip reflection point.", "StaticBody3D room kit; Control UI; interaction Area3D; display Marker3D.", "REUSE", "current StudioFloor/Wall, easels and art table"),
            ("11", "Perfect Blank arena", "Paper-layer arena, three colour anchors, creation slot and readable erase-wave lanes.", "StaticBody3D arena; Area3D anchors; decal/mesh telegraphs; checkpoint Marker3D.", "NEW", "current PerfectBlankSanctuary as location base"),
            ("12", "Guardian/Light sanctuary", "Open star-flame shrine; unified Mother Guardian, unfinished artwork and Creator’s Light reward.", "Node3D arch + shared guardian scene + reward Area3D + AnimationPlayer + light.", "MODIFY", "current Creator’s Light marker/sun rune"),
        ],
        "entities": [
            ("01", "Fox player", "Same green outfit, Wisdom Blade and Harmony Shield; Creator Star unlocks at completion.", "player_3d.tscn + three simple EquipmentSocket children.", "Current", "30 Wisdom attack", "—", COMMON_ASSETS["player"]),
            ("02", "Mayor Milo", "Same elder face, white moustache, glasses and permanent navy mayor outfit.", "One guide scene + AnimationTree + dialogue Area3D; no world skins.", "Guide", "No combat", "—", COMMON_ASSETS["milo"]),
            ("03", "Guardian Angel", "Same mature Mother Guardian expressing love, mercy, harmony, safety and hope.", "One shared humanoid scene + rigid gown/wing panels + AnimationPlayer + reward Area3D.", "Guardian", "No combat", "—", COMMON_ASSETS["guardian"]),
            ("04", "Ink Sprite", "Small drop creature; short dash, ink swipe, long pause.", "CharacterBody3D + NavigationAgent3D + capsule + Timer.", "Enemy", "25 HP", "5 XP", "NEW; sphere/drop primitive + EnemyBase"),
            ("05", "Smudge Hopper", "Round splash creature; jumps to a marked circle, splash, two-second recovery.", "CharacterBody3D + jump Tween/velocity + decal Area3D + Timer.", "Enemy", "50 HP", "10 XP", "NEW; primitive blob mesh"),
            ("06", "Blank Sentinel", "Paper/crystal guard; shield walk, slow erase beam, creation opens core.", "CharacterBody3D + NavigationAgent3D + RayCast3D/beam Area3D + shield bool.", "Elite", "100 HP", "20 XP", "NEW; modular folded panels"),
            ("07", "Perfect Blank", "Layered paper-knight boss; blank shell, colour anchors, erase waves and bright core.", "CharacterBody3D boss + phase enum + shell/core Hurtboxes + arena signals.", "Boss", "250 HP total", "80 XP", "NEW; low-poly panels over simple rig"),
            ("08", "Creation stamps", "Cloud, flower, sun, cat, heart and approved campaign stamps; not enemies.", "Control buttons + Resource recipes; spawn only approved PackedScenes.", "Tool", "No combat", "—", "res://scenes/drawing_tool.tscn + res://scripts/drawing_tool.gd"),
            ("09", "Glass-seed life", "Floating colour motes and tiny origami bird; ambient only.", "PathFollow3D/AnimationPlayer; no damage layers or blocking collision.", "Dressing", "No combat", "—", "reuse simple planes/crystals/animal source"),
            ("10", "Shared combat rig", "Visible weak core, creation-react state, erase telegraph, hit flash and dissolve.", "EnemyBase Resource/state enum reused by all normal enemies.", "System", "Varies", "Varies", "NEW shared code/material once"),
        ],
        "inventory": [
            ("Traversal", "Canvas shell; painted straight/corner/splash/plaza; stairs; created bridge; arena edge; recovery volume", "One modular collision kit; visual paint changes only"),
            ("Creation system", "Creation Frame; stamp UI; spawn slot; bridge; door; tree; light; colour/rotation controls; reset", "Reuse drawing tool UI; spawn approved PackedScenes only"),
            ("Studio", "Floor/wall; easel; art table; shelf; gallery plinth; picture frame; private reflection marker", "Reuse current studio and house prop library"),
            ("Nature/technology", "Glass seed; silver straight/elbow pipe; valve; light river; sun rune; crystal lamp", "Reuse current seeds/pipes; one shared emissive material"),
            ("Quest/magic", "Colour anchor; creation socket; unfinished picture; unified Guardian mark; Light pedestal", "One recipe Resource and saved slot state"),
            ("Combat", "Ink Sprite; Smudge Hopper; Blank Sentinel; Perfect Blank; erase wave; splash decal; checkpoint", "Shared EnemyBase and BossController"),
            ("Characters", "One fox; one permanent Mayor Milo; one unified female Guardian Angel; dialogue/display/photo markers", "Shared character scenes only; no world-specific costume or guardian model"),
            ("Dressing", "Origami bird; colour mote; crystal flower; brush lamp; pencil post; bench; sign; rock; small plant", "Procedural primitives plus installed nature/house assets"),
            ("World states", "Blank; colour returning; living studio", "Same collision and geometry; material, spawned scenes, particles and light change"),
        ],
        "lock": [
            ("Lead force", "Magic / Creativity, about 55% of a gameplay view; nature and technology support creation"),
            ("Shape rule", "Asymmetric frames, paper folds, brush strokes, glass seeds and controlled geometric light"),
            ("Must read from distance", "Dream Door, giant Creation Frame and star-flame sanctuary"),
            ("Do not borrow", "No server forest/circuit plazas; no music valley/water-organ or drum architecture"),
        ],
    },
}


TRAIN_STORY_REPLACEMENTS = {
    "mind": [
        ("This guide follows the player from the town to the Art Castle, through Mind Spark, and to the first train unlock. It also explains four quests, sword combat, the boss, and five blueprint sheets.",
         "This guide follows the player from the town to the Art Castle, through Mind Spark, and to the first optional fast-travel unlock. It also explains four quests, sword combat, the boss, and five blueprint sheets."),
        ("Technology and Science lead (about 60%): server trees, thought maps, logic gates, circuits, scanners, and the train system.",
         "Technology and Science lead (about 60%): server trees, thought maps, logic gates, circuits, scanners, and evidence tools."),
        ("This story begins in the town. Mayor Milo guides the player to the Art Castle. The train stays locked until the player saves Mind Spark.",
         "This story begins in the town. Mayor Milo guides the player to the Art Castle. The train is visible but stays parked and locked until the player saves Mind Spark."),
        ("A strange Static Blight has spread from the Art Castle. It mixes broken machines, wild roots, and unstable magic into monsters. Mayor Milo asks the player for help because the player’s crystal sword can break the dark Blight shell without harming the living world inside. The player enters Mind Spark through the first World Gate, defeats the creatures, repairs the wisdom systems, and faces the Thought Storm Warden. When the Star of Wisdom is restored, the Crown Railway wakes for the first time and becomes the travel system for later worlds.",
         "A strange Static Blight has spread from the Art Castle. It mixes broken machines, wild roots, and unstable magic into monsters. Mayor Milo asks the player for help because the player’s crystal sword can break the dark Blight shell without harming the living world inside. The player enters Mind Spark through the first World Gate, defeats the creatures, repairs the wisdom systems, and faces the Thought Storm Warden. When the Star of Wisdom is restored, the Heart Melody World Gate opens for the next story. The train also wakes, but only as optional fast travel back to completed worlds."),
        ("Main Gallery and Locked Crown Railway  •  See the problem and open the first World Gate",
         "Main Gallery, World Gates and Parked Train  •  See the problem and open the first World Gate"),
        ("Inside the castle, the player sees empty Star displays and a beautiful train behind a dark glass seal. Milo explains that this is the Crown Railway, but it has no power. It cannot be ridden yet. The first Star must wake the train. A violet signal then moves across the Gallery and opens the Mind Spark World Gate. Milo says the Star of Wisdom has stopped protecting its world. Without it, the Thought Storm has covered the land and created Static Blight monsters. Milo asks the player to recover the Star so the town, the castle, and the railway can live again.",
         "Inside the castle, the player sees empty Star displays, three World Gates, and a beautiful train behind a dark glass seal. Milo explains that the train is an optional travel service, not the way the story moves forward. A violet signal opens the Mind Spark World Gate. Milo says the Star of Wisdom has stopped protecting its world. Without it, the Thought Storm has covered the land and created Static Blight monsters. He asks the player to recover the Star so the first World Gate can be restored."),
        ("Gentle rain wakes the Oldest Tree, and the Star of Wisdom appears. The Guardian says, ‘You had the courage to protect this world, understand the truth, and choose hope.’ The game saves the player’s first identity clues, but does not choose an identity yet. Milo shares one simple strength he noticed. The player receives the Star and reaches Level 5. The player and Milo return through the World Gate and place the Star in the Gallery. The dark railway seal opens, the train lights turn on for the first time, and Heart Melody appears on the route map. The player has earned train travel between completed and unlocked worlds.",
         "Gentle rain wakes the Oldest Tree, and the Star of Wisdom appears. The Guardian says, ‘You had the courage to protect this world, understand the truth, and choose hope.’ The game saves the player’s first identity clues, but does not choose an identity yet. Milo shares one simple strength he noticed. The player receives the Star and reaches Level 5. Mind Spark Station activates. The player may walk back through the World Gate or take the train to the Art Castle. In the Gallery, the Star opens the Heart Melody World Gate for the next story. The train lists only the Art Castle and completed Mind Spark."),
        ("The Crown Railway wakes for the first time. Heart Melody becomes the first train destination.",
         "The Heart Melody World Gate opens for the next story. Mind Spark becomes the first optional train destination for later revisits."),
        ("The Crown Railway turns on for the first time, and Heart Melody becomes available.",
         "The Heart Melody World Gate opens, and Mind Spark is added to the optional fast-travel train."),
        ("☐  The identity tracker survives save, quit, reload, checkpoint restart, boss retry, World Gate return, and train unlock.",
         "☐  The identity tracker survives save, quit, reload, checkpoint restart, boss retry, World Gate return, and optional fast-travel unlock."),
        ("☐  The player can return through the World Gate, place the Star, wake the train for the first time, and open Heart Melody.",
         "☐  After the boss, the player may walk through the World Gate or take the train to the Art Castle, place the Star, open the Heart Melody World Gate, and add Mind Spark to optional travel."),
        ("Meet the Mayor. Enter the Castle. Save World One. Unlock the train.",
         "Meet the Mayor. Enter the Castle. Save World One. Open the next World Gate."),
        ("The Crown Railway itself, then the route to Heart Melody, World Two",
         "The Heart Melody World Gate; optional train travel back to completed Mind Spark"),
        ("Star and train unlock; Level 5.", "Star, Heart World Gate, optional Mind destination; Level 5."),
        ("Receive the Star, meet the Guardian, and return to unlock the train.",
         "Receive the Star, activate Mind Spark Station, and return by World Gate or optional train."),
        ("Before the Star: train dark, doors sealed, no ride action. After the Star: lights turn gold, doors open, and Heart Melody appears on the route map.",
         "Before the Star: train dark and unavailable. After the Star: train waits at the Gallery and lists Mind Spark only. Heart Melody opens through its World Gate, not the train."),
        ("Use six sound groups: town and Milo, forest circuits, sword combat, logic puzzle, storm boss, and the first train unlock. Remove storm layers as the boss is freed.",
         "Use six sound groups: town and Milo, forest circuits, sword combat, logic puzzle, storm boss, and the World Gate restoration. Remove storm layers as the boss is freed."),
        ("Show current task, health, XP bar, Level 1–5, 0/6 Sparks, hint, enemy health for elite and boss, boss stage, and the train unlock reward.",
         "Show current task, health, XP bar, Level 1–5, 0/6 Sparks, hint, enemy health for elite and boss, boss stage, and the World Gate reward."),
        ("Build shared enemy damage, XP and levels, quest progress, checkpoints, Sparks, puzzles, boss phases, world lighting, train unlock, collision, sound areas, PlayerIdentityTracker, identity save fields, and developer test tools.",
         "Build shared enemy damage, XP and levels, quest progress, checkpoints, Sparks, puzzles, boss phases, world lighting, World Gate unlocks, optional completed-world train destinations, collision, sound areas, PlayerIdentityTracker, identity save fields, and developer test tools."),
    ],
    "heart": [
        ("3. Player journey from train arrival to the next unlock", "3. Player journey from World Gate arrival to the next unlock"),
        ("The player rides the newly unlocked Crown Railway into a valley that has lost its music. Mayor Milo asks for help because the Harmony Jewel is trapped inside the final silent note. The player gives safe voices to different feelings, fights creatures made by the Silence Blight, joins the sounds into one song, and frees the Silent Conductor. Raphael returns the Harmony Jewel, and the train opens the route to World Three.",
         "The player walks through the Heart Melody World Gate into a valley that has lost its music. Mayor Milo asks for help because the Harmony Jewel is trapped inside the final silent note. The player gives safe voices to different feelings, fights creatures made by the Silence Blight, joins the sounds into one song, and frees the Silent Conductor. Raphael returns the Harmony Jewel, and the Creator’s Light World Gate opens. The train remains an optional service for completed worlds."),
        ("Read this section in order: it follows what the player sees, learns, fights, earns, and unlocks from the train arrival to the world ending.",
         "Read this section in order: it follows what the player sees, learns, fights, earns, and unlocks from the World Gate arrival to the world ending."),
        ("Ride the Crown Railway into the new kingdom.", "Walk through the Heart Melody World Gate into the new kingdom."),
        ("Receive Harmony Jewel and unlock Creator’s Light Station and the train shortcut controls.",
         "Receive the Harmony Jewel, open the Creator’s Light World Gate, and add Heart Melody to optional train travel."),
        ("1. Train arrival — the quiet valley", "1. World Gate arrival — the quiet valley"),
        ("After World One, the player may finally use the train. The Crown Railway leaves the Art Castle Gallery and arrives at Heart Melody Station. The valley is beautiful, but its waterfalls, flowers, drums, bells, and giant strings make no sound. Milo explains that the Silence Blight trapped the valley’s feelings and sealed the Harmony Jewel inside the last note.",
         "After World One, the player walks from the Art Castle Gallery through the newly opened Heart Melody World Gate. The valley is beautiful, but its waterfalls, flowers, drums, bells, and giant strings make no sound. Milo explains that the Silence Blight trapped the valley’s feelings and sealed the Harmony Jewel inside the last note. The nearby train station stays inactive until this world is complete."),
        ("Walk from the station to the Quiet Meadow while Milo teaches the sound-colour guide.",
         "Walk from the World Gate to the Quiet Meadow while Milo teaches the sound-colour guide."),
        ("The last note opens and reveals the Harmony Jewel, shining with every feeling colour. Raphael thanks the player and Milo. They return by train to the Gallery, where the Jewel joins the Star of Wisdom. Creator’s Light Station appears on the Destination Wheel, and the train shortcut controls wake up.",
         "The last note opens and reveals the Harmony Jewel, shining with every feeling colour. Raphael thanks the player and Milo. Heart Melody Station activates. The player may walk back through the World Gate or take the train to the Art Castle. In the Gallery, the Jewel joins the Star of Wisdom and opens the Creator’s Light World Gate for the next story. The train lists only the Art Castle and completed worlds."),
        ("Unlock Creator’s Light Station and the optional shortcut controls.",
         "Open the Creator’s Light World Gate and unlock optional train travel back to Heart Melody."),
        ("Build one understandable journey. Reuse modular pieces and keep decorative density lower around combat, prompts, gates, and train controls.",
         "Build one understandable journey. Reuse modular pieces and keep decorative density lower around combat, prompts, World Gates, and the optional station."),
        ("☐  Train route stays locked until the previous world completion flag is saved.",
         "☐  Heart Melody is absent from the train destination list until Heart Melody itself is complete."),
        ("☐  The treasure appears only after boss COMPLETE and the new train route unlocks only after the treasure save.",
         "☐  The treasure appears only after boss COMPLETE; then save the Creator World Gate unlock and the optional Heart train destination."),
        ("End-state vision for Heart Melody Kingdom: the route is restored, the treasure is earned, and the next Crown Railway state is clear.",
         "End-state vision for Heart Melody Kingdom: the route is restored, the treasure is earned, the next World Gate is open, and optional fast travel is clearly secondary."),
        ("One linear route with shortcuts and a clear return to the train", "One linear route with shortcuts and a clear return to the World Gate"),
        ("World One is complete. The Crown Railway can now carry the player from the Gallery to Heart Melody Station.",
         "World One is complete. The player enters Heart Melody through its World Gate; the train is not required for the story."),
        ("Creator’s Light Station and the train shortcut controls", "Creator’s Light World Gate; Heart Melody optional train destination"),
        ("Station, tutorial reminder, two Echo Moths, Raphael projection", "World Gate, tutorial reminder, two Echo Moths, Raphael projection"),
        ("Reward and train unlock", "Reward, next World Gate and optional destination"),
        ("Harmony Jewel + World Three station", "Harmony Jewel + Creator’s Light World Gate"),
        ("Choose Heart Melody on the Destination Wheel; train ride begins.", "Walk to the Heart Melody World Gate; the story journey begins."),
        ("Harmony Station / Quiet Meadow", "Heart World Gate / Quiet Meadow"),
        ("Boss, Harmony Jewel, return portal to station.", "Boss, Harmony Jewel, return path to the World Gate."),
        ("Harmony Station and train platform", "Heart World Gate and optional Harmony Station"),
        ("Set after the station arrival finishes.", "Set after the World Gate arrival finishes."),
        ("Array of available station IDs; never infer only from scene position.", "Array containing only completed-world station IDs; never add the next story world early."),
        ("DONE MEANS  Heart Melody is complete when the player can follow one clear route, safely express different feelings through sound and action, win readable sword fights, free rather than destroy the final boss, receive the Harmony Jewel, and see Creator’s Light appear on the train.",
         "DONE MEANS  Heart Melody is complete when the player can follow one clear route, safely express different feelings through sound and action, win readable sword fights, free rather than destroy the final boss, receive the Harmony Jewel, open the Creator’s Light World Gate, and add Heart Melody to optional fast travel."),
    ],
    "creator": [
        ("3. Player journey from train arrival to the next unlock", "3. Player journey from World Gate arrival to the finale"),
        ("The player rides the train into a nearly empty kingdom. Uriel explains that the world is waiting for one small mark, but the Perfect Blank keeps whispering that nothing is ready or good enough. Using a simple Creation Frame, the player makes bridges, doors, trees, and lights, fights Blank Blight creatures, and brings colour back to the land. The player defeats the Perfect Blank’s armour, places an unfinished picture, and receives the Creator’s Light. All train routes open and the Crown Railway returns to the Art Castle finale.",
         "The player walks through the Creator’s Light World Gate into a nearly empty kingdom. Uriel explains that the world is waiting for one small mark, but the Perfect Blank keeps whispering that nothing is ready or good enough. Using a simple Creation Frame, the player makes bridges, doors, trees, and lights, fights Blank Blight creatures, and brings colour back to the land. The player defeats the Perfect Blank’s armour, places an unfinished picture, and receives the Creator’s Light. Creator Station activates, so the player may walk through the World Gate or take the optional train back to the Art Castle finale."),
        ("Read this section in order: it follows what the player sees, learns, fights, earns, and unlocks from the train arrival to the world ending.",
         "Read this section in order: it follows what the player sees, learns, fights, earns, and unlocks from the World Gate arrival to the world ending."),
        ("Ride the Crown Railway into the new kingdom.", "Walk through the Creator’s Light World Gate into the new kingdom."),
        ("Receive Creator’s Light and unlock All stations, all Crown Railway routes, free travel, and the Art Castle finale.",
         "Receive Creator’s Light, activate Creator Station, return by World Gate or optional train, and open the Art Castle finale."),
        ("1. Train arrival — the world waiting for a mark", "1. World Gate arrival — the world waiting for a mark"),
        ("The train reaches a white station surrounded by floating shapes, empty frames, plants sleeping in glass seeds, and rivers held inside silver pipes. Milo and the player meet Uriel, who gives the player a glowing Creation Frame. The Perfect Blank has covered the road and trapped Creator’s Light.",
         "The player walks through the Creator’s Light World Gate into a white entry court surrounded by floating shapes, empty frames, plants sleeping in glass seeds, and rivers held inside silver pipes. Milo and the player meet Uriel, who gives the player a glowing Creation Frame. The Perfect Blank has covered the road and trapped Creator’s Light. The nearby train station remains inactive until the world is complete."),
        ("Creator’s Light appears as a flame carrying colours from the player’s creation. Uriel thanks the player, and the train returns to the Gallery. Wisdom, Harmony, and Creativity join as the Light of Identity. Every station and route opens for free travel, and the player may enter the Art Castle finale to receive the Crown of Life and choose one of the 16 friendly identity names.",
         "Creator’s Light appears as a flame carrying colours from the player’s creation. Uriel thanks the player, and Creator Station activates. The player may walk back through the Creator’s Light World Gate or take the train to the Gallery. Wisdom, Harmony, and Creativity join as the Light of Identity. The Art Castle finale opens, and the train now allows optional travel among the Art Castle and all completed worlds."),
        ("Unlock all Crown Railway destinations and free travel.", "Open the Art Castle finale and add Creator’s Light to optional completed-world train travel."),
        ("Build one understandable journey. Reuse modular pieces and keep decorative density lower around combat, prompts, gates, and train controls.",
         "Build one understandable journey. Reuse modular pieces and keep decorative density lower around combat, prompts, World Gates, and the optional station."),
        ("☐  Train route stays locked until the previous world completion flag is saved.",
         "☐  Creator’s Light is absent from the train destination list until Creator’s Light itself is complete."),
        ("☐  The treasure appears only after boss COMPLETE and the new train route unlocks only after the treasure save.",
         "☐  The treasure appears only after boss COMPLETE; then save the Art Castle finale unlock and optional Creator train destination."),
        ("End-state vision for Creator’s Light Kingdom: the route is restored, the treasure is earned, and the next Crown Railway state is clear.",
         "End-state vision for Creator’s Light Kingdom: the route is restored, the treasure is earned, the Art Castle finale is open, and the train remains optional."),
        ("One linear route with shortcuts and a clear return to the train", "One linear route with shortcuts and a clear return to the World Gate"),
        ("World Two is complete. Creator’s Light is now available on the train Destination Wheel.",
         "World Two is complete. Creator’s Light is now available through its World Gate; the train is not required for the story."),
        ("All stations, all Crown Railway routes, free travel, and the Art Castle finale", "Art Castle finale; Creator’s Light optional train destination"),
        ("Station, Uriel, four-button creation tutorial, two Ink Sprites", "World Gate, Uriel, four-button creation tutorial, two Ink Sprites"),
        ("Creator’s Light + all train routes", "Creator’s Light + Art Castle finale"),
        ("Creator Station / Entry Frame", "Creator World Gate / Entry Frame"),
        ("Creator Station and Entry Frame", "Creator World Gate and optional Creator Station"),
        ("Set after the station arrival finishes.", "Set after the World Gate arrival finishes."),
        ("Array of available station IDs; never infer only from scene position.", "Array containing only completed-world station IDs; never use it to control story progression."),
        ("DONE MEANS  Creator’s Light is complete when the player can make useful objects with a simple ungraded tool, protect those creations in readable sword fights, defeat the Perfect Blank’s armour, place an unfinished idea, receive Creator’s Light, unlock every train route, and reach the Art Castle identity finale.",
         "DONE MEANS  Creator’s Light is complete when the player can make useful objects with a simple ungraded tool, protect those creations in readable sword fights, defeat the Perfect Blank’s armour, place an unfinished idea, receive Creator’s Light, return by World Gate or optional train, and reach the Art Castle identity finale."),
    ],
}


CHARACTER_STORY_REPLACEMENTS = {
    "mind": [
        ("Guardian of Clear Thinking / Everlasting Father", "Mother Guardian Angel"),
        ("Guardian of Clear Thinking", "Mother Guardian Angel"),
        ("The player receives the Star and reaches Level 5.",
         "The player receives the Star, the Wisdom Blade upgrade, and reaches Level 5."),
        ("Star, Heart World Gate, optional Mind destination; Level 5.",
         "Star, Wisdom Blade, Heart World Gate, optional Mind destination; Level 5."),
    ],
    "heart": [
        ("Archangel Raphael", "Mother Guardian Angel"),
        ("Raphael", "Mother Guardian Angel"),
        ("The last note opens and reveals the Harmony Jewel, shining with every feeling colour. Mother Guardian Angel thanks the player and Milo.",
         "The last note opens and reveals the Harmony Jewel, shining with every feeling colour. Mother Guardian Angel thanks the player and Milo. The player receives the Harmony Shield."),
        ("Harmony Jewel + Creator’s Light World Gate", "Harmony Jewel + Harmony Shield + Creator’s Light World Gate"),
    ],
    "creator": [
        ("Uriel", "Mother Guardian Angel"),
        ("Creator’s Light appears as a flame carrying colours from the player’s creation. Mother Guardian Angel thanks the player, and Creator Station activates.",
         "Creator’s Light appears as a flame carrying colours from the player’s creation. Mother Guardian Angel thanks the player. The player receives the Creator Star skill, and Creator Station activates."),
        ("Creator’s Light + Art Castle finale", "Creator’s Light + Creator Star skill + Art Castle finale"),
    ],
}


def iter_all_paragraphs(doc):
    for paragraph in doc.paragraphs:
        yield paragraph
    for table in doc.tables:
        for row in table.rows:
            for cell in row.cells:
                for paragraph in cell.paragraphs:
                    yield paragraph


def apply_train_story_replacements(doc, key):
    matched = {old: 0 for old, _ in TRAIN_STORY_REPLACEMENTS[key]}
    for paragraph in iter_all_paragraphs(doc):
        original = paragraph.text
        revised = original
        for old, new in TRAIN_STORY_REPLACEMENTS[key]:
            if old in revised:
                matched[old] += revised.count(old)
                revised = revised.replace(old, new)
        if revised == original:
            continue
        if paragraph.runs:
            paragraph.runs[0].text = revised
            for run in paragraph.runs[1:]:
                run.text = ""
        else:
            paragraph.add_run(revised)
    missing = [old for old, count in matched.items() if count == 0]
    if missing:
        preview = "\n".join(f"- {item[:100]}" for item in missing)
        raise RuntimeError(f"Unmatched train-story replacements for {key}:\n{preview}")


def apply_character_story_replacements(doc, key):
    matched = {old: 0 for old, _ in CHARACTER_STORY_REPLACEMENTS[key]}
    for paragraph in iter_all_paragraphs(doc):
        original = paragraph.text
        revised = original
        for old, new in CHARACTER_STORY_REPLACEMENTS[key]:
            if old in revised:
                matched[old] += revised.count(old)
                revised = revised.replace(old, new)
        if revised == original:
            continue
        if paragraph.runs:
            paragraph.runs[0].text = revised
            for run in paragraph.runs[1:]:
                run.text = ""
        else:
            paragraph.add_run(revised)
    missing = [old for old, count in matched.items() if count == 0]
    if missing:
        preview = "\n".join(f"- {item[:100]}" for item in missing)
        raise RuntimeError(f"Unmatched character-story replacements for {key}:\n{preview}")

    image_replacements = {
        "mind": [("Guardian of Clear Thinking", "Guardian Angel"), ("Everlasting Father", "Mother Guardian")],
        "heart": [("Raphael", "Guardian Angel")],
        "creator": [("Uriel", "Guardian Angel")],
    }[key]
    for doc_properties in doc._element.xpath(".//wp:docPr"):
        for attribute in ("name", "descr", "title"):
            value = doc_properties.get(attribute)
            if not value:
                continue
            for old, new in image_replacements:
                value = value.replace(old, new)
            doc_properties.set(attribute, value)


def add_matrix(doc, headers, rows, widths, font_size=8.0):
    table = doc.add_table(rows=1, cols=len(headers))
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    set_table_geometry(table, widths)
    set_table_borders(table)
    set_repeat_table_header(table.rows[0])
    for index, text in enumerate(headers):
        cell = table.rows[0].cells[index]
        shade_cell(cell, "D9F2F5")
        cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
        cell.text = text
        format_cell_text(cell, size=font_size + 0.4, bold=True, color=MIDNIGHT,
                         align=WD_ALIGN_PARAGRAPH.CENTER if index == 0 else WD_ALIGN_PARAGRAPH.LEFT)
    for row_index, row in enumerate(rows):
        cells = table.add_row().cells
        prevent_row_split(table.rows[-1])
        if row_index % 2:
            for cell in cells:
                shade_cell(cell, "F6FBFC")
        for col_index, value in enumerate(row):
            cells[col_index].text = str(value)
            cells[col_index].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            format_cell_text(cells[col_index], size=font_size,
                             bold=col_index in (0, 1),
                             color=MIDNIGHT if col_index in (0, 1) else INK,
                             align=WD_ALIGN_PARAGRAPH.CENTER if col_index == 0 else WD_ALIGN_PARAGRAPH.LEFT)
    return table


def add_source_block(doc, title, items):
    doc.add_heading(title, level=2)
    for label, path in items:
        add_bullet(doc, f"{label}: {path}", bold_lead=f"{label}:")


def add_section_intro_robust(doc, part, title, summary):
    """Match the sample section intro without an empty page-break paragraph."""
    body = doc._element.body
    start = len(body) - 1
    add_section_intro(doc, part, title, summary)
    new_elements = list(body[start:len(body) - 1])
    if new_elements and new_elements[0].xpath(".//w:br[@w:type='page']"):
        body.remove(new_elements.pop(0))
    if new_elements:
        Paragraph(new_elements[0], doc).paragraph_format.page_break_before = True


def append_addendum(doc, key):
    data = WORLD_DATA[key]

    add_section_intro_robust(
        doc,
        "2026 implementation addendum",
        f"{data['name']} — Godot Blueprint Architecture",
        "A production-ready extension using the World One structure: actual-game alignment, architecture, building and dressing, quest objects, combat entities, library reuse and an optional-travel appendix.",
    )
    picture_with_alt(
        doc,
        ACTUAL_IMAGES[key],
        Inches(3.35),
        f"Actual bird's-eye runtime capture of {data['name']} inside the Art Castle Galaxy world.",
    )
    add_caption(doc, f"Current in-game {data['name'].title()} world. This runtime view is the authority for location, low-poly style and established landmark language.")
    add_callout(doc, "IDENTITY LOCK", data["identity"], fill="EAF9FB")
    doc.add_heading("What this addendum changes", level=2)
    add_bullet(doc, "Keeps the story, quests, identity tracking and World Gate progress. The train stays optional.")
    add_bullet(doc, "Adds build rules for architecture, monsters and twelve useful task objects. Each item says REUSE, MODIFY or NEW.")
    add_bullet(doc, "Locks one fox outfit, one Mayor Milo outfit, one lighter-skin Mother Guardian and one Crown Train for all three worlds.")
    add_bullet(doc, "Uses the current Art Castle Galaxy world as the style source: pale low-poly islands, cyan and violet light, gold rewards and a galaxy sky.")
    add_callout(doc, "CURRENT GAME AUDIT", data["runtime"], fill="FFF6D8", accent=GOLD)

    # add_callout leaves a spacing paragraph after its table. When the next
    # section starts with page-break-before near the page bottom, LibreOffice
    # can place that empty paragraph on its own page. Remove only this known,
    # empty spacer so the following blueprint begins on the next real page.
    body = doc._element.body
    trailing = body[-2]
    if trailing.tag.endswith("}p") and not "".join(trailing.itertext()).strip() and not trailing.xpath(".//w:drawing | .//w:br"):
        body.remove(trailing)

    train_start = len(body) - 1
    add_section_intro_robust(
        doc,
        "Optional travel appendix",
        "Optional Crown Train Fast Travel",
        "The train is a small post-completion convenience, not a story requirement. The next story world always opens through an Art Castle World Gate.",
    )
    picture_with_alt(
        doc,
        TRAIN_IMAGE,
        Inches(6.5),
        "Shared Crown Line production blueprint showing one permanent engine and two coaches, one centre monorail beam, technology, nature and magic parts, and three world-specific station and rail visual skins.",
    )
    add_caption(doc, "TRAIN AUTHORITY. Use this one vehicle unchanged in every world. One engine and two open passenger coaches sit above one structural beam on the train centreline.")
    add_callout(
        doc,
        "SIMPLE STORY RULE",
        "Complete a world → its station activates → choose World Gate or train to return to the Art Castle → enter the next story through its World Gate. The train may visit the Art Castle and completed worlds only.",
    )

    doc.add_page_break()
    doc.add_heading("Train and rail implementation authority", level=2)
    train_rows = [
        ("Purpose", "Optional post-completion travel", "The train is never a quest objective, required cutscene, boss reward ceremony or condition for starting the next world."),
        ("Story route", "World Gates only", "The player walks through the next unlocked Art Castle World Gate. Never send the player directly from one world to the next by train."),
        ("Return choice", "Gate or train", "After completing a world, the player may walk through its World Gate or take the newly activated train back to the Art Castle."),
        ("Destinations", "Castle + completed worlds", "Do not show an unfinished world in the train menu. Mind unlocks after Mind; Heart after Heart; Creator after Creator."),
        ("Line", "One continuous open line", "Art Castle ↔ Mind Spark ↔ Heart Melody ↔ Creator’s Light. It is a revisit network, not the campaign sequence."),
        ("Activation", "After local world completion", "Boss COMPLETE saves the treasure, activates that world’s station beacon and enables the call-train prompt."),
        ("Train location", "No network simulation", "If the train is not at the station, a call button brings it in after a short fade. Do not track it while the player uses World Gates."),
        ("Travel", "One action + destination menu", "Choose an allowed stop, play one short movement or fade, arrive, and leave. No manual driving, track switches, onboard quest or required dialogue."),
        ("Support", "One centre monorail beam", "3.2 m wide × 1.6 m high; exactly below train centre. No paired rails and no sleepers."),
        ("Train origin", "1.4 m above beam centre", "Keep the vehicle centred on the existing Curve3D. Visual levitation gap may glow but cannot imply a second rail."),
        ("Vehicle", "1 engine + 2 open passenger coaches", "Wide central lane, safe deck collision, low side guards, leaf-glass roofs and one simple destination console. Milo does not drive it."),
        ("Shared look", "One design in all three worlds", "Do not recolour or rebuild the vehicle for each world. It must always be easy to recognise as the same Crown Train."),
        ("Technology layer", "Navy chassis, cyan glass, circuit guide lines and gold joints", "Use simple BoxMesh, CylinderMesh and shared StandardMaterial3D parts."),
        ("Magic layer", "Violet crystals, gold star halo and soft lift light", "Use one clear glow material and a small particle budget."),
        ("Nature layer", "Living root underframe, leaf roof and small planter pods", "Use static child meshes. Only leaf tips may move; collision stays still."),
        ("Station invariant", "38 m dock radius; 16 m access bridge", "Keep the platform, boarding lane, guards, access route and train slot. Show INACTIVE until that local world is complete."),
        ("Station variation", "Visual child only", "Mind: circuit fins and server roots. Heart: leaf arches, water notes and bells. Creator: frames, pencils and violet glass. Function and collision stay the same."),
        ("Rail variation", "Visual trim child only", "Mind adds cyan node fins. Heart adds soft leaf and bell trim. Creator adds frame and violet-glass trim. The 3.2 m × 1.6 m centre beam never changes."),
        ("Current source", "REUSE/MODIFY", COMMON_ASSETS["rail"]),
    ]
    add_matrix(doc, ("Part", "Approved value", "Developer direction"), train_rows, [1.25, 1.75, 3.5], 8.2)

    doc.add_page_break()
    picture_with_alt(
        doc,
        TRAIN_RUNTIME,
        Inches(6.5),
        "Actual in-game low-poly Crown Line station and train environment showing the approved Art Castle Galaxy material and lighting style.",
    )
    add_caption(doc, "Current in-game station reference. Preserve its pale low-poly base, cyan/violet light, gold framing, clear boarding lane and galaxy setting.")
    doc.add_heading(f"{data['name'].title()} station skin", level=2)
    if key == "mind":
        add_bullet(doc, "Use angular glass fins, server-root columns, cyan node lines and one violet Thought Spark sign.")
        add_bullet(doc, "Keep plants controlled and geometric; reserve gold for the post-boss unlock beacon.")
        add_bullet(doc, "Rail visual trim: small cyan node fins and thin circuit lines. The centre beam shape, size and collision do not change.")
    elif key == "heart":
        add_bullet(doc, "Use petal/leaf arches, rounded water-note columns, hanging bell flowers and a soft aqua route light.")
        add_bullet(doc, "Let vines wrap the pavilion without entering the boarding clearance or hiding platform guards.")
        add_bullet(doc, "Rail visual trim: soft leaf edges, aqua note lights and rare small bell marks. The centre beam shape, size and collision do not change.")
    else:
        add_bullet(doc, "Use asymmetric frame arches, pencil/brush spires, glass colour panels and one floating star-flame sign.")
        add_bullet(doc, "Paint splashes remain visual overlays; the station collision and single-beam centre slot stay unchanged.")
        add_bullet(doc, "Rail visual trim: slim frame edges, pencil points and violet glass light. The centre beam shape, size and collision do not change.")
    add_bullet(doc, "Before this world is complete, show the station as inactive and do not allow boarding. After completion, activate travel to the Art Castle and already-completed stations.")
    add_source_block(doc, "Shared scene plan", [
        ("Railway root", COMMON_ASSETS["rail"]),
        ("World style source", COMMON_ASSETS["world"]),
        ("Suggested train scene", "PathFollow3D CrownTrain > EngineBody; LivingRootUnderframe; Coach_01; Coach_02; LeafCanopies; PassengerCollision; DestinationConsole; RouteLights"),
        ("Suggested station scene", "Node3D StoryStation > SharedDockCollision; BoardingLane; PlatformGuards; AccessBridge; UnlockBeacon; ThemeSkin_<World>"),
        ("Suggested rail scene", "Path3D CrownLine > SharedCentreBeamCollision; SharedCentreBeamVisual; RailTrim_<World> visual child"),
    ])
    train_end = len(body) - 1
    train_elements = list(body[train_start:train_end])
    if train_elements and train_elements[0].xpath(".//w:br[@w:type='page']"):
        body.remove(train_elements.pop(0))
        if train_elements:
            Paragraph(train_elements[0], doc).paragraph_format.page_break_before = True
    for element in train_elements:
        body.remove(element)

    add_section_intro_robust(
        doc,
        "Blueprint A",
        f"{data['name'].title()} Architecture Plate",
        f"{data['tag']}. The plate refines the existing world into modular production objects without changing its story role or current galaxy-world style.",
    )
    picture_width = Inches(4.2) if key in ("mind", "creator") else Inches(6.5)
    picture_with_alt(doc, ARCH_IMAGES[key], picture_width, data["arch_alt"])
    add_caption(doc, "Numbered architecture plate. Use the specification table—not small generated labels—as the final naming and implementation authority.")
    add_callout(doc, "MODELLING RULE", "Build silhouette, player scale, collision and interaction first. Add emissive lines, plants and particles only after the object works at the real camera distance.")

    doc.add_page_break()
    doc.add_heading("Numbered architecture specification", level=1)
    add_matrix(
        doc,
        ("ID", "Object", "Shape and purpose", "Godot scene recipe", "Status", "Existing source"),
        data["arch"],
        [0.35, 1.0, 1.45, 1.65, 0.55, 1.5],
        7.15,
    )

    doc.add_page_break()
    doc.add_heading("Complete production object inventory", level=1)
    doc.add_paragraph("‘All objects’ means every reusable gameplay or dressing family required by this guide. Repeated trees, rocks, flowers, tiles and lamps are instances of these families, not unique models.")
    add_matrix(doc, ("Group", "Objects included", "Implementation / reuse decision"), data["inventory"], [1.2, 3.35, 1.95], 8.15)
    add_source_block(doc, "Installed sources to check before modelling", [
        ("Current world", COMMON_ASSETS["world"]),
        ("Nature library", COMMON_ASSETS["nature"]),
        ("Architecture/prop library", COMMON_ASSETS["houses"]),
        ("Wayfinding", COMMON_ASSETS["sign"]),
    ])
    add_callout(doc, "REUSE TEST", "Before approving a NEW mesh, test whether the silhouette can be made from BoxMesh, CylinderMesh, SphereMesh, TorusMesh, an existing glTF, or one low-poly combination of those shapes.", fill="FFF6D8", accent=GOLD)

    functional = FUNCTIONAL_OBJECTS[key]
    add_section_intro_robust(
        doc,
        "Functional object plate",
        functional["title"],
        "Every object below helps a task, puzzle, fight, checkpoint, hint, reflection or reward. The player should see what to do, how much is complete and what happens next.",
    )
    picture_with_alt(doc, FUNCTIONAL_OBJECT_IMAGES[key], Inches(6.5), functional["alt"])
    add_caption(doc, "FUNCTIONAL OBJECT AUTHORITY. The large number in the image links to the row below. The row—not generated picture text—is the final name and game rule.")
    add_callout(
        doc,
        "MEANINGFUL OBJECT RULE",
        "Do not place a special glowing object only to look nice. It must give an action, show progress, give clear success feedback, or help the player find the next step.",
    )

    doc.add_page_break()
    doc.add_heading("Functional object implementation", level=1)
    add_matrix(
        doc,
        ("ID", "Object", "Player does", "Quest result", "Simple Godot build", "Help / clear cue"),
        functional["rows"],
        [0.35, 1.15, 1.25, 1.35, 1.55, 1.25],
        7.05,
    )
    doc.add_heading("One shared QuestObject scene", level=2)
    add_bullet(doc, "Node3D root — owns the object state: LOCKED, READY, ACTIVE and COMPLETE.")
    add_bullet(doc, "MeshRoot + StaticBody3D — visible shape and simple collision. Small moving art must not move the main collision.")
    add_bullet(doc, "Area3D InteractZone — one shared action button; emits activated and completed signals.")
    add_bullet(doc, "AnimationPlayer + AudioStreamPlayer3D — clear start, success and reset feedback.")
    add_bullet(doc, "Label3D or world icon — shows the action, count and next step without covering the player.")
    add_bullet(doc, "QuestObjectData Resource — stores object ID, needed count, icon, sound, hint and save flag.")
    add_bullet(doc, "Optional HintTimer — after 45 seconds with no progress, offer help. It never auto-solves the task.")
    doc.add_heading("Simple player-experience rules", level=2)
    add_bullet(doc, "Show only one main objective at a time. Keep a short task list for finished and unfinished steps.")
    add_bullet(doc, "Show a clear count such as 0/3 when more than one part is needed.")
    add_bullet(doc, "Use shape, icon, short text and sound for important information. Colour is extra, not the only answer.")
    add_bullet(doc, "Let the player reset one puzzle without restarting the full world.")
    add_bullet(doc, "Save each completed object, boss phase checkpoint and identity reflection choice.")
    add_bullet(doc, "Puzzle help and combat help are separate settings. Easy puzzle help must not change enemy health unless the player also chooses easier combat.")

    if key in SUPPLEMENTAL_KITS:
        kit = SUPPLEMENTAL_KITS[key]
        add_section_intro_robust(
            doc,
            "Blueprint B",
            kit["building_title"],
            "The same building-kit slot used by the World One sample: modular terrain, paths, traversal, station dressing, small props, world states, collision and LOD guidance.",
        )
        picture_with_alt(doc, BUILDING_KIT_IMAGES[key], Inches(6.5), kit["building_alt"])
        add_caption(doc, "World-building plate. Numbered rows below are the implementation authority; repeated decorations are instances, not new unique models.")
        doc.add_page_break()
        doc.add_heading("World-building kit specification", level=1)
        add_matrix(doc, ("ID", "Object family", "Purpose", "Godot construction"), kit["building_rows"], [0.4, 1.45, 2.0, 2.65], 7.8)

        add_section_intro_robust(
            doc,
            "Blueprint C",
            kit["quest_title"],
            "The same quest-and-magic slot used by the World One sample: interactive objects, reusable sockets, rewards and boss-arena props are separated from static scenery.",
        )
        picture_with_alt(doc, QUEST_KIT_IMAGES[key], Inches(6.5), kit["quest_alt"])
        add_caption(doc, "Quest-object plate. All gameplay uses authored PackedScenes, simple collision and standard Godot nodes—no runtime freeform modelling or complex simulation.")
        doc.add_page_break()
        doc.add_heading("Quest and magic kit specification", level=1)
        add_matrix(doc, ("ID", "Object family", "Purpose", "Godot construction"), kit["quest_rows"], [0.4, 1.45, 2.0, 2.65], 7.8)

    add_section_intro_robust(
        doc,
        "Blueprint D" if key in SUPPLEMENTAL_KITS else "Blueprint B",
        "Characters, Monsters, Boss & Combat Objects",
        "Every combat design uses current sword damage and standard Godot 4 nodes. Enemies are visible story blight—not a feeling, thought or creative idea—and the final interaction restores the world. Legacy player, Milo and guardian panels are superseded by the shared character blueprint that follows.",
    )
    picture_with_alt(doc, ENTITY_IMAGES[key], Inches(6.5), data["entity_alt"])
    add_caption(doc, "Enemy and boss silhouettes remain useful. Any player, Milo or guardian image on this legacy plate is replaced by the shared continuity sheets below.")
    add_callout(doc, "COMBAT READABILITY", "Every damaging action telegraphs for at least 0.75 seconds, shows a safe direction with shape as well as colour, and enters a clear recovery state. Defeat uses a soft dissolve—no gore.")

    doc.add_page_break()
    doc.add_heading("Entity implementation specification", level=1)
    add_matrix(
        doc,
        ("ID", "Entity", "Visual / behaviour", "Godot node recipe", "Role", "Health", "Reward", "Source"),
        data["entities"],
        [0.3, 0.8, 1.25, 1.55, 0.55, 0.55, 0.45, 1.05],
        6.65,
    )
    doc.add_heading("Shared enemy scene", level=2)
    add_bullet(doc, "CharacterBody3D EnemyBase — movement and main collision. Stationary enemies may stop navigation but should keep the same API.")
    add_bullet(doc, "MeshRoot + AnimationPlayer/AnimationTree — IDLE, CHASE, TELEGRAPH, ATTACK, RECOVER, HIT and DEFEATED.")
    add_bullet(doc, "NavigationAgent3D — chase only inside an assigned arena; stop before the telegraph begins.")
    add_bullet(doc, "Area3D Hurtbox + Area3D Hitbox — separate collision layers; the player’s current sword Area3D calls take_damage.")
    add_bullet(doc, "Timer nodes — cooldown, telegraph and recovery; use explicit state transitions instead of animation-name guessing.")
    add_bullet(doc, "EnemyData Resource — HP, XP, speed, damage, weak-point multiplier, scene references and accessibility timing scale.")
    add_bullet(doc, "BossController — INTRO → PHASE_1 → TRANSITION → PHASE_2 → PHASE_3 → RESTORE → COMPLETE; save treasure only at COMPLETE.")

    character_label = "Blueprint E" if key in SUPPLEMENTAL_KITS else "Blueprint C"
    add_section_intro_robust(
        doc,
        character_label,
        "Shared Character Continuity & Simple Gear",
        "One player, one Mayor Milo and one female Mother Guardian appear unchanged across all three worlds. Only three automatic player rewards are added, with no costume inventory, crafting or gear management screen.",
    )
    picture_with_alt(
        doc,
        PLAYER_CONTINUITY_IMAGE,
        Inches(6.5),
        "Shared orange fox player blueprint showing one permanent green outfit, turnaround views, Wisdom Blade, Harmony Shield, Creator Star skill, action poses and simple Godot collision areas.",
    )
    add_caption(doc, "PLAYER AUTHORITY. Keep the current fox identity and green outfit in every world. Only the three earned equipment children change visibility or material.")
    add_callout(doc, "NO INVENTORY COMPLEXITY", "The game auto-equips unlocked rewards. The player has Attack, Block and one Skill button—no inventory grid, crafting, comparison stats, durability or gear swapping.")

    heading = doc.add_heading("Mayor Milo — one permanent elder design", level=1)
    heading.paragraph_format.page_break_before = True
    picture_with_alt(
        doc,
        MILO_CONTINUITY_IMAGE,
        Inches(6.5),
        "Shared Mayor Milo blueprint showing one elderly cream-grey cat with white moustache, gold glasses, permanent navy mayor coat, guidance props, friendly gestures and a simple non-combat Godot rig.",
    )
    add_caption(doc, "MILO AUTHORITY. Use one elderly face, one white moustache, one pair of gold glasses and one navy mayor-professor outfit in Mind Spark, Heart Melody and Creator's Light.")
    add_callout(doc, "GUIDE, NOT FIGHTER", "Milo may carry a cane, map or tablet, but these are dialogue props. He has no weapon, combat hitbox, armour, world costume or boss role.")

    heading = doc.add_heading("The Mother Guardian — one female angel", level=1)
    heading.paragraph_format.page_break_before = True
    picture_with_alt(
        doc,
        GUARDIAN_CONTINUITY_IMAGE,
        Inches(6.5),
        "Unified female Mother Guardian blueprint showing a mature kind face with a warm light-beige skin tone, silver hair with leaves and flowers, warm heart light, ivory-sage leaf gown, branch halo, three-panel wings, gentle poses and a simple Godot rig.",
    )
    add_caption(doc, "GUARDIAN AUTHORITY. This one mature female angel, with the approved lighter warm skin tone, replaces every former world-specific guardian design and name.")
    add_callout(doc, "FIRST-GLANCE FEELING", "Her face, open hands, warm heart light and living leaf silhouette must communicate love, mercy, harmony, safety, patience and hope. She guides and restores; she never fights.")

    heading = doc.add_heading("What the Mother Guardian does in all three worlds", level=2)
    heading.paragraph_format.page_break_before = True
    guardian_rows = [
        ("World entrance", "Welcomes the player and gives the mission in one simple sentence.", "One short line, then control returns to the player."),
        ("Before a puzzle", "Explains why the object matters, but not the answer.", "Point to the active object and name the action button."),
        ("When the player is stuck", "Offers help after the player asks or after 45 seconds with no progress.", "Show only the next small step. The hint can be turned off."),
        ("Before the boss", "Explains that the blight is the problem—not thoughts, feelings or creativity.", "Show the safe cue, weak point and restore goal."),
        ("During the boss", "Gives short safety warnings only.", "She does not attack, spam healing or solve a boss phase."),
        ("After the boss", "Leads the gentle restore action and gives the world reward.", "Boss state must be RESTORE before COMPLETE."),
        ("Identity reflection", "Asks one short question with no score and no right answer.", "Save evidence for the 16-identity system; do not choose the identity yet."),
        ("Train unlock", "Says the local station is now open for later travel.", "She does not drive the train or make it part of the story path."),
    ]
    add_matrix(doc, ("Moment", "Guardian job", "Simple game rule"), guardian_rows, [1.15, 2.6, 2.75], 8.0)
    guide = GUARDIAN_WORLD_HELP[key]
    doc.add_heading(f"Her voice in {data['name'].title()}", level=2)
    add_bullet(doc, guide["voice"], bold_lead=None)
    add_bullet(doc, f"Puzzle help: {guide['puzzle']}", bold_lead="Puzzle help:")
    add_bullet(doc, f"Boss help: {guide['boss']}", bold_lead="Boss help:")
    add_bullet(doc, f"Identity question: {guide['reflection']}", bold_lead="Identity question:")
    add_callout(doc, "ONE GUARDIAN ONLY", "Use one shared GuardianAngel.tscn, one face, one lighter warm skin tone, one gown, one halo and one wing set. Only her dialogue, pose and small particles change by story moment.", fill="EAF9FB")

    heading = doc.add_heading("Character and equipment implementation authority", level=1)
    heading.paragraph_format.page_break_before = True
    character_rows = [
        ("Player", "Orange fox; green hood/tunic; brown belt, gloves and boots; same proportions and outfit everywhere.", "Sword, shield and star children only; hit reaction and world lighting may change.", "No skins, armour sets, recoloured outfits or alternate player models."),
        ("Mayor Milo", "Elder cream-grey cat; white moustache; gold glasses; navy coat; ivory shirt; violet waistcoat; gold trim.", "Cane, rolled map or cyan tablet may be shown for dialogue.", "No green/blue world coats, weapons, combat or costume swaps."),
        ("Guardian Angel", "Mature Mother Guardian; kind face; approved lighter warm skin; silver hair; ivory-sage leaf gown; branch halo; one shared wing design.", "Wings fold/open; heart light and small particles may brighten during restoration.", "No world-specific variants, young fairy redesign, weapons or world skins."),
    ]
    add_matrix(doc, ("Character", "Permanent appearance", "Allowed change", "Forbidden"), character_rows, [0.9, 2.35, 1.75, 1.5], 7.6)

    doc.add_heading("Three automatic player rewards", level=2)
    gear_rows = [
        ("Start", "Base Sword", "25 damage; current light slash and current SwordHitbox.", "Reuse current SwordVisual, animation and Area3D.", "Always"),
        ("Mind complete", "Wisdom Blade", "30 damage; same timing and hitbox; cyan crystal/edge material only.", "Swap SwordVisual child/material; set damage to 30.", "gear_wisdom_blade"),
        ("Heart complete", "Harmony Shield", "Hold Block to reduce frontal damage by 50%. No reflect, parry, stamina or shield attack.", "Show ShieldVisual while blocking; one frontal Area3D/dot check.", "gear_harmony_shield"),
        ("Creator complete", "Creator Star", "Skill button launches one straight 20-damage light bolt; four-second cooldown; useful in completed-world revisits.", "PackedScene Area3D projectile + Timer + velocity; one SkillSpawn Marker3D.", "gear_creator_star"),
    ]
    add_matrix(doc, ("Unlock", "Reward", "Exact behaviour", "Godot recipe", "Save flag"), gear_rows, [0.8, 1.0, 1.9, 1.95, 0.85], 7.3)
    doc.add_heading("Shared scene plan", level=2)
    add_bullet(doc, "Player3D keeps the current controller. Add EquipmentSocket/SwordVisual, ShieldVisual, CreatorStar, ShieldBlockArea and SkillSpawn; visibility comes from three save flags.")
    add_bullet(doc, "MayorMilo is one shared dialogue scene. PermanentOutfit, Glasses and Moustache are rigid mesh children; CaneSocket changes only the guidance prop.")
    add_bullet(doc, "GuardianAngel is one shared non-combat scene. Use a humanoid Skeleton3D, four-to-six rigid hair sections, five-to-seven rigid gown panels, three wing panels per side, two wing bones per side, one halo child and one GPUParticles3D.")
    add_bullet(doc, "The protection dome is optional presentation only: one Area3D and one transparent sphere material. It does not create a new combat system or required puzzle.")

    heading = doc.add_heading("Research used for the simple Godot plan", level=1)
    heading.paragraph_format.page_break_before = True
    doc.add_paragraph("These official pages were used to choose small, safe Godot parts and clear player guidance. The plan avoids custom physics, free drawing checks, manual train driving and large new systems.")
    add_matrix(doc, ("Official source", "Link", "How this guide uses it"), RESEARCH_LINKS, [1.35, 3.05, 2.1], 7.25)
    add_callout(doc, "CLEAR AND FAIR", "A player should know the current goal, see progress, ask for a hint, reset a puzzle, and read important cues without depending on colour alone.", fill="FFF6D8", accent=GOLD)

    add_section_intro_robust(
        doc,
        "Blueprint F" if key in SUPPLEMENTAL_KITS else "Blueprint D",
        "World Difference Lock & Production Handoff",
        "These rules prevent the three kingdoms from becoming recolours of one another while the player outfit, Mayor Milo outfit, one female Guardian Angel, train, railway, UI and combat foundation remain shared.",
    )
    add_matrix(doc, ("Identity control", "Approved rule"), data["lock"], [1.55, 4.95], 8.7)
    doc.add_heading("Shared versus world-specific", level=2)
    shared_rows = [
        ("SHARED", "One fox and green outfit, one navy Mayor Milo outfit, one female Mother Guardian, three simple equipment unlocks, Crown Train, one centre beam, station collision, quest/save API, identity system, EnemyBase, boss states, UI and accessibility settings"),
        ("WORLD-SPECIFIC", "Island silhouette, path surface, station ThemeSkin, landmark kit, puzzle verbs, enemy silhouettes, boss attacks, ambient audio, plant grouping, colour balance and reward presentation"),
        ("NEVER SHARED VISUALLY", "Hero landmark silhouettes. A server tree cannot become a Heart instrument by recolouring; a drum cannot become a Creator frame; a canvas arch cannot appear in Mind Spark."),
    ]
    add_matrix(doc, ("Type", "Decision"), shared_rows, [1.25, 5.25], 8.5)

    doc.add_heading("Recommended build order", level=2)
    ordered = [
        "Greybox the island route, recovery volume, station bridge, landmark sightlines and boss arena; finish the World Gate story flow first.",
        "Build the shared interactable, EnemyBase, player equipment sockets, permanent Mayor Milo and unified Mother Guardian scenes; connect the sword hitbox and save data.",
        "Implement required landmarks and quest triggers with REUSE items; build the three enemies and boss with debug telegraphs before NEW art.",
        "Replace greybox with the numbered architecture kit; then add the station ThemeSkin, dressing, audio, particles and three world-state changes.",
        "Add the optional train menu last; playtest World Gate return and fast travel only to the Art Castle or completed stations.",
    ]
    for item in ordered:
        add_check(doc, item)

    doc.add_heading("Developer acceptance checklist", level=2)
    checks = [
        "Every blueprint row has a scene owner and REUSE, MODIFY or NEW ticket; walkable objects have collision and decorations stay outside navigation/damage layers.",
        "The fox player and Mayor Milo keep one permanent outfit; Milo never fights; every world instances the same mature Mother Guardian scene.",
        "Wisdom Blade, Harmony Shield and Creator Star use three save flags and auto-equip; there is no inventory or crafting screen.",
        "Monsters take sword damage, award XP once and save correctly; bosses restart by phase; the final treasure requires the restorative interaction.",
    ]
    for item in checks:
        add_check(doc, item)

    for element in train_elements:
        body.insert(len(body) - 1, element)



def set_metadata(doc, key):
    data = WORLD_DATA[key]
    doc.core_properties.title = f"{data['name'].title()} Concise Developer Guide with Implementation Blueprints"
    doc.core_properties.subject = "ARTÉA world guide, object architecture, shared character continuity, simple Godot equipment and optional Crown Train"
    doc.core_properties.keywords = "ARTÉA, Godot 4.7, blueprint, shared player, Mayor Milo, female Guardian Angel, simple equipment, monsters, boss, Crown Train"
    doc.core_properties.comments = "Enhanced copy. Original guide preserved; implementation and shared-character blueprint addenda appended on 14 August 2026."


def ensure_safety(doc):
    for paragraph in doc.paragraphs:
        paragraph.paragraph_format.widow_control = True
        if paragraph.style and paragraph.style.name.startswith("Heading"):
            paragraph.paragraph_format.keep_with_next = True


def remove_trailing_blank_paragraphs(doc):
    body = doc._element.body
    section_properties = body.sectPr
    for child in list(reversed(body[:-1] if section_properties is not None else body[:])):
        if child.tag.endswith("}p"):
            text = "".join(child.itertext()).strip()
            has_drawing = bool(child.xpath(".//w:drawing | .//w:pict | .//w:br[@w:type='page']"))
            if not text and not has_drawing:
                body.remove(child)
                continue
        break


def build_one(key):
    source = SOURCES[key]
    output = OUTPUTS[key]
    if not source.exists():
        raise FileNotFoundError(source)
    for path in (
        ACTUAL_IMAGES[key], ARCH_IMAGES[key], ENTITY_IMAGES[key],
        PLAYER_CONTINUITY_IMAGE, MILO_CONTINUITY_IMAGE, GUARDIAN_CONTINUITY_IMAGE,
        TRAIN_IMAGE, TRAIN_RUNTIME, FUNCTIONAL_OBJECT_IMAGES[key],
    ):
        if not path.exists():
            raise FileNotFoundError(path)
    if key in SUPPLEMENTAL_KITS:
        for path in (BUILDING_KIT_IMAGES[key], QUEST_KIT_IMAGES[key]):
            if not path.exists():
                raise FileNotFoundError(path)
    doc = Document(source)
    apply_train_story_replacements(doc, key)
    apply_character_story_replacements(doc, key)
    append_addendum(doc, key)
    set_metadata(doc, key)
    ensure_safety(doc)
    remove_trailing_blank_paragraphs(doc)
    doc.save(output)
    print(output)


def main():
    for key in ("mind", "heart", "creator"):
        build_one(key)


if __name__ == "__main__":
    main()
