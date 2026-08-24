from __future__ import annotations

from datetime import date
from pathlib import Path
import sys

from PIL import Image
from docx import Document
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.opc.constants import RELATIONSHIP_TYPE as RT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Emu, Inches, Pt, RGBColor


ROOT = Path("/Users/davidsovann/S2603/artea")
DOCS = Path("/Users/davidsovann/Documents")
PACK = ROOT / "artifacts" / "implementation_blueprint_pack"

sys.path.insert(0, str(ROOT / "tools"))
from build_three_world_implementation_blueprint_guides import (  # noqa: E402
    FUNCTIONAL_OBJECTS,
    GUARDIAN_WORLD_HELP,
    RESEARCH_LINKS,
    WORLD_DATA,
)


OUTPUTS = {
    "mind": DOCS / "World_One_Mind_Spark_Concise_Developer_Guide_Implementation_Blueprints.docx",
    "heart": DOCS / "World_Two_Heart_Melody_Concise_Developer_Guide_Implementation_Blueprints.docx",
    "creator": DOCS / "World_Three_Creators_Light_Concise_Developer_Guide_Implementation_Blueprints.docx",
}

OVERVIEWS = {
    "mind": ROOT / "artifacts" / "galaxy_worlds_birdseye" / "mind_spark_birdseye.png",
    "heart": ROOT / "artifacts" / "galaxy_worlds_birdseye" / "heart_melody_birdseye.png",
    "creator": ROOT / "artifacts" / "galaxy_worlds_birdseye" / "creators_light_birdseye.png",
}

BIRDSEYE_BLUEPRINTS = {
    "mind": PACK / "mind_spark_birdseye_world_blueprint_v1.png",
    "heart": PACK / "heart_melody_birdseye_world_blueprint_v1.png",
    "creator": PACK / "creators_light_birdseye_world_blueprint_v1.png",
}

ARCHITECTURE_IMAGES = {
    key: PACK / f"{stem}_architecture_blueprint_v1.png"
    for key, stem in {
        "mind": "mind_spark",
        "heart": "heart_melody",
        "creator": "creators_light",
    }.items()
}

FUNCTIONAL_IMAGES = {
    key: PACK / f"{stem}_functional_quest_objects_v2.png"
    for key, stem in {
        "mind": "mind_spark",
        "heart": "heart_melody",
        "creator": "creators_light",
    }.items()
}

ENTITY_IMAGES = {
    key: PACK / f"{stem}_entities_combat_blueprint_v1.png"
    for key, stem in {
        "mind": "mind_spark",
        "heart": "heart_melody",
        "creator": "creators_light",
    }.items()
}

PLAYER_IMAGE = PACK / "shared_player_character_gear_blueprint_v1.png"
MILO_IMAGE = PACK / "shared_mayor_milo_continuity_blueprint_v1.png"
GUARDIAN_IMAGE = PACK / "unified_female_guardian_angel_blueprint_v3_lighter_skin.png"
TRAIN_IMAGE = PACK / "shared_crown_train_monorail_blueprint_v2.png"


# compact_reference_guide preset, with one named ARTÉA brand override per world.
FONT = "Calibri"
INK = RGBColor(24, 42, 54)
MIDNIGHT = RGBColor(20, 51, 67)
MUTED = RGBColor(92, 111, 121)
WHITE = RGBColor(255, 255, 255)
PALE = RGBColor(246, 249, 251)
GOLD = RGBColor(181, 130, 14)
VIOLET = RGBColor(116, 88, 190)
GRID = "B8D9DF"

PALETTES = {
    "mind": {
        "accent": RGBColor(0, 112, 135),
        "accent2": RGBColor(116, 88, 190),
        "fill": "E8F7FA",
        "line": "8FD6E1",
    },
    "heart": {
        "accent": RGBColor(52, 126, 91),
        "accent2": RGBColor(190, 92, 113),
        "fill": "ECF7EF",
        "line": "A7D2B4",
    },
    "creator": {
        "accent": RGBColor(105, 77, 171),
        "accent2": RGBColor(181, 130, 14),
        "fill": "F1EDFA",
        "line": "C7B8E8",
    },
}


