#!/usr/bin/env python3
"""Run the manual online Ask DJ catalogue suite on a pre-paired simulator."""

import argparse
import json
import os
from pathlib import Path
import plistlib
import subprocess
import uuid

import golden


SELECTOR = ('DJConnectIOSUITests/DJConnectIOSUITests/'
            'testOnlineActiveSessionSuggestionsAndAllFourteenHelpActions')
TARGET = 'DJConnectIOSUITests'
CATALOGUE = (Path(__file__).resolve().parents[3] /
             'Sources/DJConnectCore/Resources/ask_dj_examples_v1.json')
PLAN_KEYS = {
    'session_id': 'DJCONNECT_ONLINE_SESSION',
    'profile_id': 'DJCONNECT_ONLINE_PROFILE',
    'output_id': 'DJCONNECT_ONLINE_OUTPUT',
    'artist': 'DJCONNECT_ONLINE_ARTIST',
}


def configure(spec, root, plan):
    def expand(value):
        if isinstance(value, dict):
            return {key: expand(item) for key, item in value.items()}
        if isinstance(value, list):
            return [expand(item) for item in value]
        return value.replace('__TESTROOT__', str(root)) if isinstance(value, str) else value

    if plan.get('execute') is not True or plan.get('fixture') != 'DISPOSABLE_ONLINE_SESSION':
        raise ValueError('online_run_not_armed')
    settings = {}
    for key, name in PLAN_KEYS.items():
        value = plan.get(key)
        if not isinstance(value, str) or not value.strip() or len(value) > 160 or any(ord(c) < 32 for c in value):
            raise ValueError('invalid_scope_or_artist')
        settings[name] = value
    patterns = plan.get('reply_patterns')
    entries = json.loads(CATALOGUE.read_text(encoding='utf-8'))['entries']
    expected = {entry['id'] for entry in entries if 'active_session' in entry['surfaces']}
    if len(expected) != 14 or not isinstance(patterns, dict) or patterns.keys() != expected or any(
        not isinstance(value, str) or not value.strip() or len(value) > 500
        for value in patterns.values()
    ):
        raise ValueError('fourteen_reply_expectations_required')

    data = expand(spec)
    targets = [target for config in data.get('TestConfigurations', []) for target in config.get('TestTargets', [])]
    if not targets:
        targets = [target for key, target in data.items() if not key.startswith('__') and isinstance(target, dict)]
    matches = [target for target in targets if target.get('BlueprintName') == TARGET]
    if len(matches) != 1:
        raise ValueError('exact_ios_ui_target_required')
    matches[0].setdefault('EnvironmentVariables', {}).update({
        **settings,
        'DJCONNECT_ONLINE_CATALOGUE_TEST': '1',
        'DJCONNECT_ONLINE_REPLY_PATTERNS': json.dumps(patterns, ensure_ascii=False),
    })
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--xctestrun', type=Path, required=True)
    parser.add_argument('--plan', type=Path, required=True)
    parser.add_argument('--simulator', type=uuid.UUID, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    plan = golden.private_read(args.plan)
    source = args.xctestrun.resolve()
    spec = configure(plistlib.loads(source.read_bytes()), source.parent, plan)
    output = args.output.resolve()
    output.mkdir(mode=0o700)
    target = output / 'online.xctestrun'
    with os.fdopen(os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), 'wb') as stream:
        plistlib.dump(spec, stream)
    result = output / 'online.xcresult'
    with (output / 'xcodebuild.log').open('xb') as log:
        status = subprocess.run([
            'xcodebuild', 'test-without-building', '-xctestrun', str(target),
            '-destination', f'platform=iOS Simulator,id={str(args.simulator).upper()}',
            '-parallel-testing-enabled', 'NO', '-maximum-test-execution-time-allowance', '2400',
            '-test-timeouts-enabled', 'YES', '-only-testing:' + SELECTOR,
            '-resultBundlePath', str(result),
        ], stdout=log, stderr=subprocess.STDOUT, timeout=2700)
    if status.returncode != 0:
        return 1
    summary = json.loads(subprocess.check_output(
        ['xcrun', 'xcresulttool', 'get', 'test-results', 'summary', '--path', str(result)]
    ))
    return int(not (summary['passedTests'] == 1 and summary['failedTests'] == summary['skippedTests'] == 0))


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (ValueError, KeyError, OSError, subprocess.SubprocessError):
        raise SystemExit('Online suite not completed. Preserve the private output and review before repeating.')
