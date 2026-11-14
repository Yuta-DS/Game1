from __future__ import annotations

from pathlib import Path

from docx import Document
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.shared import Inches, Pt

from build_mind_spark_design_document import (
    CYAN,
    DEEP_CYAN,
    GOLD,
    ICE,
    INK,
    MIDNIGHT,
    MUTED,
    VIOLET,
    add_bullet,
    add_callout,
    add_caption,
    add_check,
    add_numbered_sequence,
    add_page_field,
    add_section_intro,
    configure_document,
    format_cell_text,
    picture_with_alt,
    prevent_row_split,
    set_repeat_table_header,
    set_run,
    set_table_borders,
    set_table_geometry,
    shade_cell,
)


ROOT = Path("/Users/davidsovann/S2603/artea")
OUTPUT_DIR = Path("/Users/davidsovann/Documents")


WORLD_TWO = {
    "number": "TWO",
    "title": "HEART MELODY",
    "kingdom": "Heart Melody Kingdom",
    "file": OUTPUT_DIR / "World_Two_Heart_Melody_Concise_Developer_Guide.docx",
    "hero": ROOT / "artifacts/heart_melody_world_reference/heart_melody_world_concept_v1.png",
    "board": ROOT / "artifacts/heart_melody_world_reference/heart_melody_object_blueprint_v1.png",
    "hero_alt": (
        "Isometric concept of Heart Melody Kingdom: a floating green valley with a railway station, "
        "waterfall organ, drum garden, bell grove, harmony stage, Raphael, and the Harmony Jewel."
    ),
    "board_alt": (
        "Six-panel production reference board for Heart Melody objects, including the station, waterfall "
        "instruments, harmony stage, bell grove, emotion plants, and Harmony Jewel sanctuary."
    ),
    "phrase": "A living music valley where every feeling becomes a safe sound and every sound helps the path grow.",
    "theme": "My feelings have a voice.",
    "dominant": "Nature",
    "supports": "Magic and Technology",
    "treasure": "Harmony Jewel",
    "guardian": "Archangel Raphael — healing and emotional balance",
    "guide": "Mayor Milo — explains the mission, operates sound technology, and protects the player",
    "opening_state": "World One is complete. The Crown Railway can now carry the player from the Gallery to Heart Melody Station.",
    "next_unlock": "Creator’s Light Station and the train shortcut controls",
    "identity_mix": [
        ("Nature", "55%", "Waterfalls, flowers, trees, living instruments, wind, rain, and a valley that responds to emotion."),
        ("Magic", "30%", "Feelings become coloured sound, paths grow from music, and Raphael protects the Harmony Jewel."),
        ("Technology", "15%", "Milo’s consoles translate feeling into moving platforms, bridges, lights, and safe routes."),
    ],
    "mandate": (
        "Feelings are never enemies and are never labelled good or bad. The sword only breaks the Silence Blight "
        "that traps emotion; the player restores safe expression and balance."
    ),
    "journey_summary": (
        "The player rides the newly unlocked Crown Railway into a valley that has lost its music. Mayor Milo asks "
        "for help because the Harmony Jewel is trapped inside the final silent note. The player gives safe voices "
        "to different feelings, fights creatures made by the Silence Blight, joins the sounds into one song, and "
        "frees the Silent Conductor. Raphael returns the Harmony Jewel, and the train opens the route to World Three."
    ),
    "scenes": [
        {
            "title": "1. Train arrival — the quiet valley",
            "story": (
                "After World One, the player may finally use the train. The Crown Railway leaves the Art Castle "
                "Gallery and arrives at Heart Melody Station. The valley is beautiful, but its waterfalls, flowers, "
                "drums, bells, and giant strings make no sound. Milo explains that the Silence Blight trapped the "
                "valley’s feelings and sealed the Harmony Jewel inside the last note."
            ),
            "actions": [
                "Walk from the station to the Quiet Meadow while Milo teaches the sound-colour guide.",
                "Defeat two Echo Moths with the sword and activate the first music console.",
                "Meet Raphael as a light projection; accept the mission without a forced dialogue choice.",
            ],
            "dialogue": "Raphael: “A healthy heart does not sing only happy songs. Every feeling needs a safe place in the music.”",
        },
        {
            "title": "2. Quest One — Give the feelings a voice",
            "story": (
                "Milo leads the player through the Drum Garden and Sadness River. The player strikes frustration "
                "drums to build strong platforms, then plays soft sadness notes so raindrops lift a small boat. "
                "Hush Vines and a Rhythm Golem block the route, but their dark shells open when the correct sound plays."
            ),
            "actions": [
                "Complete one three-beat drum pattern; each correct beat creates a platform.",
                "Guide the rain boat through three water gates by choosing soft note groups.",
                "Fight two Hush Vines and one Rhythm Golem; attack only while the sound-exposed core is open.",
            ],
            "dialogue": "Milo: “Strong feelings are not wrong. We can give them a safe shape and a safe sound.”",
        },
        {
            "title": "3. Quest Two — Build the Heart Song",
            "story": (
                "At the Fear Bell Grove, warning bells show which path is safe and which path needs care. In the "
                "Peace Flower Sanctuary, quiet flowers slow the broken machines. The player then adds a hopeful tune "
                "that brings morning colour back to the sky. Every restored sound becomes one layer of the Heart Song."
            ),
            "actions": [
                "Read three bell signals and choose the safe path without a fail-state punishment.",
                "Wake four peace flowers to slow two moving hazards.",
                "Choose one of three hopeful melodies; all choices are valid and change the final music layer.",
            ],
            "dialogue": "Milo: “We do not remove fear or sadness. We listen, stay safe, and let every feeling have room.”",
        },
        {
            "title": "4. Boss — the Silent Conductor",
            "story": (
                "The Heart Song opens the Harmony Stage. The Silent Conductor is not an evil person; it is a suit "
                "of Silence Blight armour holding the valley’s final note. The player fights the armour, restores "
                "three music sections, and then adds the Hope Note. The armour breaks and the Conductor becomes the "
                "gentle keeper of the valley’s music."
            ),
            "actions": [
                "Phase 1: defeat Echo Moths and activate three rhythm stones.",
                "Phase 2: use sadness, fear, and peace sounds to expose the armour, then use sword attacks.",
                "Phase 3: strike the exposed blight core three times and finish by playing the Hope Note.",
            ],
            "dialogue": "The final input is a music action, not a killing blow.",
        },
        {
            "title": "5. Reward — a new route opens",
            "story": (
                "The last note opens and reveals the Harmony Jewel, shining with every feeling colour. Raphael thanks "
                "the player and Milo. They return by train to the Gallery, where the Jewel joins the Star of Wisdom. "
                "Creator’s Light Station appears on the Destination Wheel, and the train shortcut controls wake up."
            ),
            "actions": [
                "Save the Harmony Jewel reward and World Two completion flag.",
                "Unlock Creator’s Light Station and the optional shortcut controls.",
                "Keep the player’s campaign XP, equipment, accessibility settings, and identity scores.",
            ],
            "dialogue": "Raphael: “Your feelings matter. Your heart has a beautiful voice.”",
        },
    ],
    "timing": [
        ("Arrival and mission", "1–2 min", "Station, tutorial reminder, two Echo Moths, Raphael projection"),
        ("Quest 1: Give feelings a voice", "4 min", "Drums, rain boat, Hush Vines, Rhythm Golem"),
        ("Quest 2: Build the Heart Song", "4 min", "Fear bells, peace flowers, hope melody"),
        ("Boss: Silent Conductor", "4–5 min", "Three readable phases and final Hope Note"),
        ("Reward and train unlock", "1 min", "Harmony Jewel, Gallery return, World Three route"),
    ],
    "quest_rewards": [
        ("Quest 1", "Restore drums and sadness river", "40 quest XP + enemy XP", "Heart Song layers 1–2"),
        ("Quest 2", "Restore fear, peace, and hope", "45 quest XP + enemy XP", "Harmony Stage opens"),
        ("Boss", "Free the Silent Conductor", "70 boss XP", "Harmony Jewel + World Three station"),
    ],
    "learning_prompts": [
        ("Drum Garden", "Which action gives frustration a safe rhythm?", "Play the marked three-beat pattern; retry with Milo’s slow cue."),
        ("Sadness River", "What helps the rain boat rise?", "Use soft notes; no answer removes XP or health."),
        ("Fear Bell Grove", "Which bell warns that a path needs care?", "Follow colour, icon, vibration, and sound together."),
        ("Final song", "Can different feelings stay in the same song?", "Yes. The mix changes, but every valid choice completes the quest."),
    ],
    "enemies": [
        ("Echo Moth", "25", "5", "Hover, telegraph a sound pulse, dash once, pause", "One clean sword hit; simple CharacterBody3D chase"),
        ("Hush Vine", "50", "10", "Stationary root grab, one-second recovery", "Sound cue opens core for two hits"),
        ("Rhythm Golem", "75", "15", "Slow beat stomp, short walk, long recovery", "Dodge the circle and hit during recovery"),
        ("Silent Conductor", "220 armour/core", "70", "Three scripted phases; two attacks per phase", "Boss state machine; final music interaction"),
    ],
    "boss_phases": [
        ("1 — Release the beat", "Echo Moths and muted rhythm stones", "Defeat adds; activate three stones", "Beat track starts and phase gate opens"),
        ("2 — Restore the voices", "Armour sends wide silence waves", "Play sadness, fear, and peace phrases; strike exposed armour", "Three feeling colours return"),
        ("3 — Join the harmony", "Core pulses between safe lanes", "Dodge, strike core three times, play Hope Note", "Conductor is freed; Harmony Jewel appears"),
    ],
    "route": [
        ("0", "Art Castle Gallery", "Choose Heart Melody on the Destination Wheel; train ride begins."),
        ("1", "Harmony Station / Quiet Meadow", "Arrival, mission, tutorial reminder, first fight."),
        ("2", "Drum Garden", "Frustration rhythm puzzle and platform creation."),
        ("3", "Sadness River / Waterfall Organ", "Rain boat, note gates, Hush Vines."),
        ("4", "Fear Bell Grove / Peace Flowers", "Safe-path reading, slow hazards, hope melody."),
        ("5", "Harmony Stage / Raphael Sanctuary", "Boss, Harmony Jewel, return portal to station."),
    ],
    "objects": [
        ("01", "Harmony Station and train platform", "World entrance, Milo briefing, return point, route-unlock feedback."),
        ("02", "Waterfall Organ and rain boat", "Turns sadness notes into water lifts, gates, and a safe moving platform."),
        ("03", "Drum Garden and rhythm platforms", "Creates solid paths from frustration beats; supports one short timing puzzle."),
        ("04", "Fear Bell Grove and path lights", "Marks safe, warning, and needs-care routes with sound, colour, icon, and vibration."),
        ("05", "Peace flowers and emotion plants", "Slow machines, show feeling colours, and provide calm checkpoints."),
        ("06", "Harmony Stage, Jewel, Raphael, and boss", "Final combat arena, three song anchors, reward reveal, guardian conversation."),
    ],
    "specific_systems": [
        "Use five synchronized audio stems: drums, rain, bells, flowers, and hope melody. Save only the selected variation IDs.",
        "Every sound clue also needs colour, shape/icon, and optional controller vibration. Never require hearing alone.",
        "Moving platforms read a MusicSignal event; the puzzle does not directly control transforms from UI code.",
        "The final song combines restored stems. It may sound different after player choices, but completion requirements stay equal.",
    ],
    "identity_moments": [
        ("HM_ID_01", "Station arrival", "Share a feeling with Milo", "Reflect privately", "+E / +I"),
        ("HM_ID_02", "First duet", "Perform beside Milo", "Rehearse alone, then join", "+E / +I"),
        ("HM_ID_03", "Waterfall sound", "Imagine the feeling behind it", "Notice the exact sound pattern", "+N / +S"),
        ("HM_ID_04", "Flower garden", "Combine sounds into new meaning", "Match visible petals and notes", "+N / +S"),
        ("HM_ID_05", "Fear bells", "Choose the clearest safe route", "Choose the route helping creatures", "+T / +F"),
        ("HM_ID_06", "Heart Song mix", "Balance the music structure", "Balance emotional comfort", "+T / +F"),
        ("HM_ID_07", "Repair order", "Set a clear sequence first", "Follow the active instrument", "+J / +P"),
        ("HM_ID_08", "Boss duet", "Use planned cue order", "Adapt to the live beat", "+J / +P"),
    ],
    "closing": (
        "Heart Melody is complete when the player can follow one clear route, safely express different feelings "
        "through sound and action, win readable sword fights, free rather than destroy the final boss, receive the "
        "Harmony Jewel, and see Creator’s Light appear on the train."
    ),
}


