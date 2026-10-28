"""Isolated render tests importing actual Core/UI sources, no push activation.

This does not prove shipping membership: build the real app/extension separately.
Destinations must be new external scratch directories. Existing Tools prototype
codecs/views are deliberately absent from this target.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET


def prepare(destination: Path, jose: Path, platform: str) -> None:
    root = Path(__file__).resolve().parents[3]
    helper = root / "Tools/qualification/vibecast-product/prepare_native_consent_tests.py"
    spec = importlib.util.spec_from_file_location("consent_preparation", helper)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.prepare(destination, jose, platform=platform)
    path = destination / "project.json"
    project = json.loads(path.read_text())
    project["name"] = "ShippingStatusComponents"
    project["targets"] = {key: project["targets"][key] for key in ("ConsentCore", "ConsentUI")}
    project["targets"]["ShippingStatusRenderTests"] = {
        "type": "bundle.unit-test", "platform": platform,
        "sources": [{"path": str(root / "Tools/qualification/status-only-push/ShippingStatusRenderTests.swift")}],
        "dependencies": [{"target": "ConsentCore"}, {"target": "ConsentUI"}],
        "settings": {"base": {"PRODUCT_BUNDLE_IDENTIFIER": "dev.djconnect.qualification.shippingstatus." + platform.lower(),
                               "GENERATE_INFOPLIST_FILE": "YES"}}}
    project["schemes"] = {"ShippingStatus": {"build": {"targets": {"ShippingStatusRenderTests": "all"}},
                                              "test": {"targets": ["ShippingStatusRenderTests"]}}}
    path.write_text(json.dumps(project, indent=2) + "\n")
    subprocess.run(["xcodegen", "generate", "--spec", str(path), "--project", str(destination)], check=True)
    scheme = destination / "ShippingStatusComponents.xcodeproj/xcshareddata/xcschemes/ShippingStatus.xcscheme"
    tree = ET.parse(scheme)
    action = tree.getroot().find("TestAction")
    action.set("shouldUseLaunchSchemeArgsEnv", "NO")
    env = ET.SubElement(action, "EnvironmentVariables")
    ET.SubElement(env, "EnvironmentVariable", key="DJCONNECT_STATUS_SHIPPING_ARTIFACTS",
                  value=str(destination / "observations"), isEnabled="YES")
    tree.write(scheme, encoding="UTF-8", xml_declaration=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--jose-checkout", type=Path, required=True)
    parser.add_argument("--platform", choices=("iOS", "macOS"), required=True)
    args = parser.parse_args()
    prepare(args.destination.resolve(), args.jose_checkout.resolve(), args.platform)