WORLD_PLAN = {
    "mind": {
        "level_band": "Levels 1–5",
        "treasure": "Star of Wisdom",
        "reward": "Wisdom Blade",
        "next": "Heart Melody World Gate",
        "opening": (
            "The player begins in the town and meets Mayor Milo. A strange Blight is spreading from the Art Castle. "
            "It covers living things with dark shells and turns broken magic and machines into monsters. Milo asks for help "
            "because the player’s crystal sword can break the shell without hurting the life inside. He leads the player to the Art Castle."
        ),
        "journey": [
            (
                "1. Town, Art Castle and the first World Gate",
                "Milo shows the player the Gallery, three World Gates and the parked Crown Train. He explains that the train is only for later travel to completed worlds. A violet light opens the Mind Spark World Gate. The player walks through it while Milo explains that the Star of Wisdom is missing and the Thought Storm is covering the forest.",
            ),
            (
                "2. Quest One — Wake the Living Network",
                "The player follows dark server trees and glowing roots. They defeat Static Mites and Glitch Sprouts, wake two Checkpoint Server Roots and collect the first two Thought Sparks. The forest starts to show a safe cyan route.",
            ),
            (
                "3. Quest Two — Read the Broken Pattern",
                "At the Evidence Scanner, the player separates one fear from one fact. They connect three large nodes on the Memory Constellation Board and place evidence in the Logic Gate. The Mother Guardian gives a short hint when asked, but she never answers for the player.",
            ),
            (
                "4. Quest Three — Build the Hope Path",
                "The player turns the Perspective Lens, makes the Truth Bridge solid and defeats a Root Stalker and Blight Sentinel. Each clear choice changes the route instead of grading the player. The final path leads to the Thought Storm Arena.",
            ),
            (
                "5. Quest Four — Free the Thought Storm Warden",
                "The player dodges wide storm lines, breaks three dark anchors and attacks the open crystal core. When the core reaches zero health, combat stops. The player places the final Spark in the Calm Rain Basin. The storm becomes gentle rain instead of being destroyed.",
            ),
            (
                "6. Reward and next step",
                "The Oldest Tree wakes and reveals the Star of Wisdom. The player receives the Wisdom Blade. Mind Spark Station becomes available for optional travel, but the story returns through the World Gate. In the Art Castle, the Star opens the Heart Melody World Gate.",
            ),
        ],
        "quests": [
            ("1", "Wake the Living Network", "Wake two server roots; collect two Sparks.", "Mites and Sprouts", "12–14 min", "75 XP + safe route"),
            ("2", "Read the Broken Pattern", "Scan FACT/FEAR; connect three memory nodes; open the Logic Gate.", "Wisps", "12–14 min", "100 XP + truth route"),
            ("3", "Build the Hope Path", "Turn the Lens; form the bridge; clear the elite guard.", "Stalker and Sentinel", "12–15 min", "125 XP + boss route"),
            ("4", "Free the Warden", "Break three anchors; damage the core; place the last Spark.", "Boss + small adds", "17–23 min", "200 XP + Star + Blade"),
        ],
        "zones": [
            ("1", "World Gate Landing", "Briefing, first checkpoint and safe combat reminder."),
            ("2", "Living Network Forest", "Server roots, first Sparks and small enemies."),
            ("3", "Constellation Court", "Evidence, memory pattern and Logic Gate."),
            ("4", "Hope Path Ridge", "Perspective Lens, Truth Bridge and elite fight."),
            ("5", "Thought Storm Arena", "Three boss anchors, open core and Calm Rain Basin."),
            ("6", "Oldest Tree Sanctuary", "Star, Wisdom Blade, identity reflection and return gate."),
        ],
        "boss": [
            ("1 — Slow", "Dodge storm lines and clear small enemies.", "The first anchor opens for a long safe hit window."),
            ("2 — Break", "Strike three anchors after their clear pulse.", "The dark shell falls away and the core appears."),
            ("3 — Free", "Damage the core, then place the final Spark.", "Combat ends and the storm becomes gentle rain."),
        ],
        "identity_moments": [
            ("MS_ID_01", "Town reply to Milo", "E / I"),
            ("MS_ID_02", "First route exploration", "S / N"),
            ("MS_ID_03", "Evidence choice", "T / F"),
            ("MS_ID_04", "Puzzle order", "J / P"),
            ("MS_ID_05", "Ask for help or try alone", "E / I"),
            ("MS_ID_06", "Pattern detail or big picture", "S / N"),
            ("MS_ID_07", "Boss safe-path choice", "T / F"),
            ("MS_ID_08", "Reflection order", "J / P"),
        ],
    },
    "heart": {
        "level_band": "Levels 5–9",
        "treasure": "Harmony Jewel",
        "reward": "Harmony Shield",
        "next": "Creator’s Light World Gate",
        "opening": (
            "The player enters Heart Melody through the World Gate, not by train. The valley is beautiful but silent. "
            "Mayor Milo explains that the Silence Blight has trapped the valley’s feelings and sealed the Harmony Jewel inside the last note. "
            "He asks the player to help each feeling speak safely, then free the Conductor under the Blight shell."
        ),
        "journey": [
            (
                "1. World Gate arrival — the silent valley",
                "The player walks from the Heart World Gate into the Quiet Meadow. The nearby station is dark because Heart Melody is not complete. Milo explains the sound icons, and the Mother Guardian says that every feeling may speak without being judged.",
            ),
            (
                "2. Quest One — Wake the Feeling Garden",
                "The player plants three Feeling Seeds and repeats a short three-beat pattern on Echo Drum Flowers. Echo Moths and Pulse Slimes appear from the Silence Blight. The player clears their shells, and the first music layer returns.",
            ),
            (
                "3. Quest Two — Restore the River Song",
                "The player turns three Water Organ valves, frees Hush Vines and rings the Rain Boat bell. The boat waits at every stop, so there is no jump timing. Sad water becomes a safe moving path and brings the player to the Bell Grove.",
            ),
            (
                "4. Quest Three — Build the Heart Song",
                "The player restores three bridge chimes, reads the Fear Warning Bells and activates a Peace Flower checkpoint. They defeat Rhythm Golems and a Dissonance Shell. The notes join into one Heart Song and open the Harmony Stage.",
            ),
            (
                "5. Quest Four — Free the Silent Conductor",
                "The player dodges wide music waves, strikes three Beat Anchors during broad pulses and attacks the exposed harmony core. At zero health, the player places the full song on the altar. The Conductor is freed; no feeling is called an enemy.",
            ),
            (
                "6. Reward and next step",
                "The Harmony Jewel appears and the player receives the Harmony Shield. Heart Melody Station becomes an optional destination. The player returns through the World Gate, and the Jewel opens the Creator’s Light World Gate.",
            ),
        ],
        "quests": [
            ("1", "Wake the Feeling Garden", "Plant three Seeds; repeat one three-beat pattern.", "Moths and Slimes", "12–14 min", "80 XP + music layer"),
            ("2", "Restore the River Song", "Tune three valves; free the vines; call the Rain Boat.", "Hush Vines", "12–14 min", "105 XP + river route"),
            ("3", "Build the Heart Song", "Restore three chimes; read bells; wake a Peace Flower.", "Golems and Shell", "12–15 min", "130 XP + boss stage"),
            ("4", "Free the Conductor", "Open three Beat Anchors; damage the core; place the full song.", "Boss + small adds", "17–23 min", "205 XP + Jewel + Shield"),
        ],
        "zones": [
            ("1", "Heart World Gate / Quiet Meadow", "Briefing, sound guide and first safe checkpoint."),
            ("2", "Feeling Garden", "Seeds, Drum Flowers and first enemy groups."),
            ("3", "Waterfall Organ River", "Valve puzzle, Hush Vines and waiting Rain Boat."),
            ("4", "Bell Grove / Peace Garden", "Route reading, chimes, checkpoint and elite fight."),
            ("5", "Harmony Stage", "Three Beat Anchors and Silent Conductor boss."),
            ("6", "Harmony Jewel Sanctuary", "Jewel, Shield, identity reflection and return gate."),
        ],
        "boss": [
            ("1 — Listen", "Dodge slow sound waves and clear one add group.", "The first Beat Anchor opens on a wide pulse."),
            ("2 — Join", "Strike three Beat Anchors in any order.", "The Conductor’s dark shell opens."),
            ("3 — Free", "Damage the core, then place the complete song.", "The music returns and the Conductor is restored."),
        ],
        "identity_moments": [
            ("HM_ID_01", "Greeting in the Quiet Meadow", "E / I"),
            ("HM_ID_02", "Sound or place detail", "S / N"),
            ("HM_ID_03", "Feeling support choice", "T / F"),
            ("HM_ID_04", "Rhythm order", "J / P"),
            ("HM_ID_05", "Play with help or alone", "E / I"),
            ("HM_ID_06", "Note detail or whole song", "S / N"),
            ("HM_ID_07", "Boss anchor choice", "T / F"),
            ("HM_ID_08", "Reflection order", "J / P"),
        ],
    },
    "creator": {
        "level_band": "Levels 9–13",
        "treasure": "Creator’s Light",
        "reward": "Creator Star skill",
        "next": "Art Castle identity finale",
        "opening": (
            "The player enters Creator’s Light through the World Gate, not by train. The kingdom looks unfinished and almost colourless. "
            "Mayor Milo explains that the Perfect Blank has trapped Creator’s Light by telling every idea that it is not ready. "
            "He asks the player to make small useful things, protect them with the sword and prove that an unfinished idea can still begin."
        ),
        "journey": [
            (
                "1. World Gate arrival — a world waiting for a mark",
                "The player walks into a white entry court with empty frames, glass seeds and silver pipes. The station is dark until the world is complete. The Mother Guardian gives the Creation Frame and explains that all three starter choices work.",
            ),
            (
                "2. Quest One — Make the First Mark",
                "The player chooses one large starter shape and mixes two colour stones. They place a simple result in the first frame while fighting Ink Sprites and Smudge Hoppers. The game does not score the art or ask for freehand drawing.",
            ),
            (
                "3. Quest Two — Build the Safe Way",
                "The player places three chunky stamps, completes three outline points on the Bridge Sketch Easel and chooses a Dream Door look. Sketch Beetles attack the new path, but every door choice opens the same safe route.",
            ),
            (
                "4. Quest Three — Wake the Living Studio",
                "The player charges a Glass Seed, turns Silver Pipe pieces in fixed steps and repairs one broken lane with an Eraser Patch. Eraser Wisps and a Blank Sentinel guard the studio. Colour, plants and light return together.",
            ),
            (
                "5. Quest Four — Free Creator’s Light",
                "The player seals three erase-wave cracks, activates three colour anchors and attacks the open core of the Perfect Blank. When the core reaches zero health, the player places an unfinished picture. The world accepts it without a quality score.",
            ),
            (
                "6. Reward and finale",
                "Creator’s Light appears and the player receives the Creator Star skill. Creator Station becomes an optional destination. The player returns through the World Gate. Wisdom, Harmony and Creativity open the Art Castle identity finale.",
            ),
        ],
        "quests": [
            ("1", "Make the First Mark", "Choose a shape; mix two colour stones.", "Sprites and Hoppers", "12–14 min", "85 XP + first colour"),
            ("2", "Build the Safe Way", "Place three stamps; build a bridge; choose a Dream Door.", "Sketch Beetles", "12–14 min", "110 XP + studio route"),
            ("3", "Wake the Living Studio", "Wake a Glass Seed; route pipe light; repair one lane.", "Wisps and Sentinel", "12–15 min", "135 XP + boss route"),
            ("4", "Free Creator’s Light", "Seal three cracks; activate anchors; place an unfinished idea.", "Boss + small adds", "17–23 min", "210 XP + Light + Star"),
        ],
        "zones": [
            ("1", "Creator World Gate / Entry Frame", "Briefing, Creation Frame and first checkpoint."),
            ("2", "First Mark Court", "Starter shape, colour bowl and small enemy fights."),
            ("3", "Bridge and Dream Door Walk", "Stamp table, bridge easel and door choice."),
            ("4", "Living Studio", "Glass Seed, Silver Pipes, patch repair and elite fight."),
            ("5", "Perfect Blank Arena", "Crack seals, colour anchors and open boss core."),
            ("6", "Creator Star Sanctuary", "Light, Star skill, identity reflection and return gate."),
        ],
        "boss": [
            ("1 — Open", "Seal one erase lane and dodge the slow wave.", "A safe creation lane reaches the first anchor."),
            ("2 — Colour", "Activate three anchors and damage the cracked shell.", "The blank armour breaks and the core appears."),
            ("3 — Begin", "Damage the core, then place an unfinished picture.", "Creator’s Light returns without grading the picture."),
        ],
        "identity_moments": [
            ("CL_ID_01", "Choose how to start", "E / I"),
            ("CL_ID_02", "Object detail or new idea", "S / N"),
            ("CL_ID_03", "Repair reason", "T / F"),
            ("CL_ID_04", "Build order", "J / P"),
            ("CL_ID_05", "Share or work quietly", "E / I"),
            ("CL_ID_06", "Recipe or possibility", "S / N"),
            ("CL_ID_07", "Boss opening choice", "T / F"),
            ("CL_ID_08", "Final reflection order", "J / P"),
        ],
    },
}


