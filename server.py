#!/usr/bin/env python3
"""Weather dashboard web server.

Serves index.html to every browser on the network and relays Buienradar's data
(which browsers may not read directly from another site). Python standard library only.

    python3 server.py [port]      (default port 80)
"""
import http.server
import sys
import threading
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 80

LAT, LON = "51.92", "4.48"  # Rotterdam (keep in sync with LAT/LON in index.html)
PROXY = {
    "/api/raintext": (f"https://gpsgadget.buienradar.nl/data/raintext?lat={LAT}&lon={LON}", "text/plain; charset=utf-8", 120),
    "/api/feed": ("https://data.buienradar.nl/2.0/feed/json", "application/json; charset=utf-8", 300),
}
_cache = {}
_lock = threading.Lock()


def fetch(path):
    url, ctype, ttl = PROXY[path]
    with _lock:
        hit = _cache.get(path)
        if hit and time.time() - hit[0] < ttl:
            return hit[1], ctype
    req = urllib.request.Request(url, headers={"User-Agent": "weather-dash (home dashboard)"})
    with urllib.request.urlopen(req, timeout=10) as r:
        body = r.read()
    with _lock:
        _cache[path] = (time.time(), body)
    return body, ctype


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.split("?", 1)[0]
        try:
            if path in PROXY:
                body, ctype = fetch(path)
                self.reply(200, body, ctype, "no-store")
            elif path in ("/", "/index.html"):
                self.reply(200, (ROOT / "index.html").read_bytes(), "text/html; charset=utf-8", "no-cache")
            elif path == "/favicon.ico":
                self.reply(204, b"", "text/plain", "max-age=86400")
            else:
                self.reply(404, b"Not found", "text/plain")
        except Exception as e:  # upstream down etc.
            self.reply(502, f"Upstream error: {e}".encode(), "text/plain", "no-store")

    def reply(self, code, body, ctype, cache="no-cache"):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", cache)
        self.end_headers()
        if body:
            self.wfile.write(body)

    def log_message(self, fmt, *args):  # keep the journal quiet
        pass


if __name__ == "__main__":
    srv = http.server.ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"Weather dashboard on http://0.0.0.0:{PORT}", flush=True)
    srv.serve_forever()
