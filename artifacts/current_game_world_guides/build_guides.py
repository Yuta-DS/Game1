from pathlib import Path
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.enum.style import WD_STYLE_TYPE
from docx.oxml.ns import qn

ROOT = Path('/Users/davidsovann/S2603')
OUT = ROOT / 'artifacts/current_game_world_guides'
SHOT = OUT / 'screenshots'
MIND = ROOT / 'artea/artifacts/mind_spark_three_island_world/01_three_fused_islands_hero.png'
HEART = ROOT / 'artea/artifacts/heart_garden/planter_court.png'
CREATOR = ROOT / 'artea/artifacts/current_game_world_guides/creator_studio.png'
CASTLE = SHOT / 'castle_arrival.jpg'

NAVY = RGBColor(24, 38, 58)
TEAL = RGBColor(0, 113, 134)
GREY = RGBColor(86, 99, 110)

def setup(doc, title, subtitle):
    sec = doc.sections[0]
    sec.top_margin = Inches(.72); sec.bottom_margin = Inches(.7)
    sec.left_margin = Inches(.78); sec.right_margin = Inches(.78)
    styles = doc.styles
    normal = styles['Normal']; normal.font.name = 'Aptos'; normal.font.size = Pt(9.5); normal.font.color.rgb = NAVY
    normal.paragraph_format.space_after = Pt(5)
    normal.paragraph_format.line_spacing = 1.13
    for name,size,before,after in [('Title',23,0,12),('Heading 1',13,13,6),('Heading 2',10.5,9,3)]:
        s=styles[name]; s.font.name='Aptos Display' if name=='Title' else 'Aptos'; s.font.size=Pt(size); s.font.bold=True; s.font.color.rgb=NAVY if name=='Title' else TEAL
        s.paragraph_format.space_before=Pt(before); s.paragraph_format.space_after=Pt(after)
    title_border = styles['Title'].element.get_or_add_pPr().find(qn('w:pBdr'))
    if title_border is not None: styles['Title'].element.get_or_add_pPr().remove(title_border)
    if 'Caption' not in styles: styles.add_style('Caption', WD_STYLE_TYPE.PARAGRAPH)
    styles['Caption'].font.name='Aptos'; styles['Caption'].font.size=Pt(8); styles['Caption'].font.color.rgb=GREY
    styles['Caption'].paragraph_format.space_after=Pt(9)
    doc.add_paragraph(title,'Title')
    p=doc.add_paragraph(); r=p.add_run(subtitle); r.bold=True; r.font.color.rgb=TEAL; r.font.size=Pt(10)
    p=doc.add_paragraph('Current-game edition  •  18 October 2026'); p.style='Caption'
    foot=sec.footer.paragraphs[0]; foot.alignment=WD_ALIGN_PARAGRAPH.RIGHT
    foot.add_run('ARTÉA  •  Current game guide').font.size=Pt(8)

def para(doc, text): doc.add_paragraph(text)
def heading(doc, text, level=1): doc.add_paragraph(text, f'Heading {level}')
def pic(doc, path, caption, width=6.85):
    if not path.exists(): return
    p=doc.add_paragraph(); p.alignment=WD_ALIGN_PARAGRAPH.CENTER
    p.add_run().add_picture(str(path),width=Inches(width))
    c=doc.add_paragraph(caption,'Caption'); c.alignment=WD_ALIGN_PARAGRAPH.CENTER
def table(doc, heads, rows, widths=None):
    t=doc.add_table(rows=1, cols=len(heads)); t.alignment=WD_TABLE_ALIGNMENT.CENTER; t.style='Light Shading Accent 1'
    for i,h in enumerate(heads):
        t.rows[0].cells[i].text=h
    for row in rows:
        c=t.add_row().cells
        for i,v in enumerate(row): c[i].text=str(v)
    for row in t.rows:
        for i,c in enumerate(row.cells):
            c.vertical_alignment=WD_CELL_VERTICAL_ALIGNMENT.CENTER
            if widths: c.width=Inches(widths[i])
            for p in c.paragraphs:
                p.paragraph_format.space_after=Pt(2)
                for r in p.runs: r.font.size=Pt(8.5)
    doc.add_paragraph()