COMBAT = {
    "mind": [
        ("Static Mite", "Small circuit insect; short lunge, then long pause.", "25", "10", "CharacterBody3D + NavigationAgent3D + capsule + Timer"),
        ("Glitch Sprout", "Rooted crystal plant; clear seed-bolt line.", "50", "15", "Node3D + projectile Marker3D + Hurtbox Area3D + Timer"),
        ("Circuit Wisp", "Floating orb; slow bolt can be blocked.", "50", "20", "CharacterBody3D + sphere collision + projectile scene"),
        ("Root Stalker", "Low charge; rear crystal is the weak point.", "75", "30", "CharacterBody3D + RayCast3D + rear Hurtbox"),
        ("Blight Sentinel", "Slow elite; front shield and open cyan chest.", "150", "60", "CharacterBody3D + shield state + chest Hurtbox"),
        ("Thought Storm Warden", "Three anchors, open crystal core and calm-rain end state.", "300", "150", "BossController + phase enum + anchors + core + arena signals"),
    ],
    "heart": [
        ("Echo Moth", "Petal-wing hover, sound pulse, one dash and pause.", "40", "12", "CharacterBody3D + sphere + height spring + Timer"),
        ("Pulse Slime", "Small round creature; bounces on one shown beat.", "50", "15", "CharacterBody3D + jump Tween + landing Area3D"),
        ("Hush Vine", "Rooted grab; flower core opens after the attack.", "65", "18", "Node3D + ground telegraph + core Hurtbox"),
        ("Rhythm Golem", "Slow drum-stone stomp and long recovery.", "100", "30", "CharacterBody3D + NavigationAgent3D + slam Area3D"),
        ("Dissonance Shell", "Round elite; shell opens after a missed shockwave.", "150", "55", "CharacterBody3D + shell state + shockwave Area3D"),
        ("Silent Conductor", "Armoured conductor; wide pulse, Beat Anchors and harmony core.", "320", "160", "BossController + wave Area3D + anchors + core Hurtbox"),
    ],
    "creator": [
        ("Ink Sprite", "Small folded drop; short dash and long pause.", "50", "15", "CharacterBody3D + NavigationAgent3D + capsule + Timer"),
        ("Smudge Hopper", "Jumps to a marked circle, splashes, then rests.", "75", "20", "CharacterBody3D + jump Tween + decal Area3D"),
        ("Sketch Beetle", "Draws a straight warning line, then charges.", "90", "25", "CharacterBody3D + RayCast3D + line telegraph"),
        ("Eraser Wisp", "Floating orb; slow erase bolt and open recovery.", "110", "35", "CharacterBody3D + projectile scene + Timer"),
        ("Blank Sentinel", "Paper guard; shield walk, beam and open weak frame.", "175", "60", "CharacterBody3D + beam Area3D + shield state"),
        ("Perfect Blank", "Blank shell, three colour anchors, erase lanes and bright core.", "350", "170", "BossController + shell/core Hurtboxes + arena signals"),
    ],
}


IDENTITIES = [
    ("ENFJ", "The Guiding Light"),
    ("INFJ", "The Quiet Visionary"),
    ("ENFP", "The Joyful Creator"),
    ("INFP", "The Gentle Peacemaker"),
    ("ENTJ", "The Bold Architect"),
    ("INTJ", "The Wise Strategist"),
    ("ENTP", "The Bright Spark"),
    ("INTP", "The Deep Thinker"),
    ("ESFJ", "The Warm Guardian"),
    ("ISFJ", "The Faithful Shield"),
    ("ESFP", "The Radiant Star"),
    ("ISFP", "The Silent Artist"),
    ("ESTJ", "The Steadfast Builder"),
    ("ISTJ", "The Loyal Keeper"),
    ("ESTP", "The Fearless Explorer"),
    ("ISTP", "The Calm Craftsman"),
]


def rgb_hex(color: RGBColor) -> str:
    return str(color)


def set_run(run, *, size=None, bold=None, italic=None, color=None, font=FONT):
    run.font.name = font
    run._element.get_or_add_rPr().rFonts.set(qn("w:ascii"), font)
    run._element.get_or_add_rPr().rFonts.set(qn("w:hAnsi"), font)
    if size is not None:
        run.font.size = Pt(size)
    if bold is not None:
        run.bold = bold
    if italic is not None:
        run.italic = italic
    if color is not None:
        run.font.color.rgb = color


def set_cell_margins(cell, top=80, start=120, bottom=80, end=120):
    tc_pr = cell._tc.get_or_add_tcPr()
    tc_mar = tc_pr.first_child_found_in("w:tcMar")
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for name, value in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        node = tc_mar.find(qn(f"w:{name}"))
        if node is None:
            node = OxmlElement(f"w:{name}")
            tc_mar.append(node)
        node.set(qn("w:w"), str(value))
        node.set(qn("w:type"), "dxa")


def shade_cell(cell, fill: str):
    tc_pr = cell._tc.get_or_add_tcPr()
    node = tc_pr.find(qn("w:shd"))
    if node is None:
        node = OxmlElement("w:shd")
        tc_pr.append(node)
    node.set(qn("w:fill"), fill)


def set_table_borders(table, color=GRID, size=6):
    tbl_pr = table._tbl.tblPr
    borders = tbl_pr.find(qn("w:tblBorders"))
    if borders is None:
        borders = OxmlElement("w:tblBorders")
        tbl_pr.append(borders)
    for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
        item = borders.find(qn(f"w:{edge}"))
        if item is None:
            item = OxmlElement(f"w:{edge}")
            borders.append(item)
        item.set(qn("w:val"), "single")
        item.set(qn("w:sz"), str(size))
        item.set(qn("w:color"), color)


def set_table_geometry(table, widths):
    dxa = [int(width * 1440) for width in widths]
    if sum(dxa) != 9360:
        dxa[-1] += 9360 - sum(dxa)
    tbl_pr = table._tbl.tblPr
    layout = tbl_pr.find(qn("w:tblLayout"))
    if layout is None:
        layout = OxmlElement("w:tblLayout")
        tbl_pr.append(layout)
    layout.set(qn("w:type"), "fixed")
    tbl_w = tbl_pr.find(qn("w:tblW"))
    if tbl_w is None:
        tbl_w = OxmlElement("w:tblW")
        tbl_pr.append(tbl_w)
    tbl_w.set(qn("w:w"), "9360")
    tbl_w.set(qn("w:type"), "dxa")
    tbl_ind = tbl_pr.find(qn("w:tblInd"))
    if tbl_ind is None:
        tbl_ind = OxmlElement("w:tblInd")
        tbl_pr.append(tbl_ind)
    tbl_ind.set(qn("w:w"), "120")
    tbl_ind.set(qn("w:type"), "dxa")
    grid = table._tbl.tblGrid
    for child in list(grid):
        grid.remove(child)
    for width in dxa:
        col = OxmlElement("w:gridCol")
        col.set(qn("w:w"), str(width))
        grid.append(col)
    for row in table.rows:
        for index, cell in enumerate(row.cells):
            cell.width = Emu(int(dxa[index] * 635))
            tc_w = cell._tc.get_or_add_tcPr().find(qn("w:tcW"))
            if tc_w is None:
                tc_w = OxmlElement("w:tcW")
                cell._tc.get_or_add_tcPr().append(tc_w)
            tc_w.set(qn("w:w"), str(dxa[index]))
            tc_w.set(qn("w:type"), "dxa")
            set_cell_margins(cell)


def prevent_row_split(row):
    tr_pr = row._tr.get_or_add_trPr()
    if tr_pr.find(qn("w:cantSplit")) is None:
        tr_pr.append(OxmlElement("w:cantSplit"))


def repeat_header(row):
    tr_pr = row._tr.get_or_add_trPr()
    if tr_pr.find(qn("w:tblHeader")) is None:
        header = OxmlElement("w:tblHeader")
        header.set(qn("w:val"), "true")
        tr_pr.append(header)


def next_id(elements, attr):
    values = [int(el.get(qn(attr))) for el in elements if el.get(qn(attr)) is not None]
    return max(values, default=0) + 1


