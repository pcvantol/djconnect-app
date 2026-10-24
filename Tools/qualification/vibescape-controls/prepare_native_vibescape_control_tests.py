"""Generate an isolated native VibeScape control component project; no shipping flags.

The host mounts the actual screen and AppModel with synthetic owner/runtime/catalogue responses.
It performs no real pairing, model/provider call, command, recording or speech playback.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import subprocess


def prepare(destination: Path, jose: Path, platform: str, bundle_suffix: str) -> None:
    import re
    if re.fullmatch(r"[a-z0-9-]{1,48}", bundle_suffix) is None:
        raise SystemExit("Use a fresh test-only alphanumeric bundle suffix")
    if platform != "iOS":
        raise SystemExit("This UI qualification currently covers iPhone/iPad only")
    root = Path(__file__).resolve().parents[3]
    helper = root / "Tools/qualification/vibecast-product/prepare_native_consent_tests.py"
    spec = importlib.util.spec_from_file_location("consent_preparation", helper)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.prepare(destination, jose, platform=platform)
    project_file = destination / "project.json"
    project = json.loads(project_file.read_text())
    project["name"] = "NativeVibeScapeControlQualification"
    project["targets"] = {k: v for k, v in project["targets"].items() if k in ("ConsentCore", "ConsentUI")}
    host_settings = {"PRODUCT_BUNDLE_IDENTIFIER": "dev.djconnect.qualification.visualcontrol." + bundle_suffix,
                     "GENERATE_INFOPLIST_FILE": "YES",
                     "INFOPLIST_KEY_NSMicrophoneUsageDescription": "DJConnect records your voice for push-to-talk music requests to Home Assistant.",
                     "INFOPLIST_KEY_NSSpeechRecognitionUsageDescription": "DJConnect uses speech recognition for on-device Ask DJ transcription and wake phrase detection."}
    if platform == "iOS":
        host_settings.update(INFOPLIST_KEY_UILaunchScreen_Generation="YES", INFOPLIST_KEY_UIApplicationSceneManifest_Generation="YES")
    project["targets"]["NativeVibeScapeControlHost"] = {
        "type": "application", "platform": platform,
        "sources": [{"path": str(root / "Tools/qualification/vibescape-controls/NativeVibeScapeControlHost.swift")}] + [{"path": str(root / "Tests/Fixtures" / name), "buildPhase": "resources"} for name in ("session-history-producer-receipt.json", "moment-contract-receipt.json", "vibescape-visual-catalogue-v1.json")],
        "dependencies": [{"target": "ConsentCore"}, {"target": "ConsentUI"}], "settings": {"base": host_settings}}
    project["targets"]["NativeVibeScapeControlUITests"] = {
        "type": "bundle.ui-testing", "platform": platform,
        "sources": [{"path": str(root / "Tools/qualification/vibescape-controls/NativeVibeScapeControlUITests.swift")}],
        "dependencies": [{"target": "NativeVibeScapeControlHost"}],
        "settings": {"base": {"PRODUCT_BUNDLE_IDENTIFIER": "dev.djconnect.qualification.visualcontrol.uitests." + bundle_suffix,
                              "GENERATE_INFOPLIST_FILE": "YES"}}}
    project["schemes"] = {"NativeVibeScapeControl": {"build": {"targets": {"NativeVibeScapeControlHost": "all", "NativeVibeScapeControlUITests": "all"}},
                                              "test": {"targets": ["NativeVibeScapeControlUITests"]}}}
    project_file.write_text(json.dumps(project, indent=2) + "\n")
    subprocess.run(["xcodegen", "generate", "--spec", str(project_file), "--project", str(destination)], check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--jose-checkout", type=Path, required=True)
    parser.add_argument("--platform", choices=("iOS",), required=True)
    parser.add_argument("--bundle-suffix", required=True)
    args = parser.parse_args()
    prepare(args.destination.resolve(), args.jose_checkout.resolve(), args.platform, args.bundle_suffix)
