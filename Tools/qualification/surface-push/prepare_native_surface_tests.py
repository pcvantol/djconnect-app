"""Generate an isolated real-SDK codec test project; never a shipping push flag."""
import argparse
import importlib.util
import json
from pathlib import Path
import subprocess


def prepare(destination: Path, jose: Path, platform: str) -> None:
    root = Path(__file__).resolve().parents[3]
    helper = root / "Tools/qualification/vibecast-product/prepare_native_consent_tests.py"
    spec = importlib.util.spec_from_file_location("consent_preparation", helper)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.prepare(destination, jose, platform=platform)
    file = destination / "project.json"
    project = json.loads(file.read_text())
    project["name"] = "NativeSurfacePushQualification"
    project["targets"] = {"ConsentCore": project["targets"]["ConsentCore"]}
    project["targets"]["NativeSurfacePushSDKTests"] = {
        "type": "bundle.unit-test", "platform": platform,
        "sources": [{"path": str(root / "Tools/qualification/surface-push/NativeSurfacePushSDKTests.swift")},
                    {"path": str(root / "Tools/qualification/surface-push/RemoteActivityV1Prototype.swift")},
                    {"path": str(root / "Tools/qualification/surface-push/RemoteActivityV1PrototypeTests.swift")},
                    {"path": str(root / "Tests/Fixtures/session-activity-local-codec-profile-v1.json"), "buildPhase": "resources"}],
        "dependencies": [{"target": "ConsentCore"}],
        "settings": {"base": {"PRODUCT_BUNDLE_IDENTIFIER": "dev.djconnect.qualification.surfacepush." + platform.lower(), "GENERATE_INFOPLIST_FILE": "YES"}}}
    project["schemes"] = {"NativeSurfacePushSDK": {"build": {"targets": {"NativeSurfacePushSDKTests": "all"}},
                                                 "test": {"targets": ["NativeSurfacePushSDKTests"]}}}
    file.write_text(json.dumps(project, indent=2) + "\n")
    subprocess.run(["xcodegen", "generate", "--spec", str(file), "--project", str(destination)], check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--jose-checkout", type=Path, required=True)
    parser.add_argument("--platform", choices=("iOS", "macOS"), required=True)
    args = parser.parse_args()
    prepare(args.destination.resolve(), args.jose_checkout.resolve(), args.platform)
