#!/usr/bin/env python3
"""Generate an isolated, opt-in hosted Mac test project; never install or run it."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]


def spec():
    with tempfile.TemporaryDirectory(prefix='djc-golden-spec-') as temporary:
        resolved = Path(temporary) / 'resolved.json'
        subprocess.run(['xcodegen', 'dump', '--quiet', '--type', 'json', '--file', str(resolved),
                        '--spec', str(ROOT / 'project.yml')], check=True)
        data = json.loads(resolved.read_text())
    # Keep the original project root and relative paths. XcodeGen can loop in
    # makePathRelative for relocated specs crossing the /tmp and volume roots.
    data['name'] = 'DJConnectAskDJGolden'
    data['targets']['DJConnectAskDJGoldenHosted'] = {
        'type': 'bundle.unit-test', 'platform': 'macOS',
        'sources': [{'path': 'Tests/DJConnectCoreTests/AskDJGoldenIntegrationTests.swift'}],
        'dependencies': [{'target': t} for t in ['DJConnectMac', 'DJConnectCoreMac', 'DJConnectUIMac']],
        'settings': {'base': {'PRODUCT_BUNDLE_IDENTIFIER': 'dev.djconnect.qualification.askdj-golden',
                              'GENERATE_INFOPLIST_FILE': 'YES',
                              'TEST_HOST': '$(BUILT_PRODUCTS_DIR)/DJConnect.app/Contents/MacOS/DJConnect',
                              'BUNDLE_LOADER': '$(TEST_HOST)'}}}
    data.setdefault('schemes', {})['AskDJGoldenHosted'] = {
        'build': {'targets': {'DJConnectMac': 'all', 'DJConnectAskDJGoldenHosted': ['test']}},
        'test': {'targets': ['DJConnectAskDJGoldenHosted'], 'parallelizable': False, 'randomExecutionOrder': False}}
    return data


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    generated = args.output / 'hosted.json'
    generated.write_text(json.dumps(spec(), indent=2) + '\n')
    subprocess.run(['xcodegen', 'generate', '--spec', str(generated), '--project-root', str(ROOT), '--project', str(ROOT)], check=True)
