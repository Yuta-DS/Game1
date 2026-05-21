This document provides instructions for setting up and running the Artéa game project within the Godot Development Engine.

**Note on Development Integrity:** To ensure maximum project stability and to minimise issues related to file path case sensitivity and the Godot .NET runtime dependencies, it is strongly recommended that all developers work on a _**Windows operating system.**_


Guide to Running the Project
  1. **Engine Requirement:** Download and install Godot Engine version 4.4 or newer, specifically the version that includes .NET/Mono support (for C# compilation).
  2. **Import Project:** Import the project directory into the Godot Project Manager.
  3. **Initial Scene Launch:** To test the project, click the "Run Scene" button (F6). If the main scene is not already assigned, set it to:
    - "res://scenes/start_screen.tscn"

The game file contains the previous and our group work. The previous group work was working on 2D version of the Artea game, but our group switch to working on the game in 3D. 

The 3D version contains some of the previous group files such as:
  - authentication.tscn 
  - game_start.tscn 
  - several files of the pop thoughts world (such as cloud.tscn, cloudPopFinish.tscn, cloud_pop_ui.tscn, and popThoughtsMenu.tscn. Also all the scripts for these files)

But the main worlds for this project is:

    - res://scenes/New_Hub_World.tscn
    - res://scenes/art_gallery_3D_inprogress.tscn
    - res://scenes/drawing_Tool.tscn
    - res://scenes/popThoughtsMenu.tscn

Several outstanding work is still in progress such as:

* **Popthoughts World:** The existing 2D scenes need to be adapted or replaced within the 3D environment structure.
* **Inventory:** The logic for dropping items (e.g., apples, shells) from the inventory needs to be implemented.

---

# ================================
# Changes April 2026
# ================================

## Git Setup & Large File Requirements (IMPORTANT)

This project uses **Git LFS (Large File Storage)** for large assets including:
- LLM model files (`.gguf`)
- Native plugin binaries (`.dll`, `.so`, `.pdb`)

These files are required for the project to run correctly (local/offline Milo AI Chatbot).

---

### First-time setup (required for all developers)

Install Git LFS before pulling or checking out the project files:

git lfs install
git clone <repo>
git lfs pull