WORLD_THREE = {
    "number": "THREE",
    "title": "CREATOR’S LIGHT",
    "kingdom": "Creator’s Light Kingdom",
    "file": OUTPUT_DIR / "World_Three_Creators_Light_Concise_Developer_Guide.docx",
    "hero": ROOT / "artifacts/creators_light_world_reference/creators_light_world_concept_v1.png",
    "board": ROOT / "artifacts/creators_light_world_reference/creators_light_object_blueprint_v1.png",
    "hero_alt": (
        "Isometric concept of Creator's Light Kingdom: a floating blank-to-colour world with a railway station, "
        "creation frames, stamp workshop, glass seeds, silver river pipes, Uriel, and the Perfect Blank arena."
    ),
    "board_alt": (
        "Six-panel production reference board for Creator's Light objects, including the station, creation frame, "
        "stamp set, glass seeds, creator studio, Creator's Light, Uriel, and Perfect Blank arena."
    ),
    "phrase": "A blank world where one brave mark becomes a bridge, a garden, and a light.",
    "theme": "I was created to create.",
    "dominant": "Magic / Creativity",
    "supports": "Technology and Nature",
    "treasure": "Creator’s Light",
    "guardian": "Uriel — imagination, courage, and new beginnings",
    "guide": "Mayor Milo — explains the mission, demonstrates the frame tools, and adds light at the finale",
    "opening_state": "World Two is complete. Creator’s Light is now available on the train Destination Wheel.",
    "next_unlock": "All stations, all Crown Railway routes, free travel, and the Art Castle finale",
    "identity_mix": [
        ("Magic / Creativity", "55%", "Drawings and stamps become real objects; light and colour answer the player’s ideas."),
        ("Technology", "25%", "Creation Frames, projectors, tool palettes, scanners, and train controls make ideas usable."),
        ("Nature", "20%", "Glass seeds grow into plants, silver pipes become rivers, and the empty land becomes alive."),
    ],
    "mandate": (
        "The game never grades art and never asks for a perfect picture. Sword combat only breaks Blank Blight "
        "armour that blocks creation. The final victory is the courage to place an unfinished idea."
    ),
    "journey_summary": (
        "The player rides the train into a nearly empty kingdom. Uriel explains that the world is waiting for one "
        "small mark, but the Perfect Blank keeps whispering that nothing is ready or good enough. Using a simple "
        "Creation Frame, the player makes bridges, doors, trees, and lights, fights Blank Blight creatures, and "
        "brings colour back to the land. The player defeats the Perfect Blank’s armour, places an unfinished picture, "
        "and receives the Creator’s Light. All train routes open and the Crown Railway returns to the Art Castle finale."
    ),
    "scenes": [
        {
            "title": "1. Train arrival — the world waiting for a mark",
            "story": (
                "The train reaches a white station surrounded by floating shapes, empty frames, plants sleeping in "
                "glass seeds, and rivers held inside silver pipes. Milo and the player meet Uriel, who gives the player "
                "a glowing Creation Frame. The Perfect Blank has covered the road and trapped Creator’s Light."
            ),
            "actions": [
                "Walk to the Entry Frame and learn four large tool buttons: bridge, door, tree, and light.",
                "Place one stamp; the frame spawns a safe prebuilt 3D object in the world.",
                "Defeat two Ink Sprites and open the first colour gate.",
            ],
            "dialogue": "Uriel: “You do not need a perfect idea. Make one small mark, and the world will answer.”",
        },
        {
            "title": "2. Quest One — Wake the first creations",
            "story": (
                "At the Bridge Gap, the player selects a bridge stamp and a colour. The picture becomes a real bridge. "
                "At the Dream Door, another simple creation opens a hidden route. Ink Sprites and Smudge Hoppers try "
                "to erase the new objects, so the player protects each creation with the sword."
            ),
            "actions": [
                "Create one bridge from three safe templates; every template reaches the same destination.",
                "Create one door and choose where it appears in a marked placement zone.",
                "Fight two Ink Sprites and one Smudge Hopper; restore the objects at a repair pedestal if needed.",
            ],
            "dialogue": "Milo: “Your first idea can be small. We only need enough to take the next step.”",
        },
        {
            "title": "3. Quest Two — Grow the living artwork",
            "story": (
                "The path reaches the Glass Seed Garden and Creator Studio. A tree stamp wakes the sleeping plants, "
                "and a light stamp changes the silver pipes into a flowing river. The player chooses colours and shapes "
                "for the studio display. Blank Sentinels guard the last colour anchors, but their shields fail when a "
                "nearby creation is active."
            ),
            "actions": [
                "Create one tree and one light; use the new tree as cover and the light as a shield-break signal.",
                "Defeat two Blank Sentinels using a clear shield-open, sword-attack loop.",
                "Place one creation on the studio plinth and answer, keep private, or skip Milo’s reflection question.",
            ],
            "dialogue": "Milo: “You may explain your picture, keep the meaning private, or move on. All three are allowed.”",
        },
        {
            "title": "4. Boss — the Perfect Blank",
            "story": (
                "The Perfect Blank fills the final arena with white armour and tells the player that nothing is ready. "
                "The player restores three colour anchors, creates a way across the empty floor, and uses the sword to "
                "break the Blank Blight shell. The last task is not another attack: the player places an unfinished "
                "picture. Milo adds a point of light, and the whole kingdom grows around it."
            ),
            "actions": [
                "Phase 1: defeat Ink Sprites and restore three colour anchors.",
                "Phase 2: create a bridge, door, or light path; attack the exposed shell.",
                "Phase 3: break the last armour layer and place any unfinished picture to complete the encounter.",
            ],
            "dialogue": "The game accepts every valid stamp, colour, and composition. There is no quality score.",
        },
        {
            "title": "5. Reward — Creator’s Light and the Castle finale",
            "story": (
                "Creator’s Light appears as a flame carrying colours from the player’s creation. Uriel thanks the "
                "player, and the train returns to the Gallery. Wisdom, Harmony, and Creativity join as the Light of "
                "Identity. Every station and route opens for free travel, and the player may enter the Art Castle "
                "finale to receive the Crown of Life and choose one of the 16 friendly identity names."
            ),
            "actions": [
                "Save Creator’s Light, World Three completion, and the creation recipe IDs.",
                "Unlock all Crown Railway destinations and free travel.",
                "Calculate the 16-identity result and let the player accept, rename, retake, or skip it.",
            ],
            "dialogue": "Uriel: “Your creativity is a gift that only you can share with the world.”",
        },
    ],
    "timing": [
        ("Arrival and Creation Frame", "1–2 min", "Station, Uriel, four-button creation tutorial, two Ink Sprites"),
        ("Quest 1: Wake creations", "4 min", "Bridge, door, placement zone, simple combat"),
        ("Quest 2: Grow the artwork", "4 min", "Tree, light, glass seeds, Blank Sentinels"),
        ("Boss: Perfect Blank", "4–5 min", "Colour anchors, creation path, armour fight, unfinished picture"),
        ("Reward and Castle return", "1 min", "Creator’s Light, all routes, identity finale"),
    ],
    "quest_rewards": [
        ("Quest 1", "Create bridge and door", "40 quest XP + enemy XP", "Bridge and door recipes saved"),
        ("Quest 2", "Wake nature and light", "45 quest XP + enemy XP", "Perfect Blank arena opens"),
        ("Boss", "Begin before everything feels perfect", "80 boss XP", "Creator’s Light + all train routes"),
    ],
    "learning_prompts": [
        ("Entry Frame", "What is the smallest mark that can begin?", "Any stamp; the tutorial highlights one only if the player waits."),
        ("Bridge Gap", "Which creation makes a safe crossing?", "All three bridge templates are equally correct."),
        ("Glass Seed Garden", "What could help this place grow?", "Tree or light; both reach the same progression state."),
        ("Final picture", "Does the picture need to be finished?", "No. Any non-empty composition completes the story action."),
    ],
    "enemies": [
        ("Ink Sprite", "25", "5", "Short dash, one ink swipe, long pause", "One clean sword hit; simple CharacterBody3D chase"),
        ("Smudge Hopper", "50", "10", "Jump to marked circle, splash, two-second recovery", "Leave circle, then use two hits"),
        ("Blank Sentinel", "100", "20", "Shield walk, slow beam, recovery", "Activate a nearby creation to open shield"),
        ("Perfect Blank", "250 shell/core", "80", "Three scripted phases; two attacks per phase", "Boss state machine; final creation interaction"),
    ],
    "boss_phases": [
        ("1 — Add colour", "Ink Sprites protect three blank anchors", "Defeat adds; activate three colour anchors", "Arena gains safe colour lanes"),
        ("2 — Make a way", "Blank shell covers the central floor", "Create bridge, door, or light; strike exposed shell", "Path stays and final core opens"),
        ("3 — Courage to begin", "Core repeats wide erase waves", "Dodge, break last armour, place unfinished picture", "World grows; Creator’s Light appears"),
    ],
    "route": [
        ("0", "Art Castle Gallery", "Choose Creator’s Light after completing Heart Melody."),
        ("1", "Creator Station / Entry Frame", "Arrival, Uriel, simple Creation Frame tutorial."),
        ("2", "Bridge Gap", "Bridge creation, Ink Sprites, first colour anchor."),
        ("3", "Dream Door / Glass Seed Garden", "Door placement, tree creation, Smudge Hopper."),
        ("4", "Creator Studio / Light River", "Light creation, Blank Sentinels, reflection choice."),
        ("5", "Perfect Blank Arena / Uriel Court", "Boss, Creator’s Light, return to Castle finale."),
    ],
    "objects": [
        ("01", "Creator Station and Entry Frame", "World entrance, Uriel briefing, four-button tutorial, return point."),
        ("02", "Creation Frame and stamp workstation", "Simple 2D tool UI; stores stamp, colour, rotation, and slot IDs."),
        ("03", "Creation set: bridge, door, tree, light", "Four reusable prebuilt 3D scenes with three visual variants each."),
        ("04", "Glass seeds and silver river pipes", "Nature puzzle props that wake after tree and light creations."),
        ("05", "Creator Studio and gallery plinths", "Shows the player’s chosen recipe; supports private/answer/skip reflection."),
        ("06", "Perfect Blank arena, Uriel, and flame", "Final combat, colour anchors, unfinished-picture action, treasure reveal."),
    ],
    "specific_systems": [
        "Do not convert free drawings into new 3D meshes. Save a small recipe: stamp ID, colour ID, rotation, and placement slot.",
        "Each stamp spawns a tested prebuilt PackedScene. All variants must keep the same collision and gameplay function.",
        "Use a SubViewport or Control-based frame UI only for display; world spawning is handled by a CreationManager signal.",
        "The game never grades art. A non-empty recipe is valid, and answer/private/skip reflection choices give no XP difference.",
    ],
    "identity_moments": [
        ("CL_ID_01", "First idea", "Discuss it with Milo", "Sketch privately first", "+E / +I"),
        ("CL_ID_02", "Studio work", "Create beside Milo", "Create alone, then share", "+E / +I"),
        ("CL_ID_03", "Entry shape", "Imagine an unusual possibility", "Start from the visible shape", "+N / +S"),
        ("CL_ID_04", "Living landscape", "Connect symbols into a story", "Build a practical object", "+N / +S"),
        ("CL_ID_05", "Bridge choice", "Pick the clearest solution", "Pick what comforts creatures", "+T / +F"),
        ("CL_ID_06", "Reflection", "Explain how it works", "Explain what it means", "+T / +F"),
        ("CL_ID_07", "Stamp plan", "Plan every stamp first", "Place one and adapt", "+J / +P"),
        ("CL_ID_08", "Final picture", "Choose an order before starting", "Start unfinished and respond", "+J / +P"),
    ],
    "closing": (
        "Creator’s Light is complete when the player can make useful objects with a simple ungraded tool, protect "
        "those creations in readable sword fights, defeat the Perfect Blank’s armour, place an unfinished idea, "
        "receive Creator’s Light, unlock every train route, and reach the Art Castle identity finale."
    ),
}


