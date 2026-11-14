# Download and Restore Guide

This repository contains the Artéa project and additional local workspace snapshots.

## Which branch to download

- Use `main` for the normal project source.
- Use `codex/ignored-workspace-snapshot` to restore the complete uploaded workspace snapshot, including the `S2603-clone` and `S2603-worktrees` folders.

## Download the complete snapshot

Use Git and Git LFS. Do not use a browser ZIP download for the complete restore because large files are stored with Git LFS.

```bash
git clone --branch codex/ignored-workspace-snapshot https://github.com/Yuta-DS/Game1.git
cd Game1
git lfs pull
```

If Git LFS is not installed, install it first and run `git lfs install`.

## What is included

The complete snapshot branch contains about 42,096 file paths, including:

- The main Artéa project.
- The uploaded `S2603-clone` files under `additional-local-folders/S2603-clone/`.
- The uploaded `S2603-worktrees` files under `additional-local-folders/S2603-worktrees/`.
- Large models, binaries, web packages, and other Git LFS files.

The copied folders' nested `.git` metadata is intentionally not included. Their working files are included.

## Files intentionally excluded

These local files were not uploaded:

- `.env` files, because they can contain credentials or machine-specific settings.
- `server/database.db`, because it is local database data.

Create or restore those files separately when setting up the project on a new laptop.

## Verify the download

From the cloned repository, list the uploaded paths:

```bash
git ls-tree -r --name-only HEAD > uploaded-files.txt
```

To find files listed by the snapshot but missing from a downloaded working tree:

```bash
find . -type f | sort > downloaded-files.txt
comm -23 uploaded-files.txt downloaded-files.txt
```

An empty result means no uploaded paths are missing from the downloaded tree.

