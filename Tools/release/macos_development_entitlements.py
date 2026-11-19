"""Validate an explicit macOS development profile before deriving signing entitlements."""

import datetime
import hashlib
import plistlib
import re
import sys


def signing_entitlements(profile, requested, bundle_id, identity, devices, now):
    granted = profile["Entitlements"]
    team = granted["com.apple.developer.team-identifier"]
    if not re.fullmatch(r"[A-Z0-9]{10}", team) or team not in profile.get("TeamIdentifier", []):
        raise ValueError("Provisioning team mismatch")
    identifier = granted["com.apple.application-identifier"]
    if identifier != f"{team}.{bundle_id}":
        raise ValueError("Provisioning profile does not name the exact app")
    if profile["ExpirationDate"] <= now or "OSX" not in profile.get("Platform", []):
        raise ValueError("Expected an unexpired macOS provisioning profile")
    if len(set(devices)) != 2 or not all(devices) or not set(devices) <= set(profile.get("ProvisionedDevices", [])):
        raise ValueError("Provisioning profile must cover both approved Macs")
    if identity.upper() not in {hashlib.sha1(cert).hexdigest().upper() for cert in profile["DeveloperCertificates"]}:
        raise ValueError("Signing identity is absent from provisioning profile")
    key = "com.apple.developer.aps-environment"
    if requested.get(key) != "development" or granted.get(key) != "development":
        raise ValueError("Expected development APNs entitlement in app and profile")
    group = "com.apple.security.application-groups"
    if not set(requested.get(group, [])) <= set(granted.get(group, [])):
        raise ValueError("App groups are not granted by the provisioning profile")
    return {**requested, "com.apple.application-identifier": identifier,
            "com.apple.developer.team-identifier": team}


if __name__ == "__main__":
    profile_path, entitlements_path, output, bundle_id, identity, mini, book = sys.argv[1:]
    with open(profile_path, "rb") as profile, open(entitlements_path, "rb") as entitlements:
        result = signing_entitlements(plistlib.load(profile), plistlib.load(entitlements),
                                      bundle_id, identity, [mini, book], datetime.datetime.utcnow())
    with open(output, "wb") as destination:
        plistlib.dump(result, destination)