IDENTITY_PROFILES = [
    ("ISTJ", "The Steady Keeper"), ("ISFJ", "The Caring Guardian"),
    ("INFJ", "The Quiet Guide"), ("INTJ", "The Vision Builder"),
    ("ISTP", "The Skillful Explorer"), ("ISFP", "The Gentle Artist"),
    ("INFP", "The Hopeful Dreamer"), ("INTP", "The Curious Inventor"),
    ("ESTP", "The Brave Adventurer"), ("ESFP", "The Joyful Performer"),
    ("ENFP", "The Spark Starter"), ("ENTP", "The Idea Challenger"),
    ("ESTJ", "The Strong Organizer"), ("ESFJ", "The Community Builder"),
    ("ENFJ", "The Heart Leader"), ("ENTJ", "The Bold Pathfinder"),
]


def set_world_footer(doc: Document, world_title: str) -> None:
    p = doc.sections[0].footer.paragraphs[0]
    p.text = ""
    p.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    p.paragraph_format.space_after = Pt(0)
    r = p.add_run(f"{world_title}  •  ")
    set_run(r, size=8.5, bold=True, color=MUTED)
    add_page_field(p)


def add_table(doc, headers, rows, widths, header_fill="D9F2F5", font_size=9.1):
    table = doc.add_table(rows=1, cols=len(headers))
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    set_table_geometry(table, widths)
    set_table_borders(table)
    set_repeat_table_header(table.rows[0])
    for idx, text in enumerate(headers):
        cell = table.rows[0].cells[idx]
        shade_cell(cell, header_fill)
        cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
        cell.text = str(text)
        format_cell_text(cell, size=9.2, bold=True, color=MIDNIGHT)
    for row_idx, values in enumerate(rows):
        cells = table.add_row().cells
        prevent_row_split(table.rows[-1])
        if row_idx % 2:
            for cell in cells:
                shade_cell(cell, "F6FBFC")
        for col_idx, value in enumerate(values):
            cells[col_idx].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            cells[col_idx].text = str(value)
            format_cell_text(cells[col_idx], size=font_size, bold=(col_idx == 0), color=MIDNIGHT if col_idx == 0 else INK)
    return table


