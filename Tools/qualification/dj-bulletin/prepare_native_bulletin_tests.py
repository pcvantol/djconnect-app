"""Generate a new disposable Bulletin view qualification project; no shipping flags.

The checked-in producer fixture stays byte-identical. The host only renders the
existing MomentCard; it cannot publish, pair, fetch RSS or prepare/play speech.
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
    project["name"] = "NativeBulletinQualification"
    project["targets"] = {k: v for k, v in project["targets"].items() if k in ("ConsentCore", "ConsentUI")}
    fixture = {"path": str(root / "Tests/Fixtures/dj-bulletin-v1-core-12675bc-wire.json"), "buildPhase": "resources"}
    host_settings = {"PRODUCT_BUNDLE_IDENTIFIER": "dev.djconnect.qualification.bulletin." + platform.lower(),
                     "GENERATE_INFOPLIST_FILE": "YES"}
    if platform == "iOS":
        host_settings.update(INFOPLIST_KEY_UILaunchScreen_Generation="YES", INFOPLIST_KEY_UIApplicationSceneManifest_Generation="YES")
    project["targets"]["NativeBulletinUIHost"] = {
        "type": "application", "platform": platform,
        "sources": [{"path": str(root / "Tools/qualification/dj-bulletin/NativeBulletinUIHost.swift")}, fixture],
        "dependencies": [{"target": "ConsentCore"}, {"target": "ConsentUI"}], "settings": {"base": host_settings}}
    project["targets"]["NativeBulletinUITests"] = {
        "type": "bundle.ui-testing", "platform": platform,
        "sources": [{"path": str(root / "Tools/qualification/dj-bulletin/NativeBulletinUITests.swift")}, fixture],
        "dependencies": [{"target": "NativeBulletinUIHost"}],
        "settings": {"base": {"PRODUCT_BUNDLE_IDENTIFIER": "dev.djconnect.qualification.bulletin.uitests." + platform.lower(),
                              "GENERATE_INFOPLIST_FILE": "YES"}}}
    project["schemes"] = {"NativeBulletinUI": {"build": {"targets": {"NativeBulletinUIHost": "all", "NativeBulletinUITests": "all"}},
                                              "test": {"targets": ["NativeBulletinUITests"]}}}
    project_file.write_text(json.dumps(project, indent=2) + "\n")
    subprocess.run(["xcodegen", "generate", "--spec", str(project_file), "--project", str(destination)], check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--jose-checkout", type=Path, required=True)
    parser.add_argument("--platform", choices=("iOS", "macOS"), required=True)
    args = parser.parse_args()
    prepare(args.destination.resolve(), args.jose_checkout.resolve(), args.platform)
