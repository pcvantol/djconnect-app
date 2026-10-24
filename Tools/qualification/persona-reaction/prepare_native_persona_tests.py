"""Generate an isolated native avatar-input component project; no shipping flags.

The host renders the production presentation component with a synthetic counter.
It never constructs AppModel, pairs, sends a reaction or prepares/plays speech.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import subprocess


def prepare(destination: Path, jose: Path, platform: str) -> None:
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
    project["name"] = "NativePersonaReactionQualification"
    project["targets"] = {k: v for k, v in project["targets"].items() if k in ("ConsentCore", "ConsentUI")}
    host_settings = {"PRODUCT_BUNDLE_IDENTIFIER": "dev.djconnect.qualification.persona." + platform.lower(),
                     "GENERATE_INFOPLIST_FILE": "YES"}
    if platform == "iOS":
        host_settings.update(INFOPLIST_KEY_UILaunchScreen_Generation="YES", INFOPLIST_KEY_UIApplicationSceneManifest_Generation="YES")
    project["targets"]["NativePersonaReactionHost"] = {
        "type": "application", "platform": platform,
        "sources": [{"path": str(root / "Tools/qualification/persona-reaction/NativePersonaReactionHost.swift")}],
        "dependencies": [{"target": "ConsentCore"}, {"target": "ConsentUI"}], "settings": {"base": host_settings}}
    project["targets"]["NativePersonaReactionUITests"] = {
        "type": "bundle.ui-testing", "platform": platform,
        "sources": [{"path": str(root / "Tools/qualification/persona-reaction/NativePersonaReactionUITests.swift")}],
        "dependencies": [{"target": "NativePersonaReactionHost"}],
        "settings": {"base": {"PRODUCT_BUNDLE_IDENTIFIER": "dev.djconnect.qualification.persona.uitests." + platform.lower(),
                              "GENERATE_INFOPLIST_FILE": "YES"}}}
    project["schemes"] = {"NativePersonaReaction": {"build": {"targets": {"NativePersonaReactionHost": "all", "NativePersonaReactionUITests": "all"}},
                                              "test": {"targets": ["NativePersonaReactionUITests"]}}}
    project_file.write_text(json.dumps(project, indent=2) + "\n")
    subprocess.run(["xcodegen", "generate", "--spec", str(project_file), "--project", str(destination)], check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--jose-checkout", type=Path, required=True)
    parser.add_argument("--platform", choices=("iOS",), required=True)
    args = parser.parse_args()
    prepare(args.destination.resolve(), args.jose_checkout.resolve(), args.platform)
