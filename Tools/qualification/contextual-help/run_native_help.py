#!/usr/bin/env python3
"""Explicit, provider-free native Help regression; never run as ordinary PR CI.

This component suite does not send commands, pair a client, synthesize speech,
or qualify Core/provider effects. Live Golden execution remains separately armed.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
TESTS = [
    "testEveryPublishedNLENHelpOptionForwardsItsOriginalPromptOnBothSurfaces",
    "testCurrentCatalogueSuggestionsForwardExactlyTheDisplayedText",
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=["iOS", "macOS"], required=True)
    parser.add_argument("--destination", required=True)
    parser.add_argument("--jose-checkout", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.platform == "iOS" and not args.destination.startswith("platform=iOS Simulator,id="):
        parser.error("Use an explicitly selected iPhone/iPad simulator; physical staging is separate")
    if args.platform == "macOS" and args.destination != "platform=macOS":
        parser.error("Use platform=macOS")
    output = args.output.resolve()
    if output == ROOT or ROOT in output.parents:
        parser.error("Use a new external output directory")
    output.mkdir(parents=True, exist_ok=False)
    (output / "tmp").mkdir()
    env = dict(os.environ, TMPDIR=str(output / "tmp"))
    report = {"scope": "native_help_component", "status": "RUNNING", "platform": args.platform,
              "destination": args.destination, "languages": ["nl", "en"],
              "surfaces": ["ask_dj", "active_session"], "expected_catalogue_selections": 56,
              "expected_suggestion_selections": 12, "provider_calls": 0,
              "backend_execution": "NOT_RUN", "live_watch": "NOT_RUN", "audio": "NOT_RUN",
              "source_sha": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "source_diff_sha256": hashlib.sha256(subprocess.check_output(["git", "diff", "--binary", "HEAD"], cwd=ROOT)).hexdigest()}
    receipt = output / "receipt.json"
    try:
        with (output / "prepare.log").open("w") as log:
            subprocess.run([sys.executable, str(Path(__file__).with_name("prepare_native_help_tests.py")),
                str(output / "project"), "--jose-checkout", str(args.jose_checkout.resolve()),
                "--platform", args.platform], check=True, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
        command = ["xcodebuild", "test", "-project", str(output / "project/NativeHelpQualification.xcodeproj"),
            "-scheme", "NativeHelpUI", "-destination", args.destination,
            "-derivedDataPath", str(output / "derived"), "-resultBundlePath", str(output / "native.xcresult"),
            "-parallel-testing-enabled", "NO", "CODE_SIGNING_ALLOWED=NO"]
        command.extend("-only-testing:NativeHelpUITests/NativeHelpUITests/" + name for name in TESTS)
        with (output / "native.log").open("w") as log:
            subprocess.run(command, check=True, timeout=1500, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
        report["status"] = "PASS_NATIVE_COMPONENT_ONLY"
    except (subprocess.SubprocessError, OSError):
        report["status"] = "FAIL_OR_INCOMPLETE"
    finally:
        receipt.write_text(json.dumps(report, indent=2) + "\n")
    print(report["status"])
    return int(report["status"] != "PASS_NATIVE_COMPONENT_ONLY")


if __name__ == "__main__":
    raise SystemExit(main())
