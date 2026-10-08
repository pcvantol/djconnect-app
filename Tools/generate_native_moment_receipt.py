#!/usr/bin/env python3
"""Capture actual pinned producer Runtime/HTTP/subscription output, without Core writes."""
import argparse, io, json, os, subprocess, sys, tarfile, tempfile, runpy
from pathlib import Path
p=argparse.ArgumentParser(); p.add_argument('--core',type=Path,required=True); p.add_argument('--output',type=Path,required=True); a=p.parse_args()
pin='3d17994d28c71402a9076c0082c490820204ccda'
assert subprocess.check_output(['git','-C',str(a.core),'rev-parse',pin],text=True).strip()==pin
sys.dont_write_bytecode=True
with tempfile.TemporaryDirectory(prefix='djc-native-pin-',dir='/private/tmp') as root:
    archive=subprocess.check_output(['git','-C',str(a.core),'archive',pin],timeout=30)
    with tarfile.open(fileobj=io.BytesIO(archive)) as t: t.extractall(root,filter='data')
    os.environ['GIT_DIR']=str(a.core/'.git')
    module=runpy.run_path(str(Path(root)/'scripts/verification/capture_native_moment_delivery.py'))
    capture=module['capture'](); capture['producer_sha']=pin
    capture['after']['websocket_initial'].pop('recovery_cursor',None)
    capture['after']['reconnect'].pop('recovery_cursor',None)
    # Independent child avoids the baseline module replacement in Core's
    # before/after capture. Uses the exact native producer policy scenario.
    spotify_script = r"""
import asyncio,json,sys
from unittest.mock import patch
sys.dont_write_bytecode=True
sys.path.insert(0,sys.argv[1])
from tests.test_native_moment_delivery import NativeMomentDeliveryTest
from tests.test_session_facts import SessionFactsTest
NativeMomentDeliveryTest.setUpClass()
f=NativeMomentDeliveryTest(); f.run_sequence(f.runtime.DJPersona.HOME_DJ,count=1)
catalog=SessionFactsTest().catalog()
async def run():
 manager=f.runtime.SessionRuntimeManager()
 session=await manager.async_start(owner_profile_id='synthetic-spotify-owner')
 await manager.async_update_playback_projection(owner_profile_id='synthetic-spotify-owner',session_id=session.session_id,
  state='playing',media_identity=catalog['uri'],title=catalog['title'],artist=catalog['artist'],album=catalog['album_name'])
 fact=f.facts.catalog_facts(catalog)[0]
 moment=session.moment_engine.create_qualified_fact(session_id=session.session_id,
  intent=f.runtime.KnowledgeIntent(f.runtime.KnowledgeIntentType.ALBUM_STORY,'display current album'),
  fact=fact,selected_mood='neutral',persona=f.runtime.DJPersona.HOME_DJ,locale='en')
 session.publish_moment(moment)
 snapshot=session.broadcast.as_dict(); runtime=session.as_dict()
 events=[]
 await manager.async_subscribe(owner_profile_id='synthetic-spotify-owner',session_id=session.session_id,callback=events.append)
 with patch('time.monotonic',lambda:1901.0):
  await manager.async_advance_playback_progress(owner_profile_id='synthetic-spotify-owner',session_id=session.session_id)
  expired=session.broadcast.as_dict()
 expiry_events=list(events); events.clear()
 await manager.async_end(owner_profile_id='synthetic-spotify-owner',session_id=session.session_id)
 return {'runtime':runtime,'snapshot':snapshot,'expired':expired,'expiry_events':expiry_events,'end_events':events}
with patch('time.monotonic',lambda:100.0):
 result=asyncio.run(run())
NativeMomentDeliveryTest.tearDownClass()
print(json.dumps(result))
"""
    capture['spotify'] = json.loads(subprocess.check_output([sys.executable,'-c',spotify_script,root],cwd=root,text=True,timeout=30))
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(capture,ensure_ascii=False,indent=2)+'\n')
