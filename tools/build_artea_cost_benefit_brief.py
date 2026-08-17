from pathlib import Path

from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_ALIGN_VERTICAL, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK, WD_LINE_SPACING
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


ROOT = Path("/Users/davidsovann/S2603")
OUTPUT = ROOT / "artifacts" / "ARTEA_Phase_3_Solution_Cost_Benefit_Brief.docx"
WORKFLOW = ROOT / "artifacts" / "artea_workflow.png"

BLUE = "2E74B5"
DARK_BLUE = "1F4D78"
NAVY = "17365D"
INK = "202830"
MUTED = "5E6873"
LIGHT_BLUE = "E8EEF5"
LIGHT_GRAY = "F2F4F7"
PALE_GREEN = "EAF5EF"
PALE_GOLD = "FFF7E6"
WHITE = "FFFFFF"
GRID = "C8D1DC"
RED = "9B1C1C"

CONTENT_DXA = 9360
TABLE_INDENT_DXA = 120


def rgb(hex_value: str) -> RGBColor:
    return RGBColor.from_string(hex_value)


def set_cell_shading(cell, fill: str) -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_cell_margins(cell, top=80, start=120, bottom=80, end=120) -> None:
    tc = cell._tc
    tc_pr = tc.get_or_add_tcPr()
    tc_mar = tc_pr.first_child_found_in("w:tcMar")
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for margin, value in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        node = tc_mar.find(qn(f"w:{margin}"))
        if node is None:
            node = OxmlElement(f"w:{margin}")
            tc_mar.append(node)
        node.set(qn("w:w"), str(value))
        node.set(qn("w:type"), "dxa")


def set_cell_width(cell, width_dxa: int) -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    tc_w = tc_pr.find(qn("w:tcW"))
    if tc_w is None:
        tc_w = OxmlElement("w:tcW")
        tc_pr.append(tc_w)
    tc_w.set(qn("w:w"), str(width_dxa))
    tc_w.set(qn("w:type"), "dxa")


def prevent_row_split(row) -> None:
    tr_pr = row._tr.get_or_add_trPr()
    cant_split = OxmlElement("w:cantSplit")
    tr_pr.append(cant_split)


def set_table_geometry(table, widths) -> None:
    assert sum(widths) == CONTENT_DXA
    table.alignment = WD_TABLE_ALIGNMENT.LEFT
    table.autofit = False
    tbl_pr = table._tbl.tblPr

    tbl_w = tbl_pr.find(qn("w:tblW"))
    if tbl_w is None:
        tbl_w = OxmlElement("w:tblW")
        tbl_pr.append(tbl_w)
    tbl_w.set(qn("w:w"), str(CONTENT_DXA))
    tbl_w.set(qn("w:type"), "dxa")

    tbl_ind = tbl_pr.find(qn("w:tblInd"))
    if tbl_ind is None:
        tbl_ind = OxmlElement("w:tblInd")
        tbl_pr.append(tbl_ind)
    tbl_ind.set(qn("w:w"), str(TABLE_INDENT_DXA))
    tbl_ind.set(qn("w:type"), "dxa")

    grid = table._tbl.tblGrid
    for child in list(grid):
        grid.remove(child)
    for width in widths:
        col = OxmlElement("w:gridCol")
        col.set(qn("w:w"), str(width))
        grid.append(col)

    for row in table.rows:
        prevent_row_split(row)
        for index, cell in enumerate(row.cells):
            set_cell_width(cell, widths[index])
            set_cell_margins(cell)
            cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER


def set_table_borders(table, color=GRID, size=6) -> None:
    tbl_pr = table._tbl.tblPr
    borders = tbl_pr.find(qn("w:tblBorders"))
    if borders is None:
        borders = OxmlElement("w:tblBorders")
        tbl_pr.append(borders)
    for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
        node = borders.find(qn(f"w:{edge}"))
        if node is None:
            node = OxmlElement(f"w:{edge}")
            borders.append(node)
        node.set(qn("w:val"), "single")
        node.set(qn("w:sz"), str(size))
        node.set(qn("w:space"), "0")
        node.set(qn("w:color"), color)


