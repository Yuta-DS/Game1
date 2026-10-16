"""Serve the packaged site locally with the same browser headers as CloudFront."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from verify import HEADERS, validate

class Handler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm", ".js": "application/javascript", ".json": "application/json"}
    def end_headers(self):
        for name, value in HEADERS.items(): self.send_header(name, value)
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--port", type=int, default=8877)
    args = parser.parse_args()
    package = args.package.resolve()
    validate(package)
    print(f"Local playtest: http://127.0.0.1:{args.port}/", flush=True)
    ThreadingHTTPServer(("127.0.0.1", args.port), partial(Handler, directory=str(package / "site"))).serve_forever()
