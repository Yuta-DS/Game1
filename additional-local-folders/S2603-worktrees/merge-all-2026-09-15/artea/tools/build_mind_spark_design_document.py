from __future__ import annotations

from datetime import date
from pathlib import Path

from docx import Document
from docx.enum.section import WD_SECTION_START
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_ROW_HEIGHT_RULE, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK, WD_LINE_SPACING
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


ROOT = Path("/Users/davidsovann/S2603/artea")
OUT = ROOT / "docs" / "World_One_Mind_Spark_Design_Document.docx"
HERO = ROOT / "artifacts" / "mind_spark_world_reference" / "mind_spark_professional_world_concept_v3.png"
EARLY = ROOT / "artifacts" / "mind_spark_world_reference" / "mind_spark_complete_world_concept_v2.png"

# compact_reference_guide preset, with a named Mind Spark palette override.
FONT = "Calibri"
INK = RGBColor(24, 42, 54)
MIDNIGHT = RGBColor(20, 51, 67)
CYAN = RGBColor(0, 178, 199)
DEEP_CYAN = RGBColor(0, 112, 135)
VIOLET = RGBColor(116, 88, 190)
LAVENDER = RGBColor(222, 211, 250)
ICE = RGBColor(235, 249, 251)
GOLD = RGBColor(181, 130, 14)
PALE_GOLD = RGBColor(255, 246, 211)
MUTED = RGBColor(92, 111, 121)
WHITE = RGBColor(255, 255, 255)
GRID = "B8D9DF"


def set_run(run, size=None, bold=None, italic=None, color=None, font=FONT):
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