def set_run_font(run, size=11, color=INK, bold=None, italic=None, name="Calibri") -> None:
    run.font.name = name
    run._element.get_or_add_rPr().rFonts.set(qn("w:ascii"), name)
    run._element.get_or_add_rPr().rFonts.set(qn("w:hAnsi"), name)
    run.font.size = Pt(size)
    run.font.color.rgb = rgb(color)
    if bold is not None:
        run.bold = bold
    if italic is not None:
        run.italic = italic


def configure_styles(doc: Document) -> None:
    styles = doc.styles

    normal = styles["Normal"]
    normal.font.name = "Calibri"
    normal._element.rPr.rFonts.set(qn("w:ascii"), "Calibri")
    normal._element.rPr.rFonts.set(qn("w:hAnsi"), "Calibri")
    normal.font.size = Pt(11)
    normal.font.color.rgb = rgb(INK)
    normal.paragraph_format.space_before = Pt(0)
    normal.paragraph_format.space_after = Pt(6)
    normal.paragraph_format.line_spacing = 1.1

    heading_tokens = {
        "Heading 1": (16, BLUE, 16, 8),
        "Heading 2": (13, BLUE, 12, 6),
        "Heading 3": (12, DARK_BLUE, 8, 4),
    }
    for style_name, (size, color, before, after) in heading_tokens.items():
        style = styles[style_name]
        style.font.name = "Calibri"
        style._element.rPr.rFonts.set(qn("w:ascii"), "Calibri")
        style._element.rPr.rFonts.set(qn("w:hAnsi"), "Calibri")
        style.font.size = Pt(size)
        style.font.bold = True
        style.font.color.rgb = rgb(color)
        style.paragraph_format.space_before = Pt(before)
        style.paragraph_format.space_after = Pt(after)
        style.paragraph_format.keep_with_next = True

    for style_name in ("List Bullet", "List Number"):
        style = styles[style_name]
        style.font.name = "Calibri"
        style.font.size = Pt(11)
        style.paragraph_format.left_indent = Inches(0.5)
        style.paragraph_format.first_line_indent = Inches(-0.25)
        style.paragraph_format.space_after = Pt(8)
        style.paragraph_format.line_spacing = 1.167

    caption = styles["Caption"]
    caption.font.name = "Calibri"
    caption.font.size = Pt(9)
    caption.font.italic = True
    caption.font.color.rgb = rgb(MUTED)
    caption.paragraph_format.space_before = Pt(4)
    caption.paragraph_format.space_after = Pt(4)


def add_page_number(paragraph) -> None:
    paragraph.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    run = paragraph.add_run("Page ")
    set_run_font(run, size=9, color=MUTED)
    fld = OxmlElement("w:fldSimple")
    fld.set(qn("w:instr"), "PAGE")
    paragraph._p.append(fld)


def configure_section(section) -> None:
    section.page_width = Inches(8.5)
    section.page_height = Inches(11)
    section.top_margin = Inches(1)
    section.bottom_margin = Inches(1)
    section.left_margin = Inches(1)
    section.right_margin = Inches(1)
    section.header_distance = Inches(0.492)
    section.footer_distance = Inches(0.492)

    header = section.header
    hp = header.paragraphs[0]
    hp.alignment = WD_ALIGN_PARAGRAPH.LEFT
    hp.paragraph_format.space_after = Pt(0)
    hr = hp.add_run("ARTÉA Phase 3  |  Solution & Cost–Benefit Brief")
    set_run_font(hr, size=9, color=MUTED, bold=True)

    footer = section.footer
    fp = footer.paragraphs[0]
    fp.paragraph_format.space_before = Pt(0)
    add_page_number(fp)


