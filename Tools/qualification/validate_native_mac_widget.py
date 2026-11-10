#!/usr/bin/env python3
"""Qualify the signed DJConnect app and widget, with optional APNs evidence."""
import argparse
import hashlib
import json
import plistlib
from pathlib import Path
import subprocess
import sys


def entitlements(bundle):
    result = subprocess.run(["codesign", "-d", "--entitlements", ":-", str(bundle)], capture_output=True)
    data = result.stdout + result.stderr
    start, end = data.find(b"<?xml"), data.find(b"</plist>")
    if result.returncode or start < 0 or end < 0:
        raise ValueError("signed entitlements unavailable")
    return plistlib.loads(data[start:end + len(b"</plist>")])


def push_evidence(app, widget, info, wi, platform, environment):
    def identity(bundle, metadata):
        executable = metadata["CFBundleExecutable"]
        if not executable or Path(executable).name != executable or executable in (".", ".."):
            raise ValueError("invalid signed executable name")
        binary = bundle / "Contents/MacOS" / executable if platform == "MacOSX" else bundle / executable
        digest = hashlib.sha256()
        with binary.open("rb") as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
        return {
            "bundle_id": metadata["CFBundleIdentifier"],
            "build": metadata["CFBundleVersion"],
            "executable_sha256": digest.hexdigest(),
        }

    return {
        "schema_version": 1,
        "platform": platform,
        "apns_environment": "sandbox" if environment == "development" else "production",
        "host": identity(app, info),
        "widget": identity(widget, wi),
    }


def validate(app, require_widget_push=False, *, mobile=False, emit_evidence=False):
    root = app if mobile else app / "Contents"
    platform = "iPhoneOS" if mobile else "MacOSX"
    widget = root / "PlugIns/DJConnectWidget.appex"
    check_push = mobile or require_widget_push or emit_evidence
    if check_push:
        for bundle in (app, widget):
            result = subprocess.run(["codesign", "--verify", "--strict", str(bundle)], capture_output=True)
            if result.returncode:
                raise ValueError("strict signature verification failed for " + bundle.name)
    info = plistlib.loads((root / "Info.plist").read_bytes())
    wi = plistlib.loads(((widget if mobile else widget / "Contents") / "Info.plist").read_bytes())
    rights, parent_rights = entitlements(widget), entitlements(app)
    schemes = [scheme for item in info.get("CFBundleURLTypes", []) for scheme in item.get("CFBundleURLSchemes", [])]
    checks = {
        "app registers djconnect URL scheme": "djconnect" in schemes,
        "native widget has expected platform": wi.get("CFBundleSupportedPlatforms") == [platform],
        "native WidgetKit extension point": wi.get("NSExtension", {}).get("NSExtensionPointIdentifier") == "com.apple.widgetkit-extension",
        "widget identifier belongs to app": wi.get("CFBundleIdentifier", "").startswith(info["CFBundleIdentifier"] + "."),
        "widget and app share DJConnect group": all("group.dev.djconnect" in r.get("com.apple.security.application-groups", []) for r in (rights, parent_rights)),
        "widget and app share signing team": bool(rights.get("com.apple.developer.team-identifier")) and rights.get("com.apple.developer.team-identifier") == parent_rights.get("com.apple.developer.team-identifier"),
    }
    if not mobile:
        checks["native widget is sandboxed"] = rights.get("com.apple.security.app-sandbox") is True
    if check_push:
        key = "aps-environment" if mobile else "com.apple.developer.aps-environment"
        environment = rights.get(key)
        host_id = "dev.djconnect.ios" if mobile else "dev.djconnect.mac"
        checks["signed artifact has expected host and widget identifiers"] = (
            info.get("CFBundleIdentifier") == host_id
            and wi.get("CFBundleIdentifier") == host_id + ".track-insight-widget"
        )
        checks["widget has APNs entitlement matching parent"] = (
            environment in ("development", "production") and environment == parent_rights.get(key)
        )
        checks["widget and app have matching build"] = bool(wi.get("CFBundleVersion")) and wi.get("CFBundleVersion") == info.get("CFBundleVersion")
    for label, passed in checks.items():
        print(("PASS" if passed else "FAIL") + ": " + label, file=sys.stderr if emit_evidence else sys.stdout)
    if not all(checks.values()):
        return False
    if emit_evidence:
        print(json.dumps(push_evidence(app, widget, info, wi, platform, environment), sort_keys=True))
    return True


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    parser.add_argument("--require-widget-push", action="store_true")
    parser.add_argument("--mobile", action="store_true", help="qualify a final signed iPhoneOS app, including its embedded widget")
    parser.add_argument("--push-evidence", action="store_true", help="print JSON evidence only after both signatures verify")
    args = parser.parse_args()
    try:
        ok = validate(args.app, require_widget_push=args.require_widget_push,
                      mobile=args.mobile, emit_evidence=args.push_evidence)
    except (KeyError, OSError, ValueError, plistlib.InvalidFileException) as error:
        print("FAIL: widget artifact unqualified: " + str(error), file=sys.stderr)
        ok = False
    raise SystemExit(0 if ok else 1)
