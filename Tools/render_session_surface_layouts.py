#!/usr/bin/env python3
"""Render current passive-layout source with synthetic fixtures, without a backend.

This checks native macOS SwiftUI rendering only, not installed WidgetKit,
ActivityKit, Dynamic Island, iOS Dynamic Type or background delivery.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'Apps/DJConnectTrackInsightWidgets/DJConnectTrackInsightWidgets.swift'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--framework-directory', type=Path, required=True)
    parser.add_argument('--output-directory', type=Path, required=True)
    args = parser.parse_args()
    framework = args.framework_directory.resolve()
    output = args.output_directory.resolve()
    if not (framework / 'DJConnectCore.framework').is_dir():
        parser.error('Build DJConnectCore for macOS first; framework is missing.')
    output.mkdir(parents=True, exist_ok=True)
    source = SOURCE.read_text()
    palette = source[source.index('private extension DJConnectSessionMoodTheme'):source.index('struct DJConnectSessionWidgetEntry')]
    layout = source[source.index('// MARK: - Rich presentation preparation'):source.index('#if DEBUG\n// Synthetic visual fixtures')]
    # Extract the current declarations; never keep a second hand-maintained view.
    harness = '''import AppKit
import SwiftUI
import DJConnectCore
private func text(_ key: String) -> String { DJConnectLocalization.localized(key: key) }
''' + palette + layout + r'''
@main struct RenderSessionLayouts {
 @MainActor static func main() throws {
  let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
  let sizes: [(SessionMomentLayoutSize, CGFloat, CGFloat, String)] = [
   (.small,170,170,"small"), (.medium,360,170,"medium"), (.large,360,360,"large"),
   (.activity,380,170,"activity"), (.island,340,150,"island")]
  let scenarios = ["normal", "long", "right-to-left"]
  var receipt: [[String: String]] = []
  for (index, item) in sizes.enumerated() {
   let (size, width, height, name) = item
   let theme = DJConnectSessionMoodTheme.allCases[index]
   for scenario in scenarios {
    let long = scenario == "long"
    let rtl = scenario == "right-to-left"
    let moment = rtl ? "إيقاع هادئ ولحن دافئ في هذا المثال التجريبي." : (long ? "Een warme baslijn en subtiele percussie geven dit nummer ruimte om te ademen. De zanger bouwt de spanning langzaam op, terwijl de melodie herkenbaar blijft." : "Een warme baslijn geeft dit nummer ruimte om te ademen.")
    let view = SessionMomentLayout(size: size, moment: moment,
      track: long ? "Een bijzonder lange tracktitel met een uitgebreide live-versie" : "Nachtlicht",
      artist: long ? "Voorbeeldartiest en gastmuzikanten" : "Voorbeeldartiest",
      album: "Onderweg naar de volgende bestemming",
      attribution: long ? "Synthetische bronvermelding voor uitsluitend lokale layoutcontrole" : "Voorbeeldbron · geen live sessie") {
       ZStack {
        LinearGradient(colors:theme.colors,startPoint:.topLeading,endPoint:.bottomTrailing)
        Image(systemName:"opticaldisc").font(.system(size:28)).foregroundStyle(.white)
       }
      }
      .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
      .padding(16).background { SessionMoodBackground(theme:theme) }
      .frame(width:width,height:height)
    let renderer = ImageRenderer(content:view); renderer.scale = 2
    guard let image = renderer.cgImage, image.width == Int(width*2), image.height == Int(height*2) else { fatalError("Unexpected render bounds") }
    let data = NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:])!
    let file = name + "-" + scenario + ".png"
    try data.write(to:output.appendingPathComponent(file))
    receipt.append(["file":file,"theme":theme.rawValue,"scenario":scenario,"size":name])
   }
  }
  let receiptData = try JSONSerialization.data(withJSONObject:receipt,options:[.prettyPrinted,.sortedKeys])
  try receiptData.write(to:output.appendingPathComponent("renders.json"))
 }
}
'''
    with tempfile.TemporaryDirectory(prefix='djc-session-layout-') as temporary:
        temporary = Path(temporary)
        script = temporary / 'Render.swift'
        executable = temporary / 'render'
        script.write_text(harness)
        subprocess.run(['xcrun', 'swiftc', '-parse-as-library', str(script), '-F', str(framework),
                        '-framework', 'DJConnectCore', '-Xlinker', '-rpath', '-Xlinker', str(framework),
                        '-o', str(executable)], check=True)
        subprocess.run([str(executable), str(output)], check=True)
    receipt = {'source_sha256': hashlib.sha256(source.encode()).hexdigest(),
               'renders': len(json.loads((output / 'renders.json').read_text())),
               'evidence': 'SYNTHETIC_NATIVE_MACOS_VIEW_RENDERS_ONLY',
               'not_qualified': ['installed widgets', 'ActivityKit', 'Dynamic Island',
                                 'iOS Dynamic Type', 'background updates', 'Core content grants']}
    (output / 'qualification.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt))


if __name__ == '__main__':
    main()
