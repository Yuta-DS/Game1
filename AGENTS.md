\# AGENTS.md



Guidance for Codex and other coding agents working in the Artéa repository.



\## Repository scope



These instructions apply to the entire repository.



Codex is normally launched from the repository root. Keep instructions needed for

`artea/` and `server/` in this root file unless the normal Codex launch directory

changes and nested instruction files are intentionally introduced.



\## Project overview



Artéa is a Godot game with a Flask backend used for online gallery,

authentication, artwork upload, and related server functionality.



The repository contains both desktop-oriented and web-oriented functionality.

Web support is a first-class project requirement.



Primary areas:



\- `artea/` — Godot project containing GDScript, C#, scenes, resources, addons,

&#x20; shaders, assets, local-LLM integration, and export configuration.

\- `server/` — Flask backend containing `server.py`, `schema.sql`, and

&#x20; `flaskapp.service`.

\- `web-build/` — generated Godot web-export output. Treat this as disposable

&#x20; generated output rather than source.

\- `CHANGELOG.md` — release history. Do not duplicate release history here.

\- `README.md` — setup and deployment documentation.



\## Primary development goal



Preserve gameplay and user-visible behavior across desktop Godot and web builds.



If a feature works when running the project normally in Godot, the preferred

outcome is for the same feature and player experience to work in the browser.



Do not solve web compatibility problems by silently removing, disabling, or

simplifying gameplay features.



When desktop-specific technology cannot run on the web, Codex may change the

underlying implementation, including changes to both `artea/` and `server/`,

provided that:



1\. the player-visible behavior remains equivalent as closely as reasonably

&#x20;  possible;

2\. desktop behavior is not unnecessarily broken or degraded;

3\. web-specific replacements are maintainable and clearly integrated;

4\. duplicated desktop/web implementations are avoided where a shared solution is

&#x20;  practical;

5\. platform limitations or unavoidable behavioral differences are reported

&#x20;  clearly.



Behavioral parity is more important than preserving the exact implementation.



\## Godot project



The Godot project root is:



`artea/`



The configured main scene is represented in `project.godot`; repository

documentation identifies the startup scene as:



`res://scenes/start\_screen.tscn`



The project contains both GDScript and C#.



Current checked-in project metadata includes:



\- Godot project feature metadata for 4.6.

\- `Artea.csproj` using `Godot.NET.Sdk/4.6.3`.

\- `.NET` target framework `net8.0`.



The project documentation historically states Godot 4.4+ as its development

baseline. Do not assume that 4.6 is a permanent minimum solely because the

current project files were saved with that version.



When changing Godot or .NET versions:



\- version upgrades are allowed when technically justified;

\- keep `project.godot`, `Artea.csproj`, solution/project metadata, plugins, and

&#x20; export configuration compatible with one another;

\- do not perform an engine or framework upgrade as an unrelated cleanup;

\- explain material compatibility consequences.



Prefer Windows for normal development because the repository documentation

identifies Windows as the recommended development environment.



\## Godot source and generated files



Treat source scenes, scripts, project settings, resources, shaders, and required

export configuration as editable project files.



Do not manually edit generated/import cache content merely to make an error

disappear.



In particular:



\- `.godot/` is generated project/editor state.

\- `\*.import` files are generated and ignored by the repository.

\- temporary files matching the repository ignore rules are not source.

\- exported `.wasm`, `.pck`, generated JavaScript, executables, native binaries,

&#x20; and similar build artifacts should normally be regenerated from source rather

&#x20; than hand-edited.



Codex is allowed to delete and regenerate generated directories and build

artifacts, including `web-build/` and `.godot/`, when doing so is appropriate

for the task.



This permission does not extend to deleting source assets, scenes, scripts,

configuration, user-created resources, databases, or other non-generated data

unless the task explicitly requires it.



\## Web export



The checked-in Godot export configuration contains a Web preset named

`Web\_Version`.



The current web preset excludes content including:



\- `\*.gguf`

\- `addons/nobodywho/\*`

\- `\*.cs`

\- `\*.csproj`



Do not assume the current exclusions represent the desired final architecture.

They are existing project state, not a requirement to remove those features

from the browser version.



The existing web build may therefore differ from desktop behavior, especially

where C#, native addons, or the local LLM are involved.



When fixing web support:



\- work from source in `artea/` and, where appropriate, `server/`;

\- regenerate web output rather than treating `web-build/` as authoritative;

\- preserve gameplay behavior instead of preserving incompatible

&#x20; implementation details;

