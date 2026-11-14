from __future__ import annotations

from pathlib import Path

from docx import Document
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
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
    add_check,
    add_numbered_sequence,
    add_page_field,
    configure_document,
    format_cell_text,
    prevent_row_split,
    set_cell_margins,
    set_repeat_table_header,
    set_run,
    set_table_borders,
    set_table_geometry,
    shade_cell,
)


ROOT = Path("/Users/davidsovann/S2603/artea")
OUT = ROOT / "docs" / "ARTEA_Three_World_55_70_Minute_Campaign_Guide.docx"


def add_section_intro(doc, part, title, summary):
    p = doc.add_paragraph()
    p.paragraph_format.page_break_before = True
    p.paragraph_format.space_after = Pt(3)
    r = p.add_run(part.upper())
    set_run(r, size=9.5, bold=True, color=VIOLET)
    h = doc.add_heading(title, level=1)
    h.paragraph_format.space_before = Pt(0)
    p = doc.add_paragraph(summary)
    p.paragraph_format.space_after = Pt(12)
    set_run(p.runs[0], size=12, italic=True, color=MUTED)


def add_data_table(doc, headers, rows, widths, *, compact=False, centre_columns=()):
    table = doc.add_table(rows=1, cols=len(headers))
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    set_table_geometry(table, widths)
    set_table_borders(table)
    for index, text in enumerate(headers):
        cell = table.cell(0, index)
        shade_cell(cell, "D9F2F5")
        cell.text = text
        format_cell_text(
            cell,
            size=8.1 if compact else 9.1,
            bold=True,
            color=MIDNIGHT,
            align=WD_ALIGN_PARAGRAPH.CENTER if index in centre_columns else WD_ALIGN_PARAGRAPH.LEFT,
        )
    set_repeat_table_header(table.rows[0])
    for row_index, row in enumerate(rows):
        cells = table.add_row().cells
        prevent_row_split(table.rows[-1])
        if row_index % 2:
            for cell in cells:
                shade_cell(cell, "F6FBFC")
        for index, value in enumerate(row):
            cells[index].text = str(value)
            cells[index].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            format_cell_text(
                cells[index],
                size=7.8 if compact else 8.9,
                bold=(index == 0),
                color=MIDNIGHT if index == 0 else INK,
                align=WD_ALIGN_PARAGRAPH.CENTER if index in centre_columns else WD_ALIGN_PARAGRAPH.LEFT,
            )
            set_cell_margins(cells[index], top=50 if compact else 75, start=75, bottom=50 if compact else 75, end=75)
    return table


def add_story_step(doc, heading, location, goal, text):
    h = doc.add_heading(heading, level=2)
    h.paragraph_format.space_after = Pt(2)
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(4)
    p.paragraph_format.keep_with_next = True
    r = p.add_run(f"{location}  •  {goal}")
    set_run(r, size=9.2, bold=True, color=DEEP_CYAN)
    p = doc.add_paragraph(text)
    p.paragraph_format.space_after = Pt(8)


def add_world_heading(doc, world, title, identity, treasure):
    p = doc.add_paragraph()
    p.paragraph_format.page_break_before = True
    p.paragraph_format.space_after = Pt(3)
    r = p.add_run(world.upper())
    set_run(r, size=9.5, bold=True, color=VIOLET)
    h = doc.add_heading(title, level=1)
    h.paragraph_format.space_before = Pt(0)
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(10)
    r = p.add_run(f"Identity: {identity}  •  Treasure: {treasure}")
    set_run(r, size=11.3, italic=True, color=MUTED)


def configure_campaign_document(doc):
    configure_document(doc)
    section = doc.sections[0]
    section.top_margin = Inches(0.78)
    section.bottom_margin = Inches(0.78)

    header = section.header
    p = header.paragraphs[0]
    p.clear()
    p.alignment = WD_ALIGN_PARAGRAPH.LEFT
    r = p.add_run("ARTÉA  /  THREE-WORLD CAMPAIGN GUIDE")
    set_run(r, size=8.5, bold=True, color=MUTED)

    footer = section.footer
    p = footer.paragraphs[0]
    p.clear()
    p.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    r = p.add_run("THREE WORLDS  •  ")
    set_run(r, size=8.5, bold=True, color=MUTED)
    add_page_field(p)

    doc.core_properties.title = "ARTÉA Three-World 55–70 Minute Campaign Guide"
    doc.core_properties.subject = "Three-world story, timing, quests, combat, bosses, XP, train unlocks, and Godot scope"
    doc.core_properties.author = "David Sovann and the ARTÉA team"
    doc.core_properties.keywords = "ARTÉA, Mind Spark, Heart Melody, Creator's Light, Godot, game design"
    doc.core_properties.comments = "Rebalanced from the World One guide so all three worlds fit inside the same 55–70 minute total playtime."