def shade_cell(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_cell_margins(cell, top=80, start=120, bottom=80, end=120):
    tc = cell._tc
    tc_pr = tc.get_or_add_tcPr()
    tc_mar = tc_pr.first_child_found_in("w:tcMar")
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for m, v in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        node = tc_mar.find(qn(f"w:{m}"))
        if node is None:
            node = OxmlElement(f"w:{m}")
            tc_mar.append(node)
        node.set(qn("w:w"), str(v))
        node.set(qn("w:type"), "dxa")


def set_repeat_table_header(row):
    tr_pr = row._tr.get_or_add_trPr()
    tbl_header = OxmlElement("w:tblHeader")
    tbl_header.set(qn("w:val"), "true")
    tr_pr.append(tbl_header)


def prevent_row_split(row):
    tr_pr = row._tr.get_or_add_trPr()
    cant_split = OxmlElement("w:cantSplit")
    tr_pr.append(cant_split)


def set_table_borders(table, color=GRID, size=6):
    tbl_pr = table._tbl.tblPr
    borders = tbl_pr.find(qn("w:tblBorders"))
    if borders is None:
        borders = OxmlElement("w:tblBorders")
        tbl_pr.append(borders)
    for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
        tag = borders.find(qn(f"w:{edge}"))
        if tag is None:
            tag = OxmlElement(f"w:{edge}")
            borders.append(tag)
        tag.set(qn("w:val"), "single")
        tag.set(qn("w:sz"), str(size))
        tag.set(qn("w:color"), color)


def set_table_geometry(table, widths_inches):
    total_dxa = sum(int(w * 1440) for w in widths_inches)
    tbl_pr = table._tbl.tblPr
    tbl_layout = tbl_pr.find(qn("w:tblLayout"))
    if tbl_layout is None:
        tbl_layout = OxmlElement("w:tblLayout")
        tbl_pr.append(tbl_layout)
    tbl_layout.set(qn("w:type"), "fixed")
    tbl_w = tbl_pr.find(qn("w:tblW"))
    if tbl_w is None:
        tbl_w = OxmlElement("w:tblW")
        tbl_pr.append(tbl_w)
    tbl_w.set(qn("w:w"), str(total_dxa))
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
    for w in widths_inches:
        gc = OxmlElement("w:gridCol")
        gc.set(qn("w:w"), str(int(w * 1440)))
        grid.append(gc)
    for row in table.rows:
        for idx, cell in enumerate(row.cells):
            dxa = int(widths_inches[idx] * 1440)
            cell.width = Inches(widths_inches[idx])
            tc_w = cell._tc.get_or_add_tcPr().find(qn("w:tcW"))
            if tc_w is None:
                tc_w = OxmlElement("w:tcW")
                cell._tc.get_or_add_tcPr().append(tc_w)
            tc_w.set(qn("w:w"), str(dxa))
            tc_w.set(qn("w:type"), "dxa")
            set_cell_margins(cell)


def add_page_field(paragraph):
    run = paragraph.add_run()
    fld_char1 = OxmlElement("w:fldChar")
    fld_char1.set(qn("w:fldCharType"), "begin")
    instr_text = OxmlElement("w:instrText")
    instr_text.set(qn("xml:space"), "preserve")
    instr_text.text = " PAGE "
    fld_char2 = OxmlElement("w:fldChar")
    fld_char2.set(qn("w:fldCharType"), "end")
    run._r.extend([fld_char1, instr_text, fld_char2])
    set_run(run, size=9, color=MUTED)


def picture_with_alt(doc, path, width, alt):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(4)
    p.paragraph_format.space_after = Pt(5)
    run = p.add_run()
    inline = run.add_picture(str(path), width=width)
    doc_pr = inline._inline.docPr
    doc_pr.set("descr", alt)
    doc_pr.set("title", alt)
    return p


def add_caption(doc, text):
    p = doc.add_paragraph(style="Caption")
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.keep_with_next = False
    r = p.add_run(text)
    set_run(r, size=9, italic=True, color=MUTED)
    return p


def add_callout(doc, label, text, fill="EAF9FB", accent=DEEP_CYAN):
    table = doc.add_table(rows=1, cols=1)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    set_table_geometry(table, [6.5])
    set_table_borders(table, color="A6DDE5", size=8)
    cell = table.cell(0, 0)
    shade_cell(cell, fill)
    p = cell.paragraphs[0]
    p.paragraph_format.space_before = Pt(3)
    p.paragraph_format.space_after = Pt(3)
    p.paragraph_format.line_spacing = 1.15
    r = p.add_run(f"{label}  ")
    set_run(r, size=10.5, bold=True, color=accent)
    r = p.add_run(text)
    set_run(r, size=10.5, color=INK)
    after = doc.add_paragraph()
    after.paragraph_format.space_after = Pt(1)
    return table


def add_bullet(doc, text, level=0, bold_lead=None):
    p = doc.add_paragraph(style="List Bullet" if level == 0 else "List Bullet 2")
    if bold_lead and text.startswith(bold_lead):
        r = p.add_run(bold_lead)
        set_run(r, bold=True, color=MIDNIGHT)
        r = p.add_run(text[len(bold_lead):])
        set_run(r, color=INK)
    else:
        r = p.add_run(text)
        set_run(r, color=INK)
    return p


def add_number(doc, text):
    p = doc.add_paragraph(style="List Number")
    r = p.add_run(text)
    set_run(r, color=INK)
    return p


def restart_number_sequence(doc, paragraph):
    """Give a List Number paragraph a new concrete numId that starts at 1."""
    style = doc.styles["List Number"]
    base_num_id = style._element.pPr.numPr.numId.val
    numbering = doc.part.numbering_part.element
    base_num = numbering.xpath(f"./w:num[@w:numId='{base_num_id}']")[0]
    abstract_id = base_num.find(qn("w:abstractNumId")).get(qn("w:val"))
    num_ids = [int(el.get(qn("w:numId"))) for el in numbering.findall(qn("w:num"))]
    new_id = max(num_ids, default=0) + 1
    num = OxmlElement("w:num")
    num.set(qn("w:numId"), str(new_id))
    abstract = OxmlElement("w:abstractNumId")
    abstract.set(qn("w:val"), abstract_id)
    num.append(abstract)
    override = OxmlElement("w:lvlOverride")
    override.set(qn("w:ilvl"), "0")
    start = OxmlElement("w:startOverride")
    start.set(qn("w:val"), "1")
    override.append(start)
    num.append(override)
    numbering.append(num)
    p_pr = paragraph._p.get_or_add_pPr()
    num_pr = p_pr.get_or_add_numPr()
    num_id = num_pr.get_or_add_numId()
    num_id.val = new_id


def add_numbered_sequence(doc, items):
    for index, item in enumerate(items):
        p = add_number(doc, item)
        if index == 0:
            restart_number_sequence(doc, p)


def add_check(doc, text):
    p = doc.add_paragraph()
    p.paragraph_format.left_indent = Inches(0.36)
    p.paragraph_format.first_line_indent = Inches(-0.22)
    p.paragraph_format.space_after = Pt(3)
    p.paragraph_format.line_spacing = 1.15
    r = p.add_run("☐  " + text)
    set_run(r, size=10.3, color=INK)
    return p


def add_inventory_table(doc, title, purpose, rows):
    doc.add_heading(title, level=2)
    if purpose:
        p = doc.add_paragraph(purpose)
        p.paragraph_format.keep_with_next = True
    table = doc.add_table(rows=1, cols=3)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    set_table_geometry(table, [1.95, 0.70, 3.85])
    set_table_borders(table)
    hdr = table.rows[0]
    set_repeat_table_header(hdr)
    for i, text in enumerate(("Object / asset", "Qty.", "Production purpose and design notes")):
        cell = hdr.cells[i]
        shade_cell(cell, "D9F2F5")
        cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER if i == 1 else WD_ALIGN_PARAGRAPH.LEFT
        p.paragraph_format.space_before = Pt(1)
        p.paragraph_format.space_after = Pt(1)
        r = p.add_run(text)
        set_run(r, size=9.5, bold=True, color=MIDNIGHT)
    for index, (name, qty, note) in enumerate(rows):
        cells = table.add_row().cells
        prevent_row_split(table.rows[-1])
        if index % 2:
            for c in cells:
                shade_cell(c, "F6FBFC")
        values = (name, qty, note)
        for i, value in enumerate(values):
            cells[i].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            p = cells[i].paragraphs[0]
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER if i == 1 else WD_ALIGN_PARAGRAPH.LEFT
            p.paragraph_format.space_before = Pt(1)
            p.paragraph_format.space_after = Pt(1)
            p.paragraph_format.line_spacing = 1.05
            r = p.add_run(str(value))
            set_run(r, size=9.1, bold=(i == 0), color=MIDNIGHT if i == 0 else INK)
    return table


def add_section_intro(doc, part, title, summary):
    doc.add_page_break()
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(3)
    r = p.add_run(part.upper())
    set_run(r, size=9.5, bold=True, color=VIOLET)
    h = doc.add_heading(title, level=1)
    h.paragraph_format.space_before = Pt(0)
    p = doc.add_paragraph(summary)
    p.paragraph_format.space_after = Pt(12)
    r = p.runs[0]
    set_run(r, size=12, italic=True, color=MUTED)


def format_cell_text(cell, size=9.5, bold=False, color=INK, align=None):
    for p in cell.paragraphs:
        if align is not None:
            p.alignment = align
        p.paragraph_format.space_before = Pt(1)
        p.paragraph_format.space_after = Pt(1)
        p.paragraph_format.line_spacing = 1.05
        for r in p.runs:
            set_run(r, size=size, bold=bold, color=color)


def configure_document(doc):
    section = doc.sections[0]
    section.page_width = Inches(8.5)
    section.page_height = Inches(11)
    section.top_margin = Inches(0.75)  # Named cover/field-guide override.
    section.bottom_margin = Inches(0.75)
    section.left_margin = Inches(1.0)
    section.right_margin = Inches(1.0)
    section.header_distance = Inches(0.35)
    section.footer_distance = Inches(0.35)

    styles = doc.styles
    normal = styles["Normal"]
    normal.font.name = FONT
    normal._element.rPr.rFonts.set(qn("w:ascii"), FONT)
    normal._element.rPr.rFonts.set(qn("w:hAnsi"), FONT)
    normal.font.size = Pt(10.5)
    normal.font.color.rgb = INK
    normal.paragraph_format.space_before = Pt(0)
    normal.paragraph_format.space_after = Pt(6)
    normal.paragraph_format.line_spacing = 1.18

    tokens = {
        "Title": (30, MIDNIGHT, 0, 8),
        "Subtitle": (14, VIOLET, 0, 12),
        "Heading 1": (18, DEEP_CYAN, 16, 8),
        "Heading 2": (13, VIOLET, 12, 5),
        "Heading 3": (11.5, MIDNIGHT, 8, 3),
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
        if name.startswith("Heading") or name == "Title":
            style.font.bold = True

    for list_name in ("List Bullet", "List Bullet 2", "List Number"):
        style = styles[list_name]
        style.font.name = FONT
        style._element.rPr.rFonts.set(qn("w:ascii"), FONT)
        style._element.rPr.rFonts.set(qn("w:hAnsi"), FONT)
        style.font.size = Pt(10.3)
        style.font.color.rgb = INK
        style.paragraph_format.space_after = Pt(3)
        style.paragraph_format.line_spacing = 1.15
    styles["List Bullet"].paragraph_format.left_indent = Inches(0.375)
    styles["List Bullet"].paragraph_format.first_line_indent = Inches(-0.188)
    styles["List Bullet 2"].paragraph_format.left_indent = Inches(0.65)
    styles["List Bullet 2"].paragraph_format.first_line_indent = Inches(-0.188)
    styles["List Number"].paragraph_format.left_indent = Inches(0.375)
    styles["List Number"].paragraph_format.first_line_indent = Inches(-0.188)

    header = section.header
    p = header.paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.LEFT
    p.paragraph_format.space_after = Pt(0)
    r = p.add_run("ARTÉA  /  WORLD DESIGN BIBLE")
    set_run(r, size=8.5, bold=True, color=MUTED)
    footer = section.footer
    p = footer.paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    p.paragraph_format.space_after = Pt(0)
    r = p.add_run("MIND SPARK  •  ")
    set_run(r, size=8.5, bold=True, color=MUTED)
    add_page_field(p)

    # Accessibility metadata and document properties.
    doc.core_properties.title = "World One: Mind Spark - Identity, Story and Production Design Document"
    doc.core_properties.subject = "ARTÉA World One design bible"
    doc.core_properties.author = "David Sovann and the ARTÉA team"
    doc.core_properties.keywords = "ARTÉA, Mind Spark, game design, world design, story, assets"
    doc.core_properties.comments = "Consolidated from the ARTÉA story proposal and World One concept development."


def build_document():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    doc = Document()
    configure_document(doc)

    # COVER
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(8)
    p.paragraph_format.space_after = Pt(2)
    r = p.add_run("ARTÉA  •  WORLD ONE DESIGN BIBLE")
    set_run(r, size=10, bold=True, color=VIOLET)
    p = doc.add_paragraph(style="Title")
    p.paragraph_format.keep_with_next = True
    r = p.add_run("MIND SPARK")
    set_run(r, size=34, bold=True, color=MIDNIGHT)
    p = doc.add_paragraph(style="Subtitle")
    r = p.add_run("Identity, Story, Gameplay, World Objects & Production Direction")
    set_run(r, size=14, color=DEEP_CYAN)

    picture_with_alt(
        doc,
        HERO,
        Inches(6.5),
        "Professional isometric concept of Mind Spark: a floating cyan circuit island with logic gates, a Thought Storm, and the Oldest Tree sanctuary.",
    )
    add_caption(doc, "World One production concept — Technology/Science leads; Nature and Magic make the system feel alive.")
    add_callout(
        doc,
        "IDENTITY PHRASE",
        "A living computer forest where thoughts grow like stars and wisdom reorganizes the path.",
        fill="EAF9FB",
    )
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(2)
    p.paragraph_format.space_after = Pt(0)
    r = p.add_run("Version 1.0  •  13 August 2026  •  Prepared for David Sovann and the ARTÉA team")
    set_run(r, size=9, color=MUTED)

    # PURPOSE / CONTENTS
    add_section_intro(
        doc,
        "Document orientation",
        "How to use this design bible",
        "This document consolidates the story proposal, visual concepts, gameplay structure, object inventory, and production rules established for World One.",
    )
    doc.add_heading("Purpose", level=2)
    doc.add_paragraph(
        "Mind Spark is the first complete kingdom in ARTÉA’s Crown of Life journey. This bible is the shared reference for narrative, level design, environment art, gameplay, audio, UI, accessibility, and implementation. It defines what must remain consistent while individual scenes, quests, and assets are built."
    )
    add_callout(
        doc,
        "DESIGN MANDATE",
        "The player is discovering inner wisdom, not repairing a broken self. No system may imply that the player must earn value, defeat a part of themselves, or give a perfect answer.",
        fill="FFF6D8",
        accent=GOLD,
    )
    doc.add_heading("Contents", level=2)
    contents = [
        "1. World identity and creative pillars",
        "2. Storyline, cast, and emotional arc",
        "3. Player journey, timing, quests, and quizzes",
        "4. The Thought Storm final encounter",
        "5. Level architecture and environmental storytelling",
        "6. Complete world object and asset catalogue",
        "7. Art, lighting, effects, audio, UI, and accessibility",
        "8. Technical systems, production scope, and build order",
        "9. Final acceptance checklist",
    ]
    for item in contents:
        add_bullet(doc, item)
    doc.add_heading("Source basis", level=2)
    add_bullet(doc, "ARTÉA Game Story and Game Design proposal supplied by David Sovann.")
    add_bullet(doc, "World One prototype views captured from the Art Castle Galaxy game project.")
    add_bullet(doc, "Mind Spark complete-world and professional environment concepts developed during this design process.")
    add_bullet(doc, "All quantities and timings in this bible are production estimates and should be validated through playtesting.")

    # IDENTITY
    add_section_intro(
        doc,
        "Part 1",
        "World Identity",
        "Mind Spark is the Technology/Science-dominant chapter: a place where patterns, evidence, choices, and living systems teach the player to understand thoughts.",
    )
    doc.add_heading("Core identity", level=2)
    identity_rows = [
        ("World name", "Mind Spark Kingdom"),
        ("Chapter theme", "I can understand my thoughts."),
        ("Dominant force", "Technology / Science"),
        ("Supporting forces", "Nature and Magic"),
        ("Treasure", "The Star of Wisdom"),
        ("Guardian", "Everlasting Father — truth and wisdom"),
        ("Player transformation", "From an overwhelming mixture of thoughts to a calm, hopeful next step"),
        ("Final world unlock", "Heart Melody Station becomes available after the Star returns to the Gallery"),
    ]
    table = doc.add_table(rows=0, cols=2)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    for idx, (label, value) in enumerate(identity_rows):
        cells = table.add_row().cells
        prevent_row_split(table.rows[-1])
        shade_cell(cells[0], "D9F2F5")
        if idx % 2:
            shade_cell(cells[1], "F6FBFC")
        cells[0].text = label
        cells[1].text = value
        format_cell_text(cells[0], bold=True, color=MIDNIGHT)
        format_cell_text(cells[1])
    set_table_geometry(table, [1.875, 4.625])
    set_table_borders(table)

    doc.add_heading("The three-force balance", level=2)
    add_bullet(doc, "Technology/Science leads: thought-mapping machines, evidence gates, data constellations, circuit routes, server-tree towers, and Milo’s analysis tools.", bold_lead="Technology/Science leads:")
    add_bullet(doc, "Nature supports: roots, rain, flowers, tree growth, vines, forests, and gentle weather show that thoughts are living experiences rather than cold data.", bold_lead="Nature supports:")
    add_bullet(doc, "Magic supports: Thought Sparks, glowing truth paths, the guardian, the Wisdom Tree, and the Star of Wisdom give the world wonder and spiritual meaning.", bold_lead="Magic supports:")
    add_callout(doc, "VISUAL RATIO", "Aim for roughly 60% Technology/Science, 25% Nature, and 15% Magic in an average gameplay view. Hero moments may temporarily increase the magical share.")

    doc.add_heading("Shape, material, and colour language", level=2)
    add_bullet(doc, "Technology uses grids, nodes, lines, layered plates, angular silhouettes, transparent glass, and controlled cyan emission.")
    add_bullet(doc, "Nature uses branching roots, uneven clustering, rounded lavender canopies, faceted trunks, gentle slopes, and growth around machinery.")
    add_bullet(doc, "Magic uses circles, rings, stars, suspended particles, violet light, gold focal points, and transformations rather than weapons.")
    palette = [
        ("Midnight blue", "#143343", "Server towers, deep structure, contrast"),
        ("Cyan", "#00B2C7", "Paths, interfaces, living circuits"),
        ("Ice white", "#EBF9FB", "Ground planes, calm, clarity"),
        ("Violet", "#7458BE", "Thoughts, mystery, gentle magic"),
        ("Lavender", "#DED3FA", "Forest crowns and softness"),
        ("Emerald", "#2F9F7D", "Secondary natural life"),
        ("Wisdom gold", "#FFD968", "Treasure and final guidance only"),
        ("Silver blue", "#B8D9DF", "Architecture and supporting metal"),
    ]
    table = doc.add_table(rows=1, cols=3)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    for i, value in enumerate(("Colour", "Reference", "Primary use")):
        table.cell(0, i).text = value
        shade_cell(table.cell(0, i), "D9F2F5")
        format_cell_text(table.cell(0, i), bold=True, color=MIDNIGHT, align=WD_ALIGN_PARAGRAPH.CENTER if i == 1 else WD_ALIGN_PARAGRAPH.LEFT)
    set_repeat_table_header(table.rows[0])
    for name, code, use in palette:
        cells = table.add_row().cells
        cells[0].text, cells[1].text, cells[2].text = name, code, use
        for i, cell in enumerate(cells):
            format_cell_text(cell, align=WD_ALIGN_PARAGRAPH.CENTER if i == 1 else WD_ALIGN_PARAGRAPH.LEFT)
    set_table_geometry(table, [1.65, 1.05, 3.8])
    set_table_borders(table)

    doc.add_heading("Identity non-negotiables", level=2)
    for item in [
        "No traditional castle castle inside Mind Spark. Its monumental architecture is made from logic, glass, roots, data, and starlight.",
        "The player never attacks a thought, creature, guardian, or storm.",
        "Wrong choices are treated as information. The game calmly invites another look.",
        "Routes must remain readable even when effects are active; visual beauty cannot hide gameplay.",
        "Every significant asset must support at least one identity pillar: thinking technology, living nature, or wisdom magic.",
        "The final gold colour is reserved for wisdom, achievement, and guidance so it remains emotionally powerful.",
    ]:
        add_bullet(doc, item)

    # VISUAL BLUEPRINT
    add_section_intro(
        doc,
        "Part 1 visual plate",
        "Professional World Blueprint",
        "The concept below is the visual target for the complete island: modular, readable, achievable in Godot, and rich enough to feel like a finished world.",
    )
    picture_with_alt(
        doc,
        HERO,
        Inches(6.5),
        "Full professional Mind Spark world blueprint with entrance, logic plazas, central constellation, Thought Storm, and Wisdom Tree.",
    )
    add_caption(doc, "Figure 1. Recommended overall world appearance and landmark hierarchy.")
    doc.add_heading("How to read the image", level=2)
    add_bullet(doc, "Front edge: arrival portal, safe landing, first circuit route, and onboarding props.")
    add_bullet(doc, "Lower and side districts: living server forests, Thought Spark gathering, and the three logic-gate plazas.")
    add_bullet(doc, "Centre: constellation court, where the player makes mixed thoughts readable as patterns.")
    add_bullet(doc, "Upper-left: contained Thought Storm arena, designed as a calm multi-phase puzzle rather than a battle.")
    add_bullet(doc, "Upper-right: elevated Oldest Tree sanctuary, ceremonial stairs, glowing roots, and the Star of Wisdom.")
    add_bullet(doc, "Island edge: faceted white rock and long cyan crystals reinforce the floating Art Castle Galaxy identity.")
    add_callout(doc, "LANDMARK RULE", "From most locations the player should see at least one current objective and one future landmark. Gates teach the route; the storm creates tension; the Wisdom Tree promises the destination.")

    # STORY
    add_section_intro(
        doc,
        "Part 2",
        "Storyline & Emotional Arc",
        "The story moves from confusion to understanding, then from understanding to hope. The player does not remove difficult thoughts; they learn how to meet them safely.",
    )
    doc.add_heading("Connection to the complete ARTÉA journey", level=2)
    doc.add_paragraph(
        "ARTÉA Town has become quiet and the castle’s light is sleeping. The paths between the Mind, Heart, and Creative worlds are disconnected. When the player arrives, Milo wakes and explains that the castle is waiting for a new story and a new light. Mind Spark is the first destination on the Rainbow Galaxy Train’s Crown Line and the first inner treasure the player discovers."
    )
    add_callout(doc, "MILO", "“The castle can see something special in you. Let us discover your light together.”")

    doc.add_heading("World One story synopsis", level=2)
    doc.add_paragraph(
        "The player arrives in a dim computer forest. Tower-like trees rise from a network of glowing roots. Thought Sparks—worries, fears, dreams, and hopes—float between them, joined by tangled lines. Because every thought is mixed together, no clear route exists. Milo encourages the player to slow down, study one pattern at a time, and decide what each thought is trying to say."
    )
    doc.add_paragraph(
        "The player rearranges thought dots into readable constellations, selects a difficult thought, and carries it through three logic gates. The Fear Gate asks whether the thought is fear or fact. The Proof Gate asks what evidence is actually present. The Truth Gate asks what else might also be true. A kinder, more useful next thought creates a bright path; server trees awaken, roots reconnect, and flowers open."
    )
    doc.add_paragraph(
        "At the centre of the forest, many worried thoughts have gathered into the Thought Storm. The player does not fight it. They slow the storm, examine one thought, and build a hopeful path. The storm becomes gentle rain. At the Oldest Tree sanctuary, the rain reaches the roots and the Star of Wisdom grows into view. Everlasting Father honours the player’s courage. The Star returns with the player to the Gallery, changes the castle universe, and unlocks Heart Melody as the next destination."
    )

    doc.add_heading("Story beats", level=2)
    story_beats = [
        ("1", "Departure", "Only the Gallery and Mind Spark stations are open. Milo introduces the first journey."),
        ("2", "Arrival", "The forest is dim, its circuit roots are tangled, and the destination is unclear."),
        ("3", "Listening", "The player discovers that every Thought Spark is trying to communicate something."),
        ("4", "Pattern", "The player makes thought constellations readable by moving connected dots."),
        ("5", "Examination", "Three gates separate fear, evidence, and alternative possibilities."),
        ("6", "Choice", "The player chooses a kinder and more helpful next thought."),
        ("7", "Growth", "The new path lights the forest; technology and nature wake together."),
        ("8", "Storm", "Many thoughts create overload; the player applies the same process at a larger scale."),
        ("9", "Gentle rain", "The storm transforms instead of being destroyed."),
        ("10", "Wisdom", "The Star of Wisdom appears; the player returns and unlocks the next chapter."),
    ]
    table = doc.add_table(rows=1, cols=3)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    for i, t in enumerate(("Beat", "Name", "Narrative function")):
        table.cell(0, i).text = t
        shade_cell(table.cell(0, i), "D9F2F5")
        format_cell_text(table.cell(0, i), bold=True, color=MIDNIGHT, align=WD_ALIGN_PARAGRAPH.CENTER if i == 0 else WD_ALIGN_PARAGRAPH.LEFT)
    set_repeat_table_header(table.rows[0])
    for beat, name, function in story_beats:
        cells = table.add_row().cells
        cells[0].text, cells[1].text, cells[2].text = beat, name, function
        for i, cell in enumerate(cells):
            format_cell_text(cell, align=WD_ALIGN_PARAGRAPH.CENTER if i == 0 else WD_ALIGN_PARAGRAPH.LEFT)
    set_table_geometry(table, [0.55, 1.35, 4.6])
    set_table_borders(table)

    doc.add_heading("Cast and roles", level=2)
    add_bullet(doc, "The player: already carries value and light. Their role is observer, pattern-maker, chooser, and creator of the next path.", bold_lead="The player:")
    add_bullet(doc, "Milo: glowing AI companion, tutorial guide, analysis helper, emotional safety support, and optional auto-assist. Milo listens before advising and never diagnoses.", bold_lead="Milo:")
    add_bullet(doc, "Everlasting Father: the kingdom’s guardian of truth and wisdom. He appears as a calm presence near the sanctuary, never as a judge or test-giver.", bold_lead="Everlasting Father:")
    add_bullet(doc, "Thought Sparks: visible thoughts represented by light. Their categories include worries, fears, dreams, and hopes; none is an enemy.", bold_lead="Thought Sparks:")
    add_bullet(doc, "The Thought Storm: a condition created by overload, not a villain. It demonstrates that many thoughts can be handled one at a time.", bold_lead="The Thought Storm:")
    add_callout(doc, "GUARDIAN LINE", "“You found the courage to understand your thoughts and choose hope.”", fill="FFF6D8", accent=GOLD)

    doc.add_heading("Learning outcomes", level=2)
    for item in [
        "A thought is not always a fact.",
        "Difficult thoughts can be noticed and understood without shame.",
        "Evidence and alternative explanations can create a clearer path.",
        "A helpful next step can be small, kind, and realistic.",
        "Asking Milo or a trusted person for help is a sign of courage.",
    ]:
        add_bullet(doc, item)

    # GAMEPLAY / PROGRESSION
    add_section_intro(
        doc,
        "Part 3",
        "Player Journey, Quests & Timing",
        "World One should feel substantial enough to establish ARTÉA’s emotional promise without exhausting the player before the remaining kingdoms.",
    )
    add_callout(
        doc,
        "RECOMMENDED SCOPE",
        "8 main quests • 19 required interaction beats • 9 short thought prompts • 3 Thought Storm phases • 24 Thought Sparks (12 required, 12 optional) • 85–110 minutes on a first playthrough.",
    )
    doc.add_heading("Timing targets", level=2)
    add_bullet(doc, "Focused first playthrough: 85–110 minutes, including dialogue and normal exploration.")
    add_bullet(doc, "Younger players or players using assistance: 100–135 minutes, with unlimited pauses and repeated instructions.")
    add_bullet(doc, "Replay after completion: 40–60 minutes using opened shortcuts.")
    add_bullet(doc, "Optional exploration and remaining Thought Sparks: an additional 20–35 minutes.")
    add_bullet(doc, "Session support: save safely after every quest and allow the world to be completed across two or three sessions.")

    quest_rows = [
        ("1", "The Sleeping Signal", "Arrival platform and orientation grove", "2", "0", "8–10 min", "Wake Milo’s scanner, follow the first root pulse, reach the forest."),
        ("2", "Gather the Sparks", "Living server forest", "3", "1", "10–14 min", "Find and classify 12 core Thought Sparks without calling any one ‘bad’."),
        ("3", "Untangle the Pattern", "Constellation court", "3", "1", "10–14 min", "Move connected thought dots until paths no longer cross and the meaning becomes readable."),
        ("4", "Fear or Fact?", "Fear Gate plaza", "2", "2", "10–13 min", "Recognise predictions, worries, and facts through examples and visual clues."),
        ("5", "Look for Proof", "Proof Gate plaza", "2", "2", "10–13 min", "Collect evidence fragments and separate known information from assumptions."),
        ("6", "What Else Is True?", "Truth Gate and Hope Path", "3", "2", "13–17 min", "Choose another possible explanation and build a kind, believable next thought."),
        ("7", "Calm the Thought Storm", "Storm arena", "3", "1", "16–20 min", "Slow, examine, and re-route one thought until the storm becomes rain."),
        ("8", "The Star of Wisdom", "Oldest Tree sanctuary and return platform", "1", "0", "8–10 min", "Receive the Star, see the world transformed, and unlock Heart Melody Station."),
    ]
    table = doc.add_table(rows=1, cols=7)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    headers = ("#", "Quest", "Location", "Tasks", "Prompts", "Time", "Completion result")
    for i, text in enumerate(headers):
        table.cell(0, i).text = text
        shade_cell(table.cell(0, i), "D9F2F5")
        format_cell_text(table.cell(0, i), size=8.6, bold=True, color=MIDNIGHT, align=WD_ALIGN_PARAGRAPH.CENTER if i in (0, 3, 4, 5) else WD_ALIGN_PARAGRAPH.LEFT)
    set_repeat_table_header(table.rows[0])
    for idx, row in enumerate(quest_rows):
        cells = table.add_row().cells
        prevent_row_split(table.rows[-1])
        if idx % 2:
            for c in cells:
                shade_cell(c, "F6FBFC")
        for i, value in enumerate(row):
            cells[i].text = value
            format_cell_text(cells[i], size=8.25, bold=(i == 1), color=MIDNIGHT if i == 1 else INK, align=WD_ALIGN_PARAGRAPH.CENTER if i in (0, 3, 4, 5) else WD_ALIGN_PARAGRAPH.LEFT)
    set_table_geometry(table, [0.28, 1.05, 1.15, 0.42, 0.48, 0.65, 2.47])
    set_table_borders(table)

    doc.add_heading("Core gameplay loop", level=2)
    add_numbered_sequence(doc, [
        "Notice a Thought Spark or tangled pattern in the environment.",
        "Slow down and focus on one thought rather than the entire field.",
        "Observe its connections, category, and available evidence.",
        "Move it through the appropriate logic gate or constellation puzzle.",
        "Choose a kinder, believable, and useful next thought or action.",
        "See the decision reshape the path, awaken nature, and reveal the next landmark.",
        "Reflect only if desired, then continue or ask Milo for assistance.",
    ])

    doc.add_heading("Thought prompts and quiz philosophy", level=2)
    doc.add_paragraph(
        "Prompts are short interactive checks, not school tests. They assess understanding of the mechanic and help the player consider possibilities. Personal reflection is optional, private by default, and never scored. Each prompt should offer an audio replay, a ‘show me’ example, Milo assistance, and a skip option where the question is personal."
    )
    prompts = [
        ("Pattern", "Which dots belong to the same thought?", "Trace matching colour, rhythm, and line movement."),
        ("Meaning", "Is this a fact, a feeling, a prediction, or a question?", "Choose a category; Milo explains every option without shaming."),
        ("Fear Gate", "Is the thought warning us about a possibility or describing something known?", "Separate uncertain prediction from present fact."),
        ("Fear Gate", "What is the thought trying to protect?", "Choose safety, belonging, confidence, or ‘I am not sure’."),
        ("Proof Gate", "What evidence can we see or remember?", "Collect only evidence fragments connected to the thought."),
        ("Proof Gate", "What information is still missing?", "Mark uncertainty instead of inventing certainty."),
        ("Truth Gate", "What else might also be true?", "Select one or more plausible alternatives."),
        ("Truth Gate", "Which next thought is both kind and believable?", "Avoid unrealistic positivity; choose growth-oriented language."),
        ("Storm", "What is one small next step we can take now?", "Create the final route through the storm."),
    ]
    table = doc.add_table(rows=1, cols=3)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    for i, text in enumerate(("Stage", "Player-facing prompt", "Design intention")):
        table.cell(0, i).text = text
        shade_cell(table.cell(0, i), "D9F2F5")
        format_cell_text(table.cell(0, i), bold=True, color=MIDNIGHT)
    set_repeat_table_header(table.rows[0])
    for idx, row in enumerate(prompts):
        cells = table.add_row().cells
        prevent_row_split(table.rows[-1])
        if idx % 2:
            for c in cells:
                shade_cell(c, "F6FBFC")
        for i, value in enumerate(row):
            cells[i].text = value
            format_cell_text(cells[i], size=9)
    set_table_geometry(table, [1.0, 2.65, 2.85])
    set_table_borders(table)

    doc.add_heading("Example reframes", level=2)
    examples = [
        ("I am not good enough.", "I am learning, and I can improve one step at a time."),
        ("Something bad will happen.", "Something difficult might happen, and I can ask for help and choose a next step."),
        ("Everyone will laugh at me.", "I cannot know what everyone will do. Some people may support me."),
        ("I always fail.", "Some attempts have not worked yet; they can teach me what to try next."),
    ]
    table = doc.add_table(rows=1, cols=2)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    for i, text in enumerate(("Difficult thought", "Kinder, believable path")):
        table.cell(0, i).text = text
        shade_cell(table.cell(0, i), "D9F2F5")
        format_cell_text(table.cell(0, i), bold=True, color=MIDNIGHT)
    for row in examples:
        cells = table.add_row().cells
        cells[0].text, cells[1].text = row
        format_cell_text(cells[0])
        format_cell_text(cells[1])
    set_table_geometry(table, [2.6, 3.9])
    set_table_borders(table)

    # FINAL ENCOUNTER
    add_section_intro(
        doc,
        "Part 4",
        "The Thought Storm Final Encounter",
        "The finale is a three-phase puzzle that proves the player can use the world’s complete thought-understanding process under pressure.",
    )
    add_callout(doc, "BOSS RULE", "The Thought Storm is never struck, defeated, destroyed, or treated as evil. Success means transforming overload into gentle rain and a clear next path.", fill="F1ECFB", accent=VIOLET)
    phases = [
        ("Phase 1 — Slow the storm", "Activate three breath-and-focus anchors around the arena. Each anchor reduces rotation, lowers audio density, and reveals one layer of the storm.", "The player learns that slowing down changes what can be seen."),
        ("Phase 2 — Examine one thought", "Use Milo’s lens to select one Thought Spark. Reconnect its constellation, identify fear versus fact, and gather evidence fragments.", "The huge problem becomes one understandable thought."),
        ("Phase 3 — Create a hopeful path", "Choose what else may be true and place three light tiles representing a kind thought, a helpful action, and a support option.", "The storm opens, rain falls, and the route to the Oldest Tree appears."),
    ]
    table = doc.add_table(rows=1, cols=3)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    for i, text in enumerate(("Phase", "Player actions", "Emotional result")):
        table.cell(0, i).text = text
        shade_cell(table.cell(0, i), "E8E0F8")
        format_cell_text(table.cell(0, i), bold=True, color=VIOLET)
    for idx, row in enumerate(phases):
        cells = table.add_row().cells
        prevent_row_split(table.rows[-1])
        if idx % 2:
            for c in cells:
                shade_cell(c, "F8F5FD")
        for i, value in enumerate(row):
            cells[i].text = value
            format_cell_text(cells[i], size=9.1, bold=(i == 0), color=VIOLET if i == 0 else INK)
    set_table_geometry(table, [1.45, 3.15, 1.9])
    set_table_borders(table, color="CBBDEA")

    doc.add_heading("Encounter pacing and feedback", level=2)
    add_bullet(doc, "Opening: louder layered ambience, rapid ribbons, and low visibility communicate overload without horror.")
    add_bullet(doc, "Progress: every correct interaction removes one audio layer, slows one ribbon, and reveals more of the sanctuary silhouette.")
    add_bullet(doc, "Retry: an incorrect option produces a soft neutral pulse; Milo offers a clue after two attempts. No health loss or reset.")
    add_bullet(doc, "Completion: violet wind becomes pale rain, server lights settle into a steady rhythm, flowers open, and the gold star motif appears for the first time at full strength.")
    add_bullet(doc, "Reduced-motion mode: replace rapid spiral animation with layered translucent rings and gentle particle drift.")
    doc.add_heading("Reward sequence", level=2)
    add_numbered_sequence(doc, [
        "A cyan-and-gold route grows from the arena to the Oldest Tree.",
        "Gentle rain travels through the exposed fibre roots and awakens the sanctuary.",
        "The Star of Wisdom rises from the roots into the tree’s crown.",
        "Everlasting Father delivers the guardian line and recognises the player’s courage.",
        "The Star is recorded in the Gallery; the castle universe gains clear thought paths.",
        "Heart Melody Station and its next Crown Line segment become active.",
    ])

    # LEVEL DESIGN
    add_section_intro(
        doc,
        "Part 5",
        "World Layout & Architecture",
        "The island is a guided loop with readable hubs, optional forest pockets, unlockable shortcuts, and a strong visual promise of the final sanctuary.",
    )
    doc.add_heading("Recommended route", level=2)
    route = [
        "Rainbow Galaxy Train station and arrival bridge",
        "Entry arch and orientation grove",
        "Living server forest / Thought Spark collection loop",
        "Constellation court",
        "Fear Gate plaza",
        "Proof Gate plaza",
        "Truth Gate plaza",
        "Hope Path garden and shortcut junction",
        "Thought Storm containment arena",
        "Oldest Tree sanctuary",
        "Star platform and return rail",
    ]
    add_numbered_sequence(doc, route)
    doc.add_heading("Spatial design rules", level=2)
    for item in [
        "Create one dominant route and one optional discovery pocket per major zone; avoid maze-like dead ends.",
        "Place gates on raised circular plazas so their function reads before the player reaches them.",
        "Use cyan circuit traces as navigation language. Brighter and wider traces indicate the current objective; thin branches lead to optional discoveries.",
        "Use terrain elevation to separate story chapters: arrival low, logic plazas mid-level, storm high, sanctuary highest.",
        "Make every return trip shorter by opening a bridge, lift, rail spur, or light path after quest completion.",
        "Keep traversal accessible: broad ramps alongside stairs, forgiving jumps, strong edge rails where appropriate, and recovery volumes below the island.",
        "Reserve quiet negative space around gates, the storm, and the Oldest Tree so the hero objects remain readable.",
    ]:
        add_bullet(doc, item)
    doc.add_heading("Architecture identity", level=2)
    doc.add_paragraph(
        "Mind Spark should feel monumental without using a conventional castle. Its architecture is a network of glass logic frames, raised analysis platforms, server-tree groves, observatory rings, root-supported terraces, and star sanctuaries. Repetition establishes a technological system; natural variation prevents sterility; magical focal points create awe."
    )
    add_callout(doc, "ASSET TEST", "Before approving an object, ask: Does it help the player think, make the world feel alive, or communicate wisdom and wonder? If it supports none of these, remove or redesign it.")

    # OBJECT CATALOGUE
    add_section_intro(
        doc,
        "Part 6",
        "Complete Object & Asset Catalogue",
        "The following catalogue is the recommended production inventory. Quantities indicate placed instances or required variants, not necessarily separate unique models.",
    )
    add_inventory_table(doc, "6.1 World foundation and terrain", "Build these modular pieces first; every gameplay zone depends on them.", [
        ("Main floating-island shell", "1", "Large circular low-poly island with a faceted white/blue underside; divided into streamable or cullable sectors."),
        ("Island edge modules", "8–12", "Straight, concave, convex, and broken rim pieces with safe collision and readable silhouettes."),
        ("Hanging cyan crystal formations", "12–18", "Three length variants beneath the island; glow gently and reinforce the galaxy setting."),
        ("Embedded crystal-vein decals/meshes", "10–16", "Cyan lines within the island edge; connect visually to surface circuits."),
        ("Primary terrain terraces", "7", "Arrival, forest, constellation, three gate districts, storm, and sanctuary elevation bands."),
        ("Circular plaza bases", "5", "Constellation court, three logic gates, and storm arena; bevelled modular rings."),
        ("Sanctuary hero platform", "1", "Largest raised platform with root sockets, ceremonial stair, and star focal axis."),
        ("Ramp modules", "6–10", "Accessible slopes matching the tile grid; used beside or instead of stairs."),
        ("Stair modules", "5–8", "Short, medium, and ceremonial variants with cyan edge light."),
        ("Low retaining walls", "20–30", "Define terraces without blocking sightlines; mix glass and pale stone."),
        ("Glass floor panels", "20–28", "Reveal circuit traces and fibre roots beneath selected paths and plazas."),
        ("Ground tile kit", "12", "White, ice-cyan, cracked, inset, node, edge, corner, and transparent variants."),
        ("Soft recovery cloud/fog layer", "1", "Hides lower reset volume and supports the floating-world mood."),
        ("Navigation collision mesh", "1 set", "Simplified, stable collision separate from decorative terrain."),
    ])
    add_inventory_table(doc, "6.2 Paths, bridges, and railway", "These assets make progression readable and connect Mind Spark to the larger Art Castle Galaxy.", [
        ("Primary circuit path", "1 kit", "Wide luminous route with animated direction pulses and clean corner pieces."),
        ("Secondary circuit branches", "1 kit", "Narrow paths to optional Sparks, views, and lore terminals."),
        ("Circuit node junction", "8–12", "Round intersection motif used at decisions and quest transitions."),
        ("Hope Path tiles", "12–18", "Player-placed or animated tiles that appear after reframing a thought."),
        ("Energy bridge", "2–4", "Short transparent spans that activate after gates; include off/on states."),
        ("Root bridge", "1–2", "Nature-tech bridge formed from roots wrapped around a cyan energy spine."),
        ("Arrival bridge", "1", "Strong visual threshold from train station to entry arch."),
        ("Sanctuary staircase", "1", "Ceremonial climb with wide steps, ramp option, crystals, and gold reveal framing."),
        ("Shortcut lift/platform", "2", "Unlock after quests to reduce backtracking; use a calm vertical motion profile."),
        ("Mind Spark station platform", "1", "Galaxy railway stop with world symbol, shelter frame, and safe boarding edge."),
        ("Crown Line track segment", "1 set", "Main rail connection from Gallery toward Heart Melody after completion."),
        ("Shortcut rail growth effect", "1", "Glowing rails assemble across the galaxy when a destination becomes available."),
        ("Station destination emblem", "1", "Mind Spark star-and-node symbol readable from the train."),
        ("Return portal/platform", "1", "Post-reward route to the Gallery; remains available for replay."),
    ])

    add_inventory_table(doc, "6.3 Architecture and major landmarks", "No castle castle is required. Monumentality comes from logic, glass, roots, and starlight.", [
        ("Cyan glass entry arch", "1", "First threshold; simple enough to match the prototype and bright enough to guide arrival."),
        ("Fear Gate", "1", "Single-ring logic frame; iconography communicates uncertainty and prediction."),
        ("Proof Gate", "1", "Double-support analysis frame with evidence slots and scan beams."),
        ("Truth Gate", "1", "Three-ring frame suggesting multiple possibilities; final logic gate."),
        ("Gate plaza support pylons", "6–9", "Small cyan/glass towers that frame each gate without creating clutter."),
        ("Constellation court ring", "1 set", "Concentric stone/glass circles with engraved node geometry."),
        ("Observatory pylons", "6–8", "Short posts around the constellation court; project lines and instructions."),
        ("Thought Storm containment rings", "3", "Layered arena rings with anchor sockets and calm-state animations."),
        ("Storm energy anchors", "3", "Breath/focus interactables around the arena; each visibly slows the storm."),
        ("Oldest Tree sanctuary", "1", "Hero architectural/natural landmark integrating terrace, roots, boundary markers, and reward platform."),
        ("Wisdom boundary crystals", "8–12", "Tall cyan crystals encircle the sanctuary and transition toward gold after completion."),
        ("Guardian appearance dais", "1", "Quiet, unobtrusive platform beside the sanctuary; never reads as a throne or judgement seat."),
        ("Rest and reflection pads", "3–5", "Circular safe spaces with low light, seating stones, and optional Milo dialogue."),
        ("Viewpoint balconies", "2–3", "Small overlooks toward the storm, tree, and railway; include rails and photo framing."),
        ("Service arches and root tunnels", "3–5", "Secondary thresholds that break long routes into readable chapters."),
    ])

    add_inventory_table(doc, "6.4 Technology and science objects", "Technology should appear as a living system rather than a cold laboratory.", [
        ("Server-tree tower — small", "6–8", "Short charcoal tower with cyan core vent and root sockets."),
        ("Server-tree tower — medium", "12–16", "Main forest rhythm asset; vary top bevel, seam, and light pattern."),
        ("Server-tree tower — tall", "8–12", "Landmark silhouette and canopy-height contrast; never blocks critical cameras."),
        ("Server tower crystal-fin variant", "4–6", "Adds antenna-like cyan crystal cap to important nodes."),
        ("Fibre-optic root network", "20–30", "Branching emissive root pieces that connect towers, gates, and trees."),
        ("Data pulse spline", "8–12", "Animated light packet moving along routes and roots toward current objectives."),
        ("Thought-mapping console", "3–4", "Low, child-readable interface for arranging dots and lines."),
        ("Milo analysis pedestal", "4–6", "Summons Milo’s lens, instructions, examples, or auto-assist."),
        ("Evidence scanner", "2–3", "Projects a calm sweep across fragments; uses shape and audio as well as colour."),
        ("Evidence fragment", "12–18", "Small physical data shards; known fact, missing information, and assumption have distinct silhouettes."),
        ("Thought-category sorter", "1–2", "Four receptacles for worry, fear, dream, and hope; no category is labelled bad."),
        ("Holographic node projector", "6–10", "Creates constellation dots above courts and small quest spaces."),
        ("Floating data cube", "12–20", "Ambient fragments near the storm and towers; low density during gameplay."),
        ("Dormant thought terminal", "4–6", "Optional lore or reflection object with awake/asleep state."),
        ("Scan beacon / guidance post", "10–14", "Short route marker with directional pulse and accessible audio cue."),
        ("Circuit junction box", "10–16", "Ground detail at branching traces; decorative and occasionally interactive."),
        ("Light bell receiver", "2–3", "Responds to the Rainbow Galaxy Train bell by waking nearby lights or plants."),
        ("Milo Drive station control", "1", "Allows automatic train arrival/departure support."),
    ])

    add_inventory_table(doc, "6.5 Nature objects", "Nature shows that cognition is alive, changing, and capable of growth.", [
        ("Lavender canopy tree — small", "10–14", "Low rounded crown; clusters near path edges without hiding objectives."),
        ("Lavender canopy tree — medium", "16–22", "Primary forest asset with faceted trunk and layered mushroom-like crown."),
        ("Lavender canopy tree — large", "6–8", "Creates grove landmarks and frames gates or views."),
        ("Emerald pine — small", "12–18", "Vertical accent and colour contrast; use in sparse groups."),
        ("Emerald pine — tall", "6–10", "Breaks canopy rhythm and guides the eye toward higher terrain."),
        ("Hybrid circuit tree", "4–6", "Natural trunk with embedded cyan channels; bridge asset between forests and architecture."),
        ("The Oldest Tree", "1", "Hero-quality trunk, branching crown, exposed glowing roots, hanging data leaves, and lavender canopy."),
        ("Glowing root — thin", "16–24", "Ground-level detail connecting plants to circuits."),
        ("Glowing root — structural", "8–12", "Large roots supporting terraces, bridge edges, and sanctuary forms."),
        ("Living vine", "12–20", "Wraps towers and gates; include dormant and awakened states."),
        ("Thought flower", "18–30", "Closed before a helpful reframe; opens with a cyan-violet bloom."),
        ("Wisdom flower", "6–10", "Rare gold-centred flower used only near the sanctuary and after completion."),
        ("Crystal fern", "12–18", "Low ground-cover prop that mixes plant silhouettes with translucent material."),
        ("Data grass cluster", "20–30", "Simple triangular blades with occasional light tips; fill only secondary spaces."),
        ("Luminous bud cluster", "12–16", "Small lavender/cyan buds used around rest pads and optional Sparks."),
        ("Violet thought stones", "40–60", "Small faceted ground rhythm pieces; three scale variants and restrained placement."),
        ("Sanctuary root pool", "1", "Shallow reflective basin where gentle rain reaches the Oldest Tree."),
        ("Rain-catching leaf", "6–10", "Large stylised leaf showing storm-to-rain transformation."),
        ("Optional ambient life", "3 sets", "Circuit fireflies, light moths, and data birds; subtle, friendly, non-interactive."),
    ])

    add_inventory_table(doc, "6.6 Magic and wisdom objects", "Magic should transform meaning and atmosphere; it should not behave like weapon power.", [
        ("Thought Spark — worry", "6", "Violet pulsing light with slightly looping movement; collect/process without negative judgement."),
        ("Thought Spark — fear", "6", "Faster flicker and protective orbit; slows when observed."),
        ("Thought Spark — dream", "6", "Upward drifting light with star-like trail."),
        ("Thought Spark — hope", "6", "Warm cyan-violet light that gently points toward possible routes."),
        ("Core required Thought Sparks", "12", "Selected from the full set; placed on main route to guarantee story completion."),
        ("Optional Thought Sparks", "12", "Placed in discovery pockets; unlock Gallery memories, dialogue, or cosmetics."),
        ("Thought constellation nodes", "8–12/set", "Movable glowing dots linked by elastic lines; clarity is shown through spacing and rhythm."),
        ("Constellation line", "1 system", "Dynamic line renderer with tangled, selected, solved, and reduced-motion states."),
        ("Truth path glow", "1 system", "Bright route that grows through the ground after a helpful reframe."),
        ("Hope tile", "3 hero + kit", "Final player choices become three physical lights: thought, action, and support."),
        ("Wisdom particle", "1 system", "Small gold motes reserved for guardian and Star moments."),
        ("Guardian light form", "1", "Calm silhouette/appearance effect for Everlasting Father; avoid intimidating scale."),
        ("Star of Wisdom", "1", "Primary treasure; gold star with halo ring, gentle rotation, and readable inventory icon."),
        ("Star roots emergence effect", "1", "Gold light travels from sanctuary roots into the tree crown before the Star appears."),
        ("Memory star", "3–5", "Optional railway/viewpoint reward replaying a completed learning moment."),
        ("Post-completion clear-sky aura", "1", "Subtle persistent world-state effect after the Star is collected."),
    ])

    add_inventory_table(doc, "6.7 Puzzle and interaction objects", "These objects form the playable task layer; every one needs clear idle, focus, success, help, and completed states.", [
        ("Focus anchor", "3", "Storm Phase 1 interaction; breathing rhythm and hold/press alternatives."),
        ("Movable thought node", "12–20", "Grab, drag, keyboard/controller nudge, snap, and undo support."),
        ("Connection socket", "12–20", "Shows valid node relationships using shape, animation, and sound."),
        ("Fear/fact selection pads", "2 sets", "Large floor choices with icons and spoken labels."),
        ("Evidence receptacle", "3", "Known, unknown, and assumption destinations for evidence fragments."),
        ("Alternative-truth rings", "3", "Selectable possibilities around Truth Gate; multiple options may be valid."),
        ("Helpful-thought builder", "1", "Combines phrase pieces or symbol cards into a kind, believable statement."),
        ("Next-step selector", "1", "Action, pause, Milo help, and trusted-person support choices."),
        ("Milo hint beacon", "1 system", "Appears after player request or repeated attempt; never activates as punishment."),
        ("Undo / reset pedestal", "1 per puzzle", "Returns only the current puzzle to a safe starting arrangement."),
        ("Skip reflection control", "1 system", "Allows personal questions to be skipped without reducing rewards."),
        ("Quest completion node", "8", "Persistent visual marker showing each main quest’s state."),
        ("Checkpoint / save light", "8–10", "Auto-saves after major beats; uses a quiet pulse and clear icon."),
        ("Collectible memory seed", "6–9", "Optional discovery that becomes a Gallery display or train-view memory."),
        ("Rest pad interaction", "3–5", "Pause, replay learning, talk with Milo, or adjust sensory settings."),
        ("World-state activator", "1 system", "Coordinates forest waking, path changes, weather, and post-completion visuals."),
        ("Return-to-station control", "1", "Available after completion and through accessibility menu where appropriate."),
    ])

    add_inventory_table(doc, "6.8 Characters, creatures, and presentation assets", "World One requires a small cast; animation quality matters more than character quantity.", [
        ("Player character", "1", "Existing ARTÉA avatar with walk, run, jump, interact, look, celebrate, and calm-idle states."),
        ("Milo companion", "1", "Glow AI guide with follow, point, scan, listen, encourage, drive, and assist states."),
        ("Everlasting Father guardian", "1", "Truth-and-wisdom presence with calm arrival, dialogue, blessing, and fade states."),
        ("Thought Spark behaviour set", "4", "Distinct movement behaviours for worry, fear, dream, and hope."),
        ("Circuit firefly flock", "1–2", "Ambient life around awakened roots; low-cost pooled particles or simple sprites."),
        ("Light moth flock", "1", "Appears in the gentle rain and guides the final sanctuary route."),
        ("Data bird group", "1", "Optional distant silhouettes near towers and railway; no quest dependency."),
        ("Dialogue portraits/icons", "3", "Player-neutral UI treatment, Milo portrait/icon, and guardian portrait/icon."),
    ])

    add_inventory_table(doc, "6.9 Environmental props and dressing", "Use these details to imply a functioning world without burying the route in clutter.", [
        ("Memory crystal", "6–10", "Optional lore, replay, or Gallery connection; place at views and quiet pockets."),
        ("Guiding light post", "10–14", "Marks route direction, gate status, and safe platform edges."),
        ("Reflection stone seat", "6–10", "Low faceted seat beside rest pads and overlooks."),
        ("Small scan pedestal", "4–6", "Environmental explanation, world icon, or optional tutorial replay."),
        ("Root lantern", "8–12", "Cyan light enclosed by branching organic frame."),
        ("Gate status crystal", "3", "Dormant, active, solved, and replay states for each logic gate."),
        ("World emblem plaque", "4–6", "Star-and-node symbol used at station, entry, plazas, and sanctuary."),
        ("Path-edge crystal", "20–30", "Low markers spaced only where terrain edges need additional readability."),
        ("Weather vane / data ribbon", "4–6", "Shows storm direction and reduced motion through simple cloth-like geometry."),
        ("Optional photo marker", "2–3", "Frames safe scenic views; no social-sharing dependency required."),
        ("Post-completion flower trail", "1 set", "Persistent route from arrival to sanctuary after the world is complete."),
        ("Gallery treasure display base", "1", "Receives the Star of Wisdom when the player returns to the Gallery."),
    ])

    # PRESENTATION SYSTEMS
    add_section_intro(
        doc,
        "Part 7",
        "Art, Effects, Audio, UI & Player Care",
        "Presentation systems should reinforce understanding. Effects become calmer as the player makes the world readable.",
    )
    add_inventory_table(doc, "7.1 Lighting, weather, and visual effects", "Every effect needs performance-scalable variants for the Godot Web build.", [
        ("Base daylight rig", "1", "Bright diffuse cyan daylight with soft directional shadows and readable material separation."),
        ("Ambient sky/haze", "1", "Pastel cyan background with distant particles; no busy galaxy texture behind gameplay."),
        ("Circuit emission pulse", "1 system", "Slow directional light along current paths; brightness adjustable."),
        ("Root awakening effect", "1 system", "Cyan light spreads through roots after solved tasks."),
        ("Flower opening effect", "1 system", "Simple scale/rotation bloom triggered by helpful reframes."),
        ("Thought Spark trails", "4 variants", "Category-specific trails with reduced-particle option."),
        ("Constellation solve burst", "1", "Clean radial pulse, never an explosive effect."),
        ("Gate scan effect", "3 variants", "Fear, proof, and truth scans share language but have distinct motion."),
        ("Thought Storm ribbons", "3–5", "Layered violet/cyan spirals with controllable speed and reduced-motion replacement."),
        ("Storm data cubes", "12–20 pooled", "Suspended fragments that settle as phases complete."),
        ("Gentle rain system", "1", "Soft rain with restrained screen coverage and no vision obstruction."),
        ("Wet/glow transition", "1", "Roots and sanctuary brighten when rain arrives; avoid expensive full-scene reflections."),
        ("Wisdom gold reveal", "1", "Gold root travel, star emergence, halo, and restrained bloom."),
        ("Guardian appearance effect", "1", "Warm soft light and particles; no lightning or threatening scale change."),
        ("Completion sky clear", "1", "Haze lightens and distant star path becomes visible."),
        ("Interaction focus outline", "1 system", "Shape-plus-colour highlight for objects in range."),
        ("Objective landmark beam", "1 system", "Subtle vertical guide used sparingly and removable in settings."),
        ("Edge recovery shimmer", "1", "Warns and guides without invisible-looking boundaries."),
    ])

    add_inventory_table(doc, "7.2 Audio and music", "Audio carries emotional change from busy uncertainty to clear calm.", [
        ("Mind Spark exploration theme", "1", "Light electronic pulse, glass tones, soft organic pads, and space for dialogue."),
        ("Forest dormant layer", "1", "Low data hum, restrained wind, sleeping roots."),
        ("Forest awakened layer", "1", "Added warm arpeggio, leaves, gentle chimes, and life sounds."),
        ("Constellation puzzle music", "1", "Sparse notes that become harmonic as node crossings are removed."),
        ("Fear Gate cue", "1", "Protective low pulse; resolves gently rather than triumphantly."),
        ("Proof Gate cue", "1", "Clear ticking/plucked motif associated with evidence fragments."),
        ("Truth Gate cue", "1", "Wider harmony showing multiple possibilities."),
        ("Thought Storm score", "3 layers", "Dense opening, slowed examination, hopeful resolution; layers fade with progress."),
        ("Gentle rain ambience", "1", "Soft rain, roots, distant birds, and resolved harmonic bed."),
        ("Wisdom Tree theme", "1", "Warm reprise with restrained gold bell motif."),
        ("Thought Spark category sounds", "4", "Distinct but pleasant cues for worry, fear, dream, and hope."),
        ("Gate interaction sounds", "12–15", "Idle, focus, selection, neutral retry, assist, success, and replay states."),
        ("Circuit and root sounds", "8–12", "Directional data pulses, roots waking, bridge forming, and junction activating."),
        ("Milo voice/bleep set", "1 set", "Listen, clue, encouragement, confirmation, safety support, and train assistance."),
        ("Guardian voice set", "1 set", "Short, calm, reverent delivery with full subtitles."),
        ("Railway/station sounds", "1 set", "Approach, stop, door, bell response, departure, and route unlock."),
        ("Accessibility audio cues", "1 set", "Navigation pings, focus confirmation, objective direction, and error-neutral feedback."),
        ("Mix snapshots", "5", "Exploration, dialogue, puzzle focus, storm, and reward; protect speech intelligibility."),
    ])

    add_inventory_table(doc, "7.3 UI, navigation, and accessibility", "The UI must make reflection safe and keep puzzle instructions understandable across ages and abilities.", [
        ("World title card", "1", "Mind Spark name, theme, and symbol; brief and skippable."),
        ("Quest tracker", "1", "One current action, optional hint, and progress without pressure or countdown."),
        ("Thought prompt panel", "1", "Large choices, spoken labels, controller focus, and ‘I am not sure’ where appropriate."),
        ("Milo conversation panel", "1", "Listen, reflect, encourage, offer choices, and celebrate structure."),
        ("Thought category icons", "4", "Worry, fear, dream, and hope distinguished by shape, motion, text, and colour."),
        ("Gate icons", "3", "Fear/fact, evidence/proof, and alternative truth symbols."),
        ("World progress map", "1", "Shows eight quests and opened shortcuts without revealing personal answers."),
        ("Thought Spark counter", "1", "Displays 12 core and 12 optional discoveries separately."),
        ("Star of Wisdom inventory card", "1", "Treasure meaning, world completion, and Gallery location."),
        ("Hint and example overlay", "1", "Milo demonstration with replay, step-by-step mode, and auto-solve option."),
        ("Pause / sensory settings", "1", "Motion, particles, bloom, contrast, audio layers, text size, and camera shake controls."),
        ("Subtitles and speaker labels", "1 system", "Adjustable size, contrast background, sound captions, and no dialogue-only instruction."),
        ("Input remapping and hold/toggle", "1 system", "Keyboard, controller, touch/Web as supported; alternatives for dragging and holding."),
        ("Skip/private controls", "1 system", "Personal prompts may be skipped or kept private with identical progression rewards."),
        ("No-timer default", "1 rule", "Puzzles are untimed unless the player deliberately enables a challenge replay."),
        ("Reduced-motion storm", "1 mode", "Static layered rings, slower particles, no rapid spirals or camera shake."),
        ("Colour-independent readability", "1 rule", "Every state also uses icon, silhouette, pattern, label, or audio."),
        ("Safety support route", "1", "If the player may be unsafe, Milo guides them toward a trusted adult or appropriate real-world support."),
    ])

    doc.add_heading("Milo care rules", level=2)
    for item in [
        "Milo is an AI helper, not a human counsellor or medical professional.",
        "Milo does not diagnose, label, or tell the player what they must feel.",
        "Milo listens first, reflects tentatively, encourages, offers choices, and celebrates strengths.",
        "Milo never asks the player to keep secrets from trusted adults.",
        "The player can pause, skip a question, keep an answer private, or ask for human help.",
        "Personal reflection answers are not required to unlock the Star of Wisdom.",
    ]:
        add_bullet(doc, item)

    # TECHNICAL / PRODUCTION
    add_section_intro(
        doc,
        "Part 8",
        "Technical Systems & Production Plan",
        "Invisible systems are part of the world design. They protect progress, clarity, accessibility, performance, and reliable play on the Godot Web target.",
    )
    add_inventory_table(doc, "8.1 Invisible and technical objects", "These objects may not appear in screenshots, but the world cannot ship safely without them.", [
        ("Player spawn points", "3–5", "Station arrival, world entrance, storm retry, sanctuary return, and replay start."),
        ("Checkpoint triggers", "8–10", "Save after each quest and before/after the storm; never inside unstable traversal."),
        ("Quest state controller", "1", "Tracks eight quests, gate states, world transformations, and replay."),
        ("World completion controller", "1", "Awards Star, updates Gallery, opens railway, and persists cleared state."),
        ("Thought Spark manager", "1", "Tracks 12 core and 12 optional Sparks with category and privacy-safe metadata."),
        ("Puzzle state controllers", "6–8", "Constellation, three gates, helpful-thought builder, storm, and reward sequence."),
        ("Dialogue trigger volumes", "12–18", "Milo and guardian lines; retrigger rules prevent repetition fatigue."),
        ("Objective trigger volumes", "10–14", "Update route pulse, camera framing, and quest tracker."),
        ("Camera zones", "8–12", "Protect visibility at gates, storm, sanctuary, and narrow bridges."),
        ("Camera collision volumes", "1 set", "Prevent geometry clipping and loss of player view."),
        ("Navigation mesh / regions", "1 set", "Milo following, optional ambient creatures, and stable pathing."),
        ("Simplified collision set", "1 set", "Terrain, props, gates, rail, tree roots, and accessibility ramps."),
        ("Fall recovery volumes", "1 set", "Return player to latest safe surface with no punishment."),
        ("Interaction areas", "1 per interactable", "Consistent focus range and controller priority."),
        ("Audio zones and reverb buses", "8–10", "Forest, courts, gates, storm, sanctuary, and station transitions."),
        ("VFX spawn/pool manager", "1", "Controls particles, Thought Sparks, rain, data cubes, and Web performance limits."),
        ("Lighting quality profiles", "3", "Low, medium, high; preserve route clarity at every level."),
        ("LOD / visibility ranges", "1 set", "Trees, towers, crystals, props, particles, and underside geometry."),
        ("Occlusion/culling regions", "1 set", "Reduce cost behind terraces and across the large island."),
        ("Accessibility state manager", "1", "Reduced motion, auto-assist, contrast, text, audio, and input preferences."),
        ("Analytics events — privacy safe", "Optional", "Quest completion and assistance use only; never store personal reflection text without explicit consent."),
        ("Web performance monitor", "1", "Tracks frame time, particle count, draw calls, and memory during QA."),
        ("Automated test hooks", "1 set", "Quest progression, save/load, gate completion, storm resolution, Star award, and station unlock."),
        ("Debug world-state selector", "1 dev tool", "Jump to quest stages for fast testing; excluded or disabled in production."),
    ])

    doc.add_heading("Production scope estimate", level=2)
    scope_rows = [
        ("Hero landmarks", "10–14", "Entry, three gates, constellation court, storm arena, Oldest Tree, Star, station, return point."),
        ("Reusable environment modules", "40–55", "Terrain, edge, stairs, ramps, walls, paths, bridges, plaza rings, glass panels."),
        ("Technology props and variants", "28–40", "Server towers, consoles, pylons, scanners, roots, nodes, terminals, beacons."),
        ("Nature props and variants", "30–45", "Trees, pines, vines, roots, flowers, ground cover, stones, ambient life."),
        ("Magic/puzzle objects", "24–35", "Thought Sparks, constellations, gates, evidence, hope tiles, Star systems."),
        ("VFX and lighting systems", "18–24", "World pulses, storm, rain, awakenings, reward, guidance, interaction feedback."),
        ("Audio assets and mix states", "30–45", "Music layers, ambience, interactions, dialogue cues, railway, accessibility."),
        ("UI and accessibility components", "15–20", "Prompts, tracker, map, icons, settings, hint/skip/privacy and treasure states."),
        ("Technical systems", "22–30", "Quest, save, navigation, camera, collision, triggers, pooling, LOD, test hooks."),
    ]
    table = doc.add_table(rows=1, cols=3)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    for i, text in enumerate(("Production family", "Estimated pieces", "Scope notes")):
        table.cell(0, i).text = text
        shade_cell(table.cell(0, i), "D9F2F5")
        format_cell_text(table.cell(0, i), bold=True, color=MIDNIGHT)
    set_repeat_table_header(table.rows[0])
    for idx, row in enumerate(scope_rows):
        cells = table.add_row().cells
        if idx % 2:
            for c in cells:
                shade_cell(c, "F6FBFC")
        for i, value in enumerate(row):
            cells[i].text = value
            format_cell_text(cells[i], size=9)
    set_table_geometry(table, [2.0, 1.0, 3.5])
    set_table_borders(table)
    add_callout(doc, "SCOPE NOTE", "These numbers are planning ranges, not a requirement for every piece to be a unique model. A disciplined modular kit and material variants should create most of the richness seen in the professional concept.")

    doc.add_heading("Recommended build order", level=2)
    build_order = [
        "Greybox the full island route, terraces, recovery volumes, station, storm arena, and sanctuary; validate walking time and sightlines.",
        "Implement quest state, save/load, core Thought Spark interaction, and Milo assistance before detailed art.",
        "Build the constellation puzzle and three logic gates with final accessibility behaviour.",
        "Implement the three Thought Storm phases and complete reward/unlock flow.",
        "Create the modular terrain, path, glass, server-tower, root, and tree kits; replace greybox by zone.",
        "Add hero landmarks: gates, storm containment architecture, Oldest Tree, guardian dais, and Star of Wisdom.",
        "Add VFX, lighting, music layers, dialogue, UI, and post-completion world state.",
        "Dress optional pockets with secondary props and collectibles only after route clarity and performance are stable.",
        "Run accessibility, save/reload, regression, Web performance, and full-journey playtests; tune timing from observed player behaviour.",
    ]
    add_numbered_sequence(doc, build_order)

    doc.add_heading("Performance and Web guidance", level=2)
    for item in [
        "Prefer shared materials, atlases, instancing, MultiMesh, pooled particles, and modular geometry.",
        "Keep transparent objects and full-screen bloom controlled; glass and particles are the highest-risk visual costs.",
        "Use baked or simplified lighting where possible, with a small number of meaningful dynamic lights.",
        "Provide low/medium/high profiles that reduce particles, shadows, reflection, and foliage density without removing gameplay cues.",
        "Test the complete Godot Web export in a real WebGL2 browser, including first-load memory, storm effects, train transitions, save/load, and controller input.",
        "Do not let decorative data fragments, rain, or tree density obscure the player or active interactables at any quality setting.",
    ]:
        add_bullet(doc, item)

    # ACCEPTANCE
    add_section_intro(
        doc,
        "Part 9",
        "World One Acceptance Checklist",
        "Mind Spark is complete only when its story, emotional safety, navigation, visual identity, progression, and technical reliability work together.",
    )
    checks = {
        "Identity": [
            "Technology/Science is immediately dominant, with visible support from Nature and Magic.",
            "The world reads as a living computer forest, not a futuristic city or castle castle.",
            "Cyan, violet, white, charcoal, emerald, and restrained gold follow the approved hierarchy.",
            "The professional concept’s entrance, gates, central court, storm, and sanctuary remain recognisable.",
        ],
        "Story and learning": [
            "The player understands that a thought is not always a fact.",
            "No thought is attacked, shamed, deleted, or treated as proof that the player is broken.",
            "Milo’s dialogue listens, reflects, encourages, offers choices, and supports human help when needed.",
            "The guardian recognises courage; the Star celebrates wisdom already growing in the player.",
        ],
        "Gameplay and progression": [
            "All eight quests can be completed in order and resumed from checkpoints.",
            "The 19 required interactions teach before testing and provide optional assistance.",
            "All nine prompts accept uncertainty, replay instructions, and avoid scoring personal reflection.",
            "The three storm phases transform the storm into rain and reliably open the sanctuary route.",
            "The Star updates the Gallery and unlocks Heart Melody Station without blocking replay." ,
        ],
        "World and objects": [
            "Current and future landmarks remain visible from key routes.",
            "Terrain, gates, props, foliage, effects, and audio use the catalogue consistently.",
            "Optional dressing never blocks interaction, camera, traversal, or route readability.",
            "Post-completion changes persist: clear paths, awakened forest, gentle weather, and visible wisdom route." ,
        ],
        "Accessibility and care": [
            "No mandatory timer, health loss, combat, or punitive reset is used.",
            "Reduced motion, colour-independent cues, subtitles, scalable text, input alternatives, hint, skip, and auto-assist are functional.",
            "Falling returns the player to safety without losing meaningful progress.",
            "Personal answers remain private by default and are not required for rewards." ,
        ],
        "Technical quality": [
            "Save/load works at every checkpoint and preserves puzzle, treasure, Gallery, and station state.",
            "Native and Web builds meet frame, memory, and loading targets during the Thought Storm and train transitions.",
            "Automated tests cover quest flow, gates, storm resolution, Star award, post-world state, and station unlock.",
            "A complete first-playthrough test confirms the intended 85–110 minute range or provides evidence for retuning." ,
        ],
    }
    for group, items in checks.items():
        doc.add_heading(group, level=2)
        for item in items:
            add_check(doc, item)

    add_callout(
        doc,
        "FINAL WORLD MESSAGE",
        "You found the courage to understand your thoughts and choose hope. The wisdom was already growing inside you.",
        fill="FFF6D8",
        accent=GOLD,
    )
    doc.add_heading("Relationship to the next world", level=2)
    doc.add_paragraph(
        "Mind Spark establishes that thoughts can be understood. Heart Melody then teaches that feelings have a safe voice. Creator’s Light allows the player to express identity through creation. The Star of Wisdom therefore should not feel like a final answer; it is the first light in a connected journey toward the Crown of Life."
    )

    # BACK VISUAL
    doc.add_page_break()
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(12)
    p.paragraph_format.space_after = Pt(4)
    r = p.add_run("WORLD ONE  •  MIND SPARK")
    set_run(r, size=11, bold=True, color=VIOLET)
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(12)
    r = p.add_run("A living computer forest where thoughts grow like stars and wisdom reorganizes the path.")
    set_run(r, size=18, bold=True, color=MIDNIGHT)
    picture_with_alt(doc, HERO, Inches(6.5), "Final professional Mind Spark world image.")
    add_caption(doc, "Approved direction for World One’s professional environment identity.")
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(12)
    r = p.add_run("DISCOVERY, NOT FIXING")
    set_run(r, size=13, bold=True, color=GOLD)
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("The player already has light. Mind Spark helps them see how wisdom can grow from attention, truth, kindness, and hope.")
    set_run(r, size=11, italic=True, color=MUTED)

    # Global paragraph safety.
    for p in doc.paragraphs:
        if p.style and p.style.name.startswith("Heading"):
            p.paragraph_format.keep_with_next = True
        p.paragraph_format.widow_control = True

    doc.save(OUT)
    print(OUT)


if __name__ == "__main__":
    build_document()