def add_paragraph(doc, text="", bold_lead=None, italic=False, after=6, keep=False):
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(after)
    p.paragraph_format.keep_together = keep
    if bold_lead and text.startswith(bold_lead):
        lead = p.add_run(bold_lead)
        set_run_font(lead, bold=True)
        rest = p.add_run(text[len(bold_lead):])
        set_run_font(rest, italic=italic)
    else:
        run = p.add_run(text)
        set_run_font(run, italic=italic)
    return p


def add_bullet(doc, text, level=0):
    p = doc.add_paragraph(style="List Bullet")
    p.paragraph_format.left_indent = Inches(0.5 + 0.25 * level)
    p.paragraph_format.first_line_indent = Inches(-0.25)
    p.paragraph_format.space_after = Pt(8)
    run = p.add_run(text)
    set_run_font(run)
    return p


def add_number(doc, text):
    p = doc.add_paragraph(style="List Number")
    p.paragraph_format.left_indent = Inches(0.5)
    p.paragraph_format.first_line_indent = Inches(-0.25)
    p.paragraph_format.space_after = Pt(8)
    run = p.add_run(text)
    set_run_font(run)
    return p


def add_callout(doc, label, text, fill=LIGHT_BLUE, accent=BLUE):
    table = doc.add_table(rows=1, cols=1)
    set_table_geometry(table, [CONTENT_DXA])
    set_table_borders(table, color=accent, size=8)
    cell = table.cell(0, 0)
    set_cell_shading(cell, fill)
    p = cell.paragraphs[0]
    p.paragraph_format.space_before = Pt(2)
    p.paragraph_format.space_after = Pt(2)
    r1 = p.add_run(f"{label}  ")
    set_run_font(r1, size=10.5, color=accent, bold=True)
    r2 = p.add_run(text)
    set_run_font(r2, size=10.5, color=INK)
    spacer = doc.add_paragraph()
    spacer.paragraph_format.space_after = Pt(2)


def add_table(doc, headers, rows, widths, alignments=None, header_fill=LIGHT_GRAY, font_size=9.2):
    table = doc.add_table(rows=1, cols=len(headers))
    set_table_geometry(table, widths)
    set_table_borders(table)
    hdr = table.rows[0]
    hdr._tr.get_or_add_trPr().append(OxmlElement("w:tblHeader"))
    for index, value in enumerate(headers):
        cell = hdr.cells[index]
        set_cell_shading(cell, header_fill)
        p = cell.paragraphs[0]
        p.paragraph_format.space_after = Pt(0)
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER if alignments and alignments[index] == "center" else WD_ALIGN_PARAGRAPH.LEFT
        run = p.add_run(str(value))
        set_run_font(run, size=font_size, color=NAVY, bold=True)

    for row_index, values in enumerate(rows):
        cells = table.add_row().cells
        for index, value in enumerate(values):
            cell = cells[index]
            if row_index % 2 == 1:
                set_cell_shading(cell, "FAFBFC")
            p = cell.paragraphs[0]
            p.paragraph_format.space_after = Pt(0)
            if alignments and alignments[index] == "center":
                p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            elif alignments and alignments[index] == "right":
                p.alignment = WD_ALIGN_PARAGRAPH.RIGHT
            else:
                p.alignment = WD_ALIGN_PARAGRAPH.LEFT
            run = p.add_run(str(value))
            set_run_font(run, size=font_size)
        prevent_row_split(table.rows[-1])
    set_table_geometry(table, widths)
    doc.add_paragraph().paragraph_format.space_after = Pt(2)
    return table


def add_hyperlink(paragraph, text, url):
    part = paragraph.part
    rel_id = part.relate_to(url, "http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink", is_external=True)
    hyperlink = OxmlElement("w:hyperlink")
    hyperlink.set(qn("r:id"), rel_id)
    run = OxmlElement("w:r")
    r_pr = OxmlElement("w:rPr")
    color = OxmlElement("w:color")
    color.set(qn("w:val"), BLUE)
    underline = OxmlElement("w:u")
    underline.set(qn("w:val"), "single")
    r_pr.append(color)
    r_pr.append(underline)
    run.append(r_pr)
    text_node = OxmlElement("w:t")
    text_node.text = text
    run.append(text_node)
    hyperlink.append(run)
    paragraph._p.append(hyperlink)


