#!/usr/bin/env python3

from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from patch_web_release_loader import (
	DEBUG_LIBRARY,
	RELEASE_LIBRARY,
	patch_loader,
)


class PatchWebReleaseLoaderTests(unittest.TestCase):
	def _fixture(self, directory: Path, library: str) -> Path:
		index = directory / "index.html"
		index.write_text(
			f'<script>const GODOT_CONFIG = {{"gdextensionLibs":["{library}"]}};</script>\n',
			encoding="utf-8",
		)
		(directory / RELEASE_LIBRARY).write_bytes(b"release wasm")
		return index

	def test_rewrites_debug_loader_to_release(self) -> None:
		with TemporaryDirectory() as temporary:
			index = self._fixture(Path(temporary), DEBUG_LIBRARY)

			self.assertTrue(patch_loader(index))

			html = index.read_text(encoding="utf-8")
			self.assertIn(RELEASE_LIBRARY, html)
			self.assertNotIn(DEBUG_LIBRARY, html)

	def test_release_loader_is_idempotent(self) -> None:
		with TemporaryDirectory() as temporary:
			index = self._fixture(Path(temporary), RELEASE_LIBRARY)

			self.assertFalse(patch_loader(index))

	def test_missing_release_library_fails_closed(self) -> None:
		with TemporaryDirectory() as temporary:
			index = Path(temporary) / "index.html"
			index.write_text(
				f'{{"gdextensionLibs":["{DEBUG_LIBRARY}"]}}',
				encoding="utf-8",
			)

			with self.assertRaises(FileNotFoundError):
				patch_loader(index)

	def test_unexpected_loader_configuration_fails_closed(self) -> None:
		with TemporaryDirectory() as temporary:
			index = self._fixture(Path(temporary), "another-extension.wasm")

			with self.assertRaises(RuntimeError):
				patch_loader(index)


if __name__ == "__main__":
	unittest.main()
