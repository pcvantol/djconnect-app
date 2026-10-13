"""Actual pinned HA/Core pairing and owner Broadcast for native Apple tests.

Only configured slots/music are synthetic. Clients pair through the genuine
HTTP handler; no device-token override or HA user credential is minted here.
Never run against installed HA. No spoken input/transcript or credentials logged.
"""
from __future__ import annotations
import ast
import asyncio
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys
from aiohttp import web

ROOT = Path(os.environ["DJC_SOURCE_ROOT"])
LAB = Path(os.environ["DJC_LAB_ROOT"])
CONTROL = "apple-paired-fixture-control"
BASELINE_PIN = "648496f3c218305323c752a632a086cfad97fb15f8f0c9d9126ae92fc319f58b"
PRESENCE_PIN = "2896a8172946c52760d3d00df29949dd0fcbb55cc0721451255a4fed1b0477db"
PIN = json.loads((ROOT / "consumer-source-pin.json").read_text())["content_archive_sha256"]
sys.dont_write_bytecode = True


def initializer():
    manifest = json.loads((ROOT / "consumer-source-pin.json").read_text())
    assert manifest["content_archive_sha256"] in {BASELINE_PIN, "8b0357411254eb62e12a6d89d35a72288a0642a597e595ac0ba6db5191d0de13", PRESENCE_PIN}
    if manifest["content_archive_sha256"] == PRESENCE_PIN:
        assert manifest["source_sha"] == "b5c25f7c8098ce805bf4cab94a887c8590f9717f"
    elif manifest["content_archive_sha256"] != BASELINE_PIN:
        assert manifest["source_sha"] == "491e2258920e730901875e3c8b258565a06e8463"
    for name, digest in manifest["integration_source_hashes"].items():
        assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest, name
    path = ROOT / "scripts/verification/verify_paired_live_auth.py"
    expected = manifest.get("verification_source_hashes") or json.loads((ROOT / "evidence/early-source-manifest.json").read_text())["files"]
    assert hashlib.sha256(path.read_bytes()).hexdigest() == expected[str(path.relative_to(ROOT))]
    spec = importlib.util.spec_from_file_location("pinned_paired_native", path)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    tree = ast.parse(path.read_text())
    function = next(n for n in tree.body if isinstance(n, ast.AsyncFunctionDef) and n.name == "main")
    prefix = function.body[:next(i for i, n in enumerate(function.body) if isinstance(n, ast.AsyncWith))]
    # Two configured slots persisted by the real HA ConfigEntryStore. Pairing is not replaced.
    mac = ast.parse('mac_slot = entry("mac-owner-entry", {"device_id":"djconnect-macos-ABCDEF123456", "client_type":"macos", "pair_code":"654321", "music_backend":"later_manual", "profile_id":"profile-a"})').body[0]
    for index, node in enumerate(prefix):
        if isinstance(node, ast.Expr) and isinstance(node.value, ast.Await):
            call = node.value.value
            if isinstance(call, ast.Call) and isinstance(call.func, ast.Attribute) and call.func.attr == "async_save":
                entries = call.args[0].values[0]
                assert isinstance(entries, ast.List)
                entries.elts.append(ast.Attribute(ast.Name("mac_slot", ast.Load()), "as_storage_fragment", ast.Load()))
                prefix.insert(index, mac); break
    else: raise AssertionError("Pinned store initialization changed")
    prefix.append(ast.Return(ast.Call(ast.Name("locals", ast.Load()), [], [])))
    function.name = "initialize_native"; function.body = prefix
    unit = ast.fix_missing_locations(ast.Module(body=[function], type_ignores=[]))
    exec(compile(unit, str(path), "exec"), module.__dict__)
    return module


