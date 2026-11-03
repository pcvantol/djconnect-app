#!/usr/bin/env python3
"""Capture only explicitly named disposable Watch V2 simulators.

Screenshots show native layout with modeled input, not live contract acceptance.
The script never installs on physical hardware or touches existing simulators.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--app', required=True, type=Path)
parser.add_argument('--device', required=True)
parser.add_argument('--output', required=True, type=Path)
args = parser.parse_args()

def run(*command):
    return subprocess.run(command, check=True, capture_output=True, text=True).stdout

inventory = json.loads(run('xcrun', 'simctl', 'list', 'devices', '--json'))
device = next((d for devices in inventory['devices'].values() for d in devices if d['udid'] == args.device), None)
if not device or not device['name'].startswith('DJC-Watch-V2-'):
    raise SystemExit('Only a task-owned Watch V2 simulator is permitted')
args.output.mkdir(parents=True, exist_ok=False)
run('xcrun', 'simctl', 'install', args.device, str(args.app.resolve()))
rows = []

def capture(locale, mood, suffix):
    language = locale[:2]
    command = ['xcrun', 'simctl', 'launch', '--terminate-running-process', args.device, 'dev.djconnect.ios.watch',
               '--screenshot-screen=home', '--qualification-mood=' + mood,
               '-AppleLanguages', '(' + language + ')', '-AppleLocale', locale]
    if mood == 'idle': command.append('--qualification-idle')
    run(*command)
    time.sleep(2)
    path = args.output / (mood + '-' + language + '-' + suffix + '.png')
    run('xcrun', 'simctl', 'io', args.device, 'screenshot', str(path.resolve()))
    rows.append({'locale': locale, 'modeled_mood': mood, 'size': suffix, 'file': path.name,
                 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    print(path.name, flush=True)

try:
    run('xcrun', 'simctl', 'ui', args.device, 'content_size', 'large')
    content_size_supported = True
except subprocess.CalledProcessError as error:
    content_size_supported = False
    print('Watch runtime content_size control unavailable: ' + str(error.returncode), flush=True)
try:
    for locale in ['nl_NL', 'en_GB', 'de_DE', 'fr_FR', 'es_ES']:
        for mood in ['chill', 'groove', 'energy', 'party', 'idle']:
            capture(locale, mood, 'large' if content_size_supported else 'default')
    if content_size_supported:
        run('xcrun', 'simctl', 'ui', args.device, 'content_size', 'accessibility-extra-extra-extra-large')
        for mood in ['groove', 'idle']: capture('de_DE', mood, 'accessibility-xxxl')
finally:
    if content_size_supported: run('xcrun', 'simctl', 'ui', args.device, 'content_size', 'large')
receipt = {'classification': 'MODELED_NATIVE_LAYOUT_ONLY', 'device': device, 'rows': rows,
           'app_binary_sha256': hashlib.sha256((args.app / 'DJConnect').read_bytes()).hexdigest(),
           'physical_or_provider_acceptance': False, 'system_content_size_tested': content_size_supported}
(args.output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