def make_numbering(doc, num_fmt, lvl_text):
    numbering = doc.part.numbering_part.element
    abstract_id = next_id(numbering.findall(qn("w:abstractNum")), "w:abstractNumId")
    num_id = next_id(numbering.findall(qn("w:num")), "w:numId")
    abstract = OxmlElement("w:abstractNum")
    abstract.set(qn("w:abstractNumId"), str(abstract_id))
    multi = OxmlElement("w:multiLevelType")
    multi.set(qn("w:val"), "singleLevel")
    abstract.append(multi)
    lvl = OxmlElement("w:lvl")
    lvl.set(qn("w:ilvl"), "0")
    start = OxmlElement("w:start")
    start.set(qn("w:val"), "1")
    lvl.append(start)
    fmt = OxmlElement("w:numFmt")
    fmt.set(qn("w:val"), num_fmt)
    lvl.append(fmt)
    text = OxmlElement("w:lvlText")
    text.set(qn("w:val"), lvl_text)
    lvl.append(text)
    jc = OxmlElement("w:lvlJc")
    jc.set(qn("w:val"), "left")
    lvl.append(jc)
    p_pr = OxmlElement("w:pPr")
    tabs = OxmlElement("w:tabs")
    tab = OxmlElement("w:tab")
    tab.set(qn("w:val"), "num")
    tab.set(qn("w:pos"), "540")
    tabs.append(tab)
    p_pr.append(tabs)
    ind = OxmlElement("w:ind")
    ind.set(qn("w:left"), "540")
    ind.set(qn("w:hanging"), "270")
    p_pr.append(ind)
    spacing = OxmlElement("w:spacing")
    spacing.set(qn("w:after"), "80")
    spacing.set(qn("w:line"), "300")
    spacing.set(qn("w:lineRule"), "auto")
    p_pr.append(spacing)
    lvl.append(p_pr)
    abstract.append(lvl)
    numbering.append(abstract)
    num = OxmlElement("w:num")
    num.set(qn("w:numId"), str(num_id))
    abstract_ref = OxmlElement("w:abstractNumId")
    abstract_ref.set(qn("w:val"), str(abstract_id))
    num.append(abstract_ref)
    numbering.append(num)
    return num_id


def apply_num(paragraph, num_id):
    p_pr = paragraph._p.get_or_add_pPr()
    num_pr = p_pr.get_or_add_numPr()
    num_pr.get_or_add_ilvl().val = 0
    num_pr.get_or_add_numId().val = num_id


def add_page_field(paragraph):
    run = paragraph.add_run()
    begin = OxmlElement("w:fldChar")
    begin.set(qn("w:fldCharType"), "begin")
    instruction = OxmlElement("w:instrText")
    instruction.set(qn("xml:space"), "preserve")
    instruction.text = " PAGE "
    end = OxmlElement("w:fldChar")
    end.set(qn("w:fldCharType"), "end")
    run._r.extend([begin, instruction, end])
    set_run(run, size=9, color=MUTED)


def configure_document(doc, key):
    palette = PALETTES[key]
    section = doc.sections[0]
    section.page_width = Inches(8.5)
    section.page_height = Inches(11)
    section.top_margin = Inches(1.0)
    section.bottom_margin = Inches(1.0)
    section.left_margin = Inches(1.0)
    section.right_margin = Inches(1.0)
    section.header_distance = Inches(0.492)
    section.footer_distance = Inches(0.492)

    styles = doc.styles
    normal = styles["Normal"]
    normal.font.name = FONT
    normal._element.rPr.rFonts.set(qn("w:ascii"), FONT)
    normal._element.rPr.rFonts.set(qn("w:hAnsi"), FONT)
    normal.font.size = Pt(11)
    normal.font.color.rgb = INK
    normal.paragraph_format.space_before = Pt(0)
    normal.paragraph_format.space_after = Pt(6)
    normal.paragraph_format.line_spacing = 1.25

    tokens = {
        "Title": (30, MIDNIGHT, 0, 8),  # named editorial-cover override
        "Subtitle": (14, palette["accent"], 0, 12),
        "Heading 1": (16, palette["accent"], 18, 10),
        "Heading 2": (13, palette["accent"], 14, 7),
        "Heading 3": (12, MIDNIGHT, 10, 5),
        "Caption": (9, MUTED, 0, 6),
    }
    for name, (size, color, before, after) in tokens.items():
        style = styles[name]
        style.font.name = FONT
        style._element.rPr.rFonts.set(qn("w:ascii"), FONT)
        style._element.rPr.rFonts.set(qn("w:hAnsi"), FONT)
        style.font.size = Pt(size)
        style.font.color.rgb = color
        style.paragraph_format.space_before = Pt(before)
        style.paragraph_format.space_after = Pt(after)
        style.paragraph_format.keep_with_next = True
        if name in ("Title", "Heading 1", "Heading 2", "Heading 3"):
            style.font.bold = True

    if "Table Citation" not in styles:
        styles.add_style("Table Citation", 1)
    citation = styles["Table Citation"]
    citation.font.name = FONT
    citation.font.size = Pt(9)
    citation.font.color.rgb = MUTED
    citation.paragraph_format.space_before = Pt(4)
    citation.paragraph_format.space_after = Pt(4)

    bullet_id = make_numbering(doc, "bullet", "•")
    number_id = make_numbering(doc, "decimal", "%1.")

    header = section.header.paragraphs[0]
    header.alignment = WD_ALIGN_PARAGRAPH.LEFT
    header.paragraph_format.space_after = Pt(0)
    run = header.add_run("ARTÉA  /  INTEGRATED WORLD DEVELOPER GUIDE")
    set_run(run, size=8.5, bold=True, color=MUTED)
    footer = section.footer.paragraphs[0]
    footer.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    footer.paragraph_format.space_after = Pt(0)
    run = footer.add_run(f"{WORLD_DATA[key]['name']}  •  ")
    set_run(run, size=8.5, bold=True, color=MUTED)
    add_page_field(footer)
    return bullet_id, number_id


def add_bullet(doc, text, bullet_id, *, bold_lead=None):
    paragraph = doc.add_paragraph()
    apply_num(paragraph, bullet_id)
    if bold_lead and text.startswith(bold_lead):
        lead = paragraph.add_run(bold_lead)
        set_run(lead, bold=True, color=MIDNIGHT)
        rest = paragraph.add_run(text[len(bold_lead):])
        set_run(rest, color=INK)
    else:
        run = paragraph.add_run(text)
        set_run(run, color=INK)
    return paragraph


def add_numbered(doc, text, number_id):
    paragraph = doc.add_paragraph()
    apply_num(paragraph, number_id)
    run = paragraph.add_run(text)
    set_run(run, color=INK)
    return paragraph


def add_callout(doc, key, label, text, *, gold=False):
    paragraph = doc.add_paragraph()
    paragraph.paragraph_format.space_before = Pt(6)
    paragraph.paragraph_format.space_after = Pt(8)
    paragraph.paragraph_format.left_indent = Inches(0.12)
    p_pr = paragraph._p.get_or_add_pPr()
    shading = OxmlElement("w:shd")
    shading.set(qn("w:fill"), "FFF6D8" if gold else PALETTES[key]["fill"])
    p_pr.append(shading)
    borders = OxmlElement("w:pBdr")
    left = OxmlElement("w:left")
    left.set(qn("w:val"), "single")
    left.set(qn("w:sz"), "18")
    left.set(qn("w:space"), "8")
    left.set(qn("w:color"), "B5820E" if gold else PALETTES[key]["line"])
    borders.append(left)
    p_pr.append(borders)
    run = paragraph.add_run(f"{label}  ")
    set_run(run, size=10.5, bold=True, color=GOLD if gold else PALETTES[key]["accent"])
    run = paragraph.add_run(text)
    set_run(run, size=10.5, color=INK)
    return paragraph


def picture_with_alt(doc, path, width, alt):
    paragraph = doc.add_paragraph()
    paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    paragraph.paragraph_format.space_before = Pt(4)
    paragraph.paragraph_format.space_after = Pt(5)
    inline = paragraph.add_run().add_picture(str(path), width=width)
    inline._inline.docPr.set("descr", alt)
    inline._inline.docPr.set("title", alt)
    return paragraph


def picture_cropped(doc, path, width_inches, alt, crop_top, crop_bottom):
    paragraph = doc.add_paragraph()
    paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    paragraph.paragraph_format.space_before = Pt(4)
    paragraph.paragraph_format.space_after = Pt(5)
    inline = paragraph.add_run().add_picture(str(path), width=Inches(width_inches))
    blip_fill = inline._inline.graphic.graphicData.pic.blipFill
    source_rect = blip_fill.find(qn("a:srcRect"))
    if source_rect is None:
        source_rect = OxmlElement("a:srcRect")
        blip_fill.insert(1, source_rect)
    source_rect.set("t", str(crop_top))
    source_rect.set("b", str(crop_bottom))
    with Image.open(path) as image:
        source_width, source_height = image.size
    visible = 1 - (crop_top + crop_bottom) / 100000
    height_inches = width_inches * source_height * visible / source_width
    inline.height = Inches(height_inches)
    inline._inline.docPr.set("descr", alt)
    inline._inline.docPr.set("title", alt)
    return paragraph


def add_caption(doc, text):
    paragraph = doc.add_paragraph(style="Caption")
    paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    paragraph.paragraph_format.keep_with_next = False
    run = paragraph.add_run(text)
    set_run(run, size=9, italic=True, color=MUTED)
    return paragraph


