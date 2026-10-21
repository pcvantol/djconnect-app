"""Generate an isolated iOS test project without changing shipping targets.

Uses the existing consent tests, real Core/UI sources and two checked-in
producer fixtures. No device credentials, live HA or App Attest are used.
XcodeGen must be installed; JOSESwift must already exist at its pinned checkout.
The destination must be a new directory so previous evidence is preserved.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess


def prepare(destination: Path, jose: Path, with_ui: bool = False, with_summary: bool = False) -> None:
    root = Path(__file__).resolve().parents[3]
    expected = "c2664a902e75c0426a1d43132bd4babc6fd173d3"
    actual = subprocess.check_output(["git", "-C", str(jose), "rev-parse", "HEAD"], text=True).strip()
    if actual != expected:
        raise SystemExit("JOSESwift checkout does not match the shipping pin")
    if subprocess.check_output(["git", "-C", str(jose), "status", "--porcelain"], text=True).strip():
        raise SystemExit("JOSESwift checkout has local changes")
    destination.mkdir(parents=True, exist_ok=False)

    def framework(name: str, module: str, source: str, dependencies: list) -> dict:
        return {"type": "framework", "platform": "iOS", "sources": [{"path": str(root / source)}],
                "dependencies": dependencies, "settings": {"base": {
                    "PRODUCT_BUNDLE_IDENTIFIER": "dev.djconnect.qualification." + name,
                    "PRODUCT_NAME": module, "PRODUCT_MODULE_NAME": module,
                    "GENERATE_INFOPLIST_FILE": "YES", "ENABLE_TESTABILITY": "YES"}}}

    project = {
        "name": "NativeConsentQualification",
        "options": {"deploymentTarget": {"iOS": "26.0"}},
        "settings": {"base": {"SWIFT_VERSION": "6.0", "CODE_SIGNING_ALLOWED": "NO"}},
        "packages": {"JOSESwift": {"path": str(jose.resolve())}},
        "targets": {
            "ConsentCore": framework("core", "DJConnectCore", "Sources/DJConnectCore", [{"package": "JOSESwift"}]),
            "ConsentUI": framework("ui", "DJConnectUI", "Sources/DJConnectUI", [{"target": "ConsentCore"}]),
            "NativeConsentTests": {
                "type": "bundle.unit-test", "platform": "iOS",
                "sources": [{"path": str(root / "Tests/DJConnectCoreTests/DisplayConsentSessionTests.swift")}] + [
                    {"path": str(root / "Tests/Fixtures" / name), "buildPhase": "resources"}
                    for name in ("session-history-active-session-before-auth-failure.json", "session-history-producer-receipt.json")],
                "dependencies": [{"target": "ConsentCore"}, {"target": "ConsentUI"}],
                "settings": {"base": {"PRODUCT_BUNDLE_IDENTIFIER": "dev.djconnect.qualification.nativeconsent.tests",
                                      "GENERATE_INFOPLIST_FILE": "YES"}}}},
        "schemes": {"NativeConsentTests": {"build": {"targets": {"NativeConsentTests": "all"}},
                                         "test": {"targets": ["NativeConsentTests"]}}}}
    if with_summary:
        project["targets"]["NativeConsentTests"]["sources"].append({
            "path": str(root / "Tests/Fixtures/session-history-summary-final-list.json"), "buildPhase": "resources"})
        project["targets"]["NativeSummaryTests"] = {
            "type": "bundle.unit-test", "platform": "iOS",
            "sources": [{"path": str(root / "Tools/qualification/native-history-summary/NativeHistorySummaryTests.swift")}] + [
                {"path": str(root / "Tests/Fixtures" / name), "buildPhase": "resources"}
                for name in ("session-history-summary-final-list.json", "session-history-summary-final-detail.json", "session-history-summary-summary-states.json",
                             "session-history-summary-provenance.json")],
            "dependencies": [{"target": "ConsentCore"}, {"target": "ConsentUI"}],
            "settings": {"base": {"PRODUCT_BUNDLE_IDENTIFIER": "dev.djconnect.qualification.nativesummary.tests",
                                  "GENERATE_INFOPLIST_FILE": "YES"}}}
        project["schemes"]["NativeSummaryTests"] = {
            "build": {"targets": {"NativeSummaryTests": "all"}},
            "test": {"targets": ["NativeSummaryTests"]}}
    if with_ui:
        # Reuse exactly the test wire implementation in the disposable host.
        # Test-only imports and suites are excluded; production sources are not
        # copied or patched. Keep the generated wire beside its project evidence.
        source = (root / "Tests/DJConnectCoreTests/DisplayConsentSessionTests.swift").read_text()
        wire = source.split("private let consentEpoch", 1)[1].split("@Suite(.serialized)", 1)[0]
        wire = "import Foundation\nprivate let consentEpoch" + wire
        wire = wire.replace("private final class ConsentWire:", "final class ConsentWire:", 1)
        wire_path = destination / "ConsentWire.swift"
        wire_path.write_text(wire)
        project["targets"]["NativeConsentUIHost"] = {
            "type": "application", "platform": "iOS",
            "sources": [{"path": str(root / "Tools/qualification/vibecast-product/NativeConsentUIHost.swift")},
                        {"path": str(wire_path)}] + project["targets"]["NativeConsentTests"]["sources"][1:],
            "dependencies": [{"target": "ConsentCore"}, {"target": "ConsentUI"}],
            "settings": {"base": {
                "PRODUCT_BUNDLE_IDENTIFIER": "dev.djconnect.qualification.nativeconsent.host",
                "GENERATE_INFOPLIST_FILE": "YES", "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
                "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES"}}}
        project["targets"]["NativeConsentUITests"] = {
            "type": "bundle.ui-testing", "platform": "iOS",
            "sources": [{"path": str(root / "Tools/qualification/vibecast-product/NativeConsentUITests.swift")}],
            "dependencies": [{"target": "NativeConsentUIHost"}],
            "settings": {"base": {"PRODUCT_BUNDLE_IDENTIFIER": "dev.djconnect.qualification.nativeconsent.uitests",
                                  "GENERATE_INFOPLIST_FILE": "YES"}}}
        project["schemes"]["NativeConsentUI"] = {
            "build": {"targets": {"NativeConsentUIHost": "all", "NativeConsentUITests": "all"}},
            "test": {"targets": ["NativeConsentUITests"]}}
    spec = destination / "project.json"
    spec.write_text(json.dumps(project, indent=2) + "\n")
    subprocess.run(["xcodegen", "generate", "--spec", str(spec), "--project", str(destination)], check=True)
    print(destination / "NativeConsentQualification.xcodeproj")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--jose-checkout", type=Path, required=True)
    parser.add_argument("--with-ui", action="store_true", help="Include the isolated production-form host and native tap tests")
    parser.add_argument("--with-summary", action="store_true", help="Include an isolated native historical-summary component test target")
    args = parser.parse_args()
    prepare(args.destination.resolve(), args.jose_checkout.resolve(), args.with_ui, args.with_summary)
