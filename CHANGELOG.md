# Changelog

All notable changes to the **Artéa** project are documented here, grouped by tagged release and then by application area. Entries are drawn from the project's commit history and merged/rewritten into readable release notes; noise commits (empty merges, "test commit", "stuff", etc.) are omitted, but the intent is to reflect the real breadth of work done in each release rather than a compressed highlight reel.

Releases are listed newest first.

---

## [v2.0] - 2026-06-04

### Overview

v2.0 is the project's major content release, taking Artéa from an early prototype to a full playable experience. This release introduced the ambient audio and ocean/footstep sound systems, the narrative dialogue and NPC "Narrative Bubble" system built around Milo and the other characters, the cloud-popping and music minigames, a persistent login/authentication system, and a Flask-backed online gallery that lets players upload and download artwork and rate other players' work. It also absorbed a long tail of bug fixes from repeated branch merges (`feat-ambient-audio`, `raf-test-branch`, `raf-iteration-2`, `raf-music-final`, `raf-bug-fixes`, `raf-polish`, `merge-fix`, `latestupdate`, `windows-build`) and closes with Windows build preparation and documentation cleanup.

### Highlights

- Full ambient/spatial audio system: ocean, waterfall, and dynamic footstep SFX with 3D attenuation
- Narrative Bubble dialogue system and expanded NPC scripts/prompts (Milo chatbot up to v4.13)
- Cloud-popping and music minigames, including emotion detection and a finished song list
- Persistent authentication with a Flask server, plus online artwork upload/download and gallery browsing
- Artwork rating system for the online gallery
- Windows build preparation and a large batch of crash/regression fixes from concurrent branch merges

### World & Gameplay

- Implemented environment-aware footsteps and an overhauled player movement system
- Added 3D clouds and a pastel cloud variant, plus a cloud-popping minigame with sparkle effects and a "play again" flow
- Built and iterated on a music minigame prototype, later finishing it with updated visuals, emotion detection, and a completed song list
- Added and repeatedly adjusted teleporters/portals between the hub world ("Artéa Park") and the art gallery, including colour and placement fixes after merge regressions
- Added new NPCs, repositioned existing ones, and tuned NPC animations/tracking
- Reworked the online/offline gallery flow, including an offline guest bypass
- Adjusted music minigame volume and general scene performance optimizations

### NPCs & Dialogue

- Implemented the 360-degree Narrative Bubble system for NPC dialogue
- Built the foundation for scripted NPC dialogues and a new chatbot prompt for Milo, iterated repeatedly (client feedback pass, placeholder/instructions updates, v4.13 prompt update)
- Recovered and extended the "Maestro Sinclair" script and other dialogue content lost during branch merges
- Fixed dialogue not proceeding, minigame names/paths referenced incorrectly in dialogue, and detection-area bugs
- Updated NPC and minigame names throughout dialogue text, and linked Gabriel's and Uriel's dialogues to the project website

### Audio

- Added waterfall ambient audio, later replaced with a more localized ocean ambience for better spatial believability
- Added dynamic footstep SFX to the player, then optimized footstep audio with 3D attenuation
- Added background music and a pop sound effect for the cloud minigame (later replaced with an updated pop sound)
- Finalized the hub world's audio and narrative systems as a combined milestone
- Added a volume button and adjusted minigame volume levels

### UI/UX

- Radically redesigned the login screen and modularized audio integration alongside it
- Linked the Start Screen UI to global session data to support the Narrative Bubble system
- Iterated on fonts multiple times (new fonts added, then changed again) and updated choice-button colours
- Reworked the "PopThoughtsMenu" into "PopThoughtsGarden"
- Added a live coordinate debug UI during beach audio spatiality work (later removed once no longer needed)
- Fixed the LineEdit control, the PopThoughts menu screen, and the instructions pages/theme (adjusted multiple times based on feedback)
- Renamed "Hubworld" to "Artéa Park" and made several other in-game naming/text passes ("Happier text", etc.)
- Adjusted screen size and general accessibility pass over environmental UI integration

### Online Gallery & Server

- Stood up a basic Flask server with an API script and server-side login
- Added user registration and made the server autostart with the project
- Implemented artwork upload to the server and download of a player's own artwork back into the gallery
- Fixed online gallery display/sync issues and artwork name/display-logic bugs
- Moved server IP addresses into a central `API_Manager` for easier configuration
- Added a basic online LLM API path for the chatbot
- Implemented the artwork rating system for the online gallery, then fixed a rating-system bug found post-release
- Added a painting sound effect and a "saving" notification for artwork uploads

### Build & Tooling

- Set up Git LFS for large assets (LLM `.gguf` models, native plugin binaries) and documented the setup in the README
- Did general Windows build preparation ahead of the v2.0 tag
- Updated `.gitignore` multiple times (terrain3D, import artifacts, `~*` temp files)

### Bug Fixes

- Fixed the main branch crashing on startup after a merge, and a related crash when the game starts
- Fixed camera, inventory, jump-while-interacting, and move-while-interacting behaviour broken by previous merges
- Fixed item pickup broken by a previous merge
- Restored `.gitignore` and README content that had been accidentally overwritten by a merge
- Fixed missing portals and chatbot regressions introduced during branch integration, across several follow-up passes
- Deleted a duplicate "Everlasting Father" NPC left over from a merge
- Fixed portals being misplaced, miscoloured, or otherwise broken after successive merges, with a final adjustment pass
- Fixed a crash caused by spawning on top of a collectible item
- Fixed an inventory-related game-crashing bug
- Fixed the "Art Minigame" portal and cloud minigame's "play again" button path
- Fixed cloud overlapping issues (recurred and was fixed twice)
- Fixed a button that wasn't responding correctly
- Fixed the artwork rating system bug reported after initial gallery rollout
- Fixed the artwork name bug in the online gallery

### Documentation

- Updated the README with Git LFS setup instructions
- Added and later removed a project TODO list
- General README and LICENSE cleanup, including a couple of follow-up typo fixes

---

## [v1.0] - 2025-11-04

### Overview

v1.0 covers the initial prototyping phase of Artéa, built over a few days at the end of October 2025. This release establishes the project skeleton: the initial Godot project, the art gallery world and player controller, an inventory system, a starting screen, and early NPC test scenes — the foundation that later releases built the audio, dialogue, and online gallery systems on top of.

### Highlights

- Initial Godot project and repository scaffolding
- First playable art gallery world with a player controller and teleport support
- Inventory system with pickup and open/close interaction
- Starting screen and first NPC test scene

### World & Gameplay

- Created the initial art gallery world and a player controller for navigating it
- Added an art gallery 3D model with teleport functionality between areas
- Designed and implemented the inventory system, including item pickup and opening the inventory
- Added a capsule collider to the player and fixed related collision issues
- Implemented autospawning of items into the world
- Organized and restructured the main scene as the project grew

### NPCs & Dialogue

- Added the first NPC test scene and iterated on its behaviour (including a dedicated fix pass on `NPCtest1`)

### UI/UX

- Built the starting/menu screen
- Added early UI buttons, including a button to enter the art gallery

### Build & Tooling

- Initialized the repository and imported the base Godot project
- Added a native terrain plugin binary (`libterrain` Windows debug build) and began ignoring generated terrain3D/import artifacts in `.gitignore`

### Documentation

- Added the initial README

---

[Compare v1.0...v2.0](https://gitlab.westernsydney.edu.au/capstone/spring-2026/project/S2603/-/compare/v1.0...v2.0) · [Repository](https://gitlab.westernsydney.edu.au/capstone/spring-2026/project/S2603)
