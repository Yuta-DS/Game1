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
    GRID,
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
    add_section_intro,
    configure_document,
    format_cell_text,
    picture_with_alt,
    prevent_row_split,
    set_cell_margins,
    set_repeat_table_header,
    set_run,
    set_table_borders,
    set_table_geometry,
    shade_cell,
)


ROOT = Path("/Users/davidsovann/S2603/artea")
OUT = Path("/Users/davidsovann/Documents/World_One_Mind_Spark_Concise_Developer_Guide_with_Identity_System.docx")
ART = ROOT / "artifacts" / "mind_spark_world_reference"
HERO = ART / "mind_spark_professional_world_concept_v3.png"
KEY_BLUEPRINT = ART / "mind_spark_key_objects_architecture_blueprint_v1.png"
CONSTRUCTION_BLUEPRINT = ART / "mind_spark_reduced_world_construction_blueprint_v1.png"
QUEST_BLUEPRINT = ART / "mind_spark_reduced_quest_magic_blueprint_v1.png"
CHARACTER_BLUEPRINT = ART / "mind_spark_reduced_characters_dressing_blueprint_v5_mayor_milo.png"
COMBAT_BLUEPRINT = ART / "mind_spark_static_blight_enemy_boss_blueprint_v1.png"


def add_section_intro(doc, part, title, summary):
    """Start a section without an empty continuation page when the prior page is full."""
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
            size=8.2 if compact else 9.2,
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
                size=7.8 if compact else 9.0,
                bold=(index == 0),
                color=MIDNIGHT if index == 0 else INK,
                align=WD_ALIGN_PARAGRAPH.CENTER if index in centre_columns else WD_ALIGN_PARAGRAPH.LEFT,
            )
            set_cell_margins(cells[index], top=45 if compact else 70, start=70, bottom=45 if compact else 70, end=70)
    return table


def add_story_scene(doc, heading, location, objective, narrative):
    h = doc.add_heading(heading, level=2)
    h.paragraph_format.space_after = Pt(2)
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(4)
    r = p.add_run(f"{location}  •  {objective}")
    set_run(r, size=9.2, bold=True, color=DEEP_CYAN)
    p = doc.add_paragraph(narrative)
    p.paragraph_format.space_after = Pt(8)
    return p


def add_blueprint_sheet(doc, plate, title, summary, image_path, alt, rows):
    add_section_intro(doc, plate, title, summary)
    picture_with_alt(doc, image_path, Inches(6.5), alt)
    add_caption(doc, "Numbered blueprint sheet. Match each picture number to the object list below.")
    add_data_table(
        doc,
        ("ID", "Object / group", "What it does", "What the developer builds"),
        rows,
        [0.42, 1.48, 1.85, 2.75],
        compact=True,
        centre_columns=(0,),
    )


