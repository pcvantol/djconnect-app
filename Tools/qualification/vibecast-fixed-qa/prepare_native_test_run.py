"""Prepare one exact-profile native QA run; no activation, install or SDK call.

Unsigned policy compilation can precede protected source. Signing requires the
exact clean source to be an ancestor of local origin/main. Provider admission,
final signed artifact verification and the finite user run remain separate.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
import uuid

from prepare_fixed_qa import prepare, git

NATIVE_FLAG = "DJCONNECT_VIBECAST_NATIVE_TEST_ADMISSION"


def unique_object(pairs):
    out = {}
    for key, value in pairs:
        if key in out:
            raise ValueError("Duplicate JSON member")
        out[key] = value
    return out


def run(destination: Path, jose: Path, manifest: Path, expected_source: str,
        signing_inputs: Path | None) -> None:
    root = Path(__file__).resolve().parents[3]
    if git(root, "rev-parse", "HEAD") != expected_source or git(root, "status", "--porcelain"):
        raise SystemExit("Requires the exact clean reviewed source")
    raw = manifest.read_bytes()
    if len(raw) > 8192:
        raise SystemExit("Run policy exceeds the bounded input size")
    selected = json.loads(raw, object_pairs_hook=unique_object)
    if set(selected) != {"schema", "source_sha", "policy"} or selected["schema"] != "djc-apple-native-test-run/1" or selected["source_sha"] != expected_source:
        raise SystemExit("Wrong native run source/schema")
    policy = selected["policy"]
    if set(policy) != {"identifier", "bundleID", "build", "teamID", "applicationIdentifier", "environment", "provisioningProfileSHA256", "serviceOrigin", "browserOrigin", "validFromMS", "validUntilMS"}:
        raise SystemExit("Unexpected native policy fields")
    if (policy["bundleID"], policy["teamID"], policy["applicationIdentifier"], policy["environment"], policy["serviceOrigin"], policy["browserOrigin"]) != (
        "dev.djconnect.ios.vibecastqa", "ZEML4LPXH4", "ZEML4LPXH4.dev.djconnect.ios.vibecastqa", "development", "https://api-vibecast-qa.djconnect.dev", "https://qa.vibecast.tv"):
        raise SystemExit("Only the fixed QA identity/realm is selectable")
    if str(uuid.UUID(policy["identifier"])) != policy["identifier"] or not isinstance(policy["build"], str) or not policy["build"].isdigit() or str(int(policy["build"])) != policy["build"] or int(policy["build"]) < 40407:
        raise SystemExit("Invalid finite run identity/build")
    if any(type(policy[k]) is not int for k in ("validFromMS", "validUntilMS")) or not 0 <= policy["validFromMS"] < policy["validUntilMS"] <= policy["validFromMS"] + 7_200_000 or policy["validUntilMS"] > 9_007_199_254_740_991:
        raise SystemExit("Run selection window must be finite and at most two hours")
    profile_hash = policy["provisioningProfileSHA256"]
    if not isinstance(profile_hash, str) or len(profile_hash) != 64 or any(c not in "0123456789abcdef" for c in profile_hash):
        raise SystemExit("Invalid exact provisioning-profile digest")
    signing = None
    if signing_inputs:
        git(root, "merge-base", "--is-ancestor", expected_source, "origin/main")
        entries = json.loads(signing_inputs.read_text(), object_pairs_hook=unique_object)
        if len(entries) != 1:
            raise SystemExit("Exactly one verified existing profile is required")
        signing = entries[0]
        if (signing["profile_sha256"] != profile_hash or signing["team"] != ["ZEML4LPXH4"] or signing["prefix"] != ["ZEML4LPXH4"] or signing["development"] is not True or signing["attest_environment"] not in (None, "development")):
            raise SystemExit("Signing inputs disagree with the selected native policy")
        if hashlib.sha256(Path(signing["profile_path"]).read_bytes()).hexdigest() != profile_hash:
            raise SystemExit("Existing signing profile changed")
    prepare(destination, jose)
    policy_file = destination / "native-run-policy.json"
    policy_file.write_text(json.dumps(policy, sort_keys=True, separators=(",", ":")) + "\n")
    encoded = base64.b64encode(policy_file.read_bytes()).decode("ascii")
    source_file = destination / "SelectedNativeRun.swift"
    source_file.write_text('import Foundation\n// Exact reviewed build input; no runtime selector.\nenum RendezvousSelectedNativeTestPolicy {\n    static let value = try! JSONDecoder().decode(RendezvousNativeRunPolicy.self, from: Data(base64Encoded: "' + encoded + '")!)\n}\n')
    spec_file = destination / "project.json"
    spec = json.loads(spec_file.read_text())
    core = spec["targets"]["FixedQACoreIOS"]
    core["sources"].append({"path": str(source_file)})
    core["settings"]["base"]["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "$(inherited) " + NATIVE_FLAG
    app = spec["targets"]["VibeCastFixedQAIOS"]
    app["info"]["properties"].update({"CFBundleVersion": policy["build"], "DJConnectNativeRunID": policy["identifier"]})
    if signing:
        spec["settings"]["base"].update({"CODE_SIGNING_ALLOWED": "YES", "CODE_SIGNING_REQUIRED": "YES", "CODE_SIGN_STYLE": "Manual", "DEVELOPMENT_TEAM": "ZEML4LPXH4", "CODE_SIGN_IDENTITY": signing["signer_sha1"]})
        entitlements = destination / "QA.entitlements"
        entitlements.write_bytes(plistlib.dumps({"application-identifier": policy["applicationIdentifier"], "com.apple.developer.team-identifier": "ZEML4LPXH4", "get-task-allow": True, "keychain-access-groups": [policy["applicationIdentifier"]]}))
        app["settings"]["base"].update({"CODE_SIGN_STYLE": "Automatic", "CODE_SIGN_ENTITLEMENTS": str(entitlements)})
    spec_file.write_text(json.dumps(spec, indent=2) + "\n")
    descriptor_file = destination / "source-inputs.json"
    descriptor = json.loads(descriptor_file.read_text())
    descriptor["inputs"][str(Path(__file__).resolve().relative_to(root))] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    descriptor.update({"scope": "SIGNED_NATIVE_TEST_PROPOSAL_NOT_ACTIVATED" if signing else "UNSIGNED_NATIVE_POLICY_COMPILE_ONLY", "signing": "EXISTING_DEVELOPMENT_PROFILE" if signing else "DISABLED", "current_apple_profile": None, "activation_allowed": False,
                       "native_run_identifier": policy["identifier"], "native_run_lifetime_seconds": 600,
                       "native_run_effects": {"generateKey": 1, "attestKey": 1, "generateAssertion": 1},
                       "qualification_inputs": {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in (policy_file, source_file, spec_file)}})
    descriptor_file.write_text(json.dumps(descriptor, indent=2) + "\n")
    subprocess.run(["xcodegen", "generate", "--spec", str(spec_file), "--project", str(destination)], check=True)
    print("Native test proposal prepared; SDK/installation/provider activation remain separate")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--jose-checkout", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--expected-source", required=True)
    parser.add_argument("--signing-inputs", type=Path)
    args = parser.parse_args()
    run(args.destination.resolve(), args.jose_checkout.resolve(), args.manifest.resolve(), args.expected_source, args.signing_inputs)
