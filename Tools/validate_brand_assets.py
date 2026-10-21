#!/usr/bin/env python3
"""Check native Brand V2 imports against the pinned producer manifest."""
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'Apps/Shared/Assets.xcassets'
SOURCE = ROOT / 'Tools/IconSource/BrandV2'
MANIFEST_SHA = '73cc408e10d88aa1fb8a1be2783b9c577aec398ce3dcd54c2f997ad1425984d2'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def png(path):
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', path
    return (*struct.unpack('>II', data[16:24]), data[25])


def validate():
    manifest_path = SOURCE / 'manifest.json'
    assert sha(manifest_path) == MANIFEST_SHA, 'producer manifest drift'
    manifest = json.loads(manifest_path.read_text())['files']
    mapping = {
        ROOT / 'Tools/IconSource/djconnect-icon-1024.png': 'mark-1024.png',
        SOURCE / 'headset-master.png': 'headset-master.png',
        ASSETS / 'LaunchIcon.imageset/launch-icon.png': 'mark-1024.png',
        ASSETS / 'BrandHeadset.imageset/headset-master.png': 'headset-master.png',
    }
    for kind in ('primary', 'compact'):
        for theme in ('light', 'dark'):
            name = f'wordmark-{kind}-{theme}.png'
            mapping[ASSETS / f'BrandWordmark{kind.title()}{theme.title()}.imageset' / name] = name
    for path, name in mapping.items():
        entry = manifest[f'assets/djconnect/brand-v2/{name}']
        assert sha(path) == entry['sha256'], f'altered producer image: {path}'
        assert png(path) == (entry['width'], entry['height'], 6), f'RGBA dimensions: {path}'
    ledger = json.loads((ROOT / 'docs/verification/APPLE_BRAND_V2_NATIVE_MANIFEST_20261020.json').read_text())
    assert ledger['manifest_sha256'] == MANIFEST_SHA, 'native ledger producer mismatch'
    generated_hashes = ledger['generated_icons']['files']
    generated_paths = set()
    count = 0
    for name in ('AppIconIOS', 'AppIconMac', 'AppIconWatch'):
        directory = ASSETS / f'{name}.appiconset'
        entries = json.loads((directory / 'Contents.json').read_text())['images']
        referenced = set()
        for entry in entries:
            path = directory / entry['filename']
            width, height, color = png(path)
            expected = round(float(entry['size'].split('x')[0]) * float(entry.get('scale', '1x')[:-1]))
            assert width == height == expected, f'wrong slot dimensions: {path}'
            assert color == 2, f'system icon must be opaque RGB: {path}'
            relative = path.relative_to(ROOT).as_posix()
            assert sha(path) == generated_hashes.get(relative), f'generated icon hash drift: {relative}'
            generated_paths.add(relative)
            referenced.add(path)
        assert set(directory.glob('*.png')) == referenced, f'orphan PNG: {name}'
        count += len(referenced)
    assert generated_paths == set(generated_hashes), 'native generated-icon ledger coverage mismatch'
    # These are source artwork documents, rather than a shipped font binary.
    assert sha(SOURCE / 'LICENSE.txt') == '262481e844521b326f5ecd053e59b98c8b2da78c8ee1bdbb6e8174305e54935a'
    adaptive = ROOT / 'Apps/Shared/AppIconAdaptive.icon'
    provenance = json.loads((ROOT / 'Tools/IconSource/AdaptiveHeadphone/provenance.json').read_text())
    assert provenance['source_revision'] == 'c49d49186951ed3a4eaf3cc50778e48e04cbbef9'
    foreground = ROOT / provenance['consumer_path']
    assert sha(foreground) == provenance['source_sha256'] == 'f69eb72b882f08c0dacbd3efa7e83165a56a01763aaa18e48557c03b65e11322'
    assert png(foreground) == (1254, 1254, 6), 'adaptive source must retain original RGBA canvas'
    document = json.loads((adaptive / 'icon.json').read_text())
    assert document['supported-platforms'] == {'squares': 'shared', 'circles': ['watchOS']}
    assert len(document['groups']) == 1
    layers = document['groups'][0]['layers']
    assert len(layers) == 1 and layers[0]['image-name'] == 'headphone.png'
    assert layers[0]['position'] == {'scale': 0.64, 'translation-in-points': [0, 0]}
    assert {x.get('appearance', 'default') for x in document['fill-specializations']} == {'default', 'dark'}
    assert set((adaptive / 'Assets').iterdir()) == {foreground}, 'unexpected adaptive image/wordmark'
    project = (ROOT / 'project.yml').read_text()
    assert project.count('ASSETCATALOG_COMPILER_APPICON_NAME: AppIconAdaptive') == 3
    assert project.count('- path: Apps/Shared/AppIconAdaptive.icon') == 3
    generated = (ROOT / 'DJConnectApp.xcodeproj/project.pbxproj').read_text()
    assert generated.count('ASSETCATALOG_COMPILER_APPICON_NAME = AppIconAdaptive;') == 6
    qa = (ROOT / 'Tools/qualification/vibecast-fixed-qa/prepare_fixed_qa.py').read_text()
    assert '"ASSETCATALOG_COMPILER_APPICON_NAME": "AppIconAdaptive"' in qa
    assert '"Apps/Shared/AppIconAdaptive.icon"' in qa
    print(f'PASS: {len(mapping)} exact producer imports, {count} retained opaque legacy icons, adaptive headphone source and native project wiring, Inter license')


if __name__ == '__main__':
    validate()
