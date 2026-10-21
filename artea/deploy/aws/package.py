"""Build a clean, checksummed AWS delivery from the maintained Godot Web export."""
import argparse
import gzip
import io
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
    """Include every current area pack and hashed part, never stale exports."""
    if (source / ".export-in-progress").exists():
        raise ValueError("Web export is incomplete or still running; complete the maintained export before packaging")
    html = (source / "index.html").read_text(encoding="utf-8")
    config = read_config(html)
    names = {"index.html", "index.js", "index.wasm", "pck-loader.js",
             "index.audio.worklet.js", "index.audio.position.worklet.js"}
    if any(not isinstance(name, str) or not name.endswith(".wasm") for name in config.get("gdextensionLibs", [])):
        raise ValueError("Unsafe Web extension name")
    names.update(config.get("gdextensionLibs", []))
    names.update(re.findall(r'(?:src|href)="(index\.[A-Za-z0-9_.-]+)"', html))
    if (source / "index.png").exists(): names.add("index.png")
    if config.get("serviceWorker"): names.add(config["serviceWorker"])

    def safe(name):
        path = Path(name)
        if not isinstance(name, str) or "\\" in name or path.is_absolute() or ".." in path.parts:
            raise ValueError(f"Unsafe runtime asset: {name}")
        target = source / name
        if target.is_symlink() or not target.is_file() or source.resolve() not in target.resolve().parents:
            raise ValueError(f"Missing or unsafe runtime asset: {name}")
        return target

    def split_or_whole(name, required=False):
        path = source / (name + ".parts.json")
        if not path.exists():
            if required: raise ValueError(f"Missing pack manifest: {name}")
            safe(name)
            names.add(name)
            return
        manifest = json.loads(path.read_text(encoding="utf-8"))
        count, size, part_size = (manifest[k] for k in ("count", "bytes", "partBytes"))
        if not all(type(n) is int and n > 0 for n in (count, size, part_size)) or count != (size + part_size - 1) // part_size:
            raise ValueError("Invalid pack manifest")
        if name == "index.pck" and config["fileSizes"][name] != size:
            raise ValueError("HTML and pack manifest are from different exports")
        parts = manifest.get("parts")
        if parts is not None and (not isinstance(parts, list) or len(parts) != count):
            raise ValueError("Invalid part list")
        names.add(name + ".parts.json")
        checksum = hashlib.sha256()
        for i in range(count):
            part = parts[i]["name"] if parts is not None else f"{name}.part{i:02d}"
            expected = min(part_size, size - i * part_size)
            safe(part)
            if parts is not None and not re.fullmatch(r"parts/" + re.escape(name) + r"\.[0-9a-f]{16}\.part" + f"{i:02d}", part):
                raise ValueError(f"Unsafe hashed part name: {part}")
            if safe(part).stat().st_size != expected or (parts is not None and parts[i].get("size") != expected):
                raise ValueError(f"Missing or truncated pack part: {part}")
            checksum.update(safe(part).read_bytes())
            names.add(part)
        if manifest.get("hash") and checksum.hexdigest()[:16] != manifest["hash"]:
            raise ValueError(f"Part checksum disagrees with manifest: {name}")

    split_or_whole("index.pck", required=True)
    split_or_whole("index.side.wasm")
    if (source / "web-packs.json").exists():
        names.add("web-packs.json")
        packs = json.loads((source / "web-packs.json").read_text(encoding="utf-8"))
        for pack in packs.values():
            if not re.fullmatch(r"[a-z_0-9]+\.pck", pack["file"]):
                raise ValueError("Unsafe area pack name")
            split_or_whole(pack["file"], required=True)
        for pack in packs.values():
            if any(dependency not in packs for dependency in pack.get("requires", [])):
                raise ValueError("Missing shared pack")
    elif any(source.glob("*.pck.parts.json")) and len(list(source.glob("*.pck.parts.json"))) > 1:
        raise ValueError("Area pack export needs web-packs.json; re-export with the maintained script")
    for name in names: safe(name)
    if safe("index.wasm").stat().st_size != config["fileSizes"]["index.wasm"]:
        raise ValueError("WebAssembly size disagrees with HTML")
    return sorted(names)