def bullet(doc,text): doc.add_paragraph(text,style='List Bullet')
def source(doc,text):
    p=doc.add_paragraph(text); p.style='Caption'

def mind():
    d=Document(); setup(d,'World One — Mind Spark','The Two Lenses of Wisdom · three connected islands')
    para(d,'Mind Spark is the first Crown of Life journey. Players notice a difficult thought, test its signal with evidence and hope, and help the Warden without treating fear as an enemy. The current chapter has five canonical quests, twenty narrative tasks and ten saved walkable milestones. Its reward is the Star of Wisdom.')
    pic(d,MIND,'Project runtime capture of the three connected Mind Spark islands (archived 2026). This is rendered game geometry.',6.8)
    heading(d,'What the player sees')
    para(d,'The route begins at the Signal Observatory, crosses an echo garden and the evidence and hope districts, then reaches the Thought Storm and the Oldest Tree Sanctuary. Six internal district identifiers support the route, but the player travels through three physical islands. Interaction stations, bridges, gates, changing weather and the final sanctuary make progress visible in the world.')
    d.add_page_break()
    heading(d,'Playable journey')
    table(d,['Step','Place and action','Visible result'],[
        ('1 · Notice the Signal','Signal Observatory: route Thought, Feeling and Choice through separate instruments; synchronize the first gate.','The observatory lights and the way to the echo area opens.'),
        ('2 · Listen to the Echo','Echo Forest/Garden: gather signals, sort fact from possibility, and turn a warning into a useful question.','The echo route stabilizes and the second island becomes reachable.'),
        ('3 · Understand the Moment','Evidence Constellation Court: inspect evidence and memories, revise a pattern and restore a crossing.','The broken pattern becomes a traversable path.'),
        ('4 · Build a Possible Tomorrow','Hope Path Ridge: change perspective, work with the lenses and choose a grounded next step.','The route through the storm opens.'),
        ('5 · Calm the Thought Storm','Thought Storm Arena to Oldest Tree Sanctuary: combine the chapter’s tools and free the Warden.','Gentle rain, a restored sanctuary and the Star of Wisdom.')],[1.15,3.0,2.2])
    heading(d,'Player experience')
    bullet(d,'Mistakes invite revision. The story does not score a player’s inner state or require personal disclosure.')
    bullet(d,'Optional reflection choices can be skipped and do not change XP, gates or the Star reward.')
    bullet(d,'The same five quest IDs drive the narrative data and the physical-world presentation; legacy save aliases preserve older progress.')
    heading(d,'Entry and completion')
    para(d,'The campaign’s Mind entry is the Thought menu scene. The castle gallery also presents the walkable three-island chapter. The Star of Wisdom is the first required treasure for the later Heart Melody and Creator’s Light routes.')
    heading(d,'Current implementation reference')
    para(d,'The chapter structure is in artea/data/mind_spark_chapter.json. The walkable route and milestones are in artea/scripts/mind_spark/mind_spark_world_one.gd and mind_spark_world_one_quest.gd. For the full object system and production audit, see world_one_object_minigame_catalog.gd and artea/docs/MIND_SPARK_WORLD_ONE_IMPLEMENTATION_HANDBOOK.md.')
    heading(d,'What this edition corrects')
    para(d,'The earlier guide described a generic four-quest, three-stage-boss, level-banded prototype. Those counts and a fixed playtime are not supported by the current chapter. This edition uses the five named quests, three-island route and actual Star completion path in the project.')
    heading(d,'Verification scope')
    para(d,'The refreshed web export loaded the Artéa start screen and playable castle arrival on 18 October 2026. The island image above is an earlier project runtime capture. A complete browser playthrough of all five quests and a native/Web parity check remain to be performed.')
    out=OUT/'World_One_Mind_Spark_Current_Game_Guide.docx'; d.save(out); return out