async def main():
    LAB.mkdir(parents=True, exist_ok=True)
    core = initializer(); state = await core.initialize_native()
    hass, manager = state["hass"], state["manager"]
    slot = hass.config_entries.async_get_entry("mac-owner-entry")
    # Model the configured/loaded slots explicitly, as the pinned mood producer
    # qualification does. No auth/owner handler is substituted or relaxed.
    from homeassistant.config_entries import ConfigEntryState
    for configured in (state["slot"], slot):
        configured._async_set_state(hass, ConfigEntryState.LOADED, None)
    mac = core.DJConnectRuntime(slot)
    hass.data["djconnect"]["mac-owner-entry"] = mac
    await state["storage"].async_upsert_device("djconnect-macos-ABCDEF123456", "macos", linked_profile_id="profile-a")
    from custom_components.djconnect.ask_dj_history import AskDJHistoryManager
    from custom_components.djconnect.music_dna import MusicDNAManager
    history = AskDJHistoryManager(hass); memory = MusicDNAManager(hass); await memory.async_load()
    for runtime in (state["runtime"], mac):
        runtime.ask_dj_history = history; runtime.memory = memory
    hass.data["djconnect"]["ask_dj_history_manager"] = history
    hass.data["djconnect"]["memory_manager"] = memory
    records = []

    wire_receipts = []
    original_send_json = web.WebSocketResponse.send_json
    def save_wire_receipt(item):
        wire_receipts.append(item)
        (LAB / "sanitized-paired-wire.json").write_text(json.dumps({"content_pin":PIN,"receipts":wire_receipts}, indent=2))
    async def observed_send_json(socket, value, *args, **kwargs):
        await original_send_json(socket, value, *args, **kwargs)
        if not isinstance(value, dict): return
        kind = value.get("type")
        if kind == "auth_required":
            socket._apple_receipt_connection = sum(item.get("frame") == "auth_required" for item in wire_receipts) + 1
        connection = getattr(socket, "_apple_receipt_connection", None)
        if connection is None: return
        item = {"connection":connection, "frame":kind}
        if kind == "auth_ok": item["protocol_version"] = value.get("protocol_version")
        if kind == "auth_invalid": item["code"] = value.get("code")
        if kind == "result":
            result = value.get("result", {})
            item["success"] = value.get("success") is True
            item["snapshot_sent"] = isinstance(result, dict) and isinstance(result.get("snapshot"), dict)
        if kind == "event":
            item["event_type"] = value.get("event_type")
            if value.get("event_type") == "presence_changed":
                session = value.get("payload", {}).get("session", {})
                item["selected_presence"] = session.get("selected_presence")
                item["presence_revision"] = session.get("presence_revision")
        save_wire_receipt(item)
    # Observe actual aiohttp sends without replacing producer handlers, auth,
    # Session state, payloads, or authorization. Never log private payload data.
    web.WebSocketResponse.send_json = observed_send_json

    history_fault = {"once": False}

    @web.middleware
    async def record(request, handler):
        if request.path == "/api/djconnect/v1/session/history" and history_fault["once"]:
            history_fault["once"] = False
            await asyncio.sleep(3.0)
            response = web.json_response({"success":False,"error":"test_transient_unavailable"}, status=503)
        else:
            response = await handler(request)
        # Never record bodies/headers/auth frames/tokens/text/Session IDs/cursors.
        receipt = {"method": request.method, "route": request.path.split("/")[-1], "status": response.status}
        if request.path == "/api/djconnect/v1/session/presence":
            # Narrow public policy fields only; no bearer, owner, text or Session ID.
            try:
                result = json.loads(response.body)
                for key in ("selected_presence", "presence_revision", "changed", "error"):
                    if key in result: receipt[key] = result[key]
            except (ValueError, AttributeError, TypeError): pass
        records.append(receipt)
        (LAB / "sanitized-native-transport.json").write_text(json.dumps({"content_pin": PIN, "requests": records}, indent=2))
        return response
    hass.http.app.middlewares.append(record)

    async def active_state():
        active = await manager.async_get_active("profile-a")
        if active is None: return None
        value = active.as_dict()
        return {"session_id": value["session_id"], "state": value["runtime_state"], "selected_mood":value["selected_mood"], "mood_revision":value.get("mood_revision"), "selected_presence":value.get("selected_presence"), "presence_revision":value.get("presence_revision"), "now_playing": value["broadcast"]["playback"]}

    async def seed():
        active = await manager.async_get_active("profile-a")
        if active: await manager.async_end(owner_profile_id="profile-a", session_id=active.session_id)
        active = await manager.async_start(owner_profile_id="profile-a", selected_mood="energy", locale="nl",
            history_source_context={"backend_id":"later_manual", "provider_entry_id":"owner-entry"})
        for index in range(26):
            await manager.async_update_playback_projection(owner_profile_id="profile-a", session_id=active.session_id,
                state="playing", media_identity=f"synthetic:paired:{index}", title="One" if index == 0 else f"Native fixture {index}",
                artist="Synthetic artist", duration_ms=120000, position_ms=1000)
        async def insight(): return {}
        await manager.async_process_track_started(owner_profile_id="profile-a", session_id=active.session_id, insight_provider=insight)

    async def control(request):
        if request.headers.get("Authorization") != "Bearer " + CONTROL: raise web.HTTPUnauthorized()
        operation = request.match_info["operation"]
        save_wire_receipt({"control":operation})
        if operation == "history_fail_once": history_fault["once"] = True
        elif operation == "start": await seed()
        elif operation in {"update", "resume_update"}:
            active = await manager.async_get_active("profile-a"); assert active is not None
            await manager.async_update_playback_projection(owner_profile_id="profile-a", session_id=active.session_id,
                state="playing", media_identity="synthetic:paired:" + operation, title="Paired resume update" if operation == "resume_update" else "Paired native update", artist="Synthetic artist", duration_ms=120000, position_ms=2000)
        elif operation == "end":
            active = await manager.async_get_active("profile-a")
            if active: await manager.async_end(owner_profile_id="profile-a", session_id=active.session_id)
        elif operation == "select_mac_pairing":
            hass.data["djconnect"]["runtime"] = mac
        elif operation == "select_ios_pairing":
            hass.data["djconnect"]["runtime"] = state["runtime"]
        elif operation in {"switch_profile", "restore_profile"}:
            await state["storage"].async_upsert_device("djconnect-ios-ABCDEF123456", "ios",
                linked_profile_id="profile-other" if operation == "switch_profile" else "profile-a")
        elif operation != "state": raise web.HTTPNotFound()
        users = await hass.auth.async_get_users()
        return web.json_response({"active": await active_state(), "ha_users":len(users),
            "ha_refresh_tokens":sum(len(user.refresh_tokens) for user in users),
            "initial_ha_refresh_tokens":state["initial_credentials"], "initial_ha_users":len(state["initial_users"])}, headers={"Cache-Control":"no-store"})

    hass.http.app.router.add_route("*", "/__apple_paired_fixture/{operation}", control)
    await seed()
    runner = web.AppRunner(hass.http.app); await runner.setup()
    port = int(os.environ.get("DJC_NATIVE_PORT", "18191"))
    assert port in {18191, 18213}
    await web.TCPSite(runner, "0.0.0.0", port).start()
    print(json.dumps({"ready":True,"content_pin":PIN,"pairing":"genuine HTTP/HA ConfigEntryStore","ha_user_credentials_issued":False}), flush=True)
    try: await asyncio.Event().wait()
    finally: await runner.cleanup(); await state["service"].async_close()

if __name__ == "__main__": asyncio.run(main())