def add_section(doc, key, part, title, summary):
    paragraph = doc.add_paragraph()
    paragraph.paragraph_format.page_break_before = True
    paragraph.paragraph_format.space_after = Pt(3)
    run = paragraph.add_run(part.upper())
    set_run(run, size=9.5, bold=True, color=PALETTES[key]["accent2"])
    heading = doc.add_heading(title, level=1)
    heading.paragraph_format.space_before = Pt(0)
    paragraph = doc.add_paragraph(summary)
    paragraph.paragraph_format.space_after = Pt(12)
    for run in paragraph.runs:
        set_run(run, size=12, italic=True, color=MUTED)


def add_matrix(doc, key, headers, rows, widths, *, font_size=8.3):
    table = doc.add_table(rows=1, cols=len(headers))
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    set_table_geometry(table, widths)
    set_table_borders(table)
    repeat_header(table.rows[0])
    for index, header in enumerate(headers):
        cell = table.rows[0].cells[index]
        shade_cell(cell, PALETTES[key]["fill"])
        cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
        paragraph = cell.paragraphs[0]
        paragraph.paragraph_format.space_before = Pt(1)
        paragraph.paragraph_format.space_after = Pt(1)
        paragraph.paragraph_format.line_spacing = 1.05
        run = paragraph.add_run(str(header))
        set_run(run, size=max(font_size, 8.2), bold=True, color=MIDNIGHT)
    for row_index, row in enumerate(rows):
        cells = table.add_row().cells
        prevent_row_split(table.rows[-1])
        if row_index % 2:
            for cell in cells:
                shade_cell(cell, "F7FAFB")
        for index, value in enumerate(row):
            cell = cells[index]
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.TOP
            paragraph = cell.paragraphs[0]
            paragraph.paragraph_format.space_before = Pt(1)
            paragraph.paragraph_format.space_after = Pt(1)
            paragraph.paragraph_format.line_spacing = 1.05
            run = paragraph.add_run(str(value))
            set_run(run, size=font_size, bold=(index == 0), color=MIDNIGHT if index == 0 else INK)
    return table


def add_hyperlink(paragraph, text, url):
    relationship = paragraph.part.relate_to(url, RT.HYPERLINK, is_external=True)
    hyperlink = OxmlElement("w:hyperlink")
    hyperlink.set(qn("r:id"), relationship)
    run = OxmlElement("w:r")
    r_pr = OxmlElement("w:rPr")
    color = OxmlElement("w:color")
    color.set(qn("w:val"), "0563C1")
    underline = OxmlElement("w:u")
    underline.set(qn("w:val"), "single")
    r_pr.extend([color, underline])
    run.append(r_pr)
    value = OxmlElement("w:t")
    value.text = text
    run.append(value)
    hyperlink.append(run)
    paragraph._p.append(hyperlink)


def build_cover(doc, key):
    data = WORLD_DATA[key]
    plan = WORLD_PLAN[key]
    paragraph = doc.add_paragraph()
    paragraph.paragraph_format.space_before = Pt(4)
    paragraph.paragraph_format.space_after = Pt(2)
    run = paragraph.add_run(f"ARTÉA  •  {data['number']}  •  CLEAN INTEGRATED EDITION")
    set_run(run, size=10, bold=True, color=PALETTES[key]["accent2"])
    paragraph = doc.add_paragraph(style="Title")
    run = paragraph.add_run(data["name"])
    set_run(run, size=30, bold=True, color=MIDNIGHT)
    paragraph = doc.add_paragraph(style="Subtitle")
    run = paragraph.add_run("Story Journey, Quests, Objects, Combat, Characters, Identity System & Godot Build Guide")
    set_run(run, size=13.5, color=PALETTES[key]["accent"])
    picture_with_alt(
        doc,
        OVERVIEWS[key],
        Inches(5.9),
        f"Actual Art Castle Galaxy overview reference for {data['name'].title()}.",
    )
    add_caption(doc, "Actual Art Castle Galaxy world reference. New objects must keep this low-poly, readable game style.")
    add_callout(doc, key, "WORLD IDENTITY", data["identity"])
    paragraph = doc.add_paragraph()
    paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    paragraph.paragraph_format.space_after = Pt(0)
    run = paragraph.add_run(
        f"Version 3.1  •  {date(2026, 8, 14).strftime('%d %B %Y')}  •  {plan['level_band']}  •  55–70 minutes"
    )
    set_run(run, size=9, color=MUTED)


def add_orientation(doc, key, bullet_id):
    add_section(
        doc,
        key,
        "Document orientation",
        "How to use this guide",
        "This is one clean source for the current world. It replaces the older guide-plus-addendum layout.",
    )
    add_callout(
        doc,
        key,
        "LATEST-VERSION RULE",
        "Use the story, characters, guardian, train, objects and rules in this file. Do not combine them with earlier versions. The old repeated sections and old character samples are removed.",
        gold=True,
    )
    doc.add_heading("What this file controls", level=2)
    for item in (
        "The full 55–70 minute player journey, four quests, ten main tasks and three-stage boss.",
        "The world identity, route, functional objects, architecture, enemies and reward.",
        "One shared player outfit, one Mayor Milo outfit and one female Mother Guardian model.",
        "One shared Crown Train used only as optional travel after a world is complete.",
        "One 16-identity tracker that continues through all three worlds.",
        "Simple Godot scenes, signals, Resources and save flags that the team can build.",
    ):
        add_bullet(doc, item, bullet_id)
    doc.add_heading("Document map", level=2)
    map_rows = [
        ("1", "World identity", "Visual rules and current world image"),
        ("2", "Player journey", "Story from arrival to reward"),
        ("3", "Quest plan", "Time, tasks, six zones and bird’s-eye build map"),
        ("4", "Functional objects", "Objects that change play or story"),
        ("5", "World architecture", "Godot-ready building and dressing kit"),
        ("6", "Combat", "Five enemy types, boss and XP"),
        ("7", "Shared cast", "Player, Milo and Mother Guardian"),
        ("8", "Train", "One optional Crown Train and three station skins"),
        ("9", "Identity system", "Sixteen friendly identities and save data"),
        ("10", "Implementation", "Build order, sources and acceptance checks"),
    ]
    add_matrix(doc, key, ("Part", "Section", "Main use"), map_rows, (0.55, 1.75, 4.2), font_size=8.8)


def add_world_identity(doc, key, bullet_id):
    data = WORLD_DATA[key]
    add_section(
        doc,
        key,
        "Part 1",
        f"{data['name'].title()} identity",
        data["identity"],
    )
    doc.add_heading("Identity lock", level=2)
    add_matrix(doc, key, ("Rule", "Approved direction"), data["lock"], (1.55, 4.95), font_size=9.2)
    doc.add_heading("How the three forces work", level=2)
    force_text = {
        "mind": (
            "Technology and science lead through networks, evidence tools, gates and data light.",
            "Nature supports through server trees, living roots, rain and forest growth.",
            "Magic supports through Thought Sparks, the Star, the Guardian and truth paths.",
        ),
        "heart": (
            "Nature leads through flowers, water, vines, living instruments and round valleys.",
            "Magic supports through feeling notes, the Harmony Jewel, healing and the Guardian.",
            "Technology supports through clear pads, valve steps, route icons and simple sound systems.",
        ),
        "creator": (
            "Magic and creativity lead through frames, colour, stamps, seeds and light.",
            "Nature supports through growing plants, living colour and glass seeds.",
            "Technology supports through silver pipes, fixed sockets, safe recipes and clear controls.",
        ),
    }[key]
    for text in force_text:
        add_bullet(doc, text, bullet_id)
    doc.add_heading("Current game reference", level=2)
    doc.add_paragraph(data["runtime"])
    add_callout(
        doc,
        key,
        "STYLE TEST",
        "From a long distance, a player must know which world they are in before reading any text. Keep the approved skyline, shape language and colour balance.",
    )


def add_story(doc, key):
    data = WORLD_DATA[key]
    plan = WORLD_PLAN[key]
    add_section(
        doc,
        key,
        "Part 2",
        "The player’s journey",
        "Read this section like the player is moving through the game from the first step to the final reward.",
    )
    doc.add_heading("Why Milo asks for help", level=2)
    doc.add_paragraph(plan["opening"])
    add_callout(
        doc,
        key,
        "STORY RULE",
        "The Blight shell is the enemy. The living world, feelings, thoughts and unfinished ideas are not enemies. The sword breaks the shell and helps restore what is inside.",
        gold=True,
    )
    for heading, text in plan["journey"]:
        doc.add_heading(heading, level=2)
        doc.add_paragraph(text)
    doc.add_heading("End state", level=2)
    doc.add_paragraph(
        f"The player owns the {plan['treasure']} and {plan['reward']}. {data['name'].title()} is saved, its station is an optional completed-world destination, and the {plan['next']} is ready."
    )


