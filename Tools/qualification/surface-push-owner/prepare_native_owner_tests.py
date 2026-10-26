"""Real Core/UI source with explicitly modeled URLProtocol owner tests only.

No shipping flag, token acquisition, Activity operation or provider connection.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import subprocess


def prepare(destination: Path, jose: Path, platform: str) -> None:
    root = Path(__file__).resolve().parents[3]
    helper = root / "Tools/qualification/vibecast-product/prepare_native_consent_tests.py"
    spec = importlib.util.spec_from_file_location("owner_preparation", helper)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.prepare(destination, jose, platform=platform)
    file = destination / "project.json"
    project = json.loads(file.read_text())
    project["name"] = "NativeSurfacePushOwnerQualification"
    project["targets"] = {k: v for k, v in project["targets"].items() if k in ("ConsentCore", "ConsentUI")}
    project["targets"]["SurfacePushOwnerTests"] = {
        "type": "bundle.unit-test", "platform": platform,
        "sources": [{"path": str(root / "Tests/DJConnectCoreTests/SurfacePushTaskOwnerTests.swift")},
                    {"path": str(root / "Tests/Fixtures/surface-push-core-12675bc-http.json"), "buildPhase": "resources"}],
        "dependencies": [{"target": "ConsentCore"}, {"target": "ConsentUI"}],
        "settings": {"base": {"PRODUCT_BUNDLE_IDENTIFIER": "dev.djconnect.qualification.surfaceowner." + platform.lower(), "GENERATE_INFOPLIST_FILE": "YES"}}}
    project["schemes"] = {"SurfacePushOwner": {"build": {"targets": {"SurfacePushOwnerTests": "all"}},
                                             "test": {"targets": ["SurfacePushOwnerTests"]}}}
    file.write_text(json.dumps(project, indent=2) + "\n")
    subprocess.run(["xcodegen", "generate", "--spec", str(file), "--project", str(destination)], check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--jose-checkout", type=Path, required=True)
    parser.add_argument("--platform", choices=("iOS", "macOS"), required=True)
    args = parser.parse_args()
    prepare(args.destination.resolve(), args.jose_checkout.resolve(), args.platform)
