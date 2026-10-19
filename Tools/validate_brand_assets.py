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
            referenced.add(path)
        assert set(directory.glob('*.png')) == referenced, f'orphan PNG: {name}'
        count += len(referenced)
    # These are source artwork documents, rather than a shipped font binary.
    assert sha(SOURCE / 'LICENSE.txt') == '262481e844521b326f5ecd053e59b98c8b2da78c8ee1bdbb6e8174305e54935a'
    print(f'PASS: {len(mapping)} exact producer imports, {count} opaque generated icon files across three catalogs, Inter license')


if __name__ == '__main__':
    validate()
