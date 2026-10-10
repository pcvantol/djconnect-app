"""Local negative discovery test: ensure redirect never reaches another listener."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json
import sys
import threading

records = {"source_requests": 0, "target_requests": 0, "authorization_present": False, "identity_present": False, "query_present": False}
path = Path(sys.argv[1])
lock = threading.Lock()

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_): pass
    def do_GET(self):
        with lock:
            kind = "source_requests" if self.server is source else "target_requests"
            records[kind] += 1
            if self.server is source:
                records["authorization_present"] = "Authorization" in self.headers
                records["identity_present"] = "X-DJConnect-Device-ID" in self.headers
                records["query_present"] = "?" in self.path
            path.write_text(json.dumps(records))
        if self.server is source:
            self.send_response(302)
            self.send_header("Location", f"http://127.0.0.1:{target.server_port}/api/djconnect/v1/capabilities")
            self.end_headers()
        else:
            self.send_response(200); self.send_header("Content-Type", "application/json"); self.end_headers()
            self.wfile.write(b'{"session_broadcast":{}}')

source = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
target = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
threading.Thread(target=target.serve_forever, daemon=True).start()
print(json.dumps({"source_port": source.server_port, "target_port": target.server_port}), flush=True)
source.serve_forever()
