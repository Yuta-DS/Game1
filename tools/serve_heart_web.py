"""Serve the existing local Web export, with a direct Island 1 preview route."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse

BUILD = Path(__file__).resolve().parents[1] / "artea" / "builds" / "web"


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(BUILD), **kwargs)

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        super().end_headers()

    def do_GET(self):
        if self.path.split("?", 1)[0] == "/heart.html":
            html = (BUILD / "index.html").read_text(encoding="utf-8")
            marker = 'const GODOT_CONFIG ='
            if marker not in html:
                self.send_error(500, "Export configuration has changed; refresh the preview adapter.")
                return
            html = html.replace(marker, 'window.ARTEA_HEART_PREVIEW = true;\n\t\t' + marker, 1)
            # User arguments are supported by release templates. Scene-path
            # startup arguments are not; transition through the normal menu.
            html = html.replace('const engine = new Engine(GODOT_CONFIG);',
                                'GODOT_CONFIG.args = (GODOT_CONFIG.args || []).concat(["--", "--heart-preview"]);\n'
                                'const engine = new Engine(GODOT_CONFIG);', 1)
            payload = html.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(payload)
            return
        super().do_GET()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8766)
    args = parser.parse_args()
    if not (BUILD / "index.html").is_file():
        parser.error("Export the Web build first.")
    print(f"Heart Melody: http://127.0.0.1:{args.port}/heart.html", flush=True)
    ThreadingHTTPServer(("127.0.0.1", args.port), Handler).serve_forever()
