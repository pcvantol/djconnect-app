#!/usr/bin/env python3
"""Disposable Watch render host. Modeled input is never installed on hardware.

Shipping source is copied unchanged except for one explicit fixture injection in
its existing demo initializer. No access, APNs, audio or Session execution is
qualified by the generated host. Existing product project/identity is preserved.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

parser = argparse.ArgumentParser()
parser.add_argument('--output', required=True, type=Path)
parser.add_argument('--snapshot', required=True, type=Path)
args = parser.parse_args()
source = Path(__file__).resolve().parents[3]
out = args.output.resolve()
if out == source or source in out.parents:
    raise SystemExit('Qualification output must be outside the shipping checkout')
out.mkdir(parents=True, exist_ok=False)
for name in ['Apps', 'Sources', 'Tests']:
    shutil.copytree(source / name, out / name)
shutil.copy2(source / 'project.yml', out / 'project.yml')
raw = json.loads(args.snapshot.read_text())
# The caller exports this modeled runtime from the existing native admission
# fixture tests. Never treat modified fixture clocks as a live producer receipt.
for mood in ['chill', 'groove', 'energy', 'party']:
    fixture = json.loads(json.dumps(raw))
    snapshot = fixture['settings']['snapshot']
    snapshot['defaults']['mood'] = mood
    snapshot['session']['settings']['mood'] = mood
    fixture['session']['selected_mood'] = mood
    fixture['session']['broadcast']['session']['selected_mood'] = mood
    (out / 'Apps/DJConnectWatch' / f'qualification-{mood}.json').write_text(json.dumps(fixture))
model = out / 'Apps/DJConnectWatch/DJConnectWatchModel.swift'
s = model.read_text()
marker = '            appendDiagnosticLog("Watch gestart in monkey test demo modus")'
assert s.count(marker) == 1
s = s.replace(marker, '''            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                guard !ProcessInfo.processInfo.arguments.contains("--qualification-idle") else { return }
                let mood = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--qualification-mood=") }?.split(separator: "=").last.map(String.init) ?? "groove"
                guard let url = Bundle.main.url(forResource: "qualification-" + mood, withExtension: "json"),
                      let data = try? Data(contentsOf: url),
                      let fixture = try? JSONDecoder().decode(DJConnectWatchSessionSnapshot.self, from: data) else { return }
                foregroundSession.bind(owner: "modeled-render-only", active: true)
                await foregroundSession.refresh(force: true) { fixture }
                profileDJSettings.bind(owner: fixture.settings.binding, active: true)
                await profileDJSettings.refresh(.init(read: { fixture.settings }, update: { _, _, _ in throw DJConnectError.invalidResponse }, receipt: { _, _ in throw DJConnectError.invalidResponse }))
            }
''' + marker)
model.write_text(s)
receipt = {'classification': 'MODELED_NATIVE_RENDER_ONLY_NOT_PROVIDER_OR_DEVICE_AUTHORITY',
           'source': str(source), 'fixture_sha256': hashlib.sha256(args.snapshot.read_bytes()).hexdigest(),
           'injected_copy': str(model), 'hardware_installation': False}
(out / 'qualification-manifest.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(out)