def add_functional_objects(doc, key):
    data = FUNCTIONAL_OBJECTS[key]
    add_section(
        doc,
        key,
        "Part 4",
        "Functional quest and puzzle objects",
        "Every object in this section gives the player an action, clear feedback or useful story progress. None is only decoration.",
    )
    picture_with_alt(doc, FUNCTIONAL_IMAGES[key], Inches(6.5), data["alt"])
    add_caption(doc, f"{data['title']} — approved game-style object sheet.")
    add_callout(
        doc,
        key,
        "SHARED OBJECT RULE",
        "Build one QuestObjectBase scene with an interaction Area3D, prompt, current state, completion signal, save ID and optional AnimationPlayer. Each object below is a small child setup or Resource, not a new full system.",
    )
    doc.add_heading("Object implementation list", level=2)
    add_matrix(
        doc,
        key,
        ("#", "Object", "Player action", "Story result", "Godot build", "Clear feedback"),
        data["rows"],
        (0.32, 1.05, 1.08, 1.28, 1.75, 1.02),
        font_size=7.2,
    )
    doc.add_heading("Meaningful-use check", level=2)
    checks = (
        "The object is placed where its result can be seen from the interaction point.",
        "The prompt says one small action and shows progress such as 0/3 or 1/3.",
        "Success uses shape, icon, text and sound; colour is extra support.",
        "A reset or help choice is available for any sequence puzzle.",
        "Quest completion is saved before the next gate, path or reward opens.",
    )
    for check in checks:
        paragraph = doc.add_paragraph()
        paragraph.paragraph_format.left_indent = Inches(0.36)
        paragraph.paragraph_format.first_line_indent = Inches(-0.22)
        run = paragraph.add_run("☐  " + check)
        set_run(run, size=10.3, color=INK)


def add_architecture(doc, key):
    data = WORLD_DATA[key]
    add_section(
        doc,
        key,
        "Part 5",
        "World architecture and production objects",
        "Build the clear route and gameplay collision first. Add world dressing after every quest can be completed from start to finish.",
    )
    architecture_width = 4.7 if key == "creator" else 5.8
    picture_with_alt(doc, ARCHITECTURE_IMAGES[key], Inches(architecture_width), data["arch_alt"])
    add_caption(doc, f"{data['name'].title()} architecture blueprint — low-poly modules sized for the existing Art Castle Galaxy world.")
    doc.add_heading("Architecture implementation list", level=2)
    arch_rows = [(ref, name, shape, godot, decision, source) for ref, name, shape, godot, decision, source in data["arch"]]
    architecture_font = 6.9 if key == "creator" else 7.1
    add_matrix(
        doc,
        key,
        ("#", "Object", "Shape / gameplay use", "Godot build", "Plan", "Source"),
        arch_rows,
        (0.31, 1.05, 1.65, 1.75, 0.58, 1.16),
        font_size=architecture_font,
    )
    doc.add_heading("Production inventory", level=2)
    inventory_rows = list(data["inventory"])
    inventory_font = 8.0
    if key == "creator":
        inventory_rows = inventory_rows[:-2] + [
            (
                "Dressing / world states",
                "Origami bird; colour mote; crystal flower; brush lamp; pencil post; bench; sign; rock; small plant; blank, colour-returning and living-studio states",
                "Procedural props plus installed nature/house assets; keep the same collision and geometry while materials, spawned scenes, particles and light change",
            )
        ]
        inventory_font = 7.2
    add_matrix(doc, key, ("Group", "Objects included", "Production rule"), inventory_rows, (1.15, 3.05, 2.3), font_size=inventory_font)
def add_combat(doc, key, bullet_id):
    add_section(
        doc,
        key,
        "Part 6",
        "Monsters, combat, XP and boss",
        "The enemy designs use simple shapes, one shared state machine and large safe telegraphs that are possible in Godot.",
    )
    crop = {
        "mind": (33500, 23200),
        "heart": (39000, 23000),
        "creator": (37000, 17000),
    }[key]
    picture_cropped(
        doc,
        ENTITY_IMAGES[key],
        6.5,
        f"Enemy and boss panels for {WORLD_DATA[key]['name'].title()}, cropped so older character panels do not appear.",
        crop[0],
        crop[1],
    )
    add_caption(doc, "Enemy and boss reference only. The old character panels are removed; use the shared character sheets in Part 7.")
    doc.add_heading("Enemy roster", level=2)
    add_matrix(
        doc,
        key,
        ("Entity", "Look and attack", "HP", "XP", "Simple Godot recipe"),
        COMBAT[key],
        (1.15, 2.0, 0.48, 0.48, 2.39),
        font_size=7.8,
    )
    add_callout(
        doc,
        key,
        "BALANCE NOTE",
        "HP and XP are first-pass values. Test with the current sword before final tuning. Keep the same hitbox, damage and save systems across all enemies.",
    )
    doc.add_heading("Shared enemy state machine", level=2)
    for text in (
        "IDLE → NOTICE → TELEGRAPH → ATTACK → RECOVERY → IDLE.",
        "Give every normal attack at least 0.75 seconds of warning. Use CharacterBody3D, NavigationAgent3D, one capsule, one Hurtbox Area3D and one Hitbox Area3D.",
        "Use no more than four normal enemies at one time. On defeat, the dark shell dissolves and the living part is shown as calm, free or safely gone.",
    ):
        add_bullet(doc, text, bullet_id)
    doc.add_heading("Three-stage boss flow", level=2)
    add_matrix(doc, key, ("Stage", "Player action", "Result"), WORLD_PLAN[key]["boss"], (1.0, 2.7, 2.8), font_size=8.7)
    help_data = GUARDIAN_WORLD_HELP[key]
    add_callout(doc, key, "GUARDIAN BOSS LINE", help_data["boss"], gold=True)


def add_shared_cast(doc, key, bullet_id):
    add_section(
        doc,
        key,
        "Part 7",
        "Shared player, Mayor Milo and Mother Guardian",
        "These three characters keep one body, one face and one main outfit in all worlds. Only the player’s earned equipment changes.",
    )
    doc.add_heading("Player character", level=2)
    picture_with_alt(doc, PLAYER_IMAGE, Inches(6.5), "Shared orange fox player in the permanent green outfit with the simple campaign equipment unlocks.")
    add_caption(doc, "Use the current orange fox and permanent green outfit in every world.")
    for text in (
        "Keep one Player scene, one skeleton, one green outfit and the current sword animations.",
        "Attach rewards to named EquipmentSocket children; do not replace the full player model.",
        "The sword damages only Blight shells and combat targets. Puzzle objects use a separate interaction layer.",
    ):
        add_bullet(doc, text, bullet_id)
    equipment = [
        ("Start", "Base Sword", "25 damage", "Current sword, hitbox and timing."),
        ("Mind complete", "Wisdom Blade", "30 damage", "Same hitbox and timing; visual crystal upgrade only."),
        ("Heart complete", "Harmony Shield", "50% frontal damage reduction", "Hold block; no parry, stamina or shield attack."),
        ("Creator complete", "Creator Star", "20-damage straight bolt", "One projectile, 4-second cooldown, no skill tree."),
    ]
    add_matrix(doc, key, ("Unlock", "Equipment", "Effect", "Simple rule"), equipment, (1.05, 1.2, 1.35, 2.9), font_size=8.5)

    doc.add_heading("Mayor Milo", level=2)
    picture_with_alt(doc, MILO_IMAGE, Inches(6.5), "Shared elder Mayor Milo blueprint with cream-grey fur, white moustache, gold glasses and permanent navy mayor-professor coat.")
    add_caption(doc, "One elder Mayor Milo model and one navy mayor-professor outfit for all three worlds.")
    for text in (
        "Milo is a wise elder mayor and a caring father-like guide.",
        "He asks for help, explains the mission, gives short task reminders and celebrates progress.",
        "He never fights, blocks the route or solves the player’s puzzle.",
        "Godot: one CharacterBody3D or Node3D guide scene, AnimationTree, dialogue Area3D and Marker3D guide points.",
    ):
        add_bullet(doc, text, bullet_id)

    doc.add_heading("Female Mother Guardian", level=2)
    picture_with_alt(doc, GUARDIAN_IMAGE, Inches(6.5), "Approved lighter-skin female Mother Guardian with silver hair, flowers, branch halo, ivory-sage-teal-gold gown, warm heart light and three wing panels on each side.")
    add_caption(doc, "Approved current Guardian: lighter warm light-beige skin, kind eyes, silver hair and one nature-magic-technology design.")
    guardian_rules = [
        ("Role", "She welcomes, comforts, protects, restores, gives hints and reflects the player’s growth."),
        ("Body", "One mature female humanoid; warm light-beige skin; kind eyes and gentle smile."),
        ("Hair and halo", "Long silver hair with leaves and flowers; one gold branch halo."),
        ("Outfit", "One ivory, sage, teal and gold leaf-panel gown used in every world."),
        ("Wings", "Three simple rigid wing panels on each side; cyan, violet and green with gold veins."),
        ("VFX", "Warm heart light, small leaves, stars and music notes; protection dome is optional."),
        ("Combat", "She never attacks. She gives a safe line and points to the next clear action."),
        ("Godot", "One humanoid rig, 5–7 rigid gown panels, 3 wing bones per side, AnimationPlayer and GPUParticles3D."),
    ]
    add_matrix(doc, key, ("Item", "Approved rule"), guardian_rules, (1.25, 5.25), font_size=8.8)
    world_help = GUARDIAN_WORLD_HELP[key]
    doc.add_heading(f"Her work in {WORLD_DATA[key]['name'].title()}", level=3)
    for label, value in (
        ("Voice", world_help["voice"]),
        ("Puzzle", world_help["puzzle"]),
        ("Boss", world_help["boss"]),
        ("Reflection", world_help["reflection"]),
    ):
        add_bullet(doc, f"{label}: {value}", bullet_id, bold_lead=f"{label}:")


