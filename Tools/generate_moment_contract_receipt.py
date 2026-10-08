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
    return dict(producer_sha=pin, classification='PRODUCER_GENERATED_SYNTHETIC_RECEIPT',
                runtime=initial, snapshot=snapshot, events=events, updated_snapshot=second_snapshot)

args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(asyncio.run(generate()), ensure_ascii=False, indent=2)+'\n')
