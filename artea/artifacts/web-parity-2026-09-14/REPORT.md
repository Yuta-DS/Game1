# Artéa Web parity delivery — 14 September 2026

## Outcome

The canonical production URL now serves the latest 150-part Web pack instead
of the stale 145-part deployment. The Web export includes the valid high-detail
Milo and Crown Line train resources that were explicitly omitted before.

- Public URL: <https://artea-web.vercel.app/>
- Deployment: `dpl_AaM8GvZ5QuSKctGPfXixSAnRZaBf`
- Pack: 150 parts, 1,252,055,672 bytes

## Prevention

- `test_web_feature_parity.gd` verifies the Web preset exports all resources and
  does not exclude required player-facing assets.
- `export_web.sh` runs that parity test before replacing a build and now fails
  when Godot emits a resource or script error during export.
- `deploy_web.sh` deploys, assigns `artea-web.vercel.app`, and checks that its
  public pack manifest exactly matches the local export.

## Verification

- Web feature parity guard: pass (5 required resources).
- Web environment, terrain, railway, Milo fallback, Mind Spark runtime, World
  One story, and chapter regressions: pass.
- Clean non-Mono Web export: pass; no resource or script errors.
- Local WebGL2 browser: playable; Offline Guest, hub, pointer lock, movement;
  zero fatal resource errors and zero runtime exceptions.
- Canonical production WebGL2 browser after alias correction: playable; engine
  started after the uncached download, Offline Guest entered, hub built,
  pointer lock acquired, and movement rendered; zero fatal resource errors and
  zero runtime exceptions.

## Platform limitation

The desktop NobodyWho/Gemma binary and its 2 GB model remain native-only because
the plugin provides no Web library. Web retains Milo's authored, local safe
dialogue and wisdom response path. Gameplay, quests, worlds, and valid visual
assets remain part of the Web export.