def add_train(doc, key, bullet_id):
    add_section(
        doc,
        key,
        "Part 8",
        "One shared Crown Train and simple travel rule",
        "The train is a small optional travel service. It is not the main story, and it never carries the player into the next unfinished world.",
    )
    picture_with_alt(doc, TRAIN_IMAGE, Inches(6.5), "One shared Crown Train with navy technology body, violet magic crystals, gold star light, root underframe, leaf roof and two open coaches on one centre beam.")
    add_caption(doc, "One permanent Crown Train for the full game: technology + magic + nature in one simple design.")
    train_rows = [
        ("Train scene", "One engine and two open coaches; the model never changes between worlds.", "Node3D train root + child meshes + simple seats"),
        ("Technology", "Navy chassis, cyan glass and circuit strips, gold joints.", "Shared materials and low-poly meshes"),
        ("Magic", "Violet crystals, gold star halo and soft lift light.", "MeshInstance3D + small emissive material + particles"),
        ("Nature", "Root underframe, leaf roof and small planters.", "Curve3D/root mesh + low-poly leaf children"),
        ("Rail", "One centre beam, 3.2 m wide and 1.6 m high.", "StaticBody3D beam modules; one collision box"),
        ("Movement", "Authored automatic route only; no manual driving or rail switches.", "Path3D + PathFollow3D + AnimationPlayer doors"),
        ("Menu", "Choose Art Castle or a completed world, then confirm.", "One small Control menu backed by saved destination IDs"),
        ("Story", "The next unfinished world always opens through an Art Castle World Gate.", "WorldGateController separate from train data"),
    ]
    add_matrix(doc, key, ("Part", "Approved design / rule", "Godot build"), train_rows, (1.05, 3.2, 2.25), font_size=8.2)
    doc.add_heading("Travel flow", level=2)
    for step in (
        "The player completes a world and the treasure reward is saved.",
        "That completed world is added to the Crown Train destination menu.",
        "The player may walk back through the World Gate or use the train to return to the Art Castle.",
        "Later, the player may use the train to revisit the Art Castle or any completed world.",
        "The next story world is entered through its World Gate, never through the train.",
    ):
        add_bullet(doc, step, bullet_id)
    doc.add_heading("Different station and rail skins", level=2)
    station_rows = [
        ("Mind Spark", "Circuit arch, server-tree columns and cyan node lights.", "Dark beam with cyan circuit seam."),
        ("Heart Melody", "Leaf-petal canopy, water-note columns and bell sign.", "Stone/root beam with aqua note lights."),
        ("Creator’s Light", "Asymmetric frame, pencil lamps and violet glass seed sign.", "Ivory beam with violet and gold frame marks."),
    ]
    add_matrix(doc, key, ("World", "Station visual child", "Rail visual child"), station_rows, (1.2, 3.0, 2.3), font_size=8.6)
    add_callout(
        doc,
        key,
        "DO NOT BUILD",
        "No three separate trains, no onboard quest, no manual driving, no branching rail puzzle and no train requirement for story progress.",
        gold=True,
    )


def add_identity(doc, key, bullet_id):
    add_section(
        doc,
        key,
        "Part 9",
        "Shared 16-identity tracking system",
        "The game quietly keeps small evidence across all three worlds. It gives one friendly identity only at the Art Castle finale.",
    )
    add_callout(
        doc,
        key,
        "IDENTITY SAFETY RULE",
        "Identity evidence is separate from XP, combat, treasure and quest success. There is no right answer, no bad identity and no identity result before the finale.",
        gold=True,
    )
    doc.add_heading("Four friendly choice axes", level=2)
    axes = [
        ("E / I", "Energy", "Talk and act with others / think and act quietly"),
        ("S / N", "Focus", "Notice clear details / notice patterns and possibilities"),
        ("T / F", "Decision", "Use reason and rules / use care and personal values"),
        ("J / P", "Approach", "Plan the order / explore and adapt"),
    ]
    add_matrix(doc, key, ("Axis", "Simple name", "What the game observes"), axes, (0.8, 1.2, 4.5), font_size=9.0)
    doc.add_heading(f"Eight evidence moments in {WORLD_DATA[key]['name'].title()}", level=2)
    add_matrix(doc, key, ("Save ID", "Existing game moment", "Axis"), WORLD_PLAN[key]["identity_moments"], (1.25, 4.25, 1.0), font_size=8.8)
    doc.add_heading("Sixteen friendly identity names", level=2)
    identity_rows = []
    for index in range(0, 16, 2):
        identity_rows.append((IDENTITIES[index][0], IDENTITIES[index][1], IDENTITIES[index + 1][0], IDENTITIES[index + 1][1]))
    add_matrix(doc, key, ("Code", "Friendly name", "Code", "Friendly name"), identity_rows, (0.72, 2.53, 0.72, 2.53), font_size=8.8)
    doc.add_heading("Simple save data", level=2)
    save_rows = [
        ("identity_axis_counts", "Dictionary", "Eight integer counts: E, I, S, N, T, F, J and P."),
        ("identity_evidence_ids", "PackedStringArray", "Stops the same moment from being counted twice."),
        ("identity_answer_history", "Array[Dictionary]", "Keeps moment ID, chosen side and world ID for testing."),
        ("identity_result_code", "String", "Empty until the Art Castle finale; then one four-letter code."),
        ("identity_locked", "bool", "False until the player accepts the finale result."),
        ("identity_reveal_seen", "bool", "Lets the reveal be replayed without recounting evidence."),
    ]
    add_matrix(doc, key, ("Field", "Type", "Purpose"), save_rows, (1.85, 1.45, 3.2), font_size=8.4)
    doc.add_heading("Implementation rules", level=2)
    for text in (
        "Use one autoload named PlayerIdentityTracker for all three worlds.",
        "Record only the first answer for each evidence ID unless the player starts a new save.",
        "A skipped or private reflection records no axis and never blocks the quest.",
        "Save after each evidence moment and test checkpoint restart, boss retry, World Gate return and train travel.",
        "At the finale, compare each pair, build the four-letter code and show its friendly name.",
    ):
        add_bullet(doc, text, bullet_id)


