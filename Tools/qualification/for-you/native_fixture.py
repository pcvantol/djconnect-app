"""Loopback-only native rendering fixture. No provider, authority or device acceptance.

Pinned Core 2bcc3615 for_you example; catalogue/model data are synthetic.
Run this explicitly, then set DJCONNECT_FOR_YOU_UI_FIXTURE=1 for the UI test.
"""
import copy
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import time
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[3]
WIRE = json.loads((ROOT / "Tests/Fixtures/session-for-you-v1.json").read_text())
STATE = {"started": time.monotonic(), "posts": [], "dismissed": False, "gets": []}

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def reply(self, body, status=200):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = urlsplit(self.path).path
        if path == "/fixture/reset":
            STATE.update(started=time.monotonic(), posts=[], dismissed=False, gets=[])
            return self.reply({"success": True})
        if path == "/fixture/metrics":
            return self.reply({"posts": STATE["posts"], "gets": STATE["gets"]})
        if self.headers.get("Authorization") != "Bearer synthetic-fixture-token":
            return self.reply({"success": False}, 401)
        STATE["gets"].append(path)
        if path.endswith("/capabilities"):
            return self.reply({"capabilities": {"session_conversation_history": True, "session_start_actions": True, "session_first_play_surprise_mix": True},
                "contract_versions": {"session_conversation_history": 1, "session_start_actions": 2, "session_first_play_surprise_mix": 3}})
        if path.endswith("/session/active"):
            wire = copy.deepcopy(WIRE)
            offer = wire["for_you"]
            offer["expires_in"] = max(0, 60 - (time.monotonic() - STATE["started"]))
            offer["result_set"]["expires_in"] = offer["expires_in"]
            offer["actions_available"] = offer["expires_in"] > 0 and not STATE["dismissed"]
            if STATE["dismissed"]:
                offer.update(visible=False, state="dismissed", options=[])
                offer.pop("result_set", None)
            return self.reply({"success": True, **wire})
        if "/session/history" in path:
            session_id = WIRE["session"]["session_id"]
            if path.endswith("/session/history"):
                return self.reply({"success": True, "schema_version": 1, "sessions": [], "revision": "1", "retention_days": 90})
            return self.reply({"success": True, "schema_version": 1, "session": {
                "session_id": session_id, "lifecycle_status": "ACTIVE", "created_at": WIRE["session"]["created_at"],
                "started_at": WIRE["session"]["started_at"], "ended_at": "", "interrupted_at": "",
                "revision": "1", "read_only": False, "history_coverage": "full"},
                "revision": "1", "entries": [], "window": "tail", "window_limit": 20, "scan_complete": True})

        return self.reply({"success": True, "owner_profile_id": "profile-a", "messages": [], "history_revision": 0, "clear_revision": 0})

    def do_POST(self):
        path = urlsplit(self.path).path
        data = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        if self.headers.get("Authorization") != "Bearer synthetic-fixture-token":
            return self.reply({"success": False}, 401)
        STATE["posts"].append(path)
        body = json.loads(data or b"{}")
        if path.endswith("/ask_dj/message") and body.get("choice_action", {}).get("operation") == "dismiss":
            STATE["dismissed"] = True
            return self.reply({"success": True, "for_you": {"schema_version": 1, "state": "dismissed", "visible": False}})
        return self.reply({"success": False, "error": "fixture_has_no_effect_adapter"}, 409)

if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", 18179), Handler).serve_forever()