\- investigate browser restrictions before replacing working functionality;

\- prefer explicit platform abstraction over scattered web-only conditionals;

\- do not duplicate large systems solely for web unless there is a clear

&#x20; technical need;

\- keep server-dependent web behavior compatible with desktop behavior where

&#x20; practical;

\- verify the actual Godot export destination before assuming that an existing

&#x20; `web-build/` directory is the active preset output.



Codex may modify export presets when needed for correct web behavior.



\## C# and GDScript



For C# changes:



\- respect the checked-in `.csproj` and Godot .NET integration;

\- use APIs compatible with the intended Godot/.NET project version;

\- avoid introducing desktop-only dependencies into code that is expected to

&#x20; work on the web unless an explicit platform-specific implementation exists.



For GDScript changes:



\- follow the style and patterns already used near the affected code;

\- preserve scene, signal, autoload, and resource relationships;

\- do not rename nodes, autoloads, scene paths, signals, or serialized properties

&#x20; casually because scenes and resources may reference them by name or path.



For mixed C#/GDScript systems, inspect both sides of the integration before

changing public interfaces.



\## Autoloads and shared services



`project.godot` defines shared/autoload functionality including systems such as:



\- `Firebase`

\- `MusicManager`

\- `Global`

\- `DialogueManager`

\- `GameManager`

\- `Auth`

\- `APIManager`



Treat autoloads as project-wide interfaces. Before changing an autoload name,

path, API, or lifecycle, search for all consumers.



Server URLs are centralized through the Godot `APIManager` singleton. Update

shared endpoint configuration there rather than scattering replacement server

URLs throughout unrelated scripts.



\## Addons



The repository contains third-party or bundled addons, including systems such as:



\- Dialogue Manager

\- Firebase

\- Terrain3D

\- local-LLM/NobodyWho-related functionality

\- Proton Scatter test content



Do not modify third-party addon internals as a first choice when the same result

can be achieved from project code or configuration.



If an addon must be changed:



\- identify why a project-side workaround is insufficient;

\- keep the change minimal;

\- avoid modifying generated addon binaries;

\- consider whether an upstream/addon update could overwrite the change.



\## Local LLM and web compatibility



Desktop functionality currently includes a local LLM architecture involving

NobodyWho and `.gguf` model files.



The web export currently excludes that local model implementation.



If local/native LLM functionality is unavailable in browsers, Codex may replace

or supplement it with a browser-compatible or server-backed implementation.



The goal is equivalent player-visible chatbot behavior, not necessarily running

the same model locally in the browser.



Do not silently remove chatbot functionality from web builds.



\## Flask backend



The backend is located in:



`server/`



`server.py` currently uses:



\- Flask

\- Flask-SQLAlchemy

\- Flask-JWT-Extended

\- bcrypt

\- requests

\- SQLite



There is currently no checked-in `requirements.txt`, `pyproject.toml`, or

`Pipfile`.



Do not claim that a Python dependency manifest exists unless one is added as

part of an intentional change.



The repository documentation currently installs the backend dependencies

individually. If dependency management is changed, update the relevant

documentation at the same time.



`server.py` currently:



\- creates the SQLite database tables at startup;

\- stores the database under `server/database.db`;

\- creates an uploads directory when needed;

\- binds to `0.0.0.0`;

\- listens on port 80;

\- runs with Flask debug mode disabled.



Treat those as current implementation facts, not immutable design requirements.



\## Server deployment



`server/flaskapp.service` and the README describe a Linux/systemd deployment

workflow.



Do not assume Linux `source venv/bin/activate` or `systemctl` commands are the

correct local-development commands on Windows.



Keep these concepts separate:



\- local development;

\- running the Flask application manually;

\- Linux/systemd production deployment.



Do not restart, enable, disable, or otherwise modify production services unless

the task explicitly involves deployment and the user has approved the relevant

command.



\## API compatibility



When changing backend routes or payloads:



\- inspect the Godot client callers before changing the API contract;

\- update client and server together when a contract intentionally changes;

\- preserve authentication expectations;

\- handle errors explicitly;

\- avoid hard-coded environment-specific server addresses in unrelated scripts.



Changes made to support the web version must not unnecessarily break desktop

clients.



\## Secrets and credentials



Never introduce real secrets, passwords, API keys, tokens, private credentials,

or production signing material into tracked source files.



Existing development placeholders or development secrets must not be treated as

production-safe examples.



The backend currently contains OpenRouter-related integration code and

development authentication configuration. If enabling external model access,

use an appropriate external/configurable secret mechanism rather than committing

