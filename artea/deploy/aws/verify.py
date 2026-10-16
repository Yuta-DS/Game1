"""Verify the upload manifest locally, and optionally check every hosted asset."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
from urllib.request import Request, urlopen

HEADERS = {"Cross-Origin-Opener-Policy": "same-origin", "Cross-Origin-Embedder-Policy": "require-corp", "Cross-Origin-Resource-Policy": "same-origin"}

def validate(package):
    manifest = json.loads((package / "manifest.json").read_text(encoding="utf-8"))
    release = manifest["release"]
    if not re.fullmatch(r"[0-9a-f]{16}", release): raise ValueError("Invalid release ID")
    seen = set()
    for item in manifest["files"]:
        key = item["path"]
        relative = PurePosixPath(key)
        if relative.is_absolute() or ".." in relative.parts or "\\" in key or key in seen:
            raise ValueError(f"Unsafe or repeated upload key: {key}")
        if key != "index.html" and not key.startswith(f"releases/{release}/"):
            raise ValueError(f"Unexpected upload key: {key}")
        seen.add(key)
        path = package / "site" / key
        if path.is_symlink() or not path.is_file() or path.stat().st_size != item["bytes"]:
            raise ValueError(f"Missing or changed asset: {key}")
        with path.open("rb") as source:
            if hashlib.file_digest(source, "sha256").hexdigest() != item["sha256"]:
                raise ValueError(f"Checksum mismatch: {key}")
    required = {"index.html", f"releases/{release}/index.html", f"releases/{release}/heart.html"}
    if not required.issubset(seen): raise ValueError("Missing game entry page")
    actual = {p.relative_to(package / "site").as_posix() for p in (package / "site").rglob("*") if p.is_file()}
    if actual != seen: raise ValueError("Upload folder contains files not covered by the manifest")
    if sum(item["bytes"] for item in manifest["files"]) != manifest["total_bytes"]:
        raise ValueError("Total size mismatch")
    return manifest

def verify_host(base, manifest, release_only=False):
    def check(item):
        url = base.rstrip("/") + "/" + item["path"]
        with urlopen(Request(url, method="HEAD"), timeout=60) as response:
            if response.status != 200: raise ValueError(f"HTTP {response.status}: {url}")
            for name, expected in HEADERS.items():
                if response.headers.get(name) != expected: raise ValueError(f"Missing {name}: {url}")
            if response.headers.get_content_type() != item["content_type"].split(";")[0]:
                raise ValueError(f"Wrong content type: {url}")
            if not response.headers.get("Content-Encoding") and int(response.headers.get("Content-Length", -1)) != item["bytes"]:
                raise ValueError(f"Wrong content length: {url}")
            if item["path"] == "index.html" and "no-store" not in response.headers.get("Cache-Control", ""):
                raise ValueError("Landing page must not be cached")
    items = [f for f in manifest["files"] if not release_only or f["path"] != "index.html"]
    with ThreadPoolExecutor(max_workers=6) as pool:
        list(pool.map(check, items))
    print(f"PASS: {len(items)} hosted files, MIME types and isolation headers")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--url", help="CloudFront HTTPS URL or local preview URL")
    args = parser.parse_args()
    data = validate(args.package.resolve())
    print(f"PASS: {len(data['files'])} local files match SHA-256 manifest")
    if args.url: verify_host(args.url, data)
