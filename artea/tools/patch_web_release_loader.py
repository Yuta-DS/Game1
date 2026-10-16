#!/usr/bin/env python3
"""Align Godot's Web loader with the release Terrain3D extension."""

from __future__ import annotations

import argparse
import os
from pathlib import Path


DEBUG_LIBRARY = "libterrain.web.debug.wasm32.wasm"
RELEASE_LIBRARY = "libterrain.web.release.wasm32.wasm"


def patch_loader(index_path: Path) -> bool:
	"""Select the release side module in an exported Godot index.html.

	Godot 4.7 can emit a release PCK while leaving the debug Terrain3D module in
	GODOT_CONFIG.gdextensionLibs. The PCK then selects the release extension and
	the browser has not preloaded it, so New_Hub_World cannot load.
	"""
	index_path = index_path.resolve()
	release_path = index_path.with_name(RELEASE_LIBRARY)
	if not release_path.is_file():
		raise FileNotFoundError(
			f"release Terrain3D Web library is missing: {release_path}"
		)

	html = index_path.read_text(encoding="utf-8")
	if '"gdextensionLibs"' not in html:
		raise RuntimeError(f"Godot loader configuration is missing in {index_path}")

	debug_count = html.count(DEBUG_LIBRARY)
	release_count = html.count(RELEASE_LIBRARY)
	if debug_count == 0 and release_count == 1:
		return False
	if debug_count != 1 or release_count != 0:
		raise RuntimeError(
			"unexpected Terrain3D loader configuration: "
			f"debug={debug_count}, release={release_count}"
		)

	updated = html.replace(DEBUG_LIBRARY, RELEASE_LIBRARY, 1)
	temporary_path = index_path.with_name(f".{index_path.name}.terrain-release.tmp")
	temporary_path.write_text(updated, encoding="utf-8")
	os.replace(temporary_path, index_path)
	return True


def main() -> int:
	parser = argparse.ArgumentParser()
	parser.add_argument("index", type=Path, help="exported Godot index.html")
	args = parser.parse_args()

	changed = patch_loader(args.index)
	state = "updated" if changed else "already correct"
	print(f"Terrain3D Web loader: {state} ({RELEASE_LIBRARY})")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