def add_scene(doc, scene):
    doc.add_heading(scene["title"], level=2)
    doc.add_paragraph(scene["story"])
    for item in scene["actions"]:
        add_bullet(doc, item)
    add_callout(doc, "STORY NOTE", scene["dialogue"], fill="F4EEFF", accent=VIOLET)


def add_identity_pages(doc, data):
    add_section_intro(
        doc,
        "Part 2",
        "Continuing 16-Identity Tracking",
        "World-specific choices quietly add evidence to the same four-axis identity record used across the full ARTÉA journey.",
    )
    add_callout(
        doc,
        "PLAYER PROMISE",
        "The result is a friendly mirror, not a diagnosis. The player may skip any identity choice, and no answer changes XP, combat power, treasure, or quest success.",
        fill="FFF6D8",
        accent=GOLD,
    )
    doc.add_heading("Shared scoring model", level=2)
    add_table(
        doc,
        ("Axis", "A", "B", "What it watches"),
        [
            ("Energy", "E — outward connection", "I — inner reflection", "How the player prefers to recharge or share"),
            ("Information", "S — clear detail", "N — possibility", "How the player notices and imagines"),
            ("Decision", "T — logic", "F — values", "How the player weighs a choice"),
            ("Approach", "J — plan", "P — adapt", "How the player moves through a task"),
        ],
        [0.9, 1.55, 1.55, 2.5],
    )
    doc.add_heading("Eight short moments in this world", level=2)
    doc.add_paragraph(
        "Each moment adds one point to one side only after a deliberate player choice. A neutral or skipped response saves the moment as complete but adds no point. Never show a ‘correct’ animation."
    )
    add_table(
        doc,
        ("ID", "Moment", "Choice A", "Choice B", "Score"),
        data["identity_moments"],
        [0.75, 1.0, 1.65, 1.65, 1.05],
        font_size=8.4,
    )

    doc.add_page_break()
    doc.add_heading("The 16 friendly identity names", level=1)
    doc.add_paragraph(
        "The final four-letter result is calculated only after all three worlds. Use the friendly name first and keep the code secondary. A tie uses the most recent deliberate choice; if still tied, show two possible names and let the player choose."
    )
    profile_rows = []
    for idx in range(0, len(IDENTITY_PROFILES), 2):
        code_a, name_a = IDENTITY_PROFILES[idx]
        code_b, name_b = IDENTITY_PROFILES[idx + 1]
        profile_rows.append((code_a, name_a, code_b, name_b))
    add_table(doc, ("Code", "Friendly name", "Code", "Friendly name"), profile_rows, [0.7, 2.55, 0.7, 2.55], font_size=9.0)
    doc.add_heading("Save data required", level=2)
    add_table(
        doc,
        ("Field", "Type", "Purpose"),
        [
            ("identity_scores", "Dictionary", "Eight integer totals: E, I, S, N, T, F, J, P."),
            ("identity_moments", "Dictionary", "Moment ID to chosen option, neutral, or skipped."),
            ("identity_result", "String", "Calculated code after World Three; empty before the finale."),
            ("identity_name", "String", "Friendly name selected or accepted by the player."),
            ("identity_consent", "Boolean", "Whether the player wants the result shown and saved."),
        ],
        [1.55, 1.0, 3.95],
    )
    add_callout(doc, "IMPLEMENTATION", "Store identity data in the campaign SaveData resource. Do not keep separate world-only profiles and never reset scores at a station.")


