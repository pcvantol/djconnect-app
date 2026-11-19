#!/usr/bin/env python3
"""Run only the admitted hosted native Golden test; never a release PASS by itself."""
import argparse
import os
from pathlib import Path
import plistlib
import subprocess
import uuid
import golden


def configure(data, testroot, plan, output):
    def expand(value):
        if isinstance(value, dict):
            return {k: expand(v) for k,v in value.items()}
        if isinstance(value, list):
            return [expand(v) for v in value]
        return value.replace('__TESTROOT__', str(testroot)) if isinstance(value, str) else value
    data = expand(data)
    targets = [t for c in data.get('TestConfigurations', []) for t in c.get('TestTargets', [])]
    if not targets:  # xctestrun format v1
        targets = [v for k,v in data.items() if not k.startswith('__') and isinstance(v, dict)]
    admitted = [t for t in targets if t.get('BlueprintName') == 'DJConnectAskDJGoldenHosted']
    if len(admitted) != 1:
        raise ValueError('exact_hosted_target_required')
    admitted[0].setdefault('EnvironmentVariables', {}).update({
        'DJCONNECT_ASKDJ_GOLDEN_PLAN': str(plan), 'DJCONNECT_ASKDJ_GOLDEN_OUTPUT': str(output)})
    return data


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--xctestrun', type=Path, required=True)
    parser.add_argument('--plan', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--destination', default='platform=macOS')
    args=parser.parse_args()
    plan=golden.private_read(args.plan)
    if plan.get('execute') is not True or plan.get('fixture_admission') != 'QUALIFIED_DISPOSABLE_SESSION':
        raise ValueError('not_armed')
    if args.destination != 'platform=macOS':
        raise ValueError('device_host_adapter_not_yet_qualified')
    # Real-device file staging and signing require a separately qualified adapter.
    root=args.output.resolve()
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    if root.stat().st_mode & 0o077:
        raise ValueError('private_output_directory_required')
    run_id=plan.get('run_id', '')
    if str(uuid.UUID(run_id)) != run_id or (root / run_id / 'started').exists():
        raise ValueError('invalid_or_previously_started_run')
    launch=root / ('launcher-' + str(uuid.uuid4()))
    launch.mkdir(mode=0o700)
    source=args.xctestrun.resolve()
    data=configure(plistlib.loads(source.read_bytes()), source.parent, args.plan.resolve(), root)
    target=launch / 'execution.xctestrun'
    with os.fdopen(os.open(target, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600), 'wb') as stream:
        plistlib.dump(data, stream)
    # No signature/profile changes, install helper, endpoint/key or automatic retry.
    command=['xcodebuild', 'test-without-building', '-xctestrun', str(target), '-destination', args.destination,
             '-only-testing:DJConnectAskDJGoldenHosted/AskDJGoldenIntegrationTests/testRealPairedSessionGolden',
             '-resultBundlePath', str(launch / 'native.xcresult')]
    with (launch / 'xcodebuild.log').open('xb') as log:
        result=subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=720)
    if result.returncode != 0:
        print('FAIL_OR_UNCERTAIN; preserve run marker; do not replay automatically')
        return 1
    native=golden.private_read(root / run_id / 'native-run.json')
    if native.get('status') != 'CLIENT_EXERCISED_NOT_RELEASE_PASS':
        print('FAIL: client run incomplete')
        return 1
    print('CLIENT_EXERCISED; CORE_PROVIDER_RECONCILIATION_REQUIRED; NOT_RELEASE_PASS')
    return 2


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (ValueError, KeyError, OSError, subprocess.TimeoutExpired):
        raise SystemExit('FAIL_OR_UNCERTAIN: invalid admission or native execution; preserve original run')