def metadata(path):
    suffix = Path(path).suffix
    mime = {".html": "text/html; charset=utf-8", ".js": "application/javascript", ".json": "application/json", ".wasm": "application/wasm", ".png": "image/png"}.get(suffix, "application/octet-stream")
    return {"content_type": mime, "cache_control": "no-store, max-age=0" if path == "index.html" else "public, max-age=31536000, immutable"}

def build(source, output):
    output.mkdir(parents=True, exist_ok=True)
    (output / ".gdignore").touch()
    names = required_files(source)
    hashes = {name: digest(source / name) for name in names}
    identity = {"assets": hashes, "packager": digest(Path(__file__)), "landing": digest(HERE / "landing.html")}
    release = hashlib.sha256(json.dumps(identity, sort_keys=True).encode()).hexdigest()[:16]
    target = output / ("artea-aws-" + release)
    if target.exists():
        raise ValueError(f"Package already exists: {target}. Use a different --output folder to rebuild.")
    runtime = target / "site" / "releases" / release
    runtime.mkdir(parents=True)
    for name in names:
        (runtime / name).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source / name, runtime / name)
    html = (runtime / "index.html").read_text(encoding="utf-8")
    html = html.replace("const GODOT_CONFIG =", 'window.ARTEA_AUTH_MODE = "cognito"; window.ARTEA_API_BASE = location.origin + "/api";\nconst GODOT_CONFIG =', 1)
    (runtime / "index.html").write_text(html, encoding="utf-8")
    encodings = {}
    for name in names:
        path = runtime / name
        if re.search(r"\.part[0-9]+$", name) or path.suffix in {".js", ".wasm"}:
            original = path.read_bytes()
            buffer = io.BytesIO()
            with gzip.GzipFile(fileobj=buffer, mode="wb", filename="", mtime=0, compresslevel=6) as compressed:
                compressed.write(original)
            if buffer.tell() < len(original) * .95:
                path.write_bytes(buffer.getvalue())
                encodings[name] = "gzip"
    total_mb = sum((runtime / name).stat().st_size for name in names) / 1_000_000
    def area_part(name):
        return ".pck" in name and not name.startswith("index.pck") and not name.startswith("parts/index.pck.")
    initial_mb = sum((runtime / name).stat().st_size for name in names if not area_part(name)) / 1_000_000
    landing = (HERE / "landing.html").read_text(encoding="utf-8").replace("{{RELEASE}}", release).replace("{{DOWNLOAD_MB}}", str(round(total_mb))).replace("{{INITIAL_MB}}", str(round(initial_mb)))
    (target / "site" / "index.html").write_text(landing, encoding="utf-8")
    files = []
    for path in sorted((target / "site").rglob("*")):
        if path.is_file():
            key = path.relative_to(target / "site").as_posix()
            item = {"path": key, "bytes": path.stat().st_size, "sha256": digest(path), **metadata(key)}
            relative = path.relative_to(runtime).as_posix() if runtime in path.parents else ""
            if relative in encodings: item["content_encoding"] = encodings[relative]
            files.append(item)
    (target / "manifest.json").write_text(json.dumps({"release": release, "files": files, "initial_download_bytes": round(initial_mb * 1_000_000), "total_bytes": sum(f["bytes"] for f in files)}, indent=2), encoding="utf-8")
    for name in ["cloudformation.json", "backend-cloudformation.json", "waf-cloudformation.json", "registry-cloudformation.json", "deploy_backend.py", "deploy.py", "verify.py", "preview.py", "README.md"]:
        shutil.copy2(HERE / name, target / name)
    (target / "server").mkdir()
    for name in ["Dockerfile", ".dockerignore", "requirements.txt", "requirements-aws.txt", "server.py", "aws_app.py", "manage_aws.py"]:
        shutil.copy2(PROJECT.parent / "server" / name, target / "server" / name)
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
