# Artéa

An art-therapy game: a player explores a Hub and Art Castle, plays three Kingdoms, and keeps artwork in an online gallery. This context also covers how the game is delivered to the browser.

## Language

**Kingdom**:
One of the three playable areas of the Crown of Life journey: Mind Spark, Heart Melody, Creator's Light.
_Avoid_: World One / World Two / World Three (legacy planning names), level

**World**:
A walkable 3D space: the Hub or the Art Castle.
_Avoid_: Kingdom (for these)

**Hub**:
The first walkable World a player enters after the start screen.
_Avoid_: Hub World, lobby

**Art Castle**:
The World the player returns to between Kingdoms; holds the gallery, Tree of Life and Crown Line train.
_Avoid_: Castle Galaxy (except in routing code)

**Web build**:
The browser-deliverable export of the game: HTML, JS, wasm, and Packs.
_Avoid_: web version, web app

**Pack**:
A separately downloadable bundle of game content for one area (or a group of areas); the unit that is fetched on demand.
_Avoid_: chunk (ambiguous), pck (file extension only)

**Core pack**:
The Pack every player downloads before the game starts: start screen, auth, loading screen, HUD, and assets needed from the start.
_Avoid_: base, main pack

**Shared pack**:
A Pack of assets not needed at start but used by several areas, loaded with the areas that need it.

**Part**:
A fixed-size slice of a Pack file used for hosting limits and resumable, parallel fetching; never a unit of content.
_Avoid_: chunk, segment

**First load**:
Everything a player must download before the Hub is playable (Core pack + Hub pack + engine files).