def add_page_break(doc):
    doc.add_paragraph().add_run().add_break(WD_BREAK.PAGE)


def build() -> None:
    doc = Document()
    configure_styles(doc)
    configure_section(doc.sections[0])

    # memo_masthead opening
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(14)
    p.paragraph_format.space_after = Pt(4)
    r = p.add_run("DECISION BRIEF")
    set_run_font(r, size=10, color=BLUE, bold=True)

    title = doc.add_paragraph()
    title.paragraph_format.space_after = Pt(5)
    tr = title.add_run("ARTÉA Phase 3")
    set_run_font(tr, size=25, color=NAVY, bold=True)

    subtitle = doc.add_paragraph()
    subtitle.paragraph_format.space_after = Pt(14)
    sr = subtitle.add_run("Solution Overview, Cost–Benefit Analysis, Rationale, Workflow, and Delivery Timeline")
    set_run_font(sr, size=14, color=MUTED)

    metadata = [
        ("Prepared for", "Louisa Chan Creative / COMP 3018 Project Charter"),
        ("Prepared by", "S2603 — ARTÉA Phase 3 team"),
        ("Date", "14 August 2026"),
        ("Decision", "Approve a web-first, reusable-system implementation; keep native iPad/mobile release as a stretch goal"),
    ]
    for label, value in metadata:
        p = doc.add_paragraph()
        p.paragraph_format.space_after = Pt(3)
        lr = p.add_run(f"{label}: ")
        set_run_font(lr, size=10.5, bold=True)
        vr = p.add_run(value)
        set_run_font(vr, size=10.5)

    add_callout(
        doc,
        "RECOMMENDATION",
        "Enhance the existing Godot project rather than rebuild it. Deliver a browser-based minimum viable release first, using shared systems across all three worlds. Defer App Store packaging and multiplayer unless the essential web release is stable by the end of Iteration Two.",
        fill=PALE_GOLD,
        accent="A06B00",
    )

    doc.add_heading("Solution Overview", level=1)
    add_paragraph(
        doc,
        "ARTÉA Phase 3 will transform the existing town, Art Castle, Milo companion and three minigames into one guided creative-wellbeing journey. Players enter through a simple web experience, move through Mind Spark, Heart Melody and Creator’s Light, collect one treasure from each world, and return to the Castle for the Crown of Life finale. The solution retains the project’s established Godot foundation and adds the minimum shared systems needed for progression, reflective guidance, accessibility, reliable saving and browser deployment.",
    )

    doc.add_heading("Solution Outline", level=2)
    add_bullet(doc, "Connected journey: the Castle and World Gates provide the main story path; the Crown Train is optional travel to completed worlds only.")
    add_bullet(doc, "Wonderful Counsellor Milo: a structured, strengths-based response flow—Validate, Reflect, Encourage, Guide and Connect—with bounded prompts and child-safety safeguards.")
    add_bullet(doc, "Three focused worlds: Mind Spark develops thought awareness; Heart Melody supports emotional expression through music; Creator’s Light supports creative expression and reflection.")
    add_bullet(doc, "Shared technical foundation: one save/progression model, identity-evidence tracker, quest interface, player equipment system, Milo and Guardian scenes, accessibility settings, enemy base and boss-state framework.")
    add_bullet(doc, "Web-first access: optimise for supported desktop and tablet browsers; treat native iPad/mobile packaging as conditional stretch scope.")
    add_bullet(doc, "Quality and handover: functional, usability, accessibility and performance testing, followed by source code, setup, deployment and known-issues documentation.")

    doc.add_heading("Scope Boundary", level=2)
    add_table(
        doc,
        ["Committed Phase 3 scope", "Conditional / future scope"],
        [
            ("Connected three-world journey and Castle finale", "Native App Store release after web acceptance"),
            ("Milo guidance with a remote API and safe fallback responses", "Open-ended therapeutic or diagnostic AI behaviour"),
            ("Shared save, progression, rewards and identity evidence", "Multiplayer/community systems"),
            ("Web deployment, accessibility and performance baseline", "Large-scale content expansion or additional worlds"),
            ("Reuse/modification of existing assets and procedural kits", "High-cost bespoke models for every landmark or enemy"),
        ],
        [4680, 4680],
        font_size=9.4,
    )

    doc.add_heading("Cost Benefit Analysis", level=1)
    add_callout(
        doc,
        "FINANCIAL LENS",
        "Use the sponsor-cash view for the charter: student labour is an in-kind contribution and therefore a benefit/avoided commercial cost, not a cash expense to the client. A separate full-resource view is shown to avoid implying that labour has no economic value.",
        fill=LIGHT_BLUE,
        accent=BLUE,
    )

    doc.add_heading("Assumptions", level=2)
    add_bullet(doc, "Five team members × 15 hours per week × 14 weeks = 1,050 hours of total student effort.")
    add_bullet(doc, "Indicative labour value uses the charter’s supervisor-approved range of AUD $33–$47 per hour.")
    add_bullet(doc, "The baseline release is web-first. Native iPad/App Store distribution is excluded from the baseline and requires separate sponsor approval.")
    add_bullet(doc, "Existing ARTÉA code, world foundations and assets are reused; benefits from reuse are not monetised separately because doing so would double-count the replacement-cost benefit.")
    add_bullet(doc, "AI estimates assume short, bounded Milo interactions and usage controls. Actual cost depends on model, input/output mix, session length, exchange rate and tax.")

    add_page_break(doc)
    doc.add_heading("Estimated Sponsor Cash Costs (AUD)", level=2)
    add_table(
        doc,
        ["Cost category", "Basis", "Low", "High"],
        [
            ("Godot licence", "MIT-licensed engine; no engine licence fee", "$0", "$0"),
            ("Milo AI pilot allowance", "Bounded text interactions, monitoring and usage cap", "$20", "$100"),
            ("Web hosting/backend", "Student/free tier where suitable; allowance for paid hosting/storage", "$0", "$360"),
            ("Domain / deployment incidentals", "Only if a new domain or paid deployment service is required", "$20", "$40"),
            ("Testing incidentals", "Browser/device access not available through university/team resources", "$0", "$200"),
            ("Cash contingency", "Reserve for usage variance and deployment issues", "$60", "$100"),
            ("Total sponsor cash outlay", "Baseline web release", "$100", "$800"),
        ],
        [2300, 4300, 1380, 1380],
        alignments=["left", "left", "right", "right"],
        font_size=8.9,
    )

    doc.add_heading("In-Kind Effort and Commercial Replacement Value", level=2)
    add_table(
        doc,
        ["Measure", "Calculation", "Indicative value"],
        [
            ("Total team effort", "5 × 15 hours × 14 weeks", "1,050 hours"),
            ("Low replacement value", "1,050 × $33/hour", "$34,650"),
            ("High replacement value", "1,050 × $47/hour", "$49,350"),
            ("Client payment for student labour", "In-kind academic project contribution", "$0 cash"),
        ],
        [2600, 3900, 2860],
        alignments=["left", "left", "right"],
        font_size=9.2,
    )

    add_page_break(doc)
    doc.add_heading("Benefits", level=2)
    add_table(
        doc,
        ["Benefit", "Value to the sponsor", "Treatment in analysis"],
        [
            ("Commercial development value", "Equivalent development, integration, testing, documentation and project-management effort", "$34,650–$49,350; monetised"),
            ("Reuse of existing ARTÉA", "Avoids rebuilding the town, Castle, three worlds, player, Milo, art tool and established gameplay foundations", "Enables the estimate; not separately monetised"),
            ("Lower future maintenance", "Shared systems reduce duplicated code, asset variants and inconsistent behaviour", "Qualitative"),
            ("Wider access", "A browser release can support schools, wellbeing programs and individual sessions without a local installation", "Qualitative until usage data exists"),
            ("Improved engagement", "A connected story, visible rewards, Milo guidance and a finale make the experience easier to understand and complete", "Qualitative until user testing exists"),
            ("Service opportunities", "Appropriate links to existing courses, workshops and services may generate future engagement", "Excluded until conversion data exists"),
        ],
        [2150, 4500, 2710],
        font_size=8.7,
    )

    doc.add_heading("Indicative Net Benefit", level=2)
    add_table(
        doc,
        ["Scenario", "Benefits", "Cash costs", "Net benefit", "Benefit–cost ratio"],
        [
            ("Conservative", "$34,650", "$800", "$33,850", "43.3 : 1"),
            ("Midpoint", "$42,000", "$450", "$41,550", "93.3 : 1"),
            ("Upper", "$49,350", "$100", "$49,250", "493.5 : 1"),
        ],
        [1800, 1740, 1740, 1980, 2100],
        alignments=["left", "right", "right", "right", "right"],
        header_fill=PALE_GREEN,
        font_size=9.1,
    )
    add_paragraph(
        doc,
        "Interpretation: the ratio is high because it compares donated/in-kind student development value with the sponsor’s incremental cash outlay. It is not a forecast of revenue or social return. In a full economic-resource view, the 1,050 hours are a real resource cost and should not also be counted as a benefit; because wellbeing and service-engagement outcomes are not yet monetised, a full economic benefit–cost ratio should remain TBC until pilot evidence is collected.",
        italic=True,
        after=8,
    )

    add_page_break(doc)
    doc.add_heading("Rationale for Chosen Solution", level=1)
    add_paragraph(
        doc,
        "The chosen solution is an incremental, reusable-system enhancement of the existing Godot project with a web-first release. It provides the best balance of client value, delivery certainty and technical sustainability within the 14-week semester. It also preserves the project’s therapeutic and faith-informed intent: identity before achievement, discovery before fixing, and celebration before correction.",
    )

    add_table(
        doc,
        ["Option", "Cost / schedule", "Benefits", "Assessment"],
        [
            ("A. Maintain current version", "Lowest immediate cost", "No delivery disruption", "Rejected: navigation, performance, disconnected activities and limited access remain unresolved."),
            ("B. Rebuild as a new platform", "Highest cost and schedule risk", "Maximum design freedom", "Rejected: discards valuable assets/code and is not credible within 14 weeks."),
            ("C. Incremental web-first enhancement", "Low sponsor cash; manageable technical risk", "Reuses current work, connects all worlds, supports testing and enables browser access", "Chosen: strongest cost–benefit fit and best chance of an accepted, maintainable release."),
            ("D. Native iPad/mobile first", "Additional packaging, device and store work", "Strong tablet distribution", "Stretch only: pursue after web acceptance; Apple distribution adds an annual developer membership and review overhead."),
        ],
        [1700, 2300, 2700, 2660],
        font_size=8.6,
    )

    doc.add_heading("Why the Chosen Solution Is Feasible", level=2)
    add_number(doc, "It reuses the current Godot player, sword hitbox, Milo scene, world foundations, art tool and Crown Line logic instead of replacing them.")
    add_number(doc, "It builds shared foundations once—save/progression, identity evidence, quest interaction, accessibility, enemy behaviour and boss states—then applies world-specific visuals and puzzle verbs.")
    add_number(doc, "It narrows the campaign to a guided critical path: Mind Spark provides the largest foundation; Heart Melody and Creator’s Light each target 14–16 minutes with two quests and one boss encounter.")
    add_number(doc, "It protects the essential release by deferring native store packaging, multiplayer, new worlds and open-ended AI behaviour.")
    add_number(doc, "It makes performance, accessibility and child-safety acceptance criteria part of every iteration rather than end-stage extras.")

    doc.add_heading("Design and Safety Rationale", level=2)
    add_bullet(doc, "Thoughts, emotions and creativity are never treated as enemies; combat targets only the fictional blight shell.")
    add_bullet(doc, "Identity evidence is optional, non-diagnostic and unaffected by combat skill, speed, puzzle accuracy or accessibility settings.")
    add_bullet(doc, "Milo provides structured reflection and navigation, not diagnosis, crisis counselling or unrestricted therapeutic advice.")
    add_bullet(doc, "Important cues use text, symbols, shape and sound—not colour alone—and reduced-motion, larger-text, subtitle and help options are included in acceptance testing.")

    doc.add_heading("Workflow Diagram", level=1)
    picture = doc.add_picture(str(WORKFLOW), width=Inches(6.35))
    picture.alignment = WD_ALIGN_PARAGRAPH.CENTER
    cap = doc.add_paragraph(style="Caption")
    cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
    cap.add_run("Figure 1. Player and system workflow for the web-first ARTÉA Phase 3 journey.")

    add_page_break(doc)
    doc.add_heading("Milestones and Timelines", level=1)
    add_paragraph(
        doc,
        "The schedule uses five delivery gates. Each gate produces a testable build or approved document, and scope is reduced before quality is reduced. The final acceptance target is 19 October 2026; the charter’s earlier 23 October handover date should be corrected because it falls after the stated Week 14 completion date.",
    )

    add_table(
        doc,
        ["Phase / milestone", "Dates", "Primary output", "Exit criteria"],
        [
            ("1. Charter and technical baseline", "3–14 Aug", "Approved charter, scoped backlog, repository/build audit", "Essential scope, owners, supported browsers and cost assumptions approved"),
            ("2. Prototype and shared foundations", "17–28 Aug", "One-hour prototype workshop; web export baseline; save/progression and Milo API spike", "Prototype accepted; major technical risks recorded; fallback responses work"),
            ("3. Iteration One", "31 Aug–18 Sep", "Shared systems plus playable Mind Spark and Heart Melody critical paths", "Iteration One demo accepted; rewards persist; no progression-blocking defects"),
            ("4. Iteration Two", "21 Sep–2 Oct", "Creator’s Light, Castle finale and integrated three-world journey", "End-to-end journey complete in a test build; stretch scope frozen"),
            ("5. Stabilisation, acceptance and handover", "5–19 Oct", "Accessibility/performance testing, bug fixes, deployment, video, presentation and handover pack", "Supported-browser acceptance passed; source, setup, deployment and known-issues documents delivered"),
        ],
        [2150, 1450, 3180, 2580],
        font_size=8.4,
    )

    doc.add_heading("Release Schedule", level=2)
    add_table(
        doc,
        ["Release", "Target date", "Included scope", "Decision rule"],
        [
            ("R0 — Baseline", "28 Aug", "Current build audit, browser export, Milo/API and performance spikes", "If web feasibility is poor, reduce visual/effect load before adding features"),
            ("R1 — Iteration One", "18 Sep", "Shared foundations, Milo guidance, Mind Spark and Heart Melody vertical slices", "Only defects and essential integration enter the next iteration automatically"),
            ("R2 — Feature Complete", "2 Oct", "Creator’s Light, rewards, Castle finale and end-to-end save/progression", "Freeze multiplayer, App Store and new-content requests unless all essential criteria pass"),
            ("RC — Release Candidate", "16 Oct", "Optimised web build, accessibility fixes, test evidence and draft handover", "No critical or high-severity defects; sponsor acceptance session completed"),
            ("Final — Handover", "19 Oct", "Deployed web build, source, documentation, presentation, abstract/video and known issues", "Client/supervisor sign-off or documented residual limitations"),
        ],
        [1900, 1250, 3470, 2740],
        font_size=8.5,
    )

    doc.add_heading("Delivery Priorities", level=2)
    add_table(
        doc,
        ["Priority", "Scope"],
        [
            ("Must", "Connected three-world critical path; Milo guidance and safe fallback; rewards/finale; save/progression; web deployment; accessibility/performance baseline; testing and handover"),
            ("Should", "Optional Crown Train revisits; richer NPC guidance; personal Gallery refinements; service recommendations with sponsor-approved wording"),
            ("Could", "Native iPad packaging if the web release is accepted early and required devices/accounts are available"),
            ("Won’t in Phase 3", "Multiplayer/community features, additional worlds, unrestricted generative art recognition, diagnostic AI and large bespoke asset expansion"),
        ],
        [1800, 7560],
        font_size=9.0,
    )

    doc.add_heading("Measurement at Handover", level=2)
    add_bullet(doc, "Completion: percentage of test users able to finish the three-world critical path without facilitator intervention.")
    add_bullet(doc, "Reliability: critical/high defects open, crash rate during tests and successful save/resume rate.")
    add_bullet(doc, "Performance: load time and frame-rate observations on the agreed browser/device matrix.")
    add_bullet(doc, "Accessibility/usability: navigation errors, help requests and issues found against the agreed accessibility checklist.")
    add_bullet(doc, "AI cost and quality: average tokens/cost per Milo session, fallback rate and sponsor-reviewed response quality.")
    add_bullet(doc, "Benefit validation: unique users, repeat sessions, world/finale completion and service referral clicks after pilot launch.")

    doc.add_heading("Sources and Calculation Notes", level=1)
    sources = [
        ("ARTÉA World One: Mind Spark — Concise Developer Guide and Implementation Blueprints", "Provided project document, 14 Aug 2026"),
        ("ARTÉA World Two: Heart Melody — Concise Developer Guide and Implementation Blueprints", "Provided project document, 14 Aug 2026"),
        ("ARTÉA World Three: Creator’s Light — Concise Developer Guide and Implementation Blueprints", "Provided project document, 14 Aug 2026"),
        ("ARTÉA Phase 3 Project Charter draft", "Provided project text, 14 Aug 2026"),
    ]
    for title_text, note in sources:
        p = doc.add_paragraph(style="List Bullet")
        p.paragraph_format.space_after = Pt(4)
        r1 = p.add_run(title_text + ". ")
        set_run_font(r1, size=9.2, bold=True)
        r2 = p.add_run(note)
        set_run_font(r2, size=9.2, color=MUTED)

    p = doc.add_paragraph(style="List Bullet")
    p.paragraph_format.space_after = Pt(4)
    add_hyperlink(p, "Godot Engine licence", "https://godotengine.org/license/")
    rr = p.add_run(" — Godot is free and open source under the MIT licence.")
    set_run_font(rr, size=9.2, color=MUTED)

    p = doc.add_paragraph(style="List Bullet")
    p.paragraph_format.space_after = Pt(4)
    add_hyperlink(p, "OpenAI GPT-5 mini model pricing", "https://developers.openai.com/api/docs/models/gpt-5-mini")
    rr = p.add_run(" — current official token pricing used only to validate that bounded pilot interactions are low-cost; the charter retains a conservative AUD allowance.")
    set_run_font(rr, size=9.2, color=MUTED)

    p = doc.add_paragraph(style="List Bullet")
    p.paragraph_format.space_after = Pt(4)
    add_hyperlink(p, "Apple Developer Program", "https://developer.apple.com/programs/whats-included/")
    rr = p.add_run(" — native App Store distribution requires a USD $99 annual membership; excluded from the baseline web budget.")
    set_run_font(rr, size=9.2, color=MUTED)

    add_paragraph(
        doc,
        "Calculation note: Net Benefit = Monetised Benefits − Sponsor Cash Costs. Benefit–Cost Ratio = Monetised Benefits ÷ Sponsor Cash Costs. All dollar figures are indicative and must be confirmed with the sponsor and academic supervisor before charter approval.",
        italic=True,
        after=4,
    )

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    doc.save(OUTPUT)
    print(OUTPUT)


if __name__ == "__main__":
    build()
