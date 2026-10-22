#!/usr/bin/env python3
"""Validate the signed Mac artifact needed for native widget discovery/opening."""
import argparse
import plistlib
from pathlib import Path
import subprocess


def entitlements(bundle):
    result = subprocess.run(["codesign", "-d", "--entitlements", ":-", str(bundle)], capture_output=True)
    data = result.stdout + result.stderr
    start, end = data.find(b"<?xml"), data.find(b"</plist>")
    if result.returncode or start < 0 or end < 0:
        raise ValueError("signed entitlements unavailable")
    return plistlib.loads(data[start:end + len(b"</plist>")])


def validate(app):
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    widget = app / "Contents/PlugIns/TrackInsightWidget.appex"
    wi = plistlib.loads((widget / "Contents/Info.plist").read_bytes())
    rights, parent_rights = entitlements(widget), entitlements(app)
    schemes = [scheme for item in info.get("CFBundleURLTypes", []) for scheme in item.get("CFBundleURLSchemes", [])]
    checks = {
        "Mac app registers djconnect URL scheme": "djconnect" in schemes,
        "native widget is sandboxed": rights.get("com.apple.security.app-sandbox") is True,
        "native widget has Mac platform": wi.get("CFBundleSupportedPlatforms") == ["MacOSX"],
        "native WidgetKit extension point": wi.get("NSExtension", {}).get("NSExtensionPointIdentifier") == "com.apple.widgetkit-extension",
        "widget identifier belongs to Mac app": wi.get("CFBundleIdentifier", "").startswith(info["CFBundleIdentifier"] + "."),
        "widget and app share DJConnect group": all("group.dev.djconnect" in r.get("com.apple.security.application-groups", []) for r in (rights, parent_rights)),
        "widget and app share signing team": bool(rights.get("com.apple.developer.team-identifier")) and rights.get("com.apple.developer.team-identifier") == parent_rights.get("com.apple.developer.team-identifier"),
    }
    for label, passed in checks.items():
        print(("PASS" if passed else "FAIL") + ": " + label)
    return all(checks.values())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    args = parser.parse_args()
    try:
        ok = validate(args.app)
    except (OSError, ValueError, plistlib.InvalidFileException) as error:
        print("FAIL: Mac widget artifact unreadable: " + str(error))
        ok = False
    raise SystemExit(0 if ok else 1)
