"""Bind every native test app startup to the isolated ordinary-pairing lab.

Temporary xctestrun only. No device token/HA credential, product setting, installed
application or Core source is written. Preserve the build's original xctestrun.
"""
from __future__ import annotations
import argparse
from pathlib import Path
import plistlib
import subprocess


def configure(source: Path, destination: Path, language: str, mac_app: Path | None = None) -> None:
    source = source.resolve()
    data = plistlib.loads(subprocess.check_output(['/bin/cat', str(source)]))
    root = str(source.parent)

    def paths(value):
        if isinstance(value, str): return value.replace('__TESTROOT__', root)
        if isinstance(value, list): return [paths(item) for item in value]
        if isinstance(value, dict): return {key: paths(item) for key, item in value.items()}
        return value

    data = paths(data)
    if 'TestConfigurations' in data:
        targets = [target for configuration in data['TestConfigurations'] for target in configuration.get('TestTargets', [])]
    else:
        targets = [value for value in data.values() if isinstance(value, dict)]
    count = 0
    for target in targets:
        if not target.get('IsUITestBundle'): continue
        if target.get('ProductModuleName') not in {'DJConnectIOSUITests', 'DJConnectMacUITests'}: continue
        if mac_app is not None:
            assert target['ProductModuleName'] == 'DJConnectMacUITests'
            mac_app = mac_app.resolve()
            assert mac_app.parent == Path('/private/tmp') and mac_app.name.startswith('djc-mac-presenceproof-')
            info = plistlib.loads(subprocess.check_output(['/bin/cat', str(mac_app / 'Contents/Info.plist')]))
            assert info['CFBundleIdentifier'] == 'dev.djconnect.mac.presenceproof'
            old_app = target['UITargetAppPath']
            target['UITargetAppPath'] = str(mac_app)
            target['UITargetAppBundleIdentifier'] = info['CFBundleIdentifier']
            target['DependentProductPaths'] = [str(mac_app) if item == old_app else item for item in target.get('DependentProductPaths', [])]
        # Xcode starts the target before the test's explicit app.launch(). Bind
        # this first launch too, so it cannot load normal account preferences.
        target['UITargetAppCommandLineArguments'] = ['--uitesting', '--runtime-fixture=paired_owner_contract', '-DJCONNECTRuntimeFixture', 'paired_owner_contract', '-AppleLanguages', '(' + language + ')', '-AppleLocale', language]
        target.setdefault('UITargetAppEnvironmentVariables', {}).update({
            'DJCONNECT_UITEST_HA_URL': 'http://127.0.0.1:18213',
            'DJCONNECT_UITEST_RUNTIME_FIXTURE': 'paired_owner_contract',
        })
        target.setdefault('EnvironmentVariables', {}).update({
            'DJC_APPLE_PRESENCE_UI_BASE': 'http://127.0.0.1:18213',
            'DJC_APPLE_PRESENCE_LANGUAGE': language,
        })
        count += 1
    assert count == 1, 'Expected exactly one first-party native UI test target'
    assert destination.resolve() != source, 'Preserve the original build configuration'
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(plistlib.dumps(data, fmt=plistlib.FMT_XML))
    print('ISOLATED_NATIVE_STARTUP_BOUND', language)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    parser.add_argument('destination', type=Path)
    parser.add_argument('--language', choices=['en', 'nl', 'de', 'fr', 'es'], default='nl')
    parser.add_argument('--mac-app', type=Path)
    options = parser.parse_args()
    configure(options.source, options.destination, options.language, options.mac_app)
