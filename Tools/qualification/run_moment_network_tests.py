#!/usr/bin/env python3
"""Run the six opt-in macOS Moment tests against one isolated loopback fixture."""
import argparse
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
TESTS = (
    'ownerHTTPAndWebSocketDriveAppStateAcrossReconnectAndEnd',
    'rejectedOwnerSubscriptionRemovesPrivateProjectionWithoutClaimingRuntimeEnd',
    'ownerSessionTextNeverEntersParentURLCacheEvenWithCacheableResponse',
    'sessionDecodeFailureOmitsPrivateMomentBodyFromDiagnostics',
    'nativeOwnerHTTPWebSocketBackgroundExpiryReconnectAndUnsequencedTerminal',
    'nativeOwnerCurrentFailureResetsLoadingAndObsoleteFailureCannotClearRecovery',
)


def configure(source, port):
    def expand(value):
        if isinstance(value, dict):
            return {key: expand(item) for key, item in value.items()}
        if isinstance(value, list):
            return [expand(item) for item in value]
        if isinstance(value, str):
            return value.replace('__TESTROOT__', str(source.parent))
        return value

    spec = expand(plistlib.loads(source.read_bytes()))
    targets = [target for config in spec.get('TestConfigurations', []) for target in config.get('TestTargets', [])]
    if not targets:
        targets = [target for key, target in spec.items() if not key.startswith('__') and isinstance(target, dict)]
    core, = [target for target in targets if target.get('BlueprintName') == 'DJConnectCoreTests']
    core.setdefault('EnvironmentVariables', {}).update({
        'DJCONNECT_MOMENT_NETWORK_TEST': '1',
        'DJCONNECT_NATIVE_NETWORK_TEST': '1',
        'DJCONNECT_MOMENT_FIXTURE_PORT': str(port),
    })
    return spec


def fixture_port(server, log_path):
    deadline = time.monotonic() + 10
    while server.poll() is None and time.monotonic() < deadline:
        match = re.search(r'^LOCAL_SYNTHETIC_OWNER_FIXTURE http://127\.0\.0\.1:(\d+)$',
                          log_path.read_text(), re.MULTILINE)
        if match:
            return int(match.group(1))
        time.sleep(0.05)
    raise RuntimeError('Loopback fixture did not start; inspect server.log')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--core', type=Path, required=True, help='Core checkout containing both pinned producer commits')
    parser.add_argument('--xctestrun', type=Path, required=True, help='DJConnectMac build-for-testing result')
    parser.add_argument('--output', type=Path, required=True, help='New evidence directory')
    args = parser.parse_args()
    output, core, source = args.output.resolve(), args.core.resolve(), args.xctestrun.resolve()
    output.mkdir(mode=0o700)
    temp = output / 'tmp'
    temp.mkdir()
    env = dict(os.environ, TMPDIR=str(temp))
    receipt = output / 'receipt.json'
    with (output / 'producer.log').open('xb') as log:
        for generator in ('generate_moment_contract_receipt.py', 'generate_native_moment_receipt.py'):
            destination = receipt if generator == 'generate_moment_contract_receipt.py' else output / 'producer-native.json'
            subprocess.run(['python3', 'Tools/' + generator, '--core', str(core), '--output', str(destination)],
                           cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=60, check=True)

    server_log = output / 'server.log'
    with server_log.open('xb') as log:
        server = subprocess.Popen(['node', 'Tools/moment_contract_server.js', str(receipt), str(core)],
                                  cwd=ROOT, env=dict(env, DJCONNECT_MOMENT_FIXTURE_PORT='0'),
                                  stdout=log, stderr=subprocess.STDOUT)
        try:
            target = output / 'network.xctestrun'
            target.write_bytes(plistlib.dumps(configure(source, fixture_port(server, server_log))))
            result = output / 'network.xcresult'
            with (output / 'xcodebuild.log').open('xb') as build_log:
                subprocess.run(['xcodebuild', 'test-without-building', '-xctestrun', str(target),
                                '-destination', 'platform=macOS', '-parallel-testing-enabled', 'NO',
                                '-resultBundlePath', str(result),
                                *('-only-testing:DJConnectCoreTests/' + test + '()' for test in TESTS)],
                               cwd=ROOT, env=env, stdout=build_log, stderr=subprocess.STDOUT,
                               timeout=300, check=True)
            summary = json.loads(subprocess.check_output(
                ['xcrun', 'xcresulttool', 'get', 'test-results', 'summary', '--path', str(result)], env=env
            ))
            (output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
            return int(not (summary['passedTests'] == len(TESTS) and summary['failedTests'] == summary['skippedTests'] == 0))
        finally:
            server.terminate()
            try:
                server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait()


if __name__ == '__main__':
    raise SystemExit(main())
