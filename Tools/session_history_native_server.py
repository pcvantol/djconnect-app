"""Apple native lab using the exact Core HTTP/Store/SQLite producer, never static history.

Run only with the pinned immutable Core snapshot and existing HA SDK image, isolated
from HA-dev. Native apps use synthetic paired identities on loopback. This fixture
supplies source/account metadata, not provider evidence. No injected STT transcript.
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

sys.dont_write_bytecode = True
ROOT = Path(os.environ["DJC_SOURCE_ROOT"])
LAB = Path(os.environ["DJC_LAB_ROOT"])
TOKEN = "synthetic-fixture-token"
PIN = "19b815612319291cc7e4ab1fca4718667f173970"


def load_pinned_bootstrap():
    receipt = json.loads((ROOT / "examples/client_contracts/session_conversation_history/http-producer-receipt.json").read_text())
    for relative, expected in receipt["source_files_sha256"].items():
        assert hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() == expected, relative
    path = ROOT / "scripts/verification/verify_session_conversation_history_http.py"
    spec = importlib.util.spec_from_file_location("pinned_core_http_lab", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    # Reuse precisely the producer's real HA/Store/SQLite/HTTP initialization.
    # Stop before its synthetic text/STT assertions; native clients make their own turns.
    tree = ast.parse(path.read_text())
    function = next(n for n in tree.body if isinstance(n, ast.AsyncFunctionDef) and n.name == "main")
    prefix = function.body[:next(i for i, n in enumerate(function.body) if isinstance(n, ast.AsyncWith))]
    for node in prefix:
        if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "token" for t in node.targets):
            node.value = ast.Constant(TOKEN)  # Synthetic pairing input only.
    prefix.append(ast.Return(ast.Call(ast.Name("locals", ast.Load()), [], [])))
    function.name = "initialize_native_lab"
    function.body = prefix
    unit = ast.fix_missing_locations(ast.Module(body=[function], type_ignores=[]))
    exec(compile(unit, str(path), "exec"), module.__dict__)
    return module


async def main():
    LAB.mkdir(parents=True, exist_ok=True)
    core = load_pinned_bootstrap()
    state = await core.initialize_native_lab()
    hass, manager, storage = state["hass"], state["manager"], state["storage"]
    mac_id = "djconnect-macos-ABCDEF123456"
    mac_entry = core.entry("mac-owner-entry", {"device_id": mac_id, "client_type": "macos", "music_backend": "later_manual", "profile_id": "profile-a"})
    mac = core.DJConnectRuntime(mac_entry, device_token=TOKEN)
    mac.device_status.update(device_id=mac_id, client_type="macos")
    mac.ask_dj_history = state["history"]
    hass.data["djconnect"]["mac-owner-entry"] = mac
    await storage.async_upsert_device(mac_id, "macos", display_name="Synthetic Mac", linked_profile_id="profile-a")
    from homeassistant.components import websocket_api
    await websocket_api.async_setup(hass, {})
    from custom_components.djconnect.websocket_api import async_register
    async_register(hass)
    stt_qualification = "not configured; no mocked transcript"
    if os.environ.get("DJC_WYOMING_HOST"):
        # Opt-in to the existing local provider through actual HA SDK entities.
        # No transcript hook, raw audio archive, new provider or live HA setup.
        assert os.environ["DJC_WYOMING_HOST"] == "host.docker.internal"
        assert os.environ.get("DJC_WYOMING_PORT", "10300") == "10300"
        from types import MappingProxyType
        from homeassistant.components import stt
        from homeassistant.components.wyoming.data import WyomingService
        from homeassistant.components.wyoming.stt import WyomingSttProvider
        from homeassistant.config_entries import ConfigEntry
        from wyoming.client import AsyncTcpClient
        from wyoming.info import Describe, Info
        async with AsyncTcpClient("host.docker.internal", 10300) as client:
            await client.write_event(Describe().event())
            event = await asyncio.wait_for(client.read_event(), 5)
            assert event is not None and Info.is_type(event.type)
            info = Info.from_event(event)
        hass.data.setdefault(stt.DATA_PROVIDERS, {})
        await stt.async_setup(hass, {})
        config_entry = ConfigEntry(data={"host": "host.docker.internal", "port": 10300},
            discovery_keys=MappingProxyType({}), domain="wyoming", minor_version=1,
            options={}, source="user", subentries_data=[], title="Existing local STT — isolated Apple lab", unique_id="apple-native-lab-stt", version=1)
        provider = WyomingSttProvider(config_entry, WyomingService("host.docker.internal", 10300, info))
        await hass.data[stt.DATA_COMPONENT].async_add_entities([provider])
        assert provider.entity_id in hass.states.async_entity_ids("stt")
        assert not callable(hass.data["djconnect"].get("stt_handler"))
        stt_qualification = "actual HA Wyoming STT entity ready; real native microphone acceptance still required"
    user = await hass.auth.async_create_user("Apple native isolated lab", group_ids=["system-users"])
    refresh = await hass.auth.async_create_refresh_token(user, client_id="https://apple-native-fixture.invalid", client_name="Temporary Apple native proof")
    websocket_token = hass.auth.async_create_access_token(refresh)
    entries = [state["client_entry"], state["source_entry"], mac_entry]
    hass.config_entries.async_entries = lambda domain: entries
    requests = []

    async def active_state():
        active = await manager.async_get_active("profile-a")
        if active is None:
            return None
        value = active.as_dict()
        return {"session_id": value["session_id"], "state": value["runtime_state"], "now_playing": value["broadcast"]["playback"]}

    @web.middleware
    async def record(request, handler):
        before = await active_state()
        response = await handler(request)
        after = await active_state()
        item = {"method": request.method, "path": request.path, "query": dict(request.query), "status": response.status,
                "before": before, "after": after, "navigation_mutated_runtime": before != after}
        if request.content_type == "audio/wav":
            # No raw audio saved or transcript injected in this lab.
            item["voice_qualification"] = "real native WAV submitted; STT outcome must be independently proven"
        if isinstance(response, web.Response) and response.content_type == "application/json":
            item["response"] = json.loads(response.text)
            if request.path.startswith("/__apple_fixture/"):
                item["response"].pop("websocket_access_token", None)
        requests.append(item)
        (LAB / "native-http-requests.json").write_text(json.dumps({"producer_sha": PIN, "qualification": "real HA/Core HTTP/Store/SQLite; synthetic source metadata; native acceptance separate", "requests": requests}, ensure_ascii=False, indent=2))
        return response

    hass.http.app.middlewares.append(record)

    async def seed():
        old = await manager.async_get_active("profile-a")
        if old is not None:
            await manager.async_end(owner_profile_id="profile-a", session_id=old.session_id)
        session = await manager.async_start(owner_profile_id="profile-a", selected_mood="energy", locale="nl",
            history_source_context={"backend_id":"source-spotify", "music_account_id":"source-account", "provider_entry_id":"source-entry"})
        # More than one client page, all accepted through the real Runtime/storage.
        for index in range(26):
            await manager.async_update_playback_projection(owner_profile_id="profile-a", session_id=session.session_id, state="playing",
                media_identity=f"spotify:track:{index:022d}", title="One" if index == 0 else "Nothing Else Matters",
                artist="Metallica", album="…And Justice for All" if index == 0 else "Metallica", duration_ms=120000, position_ms=index * 1000)
        async def insight():
            return {}
        await manager.async_process_track_started(owner_profile_id="profile-a", session_id=session.session_id, insight_provider=insight)
        return session

    async def control(request):
        if request.headers.get("Authorization") != "Bearer " + TOKEN:
            raise web.HTTPUnauthorized()
        operation = request.match_info["operation"]
        if operation == "start":
            await seed()
        elif operation == "end":
            active = await manager.async_get_active("profile-a")
            if active:
                await manager.async_end(owner_profile_id="profile-a", session_id=active.session_id)
        elif operation == "restart":
            await state["service"].async_close()
            await state["service"].async_initialize()
            hass.data["djconnect"].pop("session_history_query", None)
            history = core.AskDJHistoryManager(hass)
            for runtime in [state["runtime"], mac]:
                runtime.ask_dj_history = history
            hass.data["djconnect"]["ask_dj_history_manager"] = history
        elif operation != "state":
            raise web.HTTPNotFound()
        return web.json_response({"active": await active_state(), "websocket_access_token": hass.auth.async_create_access_token(refresh) if operation == "state" else None}, headers={"Cache-Control":"no-store"})

    hass.http.app.router.add_route("*", "/__apple_fixture/{operation}", control)
    await seed()
    runner = web.AppRunner(hass.http.app)
    await runner.setup()
    await web.TCPSite(runner, "0.0.0.0", 18191).start()
    print(json.dumps({"ready": True, "port": 18191, "producer_sha": PIN, "native_stt": stt_qualification}), flush=True)
    try:
        await asyncio.Event().wait()
    finally:
        await runner.cleanup()
        await core.async_shutdown_persistence(hass)

if __name__ == "__main__":
    asyncio.run(main())