def add_implementation(doc, key, bullet_id, number_id):
    add_section(
        doc,
        key,
        "Part 10",
        "Godot implementation and handoff",
        "Build shared systems once, keep world scenes modular and test the full route before adding more decoration.",
    )
    doc.add_heading("Core shared scenes", level=2)
    shared = [
        ("player_3d.tscn", "Current fox, health, sword, block and three EquipmentSocket nodes."),
        ("mayor_milo.tscn", "One elder Milo guide scene and permanent navy outfit."),
        ("guardian_angel.tscn", "One approved female Mother Guardian used unchanged everywhere."),
        ("enemy_base.tscn", "Shared hitbox, hurtbox, navigation, telegraph, recovery, XP and dissolve."),
        ("boss_controller.gd", "INTRO, PHASE_1, TRANSITION, PHASE_2, PHASE_3, COMPLETE."),
        ("quest_object_base.tscn", "Interaction, prompt, state, save ID and completion signal."),
        ("world_gate.tscn", "Story progression between Art Castle and the current world."),
        ("crown_train.tscn", "One train with PathFollow3D and destination menu for completed worlds."),
        ("station_base.tscn", "One station collision/boarding scene with a world visual child."),
        ("PlayerIdentityTracker", "Autoload for all identity evidence and finale result."),
    ]
    add_matrix(doc, key, ("Scene / system", "Purpose"), shared, (2.0, 4.5), font_size=8.7)
    doc.add_heading("Recommended build order", level=2)
    build_order = [
        "Block out the six-zone route with StaticBody3D floors, World Gate, checkpoints and boss arena.",
        "Connect navigation, recovery volumes and save flags; test walking from start to finish.",
        "Build QuestObjectBase and the ten required story tasks with placeholder meshes.",
        "Build EnemyBase, the five enemy Resources and XP rewards; test no more than four at one time.",
        "Build the boss phases and retry checkpoint using placeholder shapes.",
        "Add the world architecture kit and keep all paths, prompts and weak points clear.",
        "Add the current player, one Milo and one approved Mother Guardian scene.",
        "Add reward equipment, the next World Gate flag and the completed-world train flag.",
        "Connect the eight identity evidence moments and test save/reload.",
        "Add final materials, particles, audio and decoration after the full route passes.",
    ]
    for item in build_order:
        add_numbered(doc, item, number_id)
    doc.add_heading("Official implementation sources", level=2)
    source_table = doc.add_table(rows=1, cols=3)
    source_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    source_table.autofit = False
    set_table_geometry(source_table, (1.55, 2.75, 2.2))
    set_table_borders(source_table)
    repeat_header(source_table.rows[0])
    for index, header in enumerate(("Source", "Link", "Use in this guide")):
        cell = source_table.rows[0].cells[index]
        shade_cell(cell, PALETTES[key]["fill"])
        run = cell.paragraphs[0].add_run(header)
        set_run(run, size=8.5, bold=True, color=MIDNIGHT)
    for row_index, (name, url, use) in enumerate(RESEARCH_LINKS):
        cells = source_table.add_row().cells
        prevent_row_split(source_table.rows[-1])
        if row_index % 2:
            for cell in cells:
                shade_cell(cell, "F7FAFB")
        run = cells[0].paragraphs[0].add_run(name)
        set_run(run, size=7.7, bold=True, color=MIDNIGHT)
        add_hyperlink(cells[1].paragraphs[0], "Open official page", url)
        run = cells[2].paragraphs[0].add_run(use)
        set_run(run, size=7.7, color=INK)
        for cell in cells:
            for paragraph in cell.paragraphs:
                paragraph.paragraph_format.space_before = Pt(1)
                paragraph.paragraph_format.space_after = Pt(1)
                paragraph.paragraph_format.line_spacing = 1.05
    doc.add_heading("Final acceptance checklist", level=2)
    checklist = [
        "The guide contains one current story and no older repeated story section.",
        "First play is 55–70 minutes with four quests and ten required story tasks.",
        "All required objects have a visible action, result, save state and Godot node plan.",
        "The bird’s-eye blueprint shows zones 01–06, one story path and a secondary station spur.",
        "The world reads as its own identity and does not copy another world’s main shapes.",
        "The player keeps one green outfit; only the three simple rewards change.",
        "Mayor Milo keeps one elder design and does not fight.",
        "The approved lighter-skin Mother Guardian keeps one body, outfit and wing design.",
        "Five enemy types and the boss use clear telegraph, attack and recovery states.",
        "The boss frees the living world instead of destroying a thought, feeling or idea.",
        "The next story world opens only through a World Gate.",
        "The one Crown Train lists only Art Castle and completed worlds.",
        "The 16-identity evidence survives save, reload, boss retry and travel.",
        "Important information uses text, icon, shape and sound, not colour alone.",
        "The full route works before final decoration and particles are added.",
    ]
    for item in checklist:
        paragraph = doc.add_paragraph()
        paragraph.paragraph_format.left_indent = Inches(0.36)
        paragraph.paragraph_format.first_line_indent = Inches(-0.22)
        paragraph.paragraph_format.space_after = Pt(3)
        run = paragraph.add_run("☐  " + item)
        set_run(run, size=10.1, color=INK)
    add_callout(
        doc,
        key,
        "DONE MEANS",
        f"{WORLD_DATA[key]['name'].title()} is complete when the player can follow one clear 55–70 minute route, finish four meaningful quests, win readable fights, free the boss, receive {WORLD_PLAN[key]['treasure']} and {WORLD_PLAN[key]['reward']}, open {WORLD_PLAN[key]['next']} and add this completed world to optional train travel.",
        gold=True,
    )


def ensure_document_safety(doc):
    for paragraph in doc.paragraphs:
        paragraph.paragraph_format.widow_control = True
        if paragraph.style and paragraph.style.name.startswith("Heading"):
            paragraph.paragraph_format.keep_with_next = True


def set_metadata(doc, key):
    data = WORLD_DATA[key]
    doc.core_properties.title = f"{data['name'].title()} Clean Integrated Developer Guide"
    doc.core_properties.subject = "ARTÉA story, quests, objects, combat, shared characters, train, identity system and Godot implementation"
    doc.core_properties.author = "David Sovann and the ARTÉA team"
    doc.core_properties.keywords = "ARTÉA, Godot, world design, quests, combat, identity, Crown Train, Mayor Milo, Mother Guardian"
    doc.core_properties.comments = "Clean integrated edition. Older duplicated guide and addendum sections were replaced on 14 August 2026."


def validate_assets(key):
    paths = [
        OVERVIEWS[key],
        BIRDSEYE_BLUEPRINTS[key],
        ARCHITECTURE_IMAGES[key],
        FUNCTIONAL_IMAGES[key],
        ENTITY_IMAGES[key],
        PLAYER_IMAGE,
        MILO_IMAGE,
        GUARDIAN_IMAGE,
        TRAIN_IMAGE,
    ]
    missing = [path for path in paths if not path.exists()]
    if missing:
        raise FileNotFoundError("\n".join(str(path) for path in missing))


def build_one(key):
    validate_assets(key)
    output = OUTPUTS[key]
    output.parent.mkdir(parents=True, exist_ok=True)
    doc = Document()
    bullet_id, number_id = configure_document(doc, key)
    build_cover(doc, key)
    add_orientation(doc, key, bullet_id)
    add_world_identity(doc, key, bullet_id)
    add_story(doc, key)
    add_quest_plan(doc, key, bullet_id)
    add_functional_objects(doc, key)
    add_architecture(doc, key)
    add_combat(doc, key, bullet_id)
    add_shared_cast(doc, key, bullet_id)
    add_train(doc, key, bullet_id)
    add_identity(doc, key, bullet_id)
    add_implementation(doc, key, bullet_id, number_id)
    set_metadata(doc, key)
    ensure_document_safety(doc)
    doc.save(output)
    print(output)


def add_quest_plan(doc, key, bullet_id):
    plan = WORLD_PLAN[key]
    add_section(
        doc,
        key,
        "Part 3",
        "Quest, timing and level route",
        "All three worlds use the same story length and the same amount of main content, while their tasks stay different.",
    )
    summary_rows = [
        ("First-play target", "55–70 minutes without optional exploration"),
        ("Main structure", "4 quests • 10 required story tasks • 1 three-stage boss"),
        ("Combat", "5 normal enemy types • no more than 4 normal enemies at one time"),
        ("Identity", "8 small evidence moments inside existing scenes; no extra quest"),
        ("Level band", plan["level_band"]),
        ("Completion reward", f"{plan['treasure']} + {plan['reward']} + {plan['next']}"),
    ]
    add_matrix(doc, key, ("Target", "Approved value"), summary_rows, (1.6, 4.9), font_size=9.2)
    doc.add_heading("Four-quest plan", level=2)
    add_matrix(
        doc,
        key,
        ("#", "Quest", "Required tasks", "Required fight", "Time", "Reward / unlock"),
        plan["quests"],
        (0.32, 1.15, 2.0, 1.05, 0.72, 1.26),
        font_size=7.6,
    )
    add_callout(
        doc,
        key,
        "TIME RULE",
        "If playtesting is shorter than 55 minutes, add exploration, dialogue or one more use of an existing object. Do not add a fifth quest or a new system.",
    )
    doc.add_heading("Six-zone route", level=2)
    add_matrix(doc, key, ("#", "Zone", "Purpose"), plan["zones"], (0.35, 2.0, 4.15), font_size=8.8)
    doc.add_heading("Save gates", level=2)
    add_callout(
        doc,
        key,
        "SAVE RULE",
        "Save after each quest and before the boss. A retry keeps earlier quests. Save the treasure before opening the next World Gate or adding this completed world to the train menu.",
    )
    heading = doc.add_heading("Bird’s-eye world build blueprint", level=2)
    heading.paragraph_format.page_break_before = True
    picture_with_alt(
        doc,
        BIRDSEYE_BLUEPRINTS[key],
        Inches(6.5),
        (
            f"Simple bird's-eye implementation blueprint for {WORLD_DATA[key]['name'].title()}, "
            "showing the six numbered story zones, one connected main route and a secondary completed-world train station spur."
        ),
    )
    add_caption(
        doc,
        f"{WORLD_DATA[key]['name'].title()} bird’s-eye blueprint. Follow 01–06 in order; the small station spur is optional travel after completion.",
    )
    add_callout(
        doc,
        key,
        "GREYBOX RULE",
        "Build the six zone floors and the main walking path first. Add the World Gate, checkpoints, boss arena and final sanctuary next. Add the station side spur last; it must never block the story route.",
    )


def main():
    for key in ("mind", "heart", "creator"):
        build_one(key)


if __name__ == "__main__":
    main()
