"""Build a clean, checksummed AWS delivery from the maintained Godot Web export."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import zipfile

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[1]

def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()

def read_config(html):
    match = re.search(r"const GODOT_CONFIG\s*=\s*(\{[^\n]+\});", html)
    if not match:
        raise ValueError("Godot configuration not found; export with the maintained Web preset.")
    return json.loads(match.group(1))

def required_files(source):
    html = (source / "index.html").read_text(encoding="utf-8")
    config = read_config(html)
    manifest = json.loads((source / "index.pck.parts.json").read_text())
    count, size, part_size = (manifest[k] for k in ("count", "bytes", "partBytes"))
    if not all(type(n) is int and n > 0 for n in (count, size, part_size)) or count != (size + part_size - 1) // part_size:
        raise ValueError("Invalid pack manifest")
    if config["fileSizes"]["index.pck"] != size:
        raise ValueError("HTML and pack manifest are from different exports")
    names = {"index.html", "index.js", "index.wasm", "index.side.wasm", "pck-loader.js", "index.pck.parts.json"}
    names.update(config.get("gdextensionLibs", []))
    names.update(["index.audio.worklet.js", "index.audio.position.worklet.js"])
    names.update(re.findall(r'(?:src|href)="(index\.[A-Za-z0-9_.-]+)"', html))
    # The splash may be referenced in CSS instead of an HTML attribute.
    if (source / "index.png").exists(): names.add("index.png")
    if config.get("serviceWorker"): names.add(config["serviceWorker"])
    for i in range(count):
        name = f"index.pck.part{i:02d}"
        expected = min(part_size, size - i * part_size)
        if not (source / name).is_file() or (source / name).stat().st_size != expected:
            raise ValueError(f"Missing or truncated pack part: {name}")
        names.add(name)
    for name in names:
        if Path(name).name != name or not (source / name).is_file():
            raise ValueError(f"Missing or unsafe runtime asset: {name}")
    if (source / "index.wasm").stat().st_size != config["fileSizes"]["index.wasm"]:
        raise ValueError("WebAssembly size disagrees with HTML")
    return sorted(names)

def metadata(path):
    suffix = Path(path).suffix
    mime = {".html": "text/html; charset=utf-8", ".js": "application/javascript", ".json": "application/json", ".wasm": "application/wasm", ".png": "image/png"}.get(suffix, "application/octet-stream")
    return {"content_type": mime, "cache_control": "no-store, max-age=0" if path == "index.html" else "public, max-age=31536000, immutable"}

def build(source, output):
    names = required_files(source)
    hashes = {name: digest(source / name) for name in names}
    identity = {"assets": hashes, "packager": digest(Path(__file__)), "landing": digest(HERE / "landing.html")}
    release = hashlib.sha256(json.dumps(identity, sort_keys=True).encode()).hexdigest()[:16]
    target = output / ("artea-aws-" + release)
    if target.exists():
        raise ValueError(f"Package already exists: {target}. Use a different --output folder to rebuild.")
    runtime = target / "site" / "releases" / release
    runtime.mkdir(parents=True)
    for name in names: shutil.copy2(source / name, runtime / name)
    html = (runtime / "index.html").read_text(encoding="utf-8")
    preview = html.replace("const GODOT_CONFIG =", "window.ARTEA_HEART_PREVIEW = true;\nconst GODOT_CONFIG =", 1)
    marker = "const engine = new Engine(GODOT_CONFIG);"
    if marker not in preview: raise ValueError("Preview startup adapter does not match this export")
    preview = preview.replace(marker, 'GODOT_CONFIG.args = (GODOT_CONFIG.args || []).concat(["--", "--heart-preview"]);\n' + marker, 1)
    (runtime / "heart.html").write_text(preview, encoding="utf-8")
    total_mb = sum((runtime / name).stat().st_size for name in names) / 1_000_000
    landing = (HERE / "landing.html").read_text(encoding="utf-8").replace("{{RELEASE}}", release).replace("{{DOWNLOAD_MB}}", str(round(total_mb)))
    (target / "site" / "index.html").write_text(landing, encoding="utf-8")
    files = []
    for path in sorted((target / "site").rglob("*")):
        if path.is_file():
            key = path.relative_to(target / "site").as_posix()
            files.append({"path": key, "bytes": path.stat().st_size, "sha256": digest(path), **metadata(key)})
    (target / "manifest.json").write_text(json.dumps({"release": release, "files": files, "total_bytes": sum(f["bytes"] for f in files)}, indent=2), encoding="utf-8")
    for name in ["cloudformation.json", "deploy.py", "verify.py", "preview.py", "README.md"]:
        shutil.copy2(HERE / name, target / name)
    archive = target.with_suffix(".zip")
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=3) as bundle:
        for path in sorted(target.rglob("*")):
            if path.is_file(): bundle.write(path, path.relative_to(target.parent))
    print(json.dumps({"package": str(target), "zip": str(archive), "release": release, "bytes": sum(f["bytes"] for f in files), "files": len(files)}, indent=2))
    return target

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=PROJECT / "builds" / "web")
    parser.add_argument("--output", type=Path, default=PROJECT / "artifacts" / "aws")
    args = parser.parse_args()
    build(args.source.resolve(), args.output.resolve())