def build_document():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    doc = Document()
    configure_document(doc)
    doc.core_properties.title = "World One: Mind Spark - Simple Story, Identity System and Developer Guide"
    doc.core_properties.subject = "Player journey, identity tracking, quests, sword combat, boss encounter, world layout, and object guide"
    doc.core_properties.comments = "Simple-language edition with Mayor Milo, a child-safe 16-identity tracking system, the Art Castle as the main hub, and the Crown Railway unlocked after World One."

    # COVER
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(6)
    p.paragraph_format.space_after = Pt(2)
    r = p.add_run("ARTÉA  •  WORLD ONE SIMPLE DEVELOPER GUIDE")
    set_run(r, size=10, bold=True, color=VIOLET)
    p = doc.add_paragraph(style="Title")
    r = p.add_run("MIND SPARK")
    set_run(r, size=34, bold=True, color=MIDNIGHT)
    p = doc.add_paragraph(style="Subtitle")
    r = p.add_run("Player Story, Quests, Combat, Boss & World Building Guide")
    set_run(r, size=13.5, color=DEEP_CYAN)
    picture_with_alt(
        doc,
        HERO,
        Inches(6.5),
        "Professional isometric concept for Mind Spark, a floating living computer forest with logic plazas, a Thought Storm and the Oldest Tree sanctuary.",
    )
    add_caption(doc, "World One direction: Technology and Science lead. Nature and Magic support them.")
    add_callout(
        doc,
        "SIMPLE EDITION",
        "This guide keeps the agreed world identity while using a smaller, clearer set of quests, enemies, and objects. It also begins the player’s journey toward one of 16 friendly game identities.",
    )
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("Version 2.2  •  14 August 2026  •  Prepared for David Sovann and the ARTÉA team")
    set_run(r, size=9, color=MUTED)

    # ORIENTATION
    add_section_intro(
        doc,
        "Guide orientation",
        "What is inside this guide",
        "This guide follows the player from the town to the Art Castle, through Mind Spark, and to the first train unlock. It also explains four quests, sword combat, the boss, and five blueprint sheets.",
    )
    doc.add_heading("Recommended world scope", level=2)
    add_callout(
        doc,
        "TARGET",
        "4 main quests • 10 required tasks • 8 short identity clues inside existing scenes • 5 enemy types • 1 combat-puzzle boss • Levels 1–5 • 6 required Thought Sparks • About 55–70 minutes for the first playthrough.",
    )
    doc.add_heading("Contents", level=2)
    for item in (
        "1. Mind Spark identity",
        "1B. Player identity tracking for the 16 friendly identities",
        "2. The player’s journey from the town through World One",
        "3. Four quests, tasks, time, and unlock steps",
        "4. Sword combat, monsters, XP, and player levels",
        "5. The Thought Storm Warden boss encounter",
        "6. The world path and building scope",
        "7. Five numbered blueprint sheets and object lists",
        "8. Simple art, sound, UI, access, and programming rules",
    ):
        add_bullet(doc, item)
    doc.add_heading("How the smaller plan works", level=2)
    add_bullet(doc, "The first plan had eight quests. This guide combines them into four clear quests.")
    add_bullet(doc, "The world keeps every type of object. Repeated objects use the same base model with small changes.")
    add_bullet(doc, "Five enemy types reuse one shared Static Blight material and effect family.")
    add_bullet(doc, "The boss has three stages. Each stage combines sword combat with a skill learned earlier.")
    add_bullet(doc, "Eight short identity clues reuse existing dialogue and quest moments, so they add no new quest and do not increase the 55–70 minute target.")
    add_callout(
        doc,
        "MAIN STORY RULE",
        "The player fights the Static Blight that has trapped the world. The player does not fight thoughts or feelings. Defeated creatures break into clean light and return their energy to nature.",
        fill="FFF6D8",
        accent=GOLD,
    )

    # IDENTITY
    add_section_intro(
        doc,
        "Part 1",
        "Mind Spark Identity",
        "A world where Technology and Science lead. Nature makes it feel alive, and Magic gives it wonder.",
    )
    identity_rows = [
        ("World", "Mind Spark Kingdom"),
        ("Theme", "I can understand my thoughts."),
        ("Dominant force", "Technology / Science"),
        ("Supporting forces", "Nature and Magic"),
        ("Treasure", "Star of Wisdom"),
        ("Guide", "Mayor Milo Cat, the wise elder town leader and fatherly guide"),
        ("Guardian", "Guardian of Clear Thinking / Everlasting Father"),
        ("Next unlock", "The Crown Railway itself, then the route to Heart Melody, World Two"),
    ]
    add_data_table(doc, ("Identity field", "Approved direction"), identity_rows, [1.85, 4.65])
    doc.add_heading("How the three forces work together", level=2)
    add_bullet(doc, "Technology and Science lead (about 60%): server trees, thought maps, logic gates, circuits, scanners, and the train system.", bold_lead="Technology and Science lead (about 60%):")
    add_bullet(doc, "Nature supports (about 25%): roots, rain, flowers, lavender trees, pools, and new growth make the world feel warm and alive.", bold_lead="Nature supports (about 25%):")
    add_bullet(doc, "Magic supports (about 15%): Thought Sparks, the Truth Path, the Guardian, and the Star of Wisdom make the world feel special.", bold_lead="Magic supports (about 15%):")
    add_callout(doc, "WORLD IDEA", "A living computer forest where thoughts grow like stars and wisdom changes the path.")
    doc.add_heading("Important tone rules", level=2)
    for item in (
        "Sword fighting is clear and family-friendly. There is no blood or gore.",
        "Enemies show their attack before it happens. A defeat returns the player to the last safe node with no XP loss.",
        "The player attacks Static Blight shells, never thoughts, feelings, Milo, the Guardian, or friendly creatures.",
        "Gold shows wisdom, success, and the way forward.",
        "The path and tasks must stay easy to see during rain, lights, and effects.",
        "Every main object should mix Technology, Nature, and Magic.",
    ):
        add_bullet(doc, item)

    # PLAYER IDENTITY TRACKING
    add_section_intro(
        doc,
        "Part 1B",
        "Player Identity Tracking System",
        "World One quietly records the first clues toward one of 16 friendly game identities. It does not decide or reveal the player’s final identity.",
    )
    add_callout(
        doc,
        "IDENTITY PROMISE",
        "The identity is a guide, not a box. No identity is better than another. The game suggests two or three possibilities only after all three worlds, and the player makes the final choice. The player may choose ‘I am still discovering’ or change the result later.",
        fill="FFF6D8",
        accent=GOLD,
    )
    doc.add_heading("What World One measures", level=2)
    axis_rows = [
        ("Social energy", "Together (E)", "Quiet (I)", "Does the player prefer to think with others or first think privately?"),
        ("How ideas are noticed", "Possibility (N)", "Detail (S)", "Does the player look for hidden connections or begin with what can be seen now?"),
        ("How choices are weighed", "Logic (T)", "Care (F)", "Does the player first weigh a clear reason or the effect on people and living things?"),
        ("How action begins", "Planned (J)", "Flexible (P)", "Does the player prefer an order first or adjust while discovering?"),
    ]
    add_data_table(
        doc,
        ("Scale", "One friendly direction", "Other friendly direction", "Simple meaning"),
        axis_rows,
        [1.25, 1.25, 1.25, 2.75],
        compact=True,
    )
    add_callout(
        doc,
        "NEVER SCORE THESE",
        "Do not use right or wrong puzzle answers, combat skill, damage taken, deaths, play speed, hints, camera settings, accessibility options, or skipped dialogue as identity evidence.",
        fill="F1ECFB",
        accent=VIOLET,
    )
    doc.add_heading("Eight World One identity moments", level=2)
    identity_moment_rows = [
        ("MS_ID_01", "Town meeting", "Talk through the mission with Milo.", "Look at the map quietly first.", "E / I"),
        ("MS_ID_02", "Arrival Grove", "Explore beside Milo and share ideas.", "Inspect first, then report to Milo.", "E / I"),
        ("MS_ID_03", "Living Network", "Try a connection that may wake the whole network.", "Follow the visible powered roots step by step.", "N / S"),
        ("MS_ID_04", "Pattern Court", "Look for the meaning of the whole shape.", "Check each point and line one at a time.", "N / S"),
        ("MS_ID_05", "Truth Gate", "Choose the clearest reason that solves the fault.", "Choose what best protects the living world.", "T / F"),
        ("MS_ID_06", "Hope Garden", "Choose the most useful next action.", "Choose the most supportive next action.", "T / F"),
        ("MS_ID_07", "Before repairs", "Choose a repair order before starting.", "Start safely and adjust as clues appear.", "J / P"),
        ("MS_ID_08", "Boss preparation", "Set an order for the three anchors.", "Respond to the safe anchor as it opens.", "J / P"),
    ]
    add_data_table(
        doc,
        ("Event ID", "Story moment", "Choice A", "Choice B", "Clue"),
        identity_moment_rows,
        [0.72, 1.0, 1.85, 1.85, 0.58],
        compact=True,
        centre_columns=(0, 4),
    )
    add_bullet(doc, "Both choices must be helpful, respectful, and able to finish the same quest. There is no correct identity choice.")
    add_bullet(doc, "Add a neutral ‘Not sure / Skip’ choice. It records no point and never blocks progress.")
    add_bullet(doc, "Each event gives +1 to one direction only. Save one answer per Event ID so replaying a scene cannot add more points.")
    add_bullet(doc, "If the player changes an answer during a later reflection, remove the old point before adding the new point.")

    doc.add_heading("How World One saves the clues", level=2)
    add_data_table(
        doc,
        ("Saved field", "Type", "Purpose"),
        [
            ("identity_version", "int", "Starts at 1 so future scoring changes can be migrated safely."),
            ("identity_scores", "Dictionary", "Eight integer totals: E, I, N, S, T, F, J, and P."),
            ("identity_evidence", "Dictionary", "One record per Event ID with world, selected direction, choice ID, and short reason."),
            ("identity_world_counts", "Dictionary", "Stores completed, answered, and skipped identity moments for each world."),
            ("suggested_identity_ids", "Array", "Empty during World One. Stores two or three results after World Three."),
            ("chosen_identity_id", "String", "Empty until the player chooses at the Castle finale."),
            ("still_discovering", "bool", "True when the player does not want to choose an identity yet."),
        ],
        [1.7, 0.85, 3.95],
        compact=True,
    )
    add_callout(
        doc,
        "WORLD ONE RESULT",
        "At the Star of Wisdom scene, save the eight clues and show only a gentle strength reflection, such as ‘You looked closely’ or ‘You made room for support.’ Do not show a four-letter code, ranking, identity meter, or final identity yet.",
    )

    doc.add_heading("The 16 friendly game identities", level=2)
    game_identity_rows = [
        ("The Guiding Light", "ENFJ", "Help people grow and believe in themselves."),
        ("The Quiet Visionary", "INFJ", "See hidden meaning and bring deep healing."),
        ("The Joyful Creator", "ENFP", "Use imagination and bring hope to others."),
        ("The Gentle Peacemaker", "INFP", "Create safe spaces and help dreams grow."),
        ("The Bold Architect", "ENTJ", "Build strong plans and lead toward a better future."),
        ("The Wise Strategist", "INTJ", "Understand difficult problems and find a clear path."),
        ("The Bright Spark", "ENTP", "Try new ideas and discover clever ways forward."),
        ("The Deep Thinker", "INTP", "Understand how things work and search for truth."),
        ("The Warm Guardian", "ESFJ", "Care for people and help them feel they belong."),
        ("The Faithful Shield", "ISFJ", "Protect others and support their hearts."),
        ("The Radiant Star", "ESFP", "Bring joy, colour, and energy into the world."),
        ("The Silent Artist", "ISFP", "Create beauty and express feelings through art."),
        ("The Steadfast Builder", "ESTJ", "Bring order, solve problems, and build strong teams."),
        ("The Loyal Keeper", "ISTJ", "Protect good things and be honest and dependable."),
        ("The Fearless Explorer", "ESTP", "Act with courage and help others face challenges."),
        ("The Calm Craftsman", "ISTP", "Fix problems, make useful things, and stay calm."),
    ]
    add_data_table(
        doc,
        ("Friendly player identity", "Internal code", "Simple purpose"),
        game_identity_rows,
        [2.0, 1.0, 3.5],
        compact=True,
        centre_columns=(1,),
    )
    add_bullet(doc, "The child-facing game shows only the friendly name and purpose. The four-letter code is internal developer information or optional adult-guide information.")
    add_bullet(doc, "The four letters are created from the stronger direction on each scale. A tie is uncertainty, not an error.")

    doc.add_heading("Godot 4.7 implementation", level=2)
    identity_godot_rows = [
        ("Autoload", "Create PlayerIdentityTracker.gd as an Autoload. Keep it separate from XP, combat, and quest success."),
        ("Record", "record_choice(event_id, world_id, axis, direction, choice_id, reason) must replace, not duplicate, an existing Event ID."),
        ("Save", "CampaignState saves the tracker data with the player profile after every identity choice, safe node, world completion, and Castle return."),
        ("World balance", "Each world should provide two moments for every scale: eight clues per world and 24 possible clues across the full campaign."),
        ("Final suggestion", "After World Three, choose the stronger direction on each scale. If a scale is tied or only one point apart, create nearby alternatives by changing that uncertain letter. Rank and show two or three friendly identities."),
        ("Player control", "Milo explains the suggestions in simple words. The player selects one, chooses ‘I am still discovering,’ or reviews all 16. A later menu allows change."),
        ("Testing", "Add a developer-only panel that shows events, totals, ties, suggestions, and save/load results. Never include this score panel in the child-facing release."),
    ]
    add_data_table(doc, ("System part", "Developer rule"), identity_godot_rows, [1.4, 5.1], compact=True)
    add_callout(
        doc,
        "CHILD-SAFE RULE",
        "Treat this as a playful reflection system, not a test, diagnosis, school grade, hiring tool, or measure of value. Store the minimum information needed. Do not send identity data online without clear parent or guardian permission.",
        fill="FFF6D8",
        accent=GOLD,
    )

    # PLAYER JOURNEY AS CONTINUOUS STORY
    add_section_intro(
        doc,
        "Part 2",
        "The Player’s Journey Through Mind Spark",
        "This story begins in the town. Mayor Milo guides the player to the Art Castle. The train stays locked until the player saves Mind Spark.",
    )
    doc.add_heading("Journey overview", level=2)
    doc.add_paragraph(
        "A strange Static Blight has spread from the Art Castle. It mixes broken machines, wild roots, and unstable magic into monsters. Mayor Milo asks the player for help because the player’s crystal sword can break the dark Blight shell without harming the living world inside. The player enters Mind Spark through the first World Gate, defeats the creatures, repairs the wisdom systems, and faces the Thought Storm Warden. When the Star of Wisdom is restored, the Crown Railway wakes for the first time and becomes the travel system for later worlds."
    )

    add_story_scene(
        doc,
        "Opening — Meet Mayor Milo",
        "Town Square",
        "Meet the mayor and accept his request",
        "The player arrives in the town with a crystal sword. The streets are quiet, and small pieces of violet static move near the drains and roots. Mayor Milo waits in the square. He is an old, wise cat with a silver moustache, glasses, a mayor’s chain, and the Art Castle key. Milo explains that creatures have appeared near the castle and the town is losing power. He asks, ‘Will you help me wake the castle and protect our town?’ The player agrees. Milo gives the player a small map and leads the way.",
    )
    add_story_scene(
        doc,
        "Walk to the Art Castle",
        "Town Road and Castle Entrance",
        "Follow Milo and learn the basic controls",
        "The player follows Milo through the town. Short signs teach walking, looking, dodging, and using the sword. Two weak Static Mites block the final bridge. Milo stays behind the safe line while the player defeats them. The creatures break into clean cyan light, and the roots below them become healthy again. This shows that the sword removes the Blight shell instead of hurting nature. Milo uses the town key, and the large Art Castle doors open.",
    )
    add_story_scene(
        doc,
        "The Game Begins — Enter the Art Castle",
        "Main Gallery and Locked Crown Railway",
        "See the problem and open the first World Gate",
        "Inside the castle, the player sees empty Star displays and a beautiful train behind a dark glass seal. Milo explains that this is the Crown Railway, but it has no power. It cannot be ridden yet. The first Star must wake the train. A violet signal then moves across the Gallery and opens the Mind Spark World Gate. Milo says the Star of Wisdom has stopped protecting its world. Without it, the Thought Storm has covered the land and created Static Blight monsters. Milo asks the player to recover the Star so the town, the castle, and the railway can live again.",
    )
    add_story_scene(
        doc,
        "World Entry — Milo explains the mission",
        "Mind Spark Arrival Grove",
        "Enter World One and receive the four goals",
        "The player and Milo walk through the gate together. They arrive in a floating forest of server trees, glowing roots, and lavender plants. The Thought Storm covers the Oldest Tree. Milo stays at the safe entrance beside a Mayor’s Beacon and gives hints from there. He explains four goals: clear the Static Blight, collect six Thought Sparks, repair the Wisdom Path, and defeat the Warden. Then the Star and return gate can open.",
    )
    add_story_scene(
        doc,
        "Quest 1 — Wake the Living Network",
        "Arrival Grove and Living Server Forest",
        "Learn combat, restore two nodes, and collect three Sparks",
        "Static Mites and Glitch Sprouts guard two forest power nodes. The player learns a light attack, strong attack, dodge, and safe-node healing. After each fight, clean energy returns to the roots. The player repairs both nodes and collects three Thought Sparks. Milo explains that a Spark is not an enemy; it is wisdom that must be carried safely. The third Spark opens the Constellation Court.",
    )
    add_story_scene(
        doc,
        "Quest 2 — Read the Broken Pattern",
        "Constellation Court and Logic Plaza",
        "Fight new monsters, solve the pattern, and collect proof",
        "Circuit Wisps attack from the air, and Root Stalkers charge across the court. The player learns to deflect a spark shot and dodge a charge to expose the rear core. After the fight, the player moves three thought points into a clear pattern. The Logic Gate asks if the signal is a fact now or a fear about later. Proof pieces and the final three Sparks open the Truth Gate.",
    )
    add_story_scene(
        doc,
        "Quest 3 — Build the Hope Path",
        "Truth Gate and Hope Garden",
        "Defeat the elite guard and build a path to the storm",
        "A Blight Sentinel blocks the Truth Gate. The player dodges its shield slam and strikes the open chest core. The Sentinel becomes clean gold and cyan light. The player turns the Truth rings and chooses another answer that may also be true. Three Hope tiles—helpful thought, small action, and support—grow a new path toward the storm.",
    )
    add_story_scene(
        doc,
        "Quest 4 — Defeat the Thought Storm Warden",
        "Thought Storm Arena",
        "Use sword skill and clear thinking in the boss battle",
        "The Warden is a large shell of dark glass, roots, and storm energy. The player defeats summoned monsters, powers three focus anchors, solves the shield pattern, and attacks the exposed core. At zero boss health, the player places the final Hope tile instead of making a killing blow. The shell breaks into light, the Guardian is freed, and the storm becomes gentle rain.",
    )
    add_story_scene(
        doc,
        "Finale — The Star of Wisdom",
        "Oldest Tree Sanctuary",
        "Receive the treasure and return through the World Gate",
        "Gentle rain wakes the Oldest Tree, and the Star of Wisdom appears. The Guardian says, ‘You had the courage to protect this world, understand the truth, and choose hope.’ The game saves the player’s first identity clues, but does not choose an identity yet. Milo shares one simple strength he noticed. The player receives the Star and reaches Level 5. The player and Milo return through the World Gate and place the Star in the Gallery. The dark railway seal opens, the train lights turn on for the first time, and Heart Melody appears on the route map. The player has earned train travel between completed and unlocked worlds.",
    )

    # QUEST ALIGNMENT
    add_section_intro(
        doc,
        "Part 3",
        "Quest, Task & Story Plan",
        "Four clear quests move the story forward. Required fights give enough XP to reach the right level without grinding.",
    )
    quest_rows = [
        ("1", "Wake the Living Network", "4 Mites + 2 Sprouts", "50", "12–15 min", "Repair 2 nodes and collect 3 Sparks.", "Court opens; Level 2."),
        ("2", "Read the Broken Pattern", "2 Wisps + 2 Stalkers", "75", "14–17 min", "Fix the pattern; collect proof and 3 Sparks.", "Truth Gate opens; Level 3."),
        ("3", "Build the Hope Path", "2 Stalkers + 1 Sentinel", "100", "12–15 min", "Choose another truth and place 3 Hope tiles.", "Boss path opens; Level 4."),
        ("4", "Defeat the Storm Warden", "Boss + up to 3 Mites", "50", "17–23 min", "Break 3 anchors; attack the core; place Hope.", "Star and train unlock; Level 5."),
    ]
    add_data_table(
        doc,
        ("#", "Quest", "Required fights", "Quest XP", "Time", "Other required actions", "What opens next"),
        quest_rows,
        [0.28, 1.02, 1.05, 0.52, 0.7, 1.62, 1.31],
        compact=True,
        centre_columns=(0, 2, 3, 4),
    )
    doc.add_heading("Five short questions", level=2)
    prompt_rows = [
        ("1", "Network", "Which root still has no power?", "Teach the player to read cyan power lines."),
        ("2", "Pattern", "Which point makes the lines clear?", "Teach the pattern action used in the boss."),
        ("3", "Fear", "Is this happening now, or might it happen?", "Show the difference between fact and fear."),
        ("4", "Proof", "What do we know, and what is still missing?", "Teach the player to check proof."),
        ("5", "Hope", "What is one small helpful next step?", "Build the Hope Path and finish the boss safely."),
    ]
    add_data_table(doc, ("#", "Stage", "Question for the player", "Why we ask it"), prompt_rows, [0.4, 0.9, 2.55, 2.65], centre_columns=(0,))
    add_callout(
        doc,
        "QUESTION RULE",
        "These are short game-learning choices, not school tests or identity questions. A wrong answer gives a hint and lets the player try again. Puzzle correctness never changes an identity score. Only the five story choices are required.",
        fill="F1ECFB",
        accent=VIOLET,
    )
    doc.add_heading("Steps that unlock World Two", level=2)
    add_numbered_sequence(
        doc,
        (
            "Complete the three story quests, collect all 6 Thought Sparks, and reach Level 4.",
            "Finish all 3 boss stages and remove the Warden’s Static Blight shell.",
            "Receive the Star of Wisdom and save the calm, rainy version of Mind Spark.",
            "Walk through the World Gate and place the Star in the Art Castle Gallery.",
            "The Crown Railway wakes for the first time. Heart Melody becomes the first train destination.",
        ),
    )

    # COMBAT AND XP
    add_section_intro(
        doc,
        "Part 4",
        "Sword Combat, Monsters & Player Levels",
        "The combat plan matches the current Godot player: 100 health, 25 sword damage, attack, block, and an Area3D sword hitbox.",
    )
    add_callout(
        doc,
        "GODOT SCOPE",
        "Build one reusable EnemyBase scene and five small enemy variations. Use simple low-poly meshes, one body collision shape, Area3D hit and hurt boxes, AnimationPlayer, and short state machines. Do not use cloth, physics bones, or heavy effects.",
    )
    monster_rows = [
        ("01", "Static Mite", "25", "10", "Idle → chase → lunge → recover", "One sword hit. Step aside from the clear lunge line."),
        ("02", "Glitch Sprout", "50", "15", "Hidden → aim → seed shot → open", "Two hits. Dodge the shot and strike the open gold core."),
        ("03", "Circuit Wisp", "50", "20", "Hover → aim → 3 spark shots → stunned", "Deflect a spark with the sword, then hit the stunned Wisp."),
        ("04", "Root Stalker", "75", "30", "Patrol → charge → missed charge → recover", "Dodge the charge and strike the bright rear core three times."),
        ("05", "Blight Sentinel", "150", "60", "Guard → shield slam → open core → guard", "Dodge the slam. Attack the chest only while the shield is open."),
        ("06", "Storm Warden", "300 core", "150", "Phase 1 → shield → exposed core → final Hope", "Break anchors, attack the core during three openings, then place Hope."),
    ]
    add_data_table(
        doc,
        ("ID", "Enemy", "HP", "XP", "Small state machine", "Player answer"),
        monster_rows,
        [0.38, 1.12, 0.62, 0.48, 1.85, 2.05],
        compact=True,
        centre_columns=(0, 2, 3),
    )
    doc.add_heading("Level plan — no grinding needed", level=2)
    level_rows = [
        ("1", "0 XP", "Start with light sword attack, block, dodge, and 100 health."),
        ("2", "100 XP", "Health rises to 110. Milo opens the first safe-node heal."),
        ("3", "250 XP", "Unlock the strong sword attack for stunned or open enemies."),
        ("4", "450 XP", "Perfect block can return a Circuit Wisp shot."),
        ("5", "700 XP", "World One complete. Gain one skill point for the next world."),
    ]
    add_data_table(doc, ("Level", "Total XP", "Simple reward"), level_rows, [0.75, 1.1, 4.65], centre_columns=(0, 1))
    add_bullet(doc, "Required quest fights and quest rewards give about 700 XP. Optional fights are only for practice and a small buffer.")
    add_bullet(doc, "Use a maximum of four normal enemies at one time. The boss may summon no more than three Mites.")
    add_bullet(doc, "If health reaches zero, reload the last safe node with full health. Keep XP, Sparks, solved puzzles, and opened shortcuts.")

    p = doc.add_paragraph()
    p.paragraph_format.page_break_before = True
    p.paragraph_format.space_after = Pt(3)
    r = p.add_run("PART 4 • GODOT BUILD NOTES")
    set_run(r, size=9.5, bold=True, color=VIOLET)
    h = doc.add_heading("Godot 4.7 Implementation Plan", level=1)
    h.paragraph_format.space_before = Pt(0)
    p = doc.add_paragraph("This plan uses systems already present in the ARTÉA project and keeps every monster small enough for the mobile/GL Compatibility renderer.")
    p.paragraph_format.space_after = Pt(10)
    set_run(p.runs[0], size=11, italic=True, color=MUTED)
    add_callout(
        doc,
        "CURRENT PROJECT CHECK",
        "The current player already has 100 health, 25 sword damage, attack, block, an Area3D sword hitbox, and take_damage(amount, source). EnemyBase should use this same contract.",
    )
    doc.add_heading("Reusable scene plan", level=2)
    godot_rows = [
        ("Shared base", "EnemyBase.tscn uses CharacterBody3D, simple CollisionShape3D, NavigationAgent3D, AnimationPlayer, Detection Area3D, Attack Area3D, and light particles. EnemyBase.gd stores health, damage, XP, target, cooldown, and take_damage(amount, source)."),
        ("Enemy variations", "Five scenes inherit EnemyBase and change mesh, size, stats, movement, and one attack. A shared Area3D projectile stores speed, damage, and lifetime. Do not copy the full enemy script."),
        ("Boss + performance", "One CharacterBody3D boss uses a three-stage enum, three anchors, one core hurt box, timers, and reward signals. For the mobile/GL Compatibility renderer, use low-poly meshes, 1–2 materials, simple shadows, limited particles, and LOD meshes."),
    ]
    add_data_table(doc, ("Godot item", "Implementation rule"), godot_rows, [1.55, 4.95], compact=True)
    doc.add_heading("Build in this order", level=2)
    add_numbered_sequence(
        doc,
        (
            "Create EnemyBase.tscn and prove that the current sword can damage it.",
            "Add chase, attack warning, attack, hit reaction, defeat, and XP signals.",
            "Make Static Mite first. Test one enemy, then test four at the same time.",
            "Inherit the base for Sprout, Wisp, Stalker, and Sentinel. Give each only one main attack.",
            "Create one shared projectile for the Sprout and Wisp.",
            "Build the Warden from the same damage rules, then add the three boss stages.",
            "Test checkpoints, saved XP, mobile frame rate, reduced motion, and combat assist.",
        ),
    )
    doc.add_heading("Small animation list", level=2)
    animation_rows = [
        ("Normal enemies", "Idle, move, attack warning, attack, hit, defeat. Use 4–6 short clips."),
        ("Special states", "Sprout open, Wisp stunned, Stalker missed charge, Sentinel shield open."),
        ("Warden", "Idle storm, summon, anchor hit, core open, core hit, kneel, transform to rain."),
    ]
    add_data_table(doc, ("Asset", "Required animations"), animation_rows, [1.55, 4.95], compact=True)
    add_callout(
        doc,
        "FEASIBILITY LIMIT",
        "Use simple shapes for collision and never animate every root or armour piece. The blueprint shows the look; the Godot model uses a small skeleton, shared materials, and light particles.",
        fill="FFF6D8",
        accent=GOLD,
    )

    # BOSS
    add_section_intro(
        doc,
        "Part 5",
        "The Thought Storm Warden Boss",
        "The boss is a sword battle and a world puzzle together. It checks combat, pattern reading, and the Hope choice learned in the first three quests.",
    )
    add_callout(
        doc,
        "BOSS RULE",
        "The player attacks the Warden’s dark Blight armour and exposed core. The final action is a Hope choice, not a killing blow. The Guardian is freed, and the storm becomes gentle rain.",
        fill="F1ECFB",
        accent=VIOLET,
    )
    boss_rows = [
        ("1 — Focus", "Defeat up to 3 Mites and switch on 3 focus anchors.", "The storm slows, the Warden lands, and its shield pattern becomes visible.", "Quest 1 taught combat, nodes, and following powered roots."),
        ("2 — Break the shield", "Dodge storm lines, move 3 pattern points, and strike each matching anchor.", "The shield breaks and opens the gold chest core for a short time.", "Quest 2 taught patterns, proof, deflection, and weak points."),
        ("3 — Free the Guardian", "Damage the core during 3 openings. At zero boss HP, place the final Hope tile.", "The Blight shell dissolves, the Guardian is freed, and the storm becomes rain.", "Quest 3 taught the Hope Path and the meaning of the final choice."),
    ]
    add_data_table(doc, ("Stage", "What the player does", "What changes", "Skill used"), boss_rows, [1.0, 2.0, 1.9, 1.6])
    doc.add_heading("How the boss should feel", level=2)
    add_bullet(doc, "Start: the Warden is large and powerful, but every attack has a clear cyan or violet warning.")
    add_bullet(doc, "Combat: sword hits must feel strong. Use a brief flash, sound, small pause, and simple knockback. Do not use blood or gore.")
    add_bullet(doc, "Progress: every broken anchor removes one storm layer and reveals more of the Oldest Tree.")
    add_bullet(doc, "Defeat: reload the arena checkpoint with the player’s XP, Sparks, and completed quests kept.")
    add_bullet(doc, "Finish: the Warden kneels at zero HP and waits for the Hope action. Violet wind becomes rain and gold light.")
    add_bullet(doc, "Reduced motion: use slow clear rings and gentle particles instead of a fast spiral.")
    doc.add_heading("Reward steps", level=2)
    add_numbered_sequence(
        doc,
        (
            "The Warden gives 150 XP and the player reaches Level 5.",
            "The storm becomes gentle rain, and a path grows to the Oldest Tree.",
            "The Star of Wisdom appears, and the Guardian thanks the player.",
            "The player walks through the World Gate and places the Star in the Gallery.",
            "The Crown Railway turns on for the first time, and Heart Melody becomes available.",
        ),
    )

    # WORLD ROUTE / COMPACT PRODUCTION SCOPE
    add_section_intro(
        doc,
        "Part 6",
        "World Path & Smaller Building Plan",
        "Mind Spark has six connected areas. Reusing the same object families keeps the world beautiful and lowers the work needed to build it.",
    )
    route_rows = [
        ("0", "Town + Art Castle", "Meet Mayor Milo, fight 2 tutorial Mites, enter the castle, and see the locked train.", "Town square, road, bridge, castle doors, Main Gallery, World Gate, sealed train."),
        ("1", "World Gate + Arrival Grove", "Walk into Mind Spark with Milo and see the storm and Oldest Tree.", "World Gate, arrival bridge, Mayor’s Beacon, entry arch, root light."),
        ("2", "Living Server Forest", "Collect main and optional Sparks; learn their shapes.", "Server trees, glowing roots, lavender and green plants, guide posts."),
        ("3", "Constellation + Logic Plaza", "Fix a pattern, choose fear or fact, and check proof.", "Constellation court, logic gate, proof holder."),
        ("4", "Truth Gate + Hope Garden", "Choose another possible truth and build the Hope Path.", "Truth rings, Hope tiles, flowers, memory seed, shortcut."),
        ("5", "Thought Storm Arena", "Complete the three-stage combat-puzzle boss.", "Warden, storm rings, focus anchors, arena walls, checkpoint, rain version."),
        ("6", "Oldest Tree + World Gate", "Receive the Star, meet the Guardian, and return to unlock the train.", "Oldest Tree area, Star, Guardian platform, return path, World Gate."),
    ]
    add_data_table(doc, ("#", "Area", "What happens here", "Main objects"), route_rows, [0.35, 1.45, 2.25, 2.45], centre_columns=(0,))
    doc.add_heading("Small object budget", level=2)
    budget_rows = [
        ("Main landmarks", "8 unique", "Entry portal, three gates, Constellation Court, server trees, storm arena, and Oldest Tree."),
        ("World building", "6 groups", "Island, paths, bridges, railway, technology forest, and living nature."),
        ("Quest and magic", "6 groups", "Sparks, pattern puzzle, logic tools, Mayor’s hints, Hope and growth, and Star reward."),
        ("Enemies", "5 + 1 boss", "One shared Godot base scene, five enemy variations, and one three-stage boss."),
        ("Characters and dressing", "6 groups", "Player, Milo, Guardian, small life, signs and lights, and rest and display objects."),
        ("Optional content", "Small", "Reuse enemies and objects for one or two short side paths. No new gameplay system is needed."),
        ("World versions", "3 versions", "Sleeping, waking, and gentle rain use the same world models with different lights and effects."),
    ]
    add_data_table(doc, ("Build group", "Amount", "Simple rule"), budget_rows, [1.65, 1.15, 3.7])
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(5)
    r = p.add_run("REUSE RULE  ")
    set_run(r, size=9.2, bold=True, color=DEEP_CYAN)
    r = p.add_run("Before making a new model, reuse an approved object by changing its size, direction, group, material, light, or plants.")
    set_run(r, size=9.2, color=INK)

    # BLUEPRINT 1
    key_rows = [
        ("01", "Mind Spark World Gate", "Brings the player from the Art Castle into Mind Spark and shows the first goal.", "Add a glowing doorway, safe start point, clear view forward, and a return state that opens after the boss."),
        ("02", "Fear Gate", "Shows the difference between a fact now and a fear about later.", "Use a clear triangle shape. It holds one Thought Spark and never uses harsh flashing."),
        ("03", "Proof Gate", "Checks proof and shows what information is missing.", "Use three Spark holders. Show known, unknown, and complete with symbols as well as colour."),
        ("04", "Truth Gate", "Helps the player find another possible truth and opens the Hope Path.", "Use turning rings. More than one believable answer can work. The success light is gold."),
        ("05", "Constellation Court", "Changes crossed thought lines into a clear pattern.", "Use movable points on a round platform. Keep a clear view toward the Logic Plaza."),
        ("06", "Server-Tree Family", "Makes the technology feel alive and shows if the world has power.", "Make short, medium, and tall versions. Reuse roots, materials, detail levels, and the cyan power animation."),
        ("07", "Thought Storm Arena", "Holds the safe three-stage combat-puzzle boss.", "Use layered rings, three focus anchors, arena walls, a checkpoint, clear attack warnings, and a reduced-motion version."),
        ("08", "Oldest Tree Sanctuary", "Gives the Star, shows the Guardian, and ends the world.", "Make it the tallest landmark. Add stairs or a ramp, a place for the Star, and a permanent gentle-rain version."),
    ]
    add_blueprint_sheet(
        doc,
        "Part 7 • Blueprint plate A",
        "Eight Key Landmarks",
        "Eight important places show the main path, teach the thought skills, hold the boss battle, and give the final reward.",
        KEY_BLUEPRINT,
        "Architecture blueprint showing eight numbered Mind Spark hero landmarks in orthographic, isometric and exploded views.",
        key_rows,
    )

    # BLUEPRINT 2
    construction_rows = [
        ("01", "Floating Island Base", "Holds the world and gives it a safe outer edge.", "Use reusable cliff pieces, crystal shapes below, a collision floor, fog recovery, and hidden walls."),
        ("02", "Path and Floor Group", "Builds clear paths, plazas, ramps, stairs, and glass floors.", "Use one snap grid and a clear 3–4 metre path. Keep the cyan guide line free from objects."),
        ("03", "Bridge Group", "Connects the areas and opens new shortcuts.", "The normal, energy, and root bridges use the same width, collision, rail height, and end snaps."),
        ("04", "Crown Railway Group", "Becomes the travel system only after World One is complete.", "Before the Star: train dark, doors sealed, no ride action. After the Star: lights turn gold, doors open, and Heart Melody appears on the route map."),
        ("05", "Technology Forest Group", "Builds the science look and gives the player tools to use.", "Server trees, glowing roots, and consoles share the same light material and detail rules."),
        ("06", "Living Nature Group", "Makes the technology warmer and shows the world waking up.", "Reuse trees, pines, mixed trees, flowers, grass, ferns, and pools with simple wind and growth movement."),
    ]
    add_blueprint_sheet(
        doc,
        "Blueprint plate B",
        "World Building Kit",
        "Six reusable object groups are enough to build the full path. They keep movement, collision, size, materials, and world changes consistent.",
        CONSTRUCTION_BLUEPRINT,
        "Reduced six-family blueprint for the Mind Spark floating island, traversal, bridges, railway, technology forest and living nature.",
        construction_rows,
    )

    # BLUEPRINT 3
    quest_rows_blueprint = [
        ("01", "Thought Spark Group", "Shows feelings, facts, fears, and helpful ideas.", "Use different shapes. All Sparks share idle, pick up, carry, place, and collected states."),
        ("02", "Constellation Puzzle Group", "Helps the player see how thoughts connect.", "Use movable points, link lines, snap places, a complete pattern, a hint glow, and a reset."),
        ("03", "Logic Tool Group", "Combines fear or fact, proof, and another possible truth.", "Choice pads, Spark holders, and rings use the same controls but have different shapes."),
        ("04", "Help and Hint Group", "Gives Mayor Milo’s information, hints, save points, and a calm retry.", "Use the Mayor’s Beacon, three hint levels, a reset control, and a clear safe node."),
        ("05", "Hope and Growth Group", "Changes a helpful choice into a new path and living growth.", "Hope tiles, Truth Path, memory seed, thought flower, and wisdom flower turn on in clear stages."),
        ("06", "Wisdom Reward Group", "Shows the Guardian, gives the Star, and saves it in the Gallery.", "The Guardian, Star, memory piece, and display case change from cyan to gold when complete."),
    ]
    add_blueprint_sheet(
        doc,
        "Blueprint plate C",
        "Quest and Magic Kit",
        "Six reusable groups cover collecting, puzzles, logic, help, growth, and the final Star reward.",
        QUEST_BLUEPRINT,
        "Reduced six-family blueprint for Thought Sparks, constellation puzzles, logic interactions, guidance props, Hope growth and wisdom rewards.",
        quest_rows_blueprint,
    )

    # BLUEPRINT 4
    character_rows = [
        ("01", "In-Game Fox Player", "Lets the player explore, carry, choose, fight, block, dodge, gain XP, and level up.", "Use the current orange fox: dark-green hood, brown boots, gloves and belt, white tail tip, and crystal sword. Reuse the current health, sword Area3D, block, and take_damage system. Add strong attack, hit reaction, dodge, defeat, and level-up actions."),
        ("02", "Mayor Milo Cat", "Wise elder mayor and fatherly guide who asks for help, leads the player to the castle, explains the mission, and gives hints.", "Keep Milo as a cream, tan, and brown elder cat with blue eyes, round gold glasses, silver-white moustache, full silver cheeks, bushy eyebrows, and soft age lines. Use a midnight mayoral coat, violet waistcoat or sash, gold piping, gold chain of office, and Art Castle crest. Give him the town key and rolled map. Add welcome, listen, explain, encourage, and point-to-castle poses. Milo stays in safe areas and never fights."),
        ("03", "Guardian of Clear Thinking", "Thanks the player for being brave and gives meaning to the reward.", "Use a soft light body with appear, speak, and fade actions. Do not add fighting movement or a scary pose."),
        ("04", "Small Life Group", "Makes the forest feel safe, alive, and friendly.", "The Spark friend, firefly, moth, and bird use simple repeated movement, low-detail versions, and no blocking collision."),
        ("05", "Signs and Lights", "Shows the path, gate state, world identity, and safe edge.", "Guide posts, root lamps, short posts, status crystals, and emblems use the same clear symbols."),
        ("06", "Rest and Display", "Gives places to rest, take pictures, and show memories in the Gallery.", "Keep the root bench, memory crystal, photo marker, display case, and frame away from the main path."),
    ]
    add_blueprint_sheet(
        doc,
        "Blueprint plate D",
        "Characters and World Objects",
        "These six groups use the current fox player and elder Mayor Milo. They also cover the Guardian, small animals, path signs, rest places, and Gallery displays.",
        CHARACTER_BLUEPRINT,
        "Reduced six-family blueprint using the in-game hooded fox player and wise elder Mayor Milo Cat with mayoral chain and silver-white moustache, plus Guardian, ambient life, wayfinding and reflection/display props.",
        character_rows,
    )

    # BLUEPRINT 5
    combat_rows = [
        ("01", "Static Mite", "Fast one-hit tutorial monster worth 10 XP.", "Godot: CharacterBody3D, capsule collision, 25 HP, detection Area3D, lunge timer, 4 short animations, shared dissolve effect."),
        ("02", "Glitch Sprout", "Stationary ranged monster worth 15 XP.", "Godot: CharacterBody3D with no navigation, 50 HP, one projectile spawn point, aim timer, open-core hurt state, 4 short animations."),
        ("03", "Circuit Wisp", "Flying ranged monster that teaches deflection; 20 XP.", "Godot: floating CharacterBody3D, sphere collision, 50 HP, simple height spring, one shared projectile, stunned timer, 5 animations."),
        ("04", "Root Stalker", "Charging beast with a rear weak point; 30 XP.", "Godot: CharacterBody3D + NavigationAgent3D, box or capsule collision, 75 HP, charge RayCast3D, rear Area3D, 5 animations."),
        ("05", "Blight Sentinel", "Shielded elite that guards the Truth Gate; 60 XP.", "Godot: CharacterBody3D + NavigationAgent3D, capsule collision, 150 HP, shield bool, chest Area3D, slam timer, 6 animations."),
        ("06", "Thought Storm Warden", "Three-stage World One boss worth 150 XP and the Star.", "Godot: one boss scene, 300 core HP, three anchor nodes, one core Area3D, phase enum, timers, arena signals, checkpoint, and final Hope interaction."),
    ]
    add_blueprint_sheet(
        doc,
        "Blueprint plate E",
        "Static Blight Monsters & Boss",
        "All six designs are possible in Godot 4.7 and fit the current mobile/GL Compatibility renderer. The art is detailed, but the game models should stay low-poly and use simple shared systems.",
        COMBAT_BLUEPRINT,
        "Six-panel Godot-ready blueprint for Static Mite, Glitch Sprout, Circuit Wisp, Root Stalker, Blight Sentinel, and Thought Storm Warden.",
        combat_rows,
    )

    # PRODUCTION RULES
    add_section_intro(
        doc,
        "Part 8",
        "Simple Building Rules",
        "These rules help the art, effects, sound, UI, access, and programming teams build the same clear world.",
    )
    production_rows = [
        ("Art", "Use simple low-poly shapes, white ice ground, black glass technology, lavender plants, cyan systems, violet thoughts, and small amounts of gold for wisdom."),
        ("Lights / Effects", "Make three world versions: sleeping, waking, and complete. Goals are brighter than decorations. Add a reduced-motion option."),
        ("Sound", "Use six sound groups: town and Milo, forest circuits, sword combat, logic puzzle, storm boss, and the first train unlock. Remove storm layers as the boss is freed."),
        ("UI", "Show current task, health, XP bar, Level 1–5, 0/6 Sparks, hint, enemy health for elite and boss, boss stage, and the train unlock reward."),
        ("Access", "Add subtitles, larger text, symbols that do not need colour, control changes, camera settings, reduced motion, combat assist, hints, checkpoints, and auto-help."),
        ("Programming", "Build shared enemy damage, XP and levels, quest progress, checkpoints, Sparks, puzzles, boss phases, world lighting, train unlock, collision, sound areas, PlayerIdentityTracker, identity save fields, and developer test tools."),
    ]
    add_data_table(doc, ("Team", "What must be built"), production_rows, [1.25, 5.25])
    doc.add_heading("The world is ready when", level=2)
    checks = (
        "The player meets Mayor Milo in town, follows him to the Art Castle, and sees that the train is locked.",
        "The first playthrough takes about 55–70 minutes without optional exploration.",
        "All 4 quests, 10 main tasks, 5 learning choices, 8 identity moments, 6 main Sparks, 5 enemy types, 5 levels, and 3 boss stages save correctly.",
        "Every identity moment offers two equally helpful choices plus Not sure / Skip, and replaying an Event ID never adds a duplicate point.",
        "Puzzle results, combat performance, deaths, speed, hints, and accessibility settings never change identity scores.",
        "World One saves identity evidence but does not reveal a final identity, four-letter code, ranking, or identity meter.",
        "The identity tracker survives save, quit, reload, checkpoint restart, boss retry, World Gate return, and train unlock.",
        "Each enemy works through the current sword hitbox and shared take_damage() contract in Godot 4.7.",
        "Normal encounters never use more than 4 enemies, and the mobile renderer stays at the target frame rate.",
        "Every blueprint object group has an owner, model plan, collision rule, action rule, and state list.",
        "The current task and next landmark are easy to see in all six areas.",
        "The sleeping, waking, and gentle-rain world versions save and load correctly.",
        "The player can return through the World Gate, place the Star, wake the train for the first time, and open Heart Melody.",
        "Reduced motion, symbols, subtitles, larger text, control choices, and help options work correctly.",
    )
    for item in checks:
        check = add_check(doc, item)
        check.paragraph_format.space_after = Pt(1.5)
        check.paragraph_format.line_spacing = 1.05
        for run in check.runs:
            set_run(run, size=9.6, color=INK)
    add_callout(
        doc,
        "FINAL WORLD MESSAGE",
        "You found the courage to understand your thoughts and choose hope. The wisdom was already growing inside you.",
        fill="FFF6D8",
        accent=GOLD,
    )

    # BACK VISUAL
    doc.add_page_break()
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(12)
    r = p.add_run("WORLD ONE  •  MIND SPARK")
    set_run(r, size=11, bold=True, color=VIOLET)
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("Meet the Mayor. Enter the Castle. Save World One. Unlock the train.")
    set_run(r, size=18, bold=True, color=MIDNIGHT)
    picture_with_alt(doc, HERO, Inches(6.5), "Approved final Mind Spark world concept.")
    add_caption(doc, "Mind Spark world style and the main player path.")
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("DISCOVERY, NOT FIXING")
    set_run(r, size=13, bold=True, color=GOLD)
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("Mind Spark teaches the player to protect the world, understand a problem, choose hope, and earn the journey to Heart Melody.")
    set_run(r, size=11, italic=True, color=MUTED)

    for paragraph in doc.paragraphs:
        if paragraph.style and paragraph.style.name.startswith("Heading"):
            paragraph.paragraph_format.keep_with_next = True
        paragraph.paragraph_format.widow_control = True

    # Mark the first row of every table for assistive technology. Data tables use
    # a true header; single-row callout tables use their lead label as the header.
    for table in doc.tables:
        if table.rows:
            set_repeat_table_header(table.rows[0])

    doc.save(OUT)
    print(OUT)


if __name__ == "__main__":
    build_document()
