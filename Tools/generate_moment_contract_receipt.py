#!/usr/bin/env python3
"""Build synthetic, nonpersonal receipts through the pinned Core Runtime chain.

No Core files or HA installation are changed. Uses Core's existing test loader
for dependency isolation, and the real Runtime/Planner/Knowledge/Moment engines.
"""
import argparse
import asyncio
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import tarfile
import io

parser = argparse.ArgumentParser()
parser.add_argument('--core', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
pin = 'ee05c9422cd7a7a08bbe769925248632fa651961'
resolved = subprocess.check_output(['git', '-C', str(args.core), 'rev-parse', pin + '^{commit}'], text=True, timeout=15).strip()
if resolved != pin:
    raise SystemExit('Pinned producer commit is unavailable')
sys.dont_write_bytecode = True
# Import an immutable archive, never a peer writer's current working files.
producer_snapshot = tempfile.TemporaryDirectory(prefix='djc-apple-producer-', dir='/private/tmp')
archive = subprocess.check_output(['git', '-C', str(args.core), 'archive', pin], timeout=30)
with tarfile.open(fileobj=io.BytesIO(archive)) as files:
    files.extractall(producer_snapshot.name, filter='data')
sys.path.insert(0, producer_snapshot.name)
from tests.test_vibecast_multimoment import VibeCastMultiMomentTest
VibeCastMultiMomentTest.setUpClass()
fixture = VibeCastMultiMomentTest()

async def generate():
    manager, runtime, first, media, clock = await fixture._ready()
    snapshot = runtime.broadcast.as_dict()
    raw = runtime.as_dict()
    initial = {key: raw[key] for key in ('session_id','room','selected_mood','music_backend','runtime_state','started_at','planner','broadcast')}
    events = []
    await manager.async_subscribe(owner_profile_id=runtime.owner_profile_id, session_id=runtime.session_id, callback=events.append)
    await fixture._observe(manager, runtime, media, clock, seconds=30, position_ms=30_000)
    second = await fixture._later(manager, runtime, media)
    assert second and first.moment_id != second.moment_id
    second_snapshot = runtime.broadcast.as_dict()
    second_events = list(events)
    track_offset = len(events)
    next_media = "spotify:track:CCCCCCCC"
    await manager.async_update_playback_projection(owner_profile_id=runtime.owner_profile_id, session_id=runtime.session_id,
        state="playing", media_identity=next_media, title="Next", artist="Another Artist", album="Next Album", duration_ms=240_000, position_ms=0)
    async def next_insight():
        return {"track":{"title":"Next","artist":"Another Artist","album":"Next Album","backend":"spotify_direct","genres":["rock"]},
                "analysis":{"summary":"A new rhythm opens the next song.","full_text":"The guitar leaves room for the next melody.","genre":"rock"}}
    await manager.async_process_track_started(owner_profile_id=runtime.owner_profile_id, session_id=runtime.session_id,
        insight_provider=next_insight, media_identity=next_media, require_current_playback=True)
    track_change_events = events[track_offset:]
    track_change_snapshot = runtime.broadcast.as_dict()
    assert track_change_snapshot["playback"]["title"] == "Next"
    end_offset = len(events)
    await manager.async_end(owner_profile_id=runtime.owner_profile_id, session_id=runtime.session_id)
    end_events = events[end_offset:]
    assert {event["event_type"] for event in end_events} >= {"runtime_ended", "broadcast_stopped"}
    return dict(producer_sha=pin, classification='PRODUCER_GENERATED_SYNTHETIC_RECEIPT',
                runtime=initial, snapshot=snapshot, events=second_events, updated_snapshot=second_snapshot, track_change_events=track_change_events, track_change_snapshot=track_change_snapshot, end_events=end_events)

args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(asyncio.run(generate()), ensure_ascii=False, indent=2)+'\n')
