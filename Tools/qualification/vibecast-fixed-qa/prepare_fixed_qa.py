"""Generate a separate unsigned, fixed-origin VibeCast QA build and contract tests.

No runtime environment/host selector, signing, installation, SDK, key generation
or network execution. The normal shipping project is never changed by this tool.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess

JOSE_PIN = "c2664a902e75c0426a1d43132bd4babc6fd173d3"
FLAG = "DJCONNECT_VIBECAST_FIXED_QA"
TEST_SOURCES = ("RendezvousBuildProfileTests.swift", "RendezvousDestinationTests.swift",
                "RendezvousSubmitChallengeTests.swift", "RendezvousRecoveryJournalTests.swift",
                "RendezvousSubmissionTests.swift", "RendezvousNativeFlowTests.swift",
                "RendezvousRecoveryChallengeTests.swift", "RendezvousNativeRunGateTests.swift")


def git(root: Path, *args: str) -> str:
    environment = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
    return subprocess.check_output(["git", "--no-replace-objects", "-C", str(root), *args],
                                   env=environment, text=True).strip()


def prepare(destination: Path, jose: Path) -> None:
    root = Path(__file__).resolve().parents[3]
    if Path(git(root, "rev-parse", "--show-toplevel")).resolve() != root:
        raise SystemExit("Expected the actual Apple repository")
    if git(jose, "rev-parse", "HEAD") != JOSE_PIN or git(jose, "status", "--porcelain"):
        raise SystemExit("JOSESwift must be the clean, existing shipping pin")
    destination.mkdir(parents=True, exist_ok=False)
    # Preserve existing camera/audio/network privacy copy for the real scanner
    # UI, while keeping a distinct QA identity and URL scheme. No production
    # signing profile, entitlement or shared container is copied.
    qa_info = plistlib.loads((root / "Apps/DJConnectIOS/Info.plist").read_bytes())
    qa_info.update({"CFBundleDisplayName": "DJConnect VibeCast QA", "CFBundleShortVersionString": "4.0.0",
                    "CFBundleVersion": "40406", "DJConnectRendezvousBuildFlavor": "fixed-qa",
                    "CFBundleURLTypes": [{"CFBundleURLSchemes": ["djconnect-vibecast-qa"]}]})

    def framework(name: str, module: str, platform: str, directory: str, dependencies: list) -> dict:
        return {"type": "framework", "platform": platform, "sources": [{"path": str(root / directory)}],
                "dependencies": dependencies, "settings": {"base": {
                    "PRODUCT_BUNDLE_IDENTIFIER": "dev.djconnect.qualification.fixedqa." + name.lower(),
                    "PRODUCT_NAME": module, "PRODUCT_MODULE_NAME": module,
                    "GENERATE_INFOPLIST_FILE": "YES", "ENABLE_TESTABILITY": "YES"}}}

    project = {
        "name": "VibeCastFixedQA",
        "options": {"deploymentTarget": {"iOS": "26.0", "macOS": "26.0"}},
        "settings": {"base": {"SWIFT_VERSION": "6.0", "CODE_SIGNING_ALLOWED": "NO",
                              "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "$(inherited) " + FLAG}},
        "packages": {"JOSESwift": {"path": str(jose)}},
        "targets": {
            "FixedQACoreMac": framework("coremac", "DJConnectCore", "macOS", "Sources/DJConnectCore", [{"package": "JOSESwift"}]),
            "FixedQACoreIOS": framework("coreios", "DJConnectCore", "iOS", "Sources/DJConnectCore", [{"package": "JOSESwift"}]),
            "FixedQAUIIOS": framework("uiios", "DJConnectUI", "iOS", "Sources/DJConnectUI", [{"target": "FixedQACoreIOS"}]),
            "FixedQAContractTests": {
                "type": "bundle.unit-test", "platform": "macOS",
                "sources": [{"path": str(root / "Tests/DJConnectCoreTests" / name)} for name in TEST_SOURCES] + [
                    {"path": str(root / "Tests/Fixtures" / name), "buildPhase": "resources"} for name in
                    ("rendezvous-fixed-qa-api-3b43332.json", "rendezvous-fixed-qa-wire-3b43332.json")],
                "dependencies": [{"target": "FixedQACoreMac"}, {"package": "JOSESwift"}],
                "settings": {"base": {"PRODUCT_BUNDLE_IDENTIFIER": "dev.djconnect.qualification.fixedqa.tests",
                                      "GENERATE_INFOPLIST_FILE": "YES"}}},
            "VibeCastFixedQAIOS": {
                "type": "application", "platform": "iOS",
                "sources": [{"path": str(root / "Apps/DJConnectIOS"), "excludes": ["Info.plist"]},
                            {"path": str(root / "Apps/Shared/Assets.xcassets")},
                            {"path": str(root / "Apps/Shared/AppIconAdaptive.icon")}],
                "dependencies": [{"target": "FixedQACoreIOS"}, {"target": "FixedQAUIIOS"}],
                "info": {"path": str(destination / "FixedQA-Info.plist"), "properties": qa_info},
                "settings": {"base": {"PRODUCT_BUNDLE_IDENTIFIER": "dev.djconnect.ios.vibecastqa",
                                      "PRODUCT_NAME": "DJConnectVibeCastQA", "TARGETED_DEVICE_FAMILY": "1,2",
                                      "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIconAdaptive"}}}},
        "schemes": {
            "FixedQAContractTests": {"build": {"targets": {"FixedQAContractTests": "all"}},
                                     "test": {"targets": ["FixedQAContractTests"], "parallelizable": False}},
            "VibeCastFixedQAIOS": {"build": {"targets": {"VibeCastFixedQAIOS": "all"}}}}}
    spec = destination / "project.json"
    spec.write_text(json.dumps(project, indent=2) + "\n")
    files = [path for directory in ("Sources/DJConnectCore", "Sources/DJConnectUI", "Apps/DJConnectIOS", "Apps/Shared/Assets.xcassets", "Apps/Shared/AppIconAdaptive.icon")
             for path in (root / directory).rglob("*") if path.is_file()]
    files += [root / "Tests/DJConnectCoreTests" / name for name in TEST_SOURCES]
    files += [root / "Tests/Fixtures" / name for name in ("rendezvous-fixed-qa-api-3b43332.json", "rendezvous-fixed-qa-wire-3b43332.json")]
    files += [Path(__file__).resolve()]
    dirty = bool(git(root, "status", "--porcelain"))
    descriptor = {"scope": "UNSIGNED_FIXED_QA_BUILD_ONLY_NO_OPERATIONAL_ADMISSION", "base_sha": git(root, "rev-parse", "HEAD"),
                  "source_dirty": dirty, "source_sha": None if dirty else git(root, "rev-parse", "HEAD"),
                  "inputs": {str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest() for path in files},
                  "app_bundle_id": "dev.djconnect.ios.vibecastqa", "condition": FLAG,
                  "service": "djconnect-api-vibecast-qa", "service_origin": "https://api-vibecast-qa.djconnect.dev",
                  "browser_origin": "https://qa.vibecast.tv",
                  "activation_allowed": False, "signing": "DISABLED", "current_apple_profile": None}
    (destination / "source-inputs.json").write_text(json.dumps(descriptor, indent=2) + "\n")
    subprocess.run(["xcodegen", "generate", "--spec", str(spec), "--project", str(destination)], check=True)
    print(destination / "VibeCastFixedQA.xcodeproj")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--jose-checkout", type=Path, required=True)
    args = parser.parse_args()
    prepare(args.destination.resolve(), args.jose_checkout.resolve())