def heart():
    d=Document(); setup(d,'World Two — Heart Melody','A playable music and feeling journey')
    para(d,'Heart Melody follows the Star of Wisdom. Its current chapter data defines three regions, six zones, four ordered quests and ten tasks. The player restores a silent garden and river through instruments, fruit and collaborative musical actions, then frees the Silent Conductor. The reward is the Harmony Jewel.')
    pic(d,HEART,'Project runtime capture (archived 2026): Heart Melody’s planter court on the Quiet Meadow and Feeling Garden route.',6.8)
    heading(d,'World layout')
    table(d,['Region','Zones','Player focus'],[
        ('First Breath','Quiet Meadow · Feeling Garden','Plant feeling seeds, rebuild a rhythm, clear two Blight waves.'),
        ('River Voice','Waterfall Organ River · Bell Grove Peace Garden','Tune the organ, release the Hush Vine Harp, call the Rain Boat, cross chimes and warning bells.'),
        ('Shared Song','Harmony Stage · Harmony Jewel Sanctuary','Assemble the Heart Song and conduct the final orchestra.')],[1.25,2.2,2.9])
    d.add_page_break()
    heading(d,'Quest route in the game')
    table(d,['Quest','Playable work','Completion'],[
        ('Wake the Feeling Garden','Plant three feeling seeds. Play the Leaf → Sun → Droplet phrase. Clear two Blight waves.','Garden restored.'),
        ('Restore the River Song','Use three Dew Pears at the Waterfall Organ, five Sun Plums at the Hush Vine Harp and four Bell Apples for the Rain Boat.','River route restored.'),
        ('Build the Heart Song','Restore three bridge chimes, cross the warning path with Moon Melons, then arrange the motif at the Heart Song Loom.','Song assembled.'),
        ('Free the Silent Conductor','Join the beat anchors, place six fruits in the orchestra and conduct the final phrase.','Conductor freed; Harmony Jewel and Harmony Shield awarded.')],[1.25,3.65,1.45])
    heading(d,'Fruit and assistance')
    para(d,'Six fruit types have musical roles: Echo Berry repeats, Sun Plum supports tempo, Dew Pear pitch, Bell Apple resonance, Moon Melon sustain and Harmony Fig harmony. Recipes provide replay, focus, healing, timing help, challenge assistance and a final cosmetic upgrade. Assistance and optional identity choices do not reduce rewards.')
    heading(d,'Progression')
    para(d,'The campaign requires the Star of Wisdom before Heart Melody opens. Garden, river, song and harmony completion are separate saved states. The Harmony Jewel unlocks the Creator’s Light route together with the Star.')
    heading(d,'Current implementation reference')
    table(d,['Area','Source in the game'],[
        ('Quest and item data','artea/data/heart_melody_chapter.json — regions, four quests, ten tasks, fruit and recipes.'),
        ('Progression rules','artea/scripts/heart_melody/heart_garden_state.gd — current objective text and completion flags.'),
        ('Playable world','artea/scripts/heart_melody/heart_garden_world.gd and heart_world.gd.'),
        ('Campaign connection','artea/scripts/journey_campaign.gd and JourneyState.gd.')],[1.55,4.8])
    heading(d,'What this edition corrects')
    para(d,'The old guide’s fixed level range, three-stage boss and estimated duration were concept targets. The checked-in chapter has four specific quests and a Silent Conductor finale. The early implementation plan described only the first garden; current state and chapter files include the river, song and harmony sequences.')
    heading(d,'Verification scope')
    para(d,'The refreshed Web build loaded the shared Artéa hub. The garden image is an earlier project runtime capture. This update checks the quest data and state code, but does not claim an end-to-end browser completion of Heart Melody.')
    out=OUT/'World_Two_Heart_Melody_Current_Game_Guide.docx'; d.save(out); return out