a real API key.



Do not print or expose secret values in summaries, logs, patches, or generated

documentation.



Treat files related to Firebase or other external services carefully. Do not

replace service configuration or credentials unless required by the task.



\## Git LFS and large files



This repository uses Git LFS.



Current LFS rules include:



\- `artea/nobodywhomodels/\*`

\- `\*.dll`

\- `\*.so`

\- `\*.pdb`



Preserve Git LFS tracking for files already covered by these rules.



Do not:



\- convert LFS-managed large files into ordinary Git blobs unintentionally;

\- edit binary/model files as text;

\- duplicate `.gguf` models to work around web-export problems;

\- remove LFS rules merely to make a local checkout appear complete.



If required LFS content is missing after cloning, identify that condition before

trying to rewrite source code around missing assets.



\## Generated and legacy content



The repository contains generated, old, exported, and platform-metadata files,

including items such as:



\- `.godot/`

\- `web-build/`

\- `.DS\_Store`

\- `\_\_MACOSX/`

\- `\*.import`

\- old `.csproj` copies

\- generated web artifacts



Do not use obvious generated/metadata duplicates as the authoritative source

when a current project source file exists.



Generated or obsolete artifacts may be removed when they are clearly

unnecessary and their removal is relevant to the task.



Do not perform broad repository cleanup as an unrelated side effect.



\## Change discipline



Before editing:



1\. inspect the files directly involved in the task;

2\. inspect callers, references, scenes, resources, API consumers, or server

&#x20;  routes that could be affected;

3\. distinguish generated output from authoritative source;

4\. check whether the requested behavior must work on both desktop and web.



During changes:



\- keep edits scoped to the requested goal;

\- prefer fixing root causes over patching generated output;

\- preserve existing working behavior outside the task;

\- avoid unrelated formatting or mass rewrites;

\- do not create duplicate implementations without a technical reason;

\- update documentation when setup, architecture, dependencies, or deployment

&#x20; behavior materially changes.



When a change affects web compatibility, explicitly consider both the desktop

and browser execution paths.



\## Commands and validation



Do not automatically run build, test, validation, export, server-start, package

installation, deployment, or service-management commands.



Ask the user for permission before running such commands.



This includes commands that:



\- build the Godot/.NET project;

\- launch Godot;

\- run or export the game;

\- start the Flask server;

\- install Python packages;

\- invoke automated or scene-based tests;

\- regenerate a web export;

\- run deployment or `systemctl` operations.



After making changes, identify the checks that would be appropriate and ask

before executing them.



Potential checks depend on the changed area:



\- C# changes: build the Godot/.NET project.

\- GDScript or scene changes: open/run the affected Godot project or scene.

\- Web changes: create a fresh web export and test the relevant browser behavior.

\- Flask changes: start the backend and perform targeted API checks.

\- Cross-platform changes: validate both desktop and browser behavior.



There is no established repository-wide automated test command. Do not invent

one.



Addon test scenes or test files are not automatically equivalent to a

repository-wide test suite.



Never state that a build, test, export, or validation passed unless it was

actually run successfully.



\## Destructive operations



Codex is allowed to delete generated build/cache output when necessary,

including regenerated web output.



Before destructive changes involving source code, project assets, databases,

uploaded user data, Git history, credentials, or other non-generated content,

obtain explicit user approval unless deletion is the task the user directly

requested.



Do not:



\- reset or rewrite Git history casually;

\- discard unrelated working-tree changes;

\- remove user-created data to resolve a development issue;

\- delete databases or upload directories as a routine troubleshooting step.



\## Documentation



Keep repository documentation consistent with actual project behavior.



In particular, when architecture or setup changes:



\- update `README.md` where appropriate;

\- update API/setup guidance when server behavior changes;

\- avoid duplicating release history from `CHANGELOG.md`;

\- prefer actual checked-in project metadata over stale documentation when

&#x20; describing the current implementation.



The repository currently contains `CLAUDE.md` pointing to the older

`AGENT.md`. If the project standardizes on this `AGENTS.md`, update references

to the old singular filename so documentation does not point to stale agent

guidance.



\## Completion reports



When finishing a task, report:



\- what changed;

\- any important desktop/web implications;

\- any files intentionally regenerated or removed;

\- validation that was actually performed;

\- validation that was not performed because permission was not granted or the

&#x20; required environment was unavailable;

\- any remaining platform limitations, risks, or follow-up work.



Do not claim full desktop/web parity until the affected behavior has actually

been tested on both relevant targets.

