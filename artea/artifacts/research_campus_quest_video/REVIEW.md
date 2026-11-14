# Island One — latest local quest test

13 September 2026. Actual Godot Compatibility-renderer recording of the research
campus layout after the quality pass, with an isolated save. No gameplay code changed
for this test. The recording harness streams RGB frames directly to FFmpeg to avoid
large temporary frame files on the nearly full disk.

![55-second current quality-pass quest test](/Users/davidsovann/S2603/artea/artifacts/research_campus_quest_video/quest-quality-test.mp4)

## Results

- PASS: Quest One composition, analysis, regulators and alignment; save/reload regression.
- PASS: Signal Prism opens the internal garden gate, while the Island Two exit stays locked.
- PASS: Quest Two rejects misaligned capture, accepts gear tuning and captured echoes,
  supports classification and a useful preparation question, and awards the Echo Seed.
- PASS: Quest Two wrong interpretations, revision and save/reload regression.
- PASS: Actual player collision approaches against 16 instruments and four helper
  cabinets; occupied gate opening/closing stop and resume; narrow UI bounds/focus.
- PASS: Fresh full-story regression. Earlier layout/beam and gate/saddle checks are
  retained evidence, not rerun as part of this recording request.
- PASS: H.264 video encoding and full decode check, 960×540, 12 fps, 54.83 seconds.

Visual findings still open: Receiver II's nearby garden geometry crowds its base
and operating view; floating world labels overlap and compete with the panel.
The mechanical test pass does not certify final visual quality or all-object clearance.
The video is 1,282,578 bytes and contains 658 frames, without an audio track.
The older `quest-test.mp4` is retained as historical evidence, not the current clip.

This is an automated local test using public proximity interactions and actual
panel button signals, with player-height camera cuts. It is not continuous walking,
a recorded human playthrough, or browser verification. Audio is not recorded.
The isolated puzzle recording disables the campaign controller; the campaign is
tested separately. Some runs retain existing ObjectDB shutdown warnings.
Current web deployment remains the previous version: local disk space is still
insufficient for exporting this redesign. No commit, push or deployment performed.

## Screenshots

![Signal Laboratory](/Users/davidsovann/S2603/artea/artifacts/research_campus_quest_video/01_signal_laboratory.png)

![Garden entrance opens](/Users/davidsovann/S2603/artea/artifacts/research_campus_quest_video/02_garden_gate_open.png)

![Prism collector](/Users/davidsovann/S2603/artea/artifacts/research_campus_quest_video/03_garden_collector.png)

![Wrong alignment rejected](/Users/davidsovann/S2603/artea/artifacts/research_campus_quest_video/04_wrong_alignment.png)

![Thought classification](/Users/davidsovann/S2603/artea/artifacts/research_campus_quest_video/05_thought_classification.png)

![Echo Seed earned](/Users/davidsovann/S2603/artea/artifacts/research_campus_quest_video/06_echo_seed_complete.png)

Machine-readable recording events: [test_record.json](/Users/davidsovann/S2603/artea/artifacts/research_campus_quest_video/test_record.json).