def creator():
    d=Document(); setup(d,'World Three — Creator’s Light','The artwork and gallery journey in the current game')
    para(d,'Creator’s Light opens after the Star of Wisdom and Harmony Jewel. The current reward route begins in the drawing studio and ends with a deliberate Gallery Frame Ritual. The player creates and saves artwork, chooses a motif, places it in a frame and confirms it. This act grants Creator’s Light; exporting or saving an image alone does not.')
    pic(d,CREATOR if CREATOR.exists() else CASTLE,'Current Godot scene capture: the drawing studio.' if CREATOR.exists() else 'Fresh Web build screenshot: Artéa Castle, the shared journey hub.',6.8)
    heading(d,'Core experience')
    para(d,'The studio supplies brush, stamp, eraser, clear and save tools. The player can keep the original or make an optional local colour variation; the original file remains intact. Saved work can be viewed in the gallery and prepared as an explorable artwork world. The gallery ritual lets the player give that creation a chosen meaning without analysing or judging the image.')
    d.add_page_break()
    heading(d,'Current reward flow')
    table(d,['Step','Player action','Game result'],[
        ('1 · Enter the studio','Use the drawing tool after Mind Spark and Heart Melody rewards are earned.','Creator’s Light route is available.'),
        ('2 · Make and save art','Draw or stamp a scene, save it locally, and optionally keep a separate colour variation.','A creation record and artwork file are available to the gallery.'),
        ('3 · Frame the creation','Open Gallery Frame Ritual; choose Star Bridge, Dream Door or Constellation Mural.','A motif is placed over the chosen artwork. The player may undo or revise.'),
        ('4 · Confirm','Confirm the placed motif.','The ritual is recorded and Creator’s Light is awarded.'),
        ('5 · Explore further','Enter the artwork world from the gallery when a world is ready.','The painting becomes a small navigable space with an interactive environment.')],[1.2,3.25,1.9])
    heading(d,'Meaning of the three motifs')
    bullet(d,'Star Bridge suggests a hopeful next step.')
    bullet(d,'Dream Door suggests a possibility to explore.')
    bullet(d,'Constellation Mural celebrates parts of the player’s story.')
    para(d,'There is no correct motif. The ritual records the player’s choice; it does not infer personality from the picture or use artwork analysis to award the treasure.')
    heading(d,'Current implementation reference')
    table(d,['Area','Source in the game'],[
        ('Unlocks and reward','artea/scripts/journey_campaign.gd and JourneyState.gd — prerequisite treasures and frame ritual award.'),
        ('Studio','artea/scenes/drawing_tool.tscn and artea/scripts/drawing_tool.gd — tools, save and gallery flow.'),
        ('Ritual','artea/scripts/creation_world/gallery_frame_ritual.gd — three motifs, placement, undo and confirmation.'),
        ('Artwork world','artea/scripts/creation_world/creation_world.gd — explorable world generated from a selected creation.')],[1.55,4.8])
    heading(d,'What this edition corrects')
    para(d,'The previous four-quest kingdom, level curve and three-stage boss are not the current Creator’s Light completion path. The Art Castle also contains a Creator-themed landscape and other optional viewing systems, but the campaign treasure is awarded by the Gallery Frame Ritual. This guide describes that implemented path.')
    heading(d,'Verification scope')
    para(d,'The refreshed Web build loaded the shared hub. The route and reward were checked in the current scenes and scripts. Studio, ritual, artwork-world interaction and completion have not yet been played through end to end in this browser session.')
    out=OUT/'World_Three_Creators_Light_Current_Game_Guide.docx'; d.save(out); return out

if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True)
    for f in (mind(),heart(),creator()): print(f)
