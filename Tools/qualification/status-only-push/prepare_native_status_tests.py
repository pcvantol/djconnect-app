"""Isolated native status codec/view proposal tests. No shipping registration."""
import argparse
import importlib.util
import json
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET


def prepare(destination: Path, jose: Path, platform: str) -> None:
    root = Path(__file__).resolve().parents[3]
    helper = root / "Tools/qualification/vibecast-product/prepare_native_consent_tests.py"
    spec = importlib.util.spec_from_file_location("status_preparation", helper)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.prepare(destination, jose, platform=platform)
    file = destination / "project.json"
    project = json.loads(file.read_text())
    project["name"] = "NativeStatusOnlyProposal"
    project["targets"] = {"ConsentCore": project["targets"]["ConsentCore"]}
    own = root / "Tools/qualification/status-only-push"
    sources = [{"path": str(own / f)} for f in ("StatusOnlyCandidateCodec.swift", "StatusOnlyCandidateView.swift", "StatusOnlyCandidateTests.swift")]
    fixtures = {
        "activity-status-attributes-v1.schema.json", "activity-status-profile-tuple.json",
        "activity-status-v1.schema.json", "status-only-contract-candidate.json",
        "status-only-wire-vectors.json", "widget-status-observation-v1.schema.json"}
    actual = {p.name for p in (own / "fixtures").iterdir() if p.is_file()}
    if actual != fixtures:
        raise SystemExit("Only the exact six private contract fixtures may enter this test bundle")
    sources += [{"path": str(own / "fixtures" / name), "buildPhase": "resources"} for name in sorted(fixtures)]
    project["targets"]["StatusOnlyTests"] = {
        "type": "bundle.unit-test", "platform": platform, "sources": sources,
        "dependencies": [{"target": "ConsentCore"}],
        "settings": {"base": {"PRODUCT_BUNDLE_IDENTIFIER": "dev.djconnect.qualification.statusonly." + platform.lower(), "GENERATE_INFOPLIST_FILE": "YES"}}}
    project["schemes"] = {"StatusOnly": {"build": {"targets": {"StatusOnlyTests": "all"}}, "test": {"targets": ["StatusOnlyTests"]}}}
    file.write_text(json.dumps(project, indent=2) + "\n")
    subprocess.run(["xcodegen", "generate", "--spec", str(file), "--project", str(destination)], check=True)
    scheme = destination / "NativeStatusOnlyProposal.xcodeproj/xcshareddata/xcschemes/StatusOnly.xcscheme"
    tree = ET.parse(scheme); action = tree.getroot().find("TestAction")
    action.set("shouldUseLaunchSchemeArgsEnv", "NO")
    env = ET.SubElement(action, "EnvironmentVariables")
    ET.SubElement(env, "EnvironmentVariable", key="DJCONNECT_STATUS_PROPOSAL_ARTIFACTS", value=str(destination / "observations"), isEnabled="YES")
    tree.write(scheme, encoding="UTF-8", xml_declaration=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--jose-checkout", type=Path, required=True)
    parser.add_argument("--platform", choices=("iOS", "macOS"), required=True)
    args = parser.parse_args()
    prepare(args.destination.resolve(), args.jose_checkout.resolve(), args.platform)