def build_world(data):
    data["file"].parent.mkdir(parents=True, exist_ok=True)
    doc = Document()
    configure_document(doc)
    set_world_footer(doc, data["title"])
    doc.core_properties.title = f"World {data['number'].title()}: {data['kingdom']} — Concise Developer Guide"
    doc.core_properties.subject = f"ARTÉA {data['kingdom']} story, identity, gameplay, and production guide"
    doc.core_properties.author = "David Sovann and the ARTÉA team"
    doc.core_properties.keywords = f"ARTÉA, {data['kingdom']}, game design, identity system, Godot, quests, boss"
    doc.core_properties.comments = "Adapted from the ARTÉA Game Story and the World One concise developer guide system."

    # Cover
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(8)
    p.paragraph_format.space_after = Pt(2)
    r = p.add_run(f"ARTÉA  •  WORLD {data['number']} SIMPLE DEVELOPER GUIDE")
    set_run(r, size=10, bold=True, color=VIOLET)
    p = doc.add_paragraph(style="Title")
    r = p.add_run(data["title"])
    set_run(r, size=34, bold=True, color=MIDNIGHT)
    p = doc.add_paragraph(style="Subtitle")
    r = p.add_run("Story Journey, Identity Tracking, Quests, Combat, Boss & World Building")
    set_run(r, size=14, color=DEEP_CYAN)
    picture_with_alt(doc, data["hero"], Inches(6.5), data["hero_alt"])
    add_caption(doc, f"{data['kingdom']} production concept — {data['dominant']} leads; {data['supports']} support the experience.")
    add_callout(doc, "IDENTITY PHRASE", data["phrase"])
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("Version 1.0  •  14 August 2026  •  Prepared for David Sovann and the ARTÉA team")
    set_run(r, size=9, color=MUTED)

    # Orientation
    add_section_intro(
        doc,
        "Document orientation",
        "How to use this guide",
        "A simple shared reference for story, level design, environment art, gameplay, audio, UI, accessibility, and Godot implementation.",
    )
    doc.add_heading("Purpose", level=2)
    doc.add_paragraph(
        f"This guide turns the proposal for {data['kingdom']} into one short playable journey. It follows the same structure and visual language as the World One guide while keeping the scope small enough for a practical Godot production."
    )
    add_callout(doc, "DESIGN MANDATE", data["mandate"], fill="FFF6D8", accent=GOLD)
    doc.add_heading("Guide contents", level=2)
    for item in (
        "1. World identity and the three-force design balance",
        "2. Continuing 16-identity tracking system",
        "3. Player journey from train arrival to the next unlock",
        "4. Timing, quests, learning prompts, rewards, and XP",
        "5. Godot-friendly enemies, sword combat, and boss flow",
        "6. Level route, required objects, and visual reference board",
        "7. Technical rules, accessibility, save data, and build checklist",
    ):
        add_bullet(doc, item)
    doc.add_heading("Production target", level=2)
    add_table(
        doc,
        ("Target", "Decision"),
        [
            ("First-play time", "14–16 minutes as part of the previously agreed three-world 55–70 minute campaign"),
            ("Quest count", "2 main quests + 1 boss encounter"),
            ("Combat scope", "3 normal enemy types + 1 boss; all use readable state loops"),
            ("Identity scope", "8 optional micro-decisions; 2 for each identity axis"),
            ("Level shape", "One linear route with shortcuts and a clear return to the train"),
        ],
        [1.7, 4.8],
    )

    # Identity
    add_section_intro(
        doc,
        "Part 1",
        "World Identity",
        f"{data['kingdom']} gives one force a strong visual lead while the other two remain visible and useful.",
    )
    add_table(
        doc,
        ("Identity field", "Approved direction"),
        [
            ("Chapter theme", data["theme"]),
            ("Dominant force", data["dominant"]),
            ("Supporting forces", data["supports"]),
            ("Treasure", data["treasure"]),
            ("Guardian", data["guardian"]),
            ("Player guide", data["guide"]),
            ("Opening state", data["opening_state"]),
            ("Completion unlock", data["next_unlock"]),
        ],
        [1.65, 4.85],
    )
    doc.add_heading("How the three forces combine", level=2)
    add_table(doc, ("Force", "Visual share", "Use in this world"), data["identity_mix"], [1.35, 1.05, 4.1])
    add_callout(doc, "WORLD RULE", data["phrase"], fill="F4EEFF", accent=VIOLET)
    doc.add_heading("Story overview", level=2)
    doc.add_paragraph(data["journey_summary"])

    add_identity_pages(doc, data)

    # Player journey
    add_section_intro(
        doc,
        "Part 3",
        "The Player Journey",
        "Read this section in order: it follows what the player sees, learns, fights, earns, and unlocks from the train arrival to the world ending.",
    )
    doc.add_heading("Simple journey map", level=2)
    add_numbered_sequence(doc, [
        "Ride the Crown Railway into the new kingdom.",
        "Meet the guardian and hear the problem and mission from Milo.",
        "Complete Quest One and learn the world’s main interaction.",
        "Complete Quest Two and prepare the final route.",
        "Fight the boss in three clear phases.",
        f"Receive {data['treasure']} and unlock {data['next_unlock']}.",
    ])
    for idx, scene in enumerate(data["scenes"]):
        if idx == 2:
            doc.add_page_break()
        add_scene(doc, scene)

    # Quests
    add_section_intro(
        doc,
        "Part 4",
        "Timing, Quests, Learning Prompts & Rewards",
        "Keep the chapter short, readable, and generous. Identity choices and learning prompts never remove rewards.",
    )
    doc.add_heading("First-play timing", level=2)
    add_table(doc, ("Section", "Time", "Included play"), data["timing"], [1.75, 1.0, 3.75])
    doc.add_heading("Quest and unlock table", level=2)
    add_table(doc, ("Step", "Main objective", "Reward", "Story unlock"), data["quest_rewards"], [1.0, 2.0, 1.45, 2.05], font_size=8.7)
    doc.add_heading("Short learning prompts", level=2)
    add_table(doc, ("Place", "Prompt", "Implementation / hint"), data["learning_prompts"], [1.2, 2.2, 3.1], font_size=8.7)
    add_callout(doc, "QUIZ RULE", "A wrong answer gives a helpful response and an immediate retry. It never removes health, XP, identity points, treasure, or access.", fill="FFF6D8", accent=GOLD)

    # Combat
    add_section_intro(
        doc,
        "Part 5",
        "Sword Combat, Enemies & Campaign XP",
        "All enemies are small, readable, and possible with standard Godot scenes, navigation, timers, hitboxes, and animation states.",
    )
    doc.add_heading("Enemy roster", level=2)
    add_table(doc, ("Enemy", "HP", "XP", "Simple behaviour loop", "Player answer"), data["enemies"], [1.2, 0.55, 0.5, 2.3, 1.95], font_size=8.2)
    doc.add_heading("Shared Godot enemy scene", level=2)
    add_table(
        doc,
        ("Node / resource", "Purpose"),
        [
            ("CharacterBody3D", "Enemy movement and collision. Stationary enemies may use Node3D instead."),
            ("NavigationAgent3D", "Simple chase path; stop before attacks and never chase outside the arena."),
            ("Area3D Hurtbox / Hitbox", "Receive sword damage and apply enemy damage with separate collision layers."),
            ("AnimationPlayer", "Telegraph, attack, recovery, hit, and defeat animations."),
            ("Timer", "Attack cooldown and readable recovery window."),
            ("EnemyData Resource", "HP, XP, speed, damage, and scene references without copied scripts."),
            ("State enum", "IDLE → CHASE → TELEGRAPH → ATTACK → RECOVER → HIT → DEFEATED."),
        ],
        [2.0, 4.5],
    )
    doc.add_heading("Campaign level rule", level=2)
    expected = "Level 3 at arrival and Level 4 after completion" if data["number"] == "TWO" else "Level 4 at arrival and Level 5 after completion"
    add_bullet(doc, f"Expected campaign range: {expected}. Never reset the player’s level at the station.")
    add_bullet(doc, "Normal enemies award XP once. Quest and boss rewards are saved immediately.")
    add_bullet(doc, "Identity decisions, quiz answers, accessibility assists, and reflection skips give no XP difference.")
    add_bullet(doc, "If balancing changes global thresholds, keep the world reward total proportional rather than adding more enemies.")

    # Boss
    add_section_intro(
        doc,
        "Part 6",
        "Boss Encounter",
        "The boss uses combat because the hero carries a sword, but the story ending remains restorative instead of violent.",
    )
    doc.add_heading(f"Final encounter: {data['enemies'][-1][0]}", level=2)
    add_table(doc, ("Phase", "Threat", "Player task", "Completion state"), data["boss_phases"], [1.25, 1.65, 2.15, 1.45], font_size=8.5)
    doc.add_heading("Boss implementation", level=2)
    for item in (
        "Use one BossController with explicit INTRO, PHASE_1, TRANSITION, PHASE_2, PHASE_3, RESTORE, and COMPLETE states.",
        "Lock progression triggers while a transition animation is running; save only after COMPLETE.",
        "Show attack zones on the ground for at least 0.75 seconds and provide high-contrast and reduced-flash settings.",
        "If the player falls, restart the current phase with full healing items; do not replay the whole world.",
        "The final story action is an interaction prompt. Sword damage cannot trigger the treasure reveal by itself.",
    ):
        add_bullet(doc, item)
    add_callout(doc, "BOSS ACCEPTANCE", data["mandate"], fill="FFF6D8", accent=GOLD)

    # Route and objects
    add_section_intro(
        doc,
        "Part 7",
        "Level Route & Required World Objects",
        "Build one understandable journey. Reuse modular pieces and keep decorative density lower around combat, prompts, gates, and train controls.",
    )
    doc.add_heading("Linear route", level=2)
    add_table(doc, ("#", "Area", "Player purpose"), data["route"], [0.55, 2.25, 3.7])
    doc.add_heading("Important object groups", level=2)
    add_table(doc, ("Ref.", "Object group", "Purpose for designer / developer"), data["objects"], [0.65, 2.35, 3.5], font_size=8.8)
    doc.add_heading("Simple dressing kit", level=2)
    for item in (
        "6 modular ground pieces: straight, corner, T-junction, small plaza, stairs, and arena edge.",
        "3 large landmarks, 6 medium landmarks, and 12 small props; reuse materials and colour variants.",
        "1 checkpoint style, 1 interaction pedestal, 1 quest marker, 1 locked gate, and 1 unlocked gate.",
        "3 terrain plants, 3 rocks/crystals, 2 lamps, 2 benches, 2 signs, and 3 particle effects.",
        "Keep a clear 2.0–2.5 metre walkable path and avoid placing props inside enemy or camera safety zones.",
    ):
        add_bullet(doc, item)

    # Visual board
    add_section_intro(
        doc,
        "Part 8",
        "Object Architecture Reference",
        "This board gives the art team a shared shape language. The numbered table states what each group must do in the playable build.",
    )
    picture_with_alt(doc, data["board"], Inches(6.5), data["board_alt"])
    add_caption(doc, f"{data['kingdom']} object reference board. Treat forms and colours as direction; use the purpose table as the implementation authority.")
    add_table(doc, ("Ref.", "Object name", "Required gameplay purpose"), data["objects"], [0.65, 2.35, 3.5], font_size=8.5)
    add_callout(doc, "MODELLING RULE", "Build the large silhouette and gameplay collision first. Add small decoration only after the object works at the correct camera distance.")

    # Technical and checklist
    add_section_intro(
        doc,
        "Part 9",
        "Technical, UI, Audio & Accessibility Rules",
        "Keep the systems modular, saveable, readable without one sensory channel, and small enough to test every week.",
    )
    doc.add_heading("World-specific implementation", level=2)
    for item in data["specific_systems"]:
        add_bullet(doc, item)
    doc.add_heading("Required save flags", level=2)
    save_rows = [
        (f"world_{data['number'].lower()}_started", "Set after the station arrival finishes."),
        (f"world_{data['number'].lower()}_quest_1", "Set after Quest One reward and checkpoint."),
        (f"world_{data['number'].lower()}_quest_2", "Set after Quest Two opens the boss route."),
        (f"world_{data['number'].lower()}_boss_complete", "Set after the final non-combat interaction."),
        (f"world_{data['number'].lower()}_treasure", f"Stores ownership of {data['treasure']}."),
        ("train_unlocked_routes", "Array of available station IDs; never infer only from scene position."),
        ("campaign_level / xp", "Continues from the previous world and returns to the Gallery."),
        ("identity_scores / moments", "Continues the shared 16-identity record."),
    ]
    add_table(doc, ("Field", "Purpose"), save_rows, [2.45, 4.05], font_size=8.7)
    doc.add_heading("Accessibility minimum", level=2)
    for item in (
        "Subtitles with speaker names and scalable text; short sentences and replay dialogue button.",
        "Colour cues repeated with icon, shape, sound, and optional vibration.",
        "Reduced flash, reduced particles, camera shake slider, and motion-safe platform option.",
        "Combat assist: slower enemy attacks, wider parry/dodge window, and boss phase restart.",
        "Puzzle assist after two misses; skip reflection and identity questions without losing progress.",
    ):
        add_check(doc, item)

    doc.add_page_break()
    doc.add_heading("Final build checklist", level=1)
    checks = [
        "Train route stays locked until the previous world completion flag is saved.",
        "Milo explains what happened, why help is needed, the goal, and the reward in simple language.",
        "The full first-play path fits 14–16 minutes without rushing dialogue.",
        "Two quests and three boss phases each have clear start, progress, complete, and saved states.",
        "All three normal enemy types and the boss use readable telegraph and recovery states.",
        "The player uses the sword, but the final story action restores rather than kills.",
        "Eight identity moments score the correct axis and may be skipped without penalty.",
        "All visuals, sounds, prompts, and hazards have at least one non-colour and non-audio cue.",
        "The treasure appears only after boss COMPLETE and the new train route unlocks only after the treasure save.",
        "Returning to the Gallery preserves XP, inventory, settings, creation/music choices, and identity scores.",
    ]
    for item in checks:
        add_check(doc, item)
    add_callout(doc, "DONE MEANS", data["closing"], fill="EAF9FB", accent=DEEP_CYAN)

    picture_with_alt(doc, data["hero"], Inches(5.4), data["hero_alt"])
    add_caption(doc, f"End-state vision for {data['kingdom']}: the route is restored, the treasure is earned, and the next Crown Railway state is clear.")

    # Mark single-cell callout rows for assistive navigation as well as data-table headers.
    for table in doc.tables:
        if len(table.rows) == 1 and len(table.columns) == 1:
            set_repeat_table_header(table.rows[0])

    doc.save(data["file"])
    print(data["file"])


def main():
    for world in (WORLD_TWO, WORLD_THREE):
        build_world(world)


if __name__ == "__main__":
    main()
