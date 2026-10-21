#!/usr/bin/env python3
"""Validate shared localized app branding and the language-neutral system launch.

The OS launch screen contains only the logo and product name. Localized copy
is rendered by the app after launch, using its selected language.
"""
import argparse
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = ('en', 'nl', 'de', 'fr', 'es')
EXPECTED = {
    'en': 'Your music. Your DJ.',
    'nl': 'Jouw muziek. Jouw DJ.',
    'de': 'Deine Musik. Dein DJ.',
    'fr': 'Votre musique. Votre DJ.',
    'es': 'Tu música. Tu DJ.',
}
LEGACY = ('ui.music.control.with.character', 'watch.music.control.with.character',
          'launch.music.control.with.character', 'Muziekbediening met karakter',
          'Music control with character')


def validate(write=False):
    key_sets = []
    for language in LANGUAGES:
        path = ROOT / f'Sources/DJConnectCore/Resources/Localization/{language}.lproj/Localizable.strings'
        source = path.read_text()
        rows = re.findall(r'^"([^"\\]+)"\s*=\s*("(?:[^"\\]|\\.)*");\s*$', source, re.M)
        values = {key: json.loads(value) for key, value in rows}
        assert len(values) == len(rows), f'duplicate localization key: {language}'
        assert values.get('brand.tagline') == EXPECTED[language], f'incorrect brand sentence: {language}'
        assert values.get('ui.device_speech.sample', '').startswith(EXPECTED[language] + ' '), f'stale spoken brand preview: {language}'
        assert not any(old in source for old in LEGACY), f'legacy tagline: {path}'
        key_sets.append(set(values))
    assert all(keys == key_sets[0] for keys in key_sets), 'five-language localization key mismatch'
    for directory in ('Sources', 'Apps'):
        for path in (ROOT / directory).rglob('*'):
            if path.suffix not in ('.swift', '.strings', '.storyboard'):
                continue
            assert not any(old in path.read_text() for old in LEGACY), f'active legacy tagline: {path}'
    storyboard = ET.parse(ROOT / 'Apps/DJConnectIOS/LaunchScreen.storyboard')
    assert [label.get('text') for label in storyboard.findall('.//label')] == ['DJConnect'], 'system launch must contain only the product name'
    assert storyboard.find(".//imageView[@image='LaunchIcon']") is not None
    assert not list((ROOT / 'Apps/DJConnectIOS').glob('*.lproj/LaunchScreen.strings')), 'obsolete launch translations are still shipped'
    assert storyboard.find(".//image[@name='LaunchBanner']") is None, 'old raster tagline is active'
    assert not (ROOT / 'Apps/Shared/Assets.xcassets/LaunchBanner.imageset').exists(), 'old raster is still shipped'
    launch = (ROOT / 'Sources/DJConnectUI/DJConnectLaunchView.swift').read_text()
    root = (ROOT / 'Sources/DJConnectUI/DJConnectRootView.swift').read_text()
    watch = (ROOT / 'Apps/DJConnectWatch/DJConnectWatchRootView.swift').read_text()
    assert 'localized(key: "brand.tagline")' in launch
    assert 'DJConnectLaunchBanner()' in root
    assert 'watchLocalizedKey(model.language, "brand.tagline")' in watch
    # Layout/font sizing is covered by the native brand presentation tests.
    # This check owns the shared localized sentence, not an obsolete font style.
    assert re.search(r'private func tagline\(size: CGFloat\).*?Text\(subtitle\)', launch, re.S), 'shared tagline renderer missing'
    print(f'PASS: exact brand sentence in {len(LANGUAGES)} languages; {len(key_sets[0])} matching keys; language-neutral system launch; active legacy references/raster absent')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    validate(parser.parse_args().write)
