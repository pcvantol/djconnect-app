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
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(capture,ensure_ascii=False,indent=2)+'\n')
