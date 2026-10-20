import json
import contextlib
import gzip
import io
from pathlib import Path
import tempfile
import unittest
from package import required_files, metadata, build
from verify import validate

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

    def test_rejects_failed_or_running_export(self):
        (self.source / ".export-in-progress").touch()
        with self.assertRaisesRegex(ValueError, "incomplete"): required_files(self.source)

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

    def test_hashed_parts_and_all_area_dependencies(self):
        (self.source / "parts").mkdir()
        for pack in ["index", "hub", "shared_runtime"]:
            entries = [{"name": f"parts/{pack}.pck.0123456789abcdef.part00", "size": 4}, {"name": f"parts/{pack}.pck.0123456789abcdef.part01", "size": 2}]
            (self.source / (pack + ".pck.parts.json")).write_text(json.dumps({"count": 2, "bytes": 6, "partBytes": 4, "parts": entries}))
            for entry in entries: (self.source / entry["name"]).write_bytes(b"x" * entry["size"])
        (self.source / "web-packs.json").write_text(json.dumps({"hub": {"file": "hub.pck", "requires": ["shared_runtime"]}, "shared_runtime": {"file": "shared_runtime.pck", "requires": []}}))
        names = required_files(self.source)
        self.assertIn("parts/hub.pck.0123456789abcdef.part00", names)
        self.assertIn("parts/shared_runtime.pck.0123456789abcdef.part01", names)
        self.assertNotIn("index.pck.part00", names)

    def test_rejects_escaped_part_path(self):
        (self.source / "index.pck.parts.json").write_text(json.dumps({"count": 2, "bytes": 6, "partBytes": 4, "parts": [{"name": "../private", "size": 4}, {"name": "index.pck.part01", "size": 2}]}))
        with self.assertRaisesRegex(ValueError, "Unsafe"): required_files(self.source)

    def test_delivery_compression_and_private_backend_separation(self):
        with (self.source / "index.html").open("a") as stream:
            stream.write("const engine = new Engine(GODOT_CONFIG);\n")
        content = b"// representative repeated script content\n" * 1000
        (self.source / "index.js").write_bytes(content)
        with contextlib.redirect_stdout(io.StringIO()):
            target = build(self.source, self.source / "delivery")
        manifest = validate(target)
        key = f"releases/{manifest['release']}/index.js"
        entry = next(item for item in manifest["files"] if item["path"] == key)
        self.assertEqual(entry["content_encoding"], "gzip")
        self.assertEqual(gzip.decompress((target / "site" / key).read_bytes()), content)
        self.assertTrue((target / "server" / "aws_app.py").is_file())
        self.assertFalse((target / "site" / "server").exists())
        self.assertTrue((self.source / "delivery" / ".gdignore").is_file())

if __name__ == "__main__": unittest.main()
