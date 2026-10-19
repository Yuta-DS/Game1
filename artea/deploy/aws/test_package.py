import json
from pathlib import Path
import tempfile
import unittest
from package import required_files, metadata

class PackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.source = Path(self.temp.name)
        config = {"fileSizes": {"index.pck": 6, "index.wasm": 4}, "gdextensionLibs": ["terrain.wasm"]}
        (self.source / "index.html").write_text("const GODOT_CONFIG = " + json.dumps(config) + ";\n")
        (self.source / "index.pck.parts.json").write_text(json.dumps({"count": 2, "bytes": 6, "partBytes": 4}))
        for name in ["index.js", "index.wasm", "index.side.wasm", "terrain.wasm", "pck-loader.js", "index.audio.worklet.js", "index.audio.position.worklet.js", "index.pck.part00"]:
            (self.source / name).write_bytes(b"1234")
        (self.source / "index.pck.part01").write_bytes(b"56")

    def test_excludes_stale_and_private_files(self):
        for name in ["index.pck.part108", "export.log", ".env", "index.png.import", "index.side.wasm.part00"]:
            (self.source / name).write_text("stale")
            self.assertNotIn(name, required_files(self.source))

    def test_rejects_truncated_pack(self):
        (self.source / "index.pck.part01").write_bytes(b"5")
        with self.assertRaisesRegex(ValueError, "truncated"): required_files(self.source)

    def test_rejects_mixed_export(self):
        (self.source / "index.pck.parts.json").write_text(json.dumps({"count": 2, "bytes": 7, "partBytes": 4}))
        with self.assertRaisesRegex(ValueError, "different exports"): required_files(self.source)

    def test_rejects_missing_extension(self):
        (self.source / "terrain.wasm").unlink()
        with self.assertRaisesRegex(ValueError, "runtime asset"): required_files(self.source)

    def test_cache_and_wasm_metadata(self):
        self.assertIn("no-store", metadata("index.html")["cache_control"])
        self.assertIn("immutable", metadata("releases/abc/index.js")["cache_control"])
        self.assertEqual(metadata("releases/abc/index.side.wasm")["content_type"], "application/wasm")

if __name__ == "__main__": unittest.main()
