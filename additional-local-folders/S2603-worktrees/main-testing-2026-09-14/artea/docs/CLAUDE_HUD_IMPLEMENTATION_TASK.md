# Claude implementation task — supervised Artéa HUD pass

## Canonical user request

> remove the need help and my journey and setup feature for me. and using
> vision and design that i show you in the images and make it better for me.
> using clude as plugin for implementation for me and you as supervisor and
> planning

The supervisor inspected the twelve supplied screenshots and wrote the approved
design and acceptance criteria in `docs/HUD_VISUAL_SUPERVISION.md`. Read that
entire file before editing.

## Your bounded task

Implement the approved HUD pass in the existing Godot project. You may edit only:

- `project.godot`
- `scripts/creation_world/creation_world.gd`
- `scripts/hub_sky_isles.gd`
- a new helper under `scripts/ui/` if it materially improves cohesion
- a new focused test `scripts/test_hud_presentation.gd`
- `docs/HUD_VISUAL_SUPERVISION.md` only to append implementation/test notes

Requirements:

1. Remove the `JourneySafeguards` autoload entry. Do not delete unrelated
   safeguard/privacy files and do not replace the strip with another permanent
   settings control.
2. Redesign the creation-world HUD and idea/sketch panels according to the
   approved field-journal system. Use the bundled Artéa fonts, named nodes,
   artwork-derived accents, dark translucent backing, minimum 44 px actions,
   and concise contextual status. Preserve actions and key bindings.
3. Make the island-state debug label false-by-default even in debug builds, with
   an explicit opt-in project setting for developers.
4. Add a headless focused test for absence of the strip/autoload, structure and
   accessibility of the new HUD, and default absence of island debug UI.
5. Keep GDScript compatible with this project's Godot version and formatting.
6. Do not modify 3D world geometry, lighting, controls, generation, APIs,
   persistence, unrelated tests, import files, or any other dirty file.
7. Do not use git, commit, reset, delete, or revert user work.

Run the focused test if the environment permits. Report exact files changed,
test commands/results, and any remaining uncertainty. Do not claim success
without filesystem/test evidence; the supervisor will independently review and
validate everything.
