"""Generate a new disposable Help view qualification project; no shipping flags.

The synthetic qualification fixture is confined to this disposable host.
It renders the real shared Help view without AppModel, HTTP, pairing or sending.
"""
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
    project_file = destination / "project.json"
    project = json.loads(project_file.read_text())
    project["name"] = "NativeHelpQualification"
    project["targets"] = {k: v for k, v in project["targets"].items() if k in ("ConsentCore", "ConsentUI")}
    fixture = {"path": str(root / "Tests/Fixtures/askdj-catalogue-selector-golden-v1.json"), "buildPhase": "resources"}
    host_settings = {"PRODUCT_BUNDLE_IDENTIFIER": "dev.djconnect.qualification.help." + platform.lower(),
                     "GENERATE_INFOPLIST_FILE": "YES"}
    if platform == "iOS":
        host_settings.update(INFOPLIST_KEY_UILaunchScreen_Generation="YES", INFOPLIST_KEY_UIApplicationSceneManifest_Generation="YES")
    project["targets"]["NativeHelpUIHost"] = {
        "type": "application", "platform": platform,
        "sources": [{"path": str(root / "Tools/qualification/contextual-help/NativeHelpUIHost.swift")}, fixture],
        "dependencies": [{"target": "ConsentCore"}, {"target": "ConsentUI"}], "settings": {"base": host_settings}}
    project["targets"]["NativeHelpUITests"] = {
        "type": "bundle.ui-testing", "platform": platform,
        "sources": [{"path": str(root / "Tools/qualification/contextual-help/NativeHelpUITests.swift")}, fixture],
        "dependencies": [{"target": "NativeHelpUIHost"}],
        "settings": {"base": {"PRODUCT_BUNDLE_IDENTIFIER": "dev.djconnect.qualification.help.uitests." + platform.lower(),
                              "GENERATE_INFOPLIST_FILE": "YES"}}}
    project["schemes"] = {"NativeHelpUI": {"build": {"targets": {"NativeHelpUIHost": "all", "NativeHelpUITests": "all"}},
                                              "test": {"targets": ["NativeHelpUITests"]}}}
    project_file.write_text(json.dumps(project, indent=2) + "\n")
    subprocess.run(["xcodegen", "generate", "--spec", str(project_file), "--project", str(destination)], check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--jose-checkout", type=Path, required=True)
    parser.add_argument("--platform", choices=("iOS", "macOS"), required=True)
    args = parser.parse_args()
    prepare(args.destination.resolve(), args.jose_checkout.resolve(), args.platform)
