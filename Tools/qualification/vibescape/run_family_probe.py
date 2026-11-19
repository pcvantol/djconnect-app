"""Render synthetic worlds using the shipping Mac Metal engine and Core palette.

Build the Swift package first. --products must contain DJConnectCore.o,
JOSESwift.o and their modules. Output must be a fresh external directory.
This probe neither launches the app nor uses pairing/profile/provider services.
"""
from pathlib import Path
import argparse
import hashlib
import json
import platform
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--products", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    products = args.products.resolve()
    objects = [products / "DJConnectCore.o", products / "JOSESwift.o"]
    if platform.system() != "Darwin" or not all(p.is_file() for p in objects):
        raise SystemExit("Requires macOS Metal and the existing built Core/JOSESwift products")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    sources = [root / p for p in ["Sources/DJConnectUI/VibeScapeShaders/VibeScape.metal",
        "Sources/DJConnectUI/VibeScapeFamilies.swift", "Sources/DJConnectUI/VibeScapeScene.swift",
        "Sources/DJConnectUI/VibeScapeMetalEngine.swift", "Tools/qualification/vibescape/FamilyMetalProbe.swift"]]
    def digest(path):
        return hashlib.sha256(path.read_bytes()).hexdigest()
    inputs = {str(p): digest(p) for p in sources + objects}
    commands = [
        ["xcrun", "-sdk", "macosx", "metal", "-c", str(sources[0]), "-o", str(output / "scene.air")],
        ["xcrun", "-sdk", "macosx", "metallib", str(output / "scene.air"), "-o", str(output / "scene.metallib")],
        ["swiftc", "-O", "-parse-as-library", "-target", platform.machine() + "-apple-macosx26.0",
         "-I", str(products), "-I", str(products / "Modules"), "-module-cache-path", str(output / "module-cache")]
            + [str(p) for p in sources[1:] + objects] + ["-o", str(output / "probe")],
        [str(output / "probe"), str(output / "scene.metallib"), str(output / "renders")]]
    with (output / "run.log").open("w") as log:
        for command in commands:
            subprocess.run(command, cwd=root, stdout=log, stderr=subprocess.STDOUT, check=True)
    unchanged = inputs == {str(p): digest(p) for p in sources + objects}
    receipt = {"base_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
        "inputs_sha256": inputs, "source_and_products_unchanged": unchanged, "commands": commands,
        "xcode": subprocess.check_output(["xcodebuild", "-version"], text=True),
        "scope": "synthetic inputs, native offscreen Mac GPU only"}
    (output / "source-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    if not unchanged:
        raise SystemExit("Sources or linked products changed during this probe")
    print(output / "renders/gpu-report.json")


if __name__ == "__main__":
    main()