def build_document():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    doc = Document()
    configure_campaign_document(doc)

    # COVER
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(20)
    p.paragraph_format.space_after = Pt(8)
    r = p.add_run("ARTÉA  •  COMPLETE SHORT CAMPAIGN")
    set_run(r, size=10, bold=True, color=VIOLET)
    p = doc.add_paragraph(style="Title")
    r = p.add_run("THREE WORLDS")
    set_run(r, size=34, bold=True, color=MIDNIGHT)
    p = doc.add_paragraph(style="Subtitle")
    r = p.add_run("A 55–70 Minute Story, Quest, Combat & Godot Production Guide")
    set_run(r, size=14, color=DEEP_CYAN)

    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(42)
    p.paragraph_format.space_after = Pt(8)
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("01  MIND SPARK")
    set_run(r, size=20, bold=True, color=DEEP_CYAN)
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("Technology / Science leads  •  Understand thoughts  •  Star of Wisdom")
    set_run(r, size=11, italic=True, color=MUTED)

    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(18)
    p.paragraph_format.space_after = Pt(8)
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("02  HEART MELODY")
    set_run(r, size=20, bold=True, color=VIOLET)
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("Nature leads  •  Give feelings a safe voice  •  Harmony Jewel")
    set_run(r, size=11, italic=True, color=MUTED)

    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(18)
    p.paragraph_format.space_after = Pt(8)
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("03  CREATOR’S LIGHT")
    set_run(r, size=20, bold=True, color=GOLD)
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("Magic / Creativity leads  •  Create without perfection  •  Creator’s Light")
    set_run(r, size=11, italic=True, color=MUTED)

    add_callout(
        doc,
        "MAIN SCOPE DECISION",
        "Keep the full first campaign at 55–70 minutes. Each world is a short 14–16 minute chapter with two quests and one boss. The game is not three times longer.",
        fill="EAF9FB",
    )
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("Version 1.0  •  14 August 2026  •  Prepared for David Sovann and the ARTÉA team")
    set_run(r, size=9, color=MUTED)

    # SCOPE
    add_section_intro(
        doc,
        "Campaign decision",
        "Same Total Playtime, Three Complete Worlds",
        "The earlier 55–70 minute World One plan is now shared across Mind Spark, Heart Melody, and Creator’s Light.",
    )
    add_callout(
        doc,
        "DESIGNED PATH",
        "About 61 minutes: 5 minutes opening + 15 minutes per world + two 2-minute train transitions + 7 minutes for the Castle finale. Exploration, retries, and optional reflection create the 55–70 minute player range.",
    )
    timing_rows = [
        ("Opening", "ARTÉA Town + Art Castle", "5–6 min", "Meet Mayor Milo, fight the tutorial, enter the castle, and see the locked train."),
        ("World 1", "Mind Spark", "14–16 min", "Two quests, two enemy families, one boss, and the Star of Wisdom."),
        ("Transition", "First train unlock", "1–2 min", "Place the Star, wake the train, and ride to Heart Melody."),
        ("World 2", "Heart Melody", "14–16 min", "Two quests, two enemy families, one boss, and the Harmony Jewel."),
        ("Transition", "World Three route", "1–2 min", "Place the Jewel and ride to Creator’s Light."),
        ("World 3", "Creator’s Light", "14–16 min", "Two quests, two enemy families, one boss, and the Creator’s Light."),
        ("Finale", "ARTÉA Castle", "5–7 min", "Join the treasures, choose an identity, receive the Crown of Life, and open free travel."),
    ]
    add_data_table(doc, ("Stage", "Location", "Target", "Story and gameplay"), timing_rows, [0.85, 1.45, 0.8, 3.4], centre_columns=(2,))
    doc.add_heading("Total content budget", level=2)
    for item in (
        "3 worlds, each with 2 short quests and 1 three-stage boss.",
        "6 normal monster designs, but only 2 shared Godot enemy script templates.",
        "15 main story tasks: 5 tasks in each world, including the boss.",
        "6 required game choices: 2 in each world. Personal questions stay optional.",
        "Levels 1–5 across the complete campaign, not Levels 1–5 inside every world.",
        "The Crown Railway cannot be ridden before World One is complete.",
    ):
        add_bullet(doc, item)
    add_callout(
        doc,
        "PLAYER VALUE RULE",
        "The player fights corrupted Blight shells and dangerous machines. Thoughts, feelings, creativity, Milo, guardians, and friendly creatures are never treated as enemies.",
        fill="FFF6D8",
        accent=GOLD,
    )

    # COMPLETE JOURNEY
    add_section_intro(
        doc,
        "Part 1",
        "The Complete Player Journey",
        "The three kingdoms are short chapters of one connected story. Every treasure changes the Art Castle and opens the next step.",
    )
    add_story_step(
        doc,
        "Opening — Mayor Milo asks for help",
        "ARTÉA Town",
        "Meet the mayor and walk to the Art Castle",
        "The player arrives with a crystal sword. Mayor Milo explains that Static Blight creatures are draining the town and the Art Castle has gone dark. He asks for help and leads the player toward the castle. Two weak creatures teach movement, dodge, block, and sword attack. Milo opens the castle with the town key.",
    )
    add_story_step(
        doc,
        "The locked railway and the first gate",
        "Art Castle Main Gallery",
        "Understand the full mission",
        "Inside the Gallery, the player sees three empty treasure displays and the Crown Railway behind a dark seal. Milo explains that the train has no power and cannot be ridden. The Mind Spark World Gate is the only open path. The player must recover the first treasure to wake the train, then use the train to reach the other kingdoms.",
    )
    add_story_step(
        doc,
        "Chapter One — Wisdom",
        "Mind Spark Kingdom",
        "Understand one thought and free the Star of Wisdom",
        "The player clears Static Blight from a living computer forest, collects Thought Sparks, reads a simple pattern, and faces the Thought Storm Warden. The final Hope action frees the Guardian and turns the storm into gentle rain. The Star of Wisdom opens the return World Gate.",
    )
    add_story_step(
        doc,
        "First train ride — The heart route",
        "Art Castle Gallery Station",
        "Wake the railway and travel to World Two",
        "The player places the Star in the Gallery. The dark railway seal breaks, and the train wakes for the first time. Mayor Milo and the player board together. Heart Melody becomes the first destination. The short ride shows Mind Spark shining behind them and the green valley ahead.",
    )
    add_story_step(
        doc,
        "Chapter Two — Feeling and connection",
        "Heart Melody Kingdom",
        "Give feelings a safe voice and earn the Harmony Jewel",
        "The valley is silent because Discord Blight has trapped the instruments. The player fights the Blight shells, uses drums, bells, water, and flowers to express different feelings, and helps Milo reconnect the music machines. The Silent Conductor boss is defeated when the player combines different feeling sounds into one honest chord.",
    )
    add_story_step(
        doc,
        "Second train ride — The creation route",
        "Heart Melody Station",
        "Place the Jewel and open World Three",
        "The Harmony Jewel powers the next railway line. The train plays the player’s short melody during the ride. Creator’s Light appears as a world of blank frames, floating shapes, glass seeds, and silver pipes waiting for imagination.",
    )
    add_story_step(
        doc,
        "Chapter Three — Creativity",
        "Creator’s Light Kingdom",
        "Make one brave mark and earn the Creator’s Light",
        "Blank Blight creatures erase paths and cover useful objects. The player fights them, uses a small creation palette to make a bridge, door, tree, or light, and learns that art does not need to be perfect. The Perfect Blank boss falls when the player uses an unfinished creation as the final answer.",
    )
    add_story_step(
        doc,
        "Finale — The Crown of Life",
        "ARTÉA Castle",
        "Join the three treasures and celebrate the player’s light",
        "The train returns to the castle. The Star of Wisdom, Harmony Jewel, and Creator’s Light become the Light of Identity. Milo offers two or three friendly identity suggestions, but the player may choose another or say, ‘I am still discovering.’ The Maker shapes the light into the Crown of Life. Free train travel and replay open as post-game rewards.",
    )

    # WORLD ONE
    add_world_heading(doc, "Part 2 • World One", "Mind Spark — The Wisdom Chapter", "Technology / Science leads", "Star of Wisdom")
    add_callout(doc, "TIME", "14–16 minutes total: Quest 1 (4–5 min) • Quest 2 (4–5 min) • Boss and reward (5–6 min).")
    doc.add_paragraph(
        "Mayor Milo enters through the World Gate with the player, explains the four goals, and then remains beside a safe Mayor’s Beacon. The player clears Blight, collects four Thought Sparks, repairs the Wisdom Path, and defeats the Thought Storm Warden."
    )
    quest_rows = [
        ("1", "Wake the Network", "2 Static Mites + 1 Glitch Sprout", "Power 1 forest node; collect 2 Sparks.", "Which root still has no power?", "Court opens."),
        ("2", "Read the Pattern", "1 Static Mite + 1 Glitch Sprout", "Move 3 points; collect 2 Sparks; choose fact or fear.", "Is this happening now, or might it happen?", "Boss path opens."),
        ("Boss", "Thought Storm Warden", "Boss + up to 2 Mites", "Power 3 anchors; break shield; attack core; place Hope.", "What is one helpful next step?", "Star and return gate."),
    ]
    add_data_table(doc, ("#", "Quest", "Required fight", "Other tasks", "Short choice", "Unlock"), quest_rows, [0.42, 1.05, 1.35, 1.65, 1.38, 0.65], compact=True, centre_columns=(0,))
    doc.add_heading("Boss alignment", level=2)
    add_numbered_sequence(doc, (
        "Focus: defeat two summoned Mites and switch on three anchors.",
        "Understand: move the three shield points into the clear pattern.",
        "Act: strike the exposed core during two openings, then place the Hope tile instead of making a killing blow.",
    ))
    doc.add_heading("World One result", level=2)
    add_bullet(doc, "The storm becomes gentle rain and the Star grows from the Oldest Tree.")
    add_bullet(doc, "The player reaches Level 2 and gains 110 maximum health.")
    add_bullet(doc, "The player returns through the World Gate. The train wakes only after the Star is placed in the Gallery.")

    # WORLD TWO
    add_world_heading(doc, "Part 3 • World Two", "Heart Melody — The Feeling Chapter", "Nature leads; Technology and Magic support", "Harmony Jewel")
    add_callout(doc, "TIME", "14–16 minutes total: Quest 1 (4–5 min) • Quest 2 (4–5 min) • Boss and reward (5–6 min).")
    doc.add_paragraph(
        "The player and Mayor Milo arrive by train. Waterfalls, flowers, drums, bells, and glowing strings fill the valley, but the music is trapped inside Discord Blight. Feelings are not the enemy. The player fights only the shell that is stopping the feelings from being expressed safely."
    )
    quest_rows = [
        ("1", "Wake the Feeling Garden", "2 Echo Moths", "Touch 3 flowers and match joy, sadness, or fear to a sound.", "Which sound fits this feeling?", "Drum bridge opens."),
        ("2", "Build the Harmony Bridge", "2 Rhythm Golems", "Play 3 drum beats; Milo turns them into platforms.", "What is a safe way to show this feeling?", "Boss stage opens."),
        ("Boss", "Silent Conductor", "Boss + 2 Echo Moths", "Restore 3 instruments; block sound waves; attack mute core.", "Which two feelings can sing together?", "Harmony Jewel."),
    ]
    add_data_table(doc, ("#", "Quest", "Required fight", "Other tasks", "Short choice", "Unlock"), quest_rows, [0.42, 1.12, 1.18, 1.72, 1.42, 0.64], compact=True, centre_columns=(0,))
    doc.add_heading("Boss alignment", level=2)
    add_numbered_sequence(doc, (
        "Listen: defeat the Echo Moths and turn on drums, bells, and strings.",
        "Respond: dodge or block the Conductor’s clear sound rings in the shown rhythm.",
        "Connect: attack the mute core during two openings, then play one chord made from two different feeling sounds.",
    ))
    doc.add_heading("World Two result", level=2)
    add_bullet(doc, "The valley’s full song returns, with all feelings represented as colours and sounds.")
    add_bullet(doc, "The player reaches Level 3 and unlocks the strong sword attack.")
    add_bullet(doc, "The Harmony Jewel powers the Creator’s Light route on the train map.")

    # WORLD THREE
    add_world_heading(doc, "Part 4 • World Three", "Creator’s Light — The Creativity Chapter", "Magic / Creativity leads; Technology and Nature support", "Creator’s Light")
    add_callout(doc, "TIME", "14–16 minutes total: Quest 1 (4–5 min) • Quest 2 (4–5 min) • Boss and reward (5–6 min).")
    doc.add_paragraph(
        "The world contains blank frames, floating shapes, glass seeds, and silver pipes. It is waiting for the player’s imagination. To keep the short campaign realistic in Godot, the player uses simple shapes, colours, and picture stamps. The game changes approved artwork into prebuilt 3D objects; it does not need to turn any freehand drawing into a new 3D mesh."
    )
    quest_rows = [
        ("1", "Make the First Mark", "3 Ink Sprites", "Choose shapes and create 1 bridge or door from a stamp.", "Which tool helps you continue?", "Creation garden opens."),
        ("2", "Grow the Creation Garden", "2 Blank Sentinels", "Create a tree or light; choose colour; grow 3 glass seeds.", "What do you like about your creation?", "Perfect Blank opens."),
        ("Boss", "The Perfect Blank", "Boss + 2 Ink Sprites", "Create cover; stop eraser waves; attack blank core.", "Will you share one unfinished picture?", "Creator’s Light."),
    ]
    add_data_table(doc, ("#", "Quest", "Required fight", "Other tasks", "Short choice", "Unlock"), quest_rows, [0.42, 1.08, 1.18, 1.74, 1.46, 0.62], compact=True, centre_columns=(0,))
    doc.add_heading("Boss alignment", level=2)
    add_numbered_sequence(doc, (
        "Begin: place a bridge, shield, or light stamp so the player can reach the arena core.",
        "Try again: dodge eraser waves, rebuild one removed object, and defeat the Ink Sprites.",
        "Share: strike the exposed Blank core during two openings, then place an unfinished picture into the final frame.",
    ))
    doc.add_heading("World Three result", level=2)
    add_bullet(doc, "The empty space grows into a landscape using colours and shapes chosen by the player.")
    add_bullet(doc, "The player reaches Level 5 by the end of the world and receives one post-game skill point.")
    add_bullet(doc, "The Creator’s Light completes the treasure set and opens the Art Castle finale.")

    # COMBAT / XP
    add_section_intro(
        doc,
        "Part 5",
        "Combat, Monsters & XP Across Three Worlds",
        "The normal enemies change their art and one main attack, but reuse only two Godot script templates.",
    )
    monster_rows = [
        ("W1", "Static Mite", "MobileEnemyBase", "25", "10", "Ground lunge; one sword hit."),
        ("W1", "Glitch Sprout", "GuardEnemyBase", "50", "15", "Seed shot; open core after firing."),
        ("W2", "Echo Moth", "MobileEnemyBase", "50", "20", "Flying sound ring; block or dodge."),
        ("W2", "Rhythm Golem", "GuardEnemyBase", "75", "30", "Two-beat ground slam; attack during pause."),
        ("W3", "Ink Sprite", "MobileEnemyBase", "25", "10", "Ink dash; one sword hit after the dash."),
        ("W3", "Blank Sentinel", "GuardEnemyBase", "75", "30", "Eraser shield; attack when the frame opens."),
    ]
    add_data_table(doc, ("World", "Enemy", "Shared script", "HP", "XP", "One main attack"), monster_rows, [0.6, 1.2, 1.45, 0.5, 0.5, 2.25], compact=True, centre_columns=(0, 3, 4))
    doc.add_heading("Boss scope", level=2)
    boss_rows = [
        ("Thought Storm Warden", "200 core HP", "Anchors → pattern → two damage openings → Hope action", "50 XP + Star"),
        ("Silent Conductor", "200 core HP", "Instruments → sound rhythm → two damage openings → harmony chord", "75 XP + Jewel"),
        ("Perfect Blank", "200 core HP", "Create cover → eraser pattern → two damage openings → unfinished art", "100 XP + Light"),
    ]
    add_data_table(doc, ("Boss", "Health", "Three-stage structure", "Reward"), boss_rows, [1.45, 0.9, 3.2, 0.95], compact=True, centre_columns=(1,))
    doc.add_heading("Level plan", level=2)
    level_rows = [
        ("1", "0 XP", "Start: light attack, block, dodge, 100 health."),
        ("2", "100 XP", "After World One: 110 health."),
        ("3", "250 XP", "During or after World Two: strong sword attack."),
        ("4", "430 XP", "During World Three: perfect block can return a projectile."),
        ("5", "600 XP", "End of World Three: post-game skill point and free travel."),
    ]
    add_data_table(doc, ("Level", "Total XP", "Reward"), level_rows, [0.75, 1.05, 4.7], centre_columns=(0, 1))
    add_bullet(doc, "Each of the six normal quests gives 15 completion XP. Required fights, three bosses, and these six rewards give about 645 XP in total.")
    add_bullet(doc, "The player reaches Level 2 after World One, Level 3 in World Two, Level 4 in World Three, and Level 5 after the final boss. No grinding is needed.")
    add_bullet(doc, "Keep a maximum of three normal enemies active in the short campaign, or two normal enemies during a boss phase.")
    add_bullet(doc, "Player defeat returns to the last checkpoint with XP, treasures, completed tasks, and solved puzzles kept.")

    # GODOT
    add_section_intro(
        doc,
        "Part 6",
        "Godot 4.7 Production Plan",
        "The three-world campaign stays possible by sharing code, limiting unique systems, and building pre-authored content instead of expensive procedural technology.",
    )
    add_callout(
        doc,
        "CURRENT PROJECT FIT",
        "The ARTÉA player already has health, sword attack, block, Area3D hit detection, and take_damage(amount, source). All enemies and bosses should use this contract.",
    )
    godot_rows = [
        ("MobileEnemyBase.tscn", "CharacterBody3D, simple collision, detection Area3D, attack Area3D, optional hover setting, AnimationPlayer, health, XP, and one attack timer."),
        ("GuardEnemyBase.tscn", "CharacterBody3D, simple collision, open/closed hurt state, AnimationPlayer, health, XP, and one ranged, slam, or shield attack."),
        ("BossBase.tscn", "CharacterBody3D, 200 core HP, phase enum, two core openings, three interaction nodes, checkpoint signal, reward signal, and final non-killing interaction."),
        ("CampaignState", "Stores world completion, treasure ownership, train routes, level, XP, quest steps, checkpoints, optional answers, and post-game free travel."),
        ("Crown Railway", "A short real ride scene with destination lock states. Before World One: no ride action. After each treasure: add only the next route."),
        ("Mind Spark puzzle", "Three selectable pattern points, four Sparks, two nodes, simple choice UI, and two world lighting states."),
        ("Heart Melody puzzle", "Four pre-recorded sound loops, quantized buttons, three instruments, moving platforms, and one combined final chord."),
        ("Creator’s Light tool", "Use four prebuilt object stamps—bridge, door, tree, light—with chosen colour/material. Do not generate arbitrary 3D meshes from drawings."),
        ("Renderer limits", "For mobile/GL Compatibility: low-poly meshes, 1–2 materials per enemy, simple shadows, short particles, limited transparent layers, and LOD meshes."),
    ]
    add_data_table(doc, ("Godot item", "Implementation rule"), godot_rows, [1.65, 4.85], compact=True)
    doc.add_heading("Build order", level=2)
    add_numbered_sequence(doc, (
        "Finish the town, castle entrance, locked railway, and Mind Spark World Gate state.",
        "Build the two shared enemy bases and prove all six enemy variations work with the current sword.",
        "Build one BossBase and test the Mind Spark boss before making the other boss variations.",
        "Finish the full World One loop and first train unlock.",
        "Add Heart Melody using pre-recorded sounds and existing platform systems.",
        "Add Creator’s Light using prebuilt stamps and colour/material choices.",
        "Connect the three treasures, Castle finale, identity choice, Crown of Life, and free travel.",
        "Test the 55–70 minute target, mobile frame rate, saving, checkpoints, combat assist, and reduced motion.",
    ))
    add_callout(
        doc,
        "DO NOT OVERBUILD",
        "Do not create a full procedural music engine, AI drawing-to-3D system, six separate enemy codebases, or three different train systems for this short campaign.",
        fill="FFF6D8",
        accent=GOLD,
    )

    # FINALE / ACCEPTANCE
    add_section_intro(
        doc,
        "Part 7",
        "Castle Finale & Acceptance Checklist",
        "The final 5–7 minutes bring the three discoveries together without adding a fourth full world.",
    )
    doc.add_heading("Finale sequence", level=2)
    add_numbered_sequence(doc, (
        "The train returns from Creator’s Light and enters Celebration Mode.",
        "The player places the Creator’s Light beside the Star of Wisdom and Harmony Jewel.",
        "The three treasures become the Light of Identity.",
        "Milo shows two or three friendly identity suggestions based on saved choices.",
        "The player chooses one, selects another, or chooses ‘I am still discovering.’",
        "The Maker creates the Crown of Life and reminds the player that the treasures did not create their value.",
        "A star receives the player’s chosen name or symbol. Free railway travel and world replay open.",
    ))
    add_callout(
        doc,
        "FINAL MESSAGE",
        "Your story matters. You are uniquely created. Your light has a place in this universe.",
        fill="FFF6D8",
        accent=GOLD,
    )
    doc.add_heading("The campaign is ready when", level=2)
    checks = (
        "A normal first playthrough finishes in 55–70 minutes, including all three worlds and the Castle finale.",
        "World One can be entered without riding the train, and the train stays sealed until the Star is placed.",
        "Each world contains exactly two short quests, two normal enemy families, and one three-stage boss.",
        "All required fights and story rewards give enough XP to reach Level 5 without grinding.",
        "The player can finish the story after a defeat without losing XP, treasure, solved puzzles, or completed tasks.",
        "Feelings, thoughts, creativity, Milo, guardians, and friendly creatures are never attack targets.",
        "Heart Melody uses pre-recorded sounds and Creator’s Light uses prebuilt object stamps, keeping both systems practical in Godot.",
        "World completion, treasure placement, train routes, levels, XP, checkpoints, and the finale save and load correctly.",
        "No normal encounter has more than three enemies, and the project meets the mobile/GL Compatibility frame-rate target.",
        "Subtitles, larger text, symbols, combat assist, reduced motion, checkpoints, optional reflection, and skip work correctly.",
    )
    for item in checks:
        add_check(doc, item)

    # BACK PAGE
    doc.add_page_break()
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(70)
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("ARTÉA  •  THE COMPLETE SHORT JOURNEY")
    set_run(r, size=11, bold=True, color=VIOLET)
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("THINK  •  FEEL  •  CREATE")
    set_run(r, size=28, bold=True, color=MIDNIGHT)
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(28)
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("Mind Spark")
    set_run(r, size=18, bold=True, color=DEEP_CYAN)
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("Understand your thoughts.")
    set_run(r, size=12, italic=True, color=MUTED)
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(20)
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("Heart Melody")
    set_run(r, size=18, bold=True, color=VIOLET)
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("Give your feelings a safe voice.")
    set_run(r, size=12, italic=True, color=MUTED)
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(20)
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("Creator’s Light")
    set_run(r, size=18, bold=True, color=GOLD)
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("Create with courage, not perfection.")
    set_run(r, size=12, italic=True, color=MUTED)
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(40)
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("55–70 MINUTES  •  THREE TREASURES  •  ONE CONNECTED STORY")
    set_run(r, size=12, bold=True, color=DEEP_CYAN)

    for paragraph in doc.paragraphs:
        if paragraph.style and paragraph.style.name.startswith("Heading"):
            paragraph.paragraph_format.keep_with_next = True
        paragraph.paragraph_format.widow_control = True
    for table in doc.tables:
        if table.rows:
            set_repeat_table_header(table.rows[0])

    doc.save(OUT)
    print(OUT)


if __name__ == "__main__":
    build_document()
