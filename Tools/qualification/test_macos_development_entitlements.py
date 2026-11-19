import datetime
import hashlib
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "release"))
from macos_development_entitlements import signing_entitlements


class MacDevelopmentEntitlementsTests(unittest.TestCase):
    def test_profile_must_cover_identity_both_hosts_app_and_development_apns(self):
        team = "ABCDE12345"
        now = datetime.datetime(2026, 11, 3)
        key = "com.apple.developer.aps-environment"
        certificate = b"fixture"
        identity = hashlib.sha1(certificate).hexdigest()
        devices = ["mini", "book"]
        for bundle in ("dev.djconnect.mac", "dev.djconnect.mac.track-insight-widget"):
            identifier = f"{team}.{bundle}"
            granted = {
                "com.apple.developer.team-identifier": team,
                "com.apple.application-identifier": identifier,
                key: "development",
            }
            profile = {
                "Entitlements": granted, "TeamIdentifier": [team],
                "ExpirationDate": now + datetime.timedelta(days=1), "Platform": ["OSX"],
                "ProvisionedDevices": devices, "DeveloperCertificates": [certificate],
            }
            signed = signing_entitlements(profile, {key: "development"}, bundle, identity, devices, now)
            self.assertEqual(signed[key], "development")
            self.assertEqual(signed["com.apple.application-identifier"], identifier)
            for override in (
                {"Entitlements": granted | {key: "production"}},
                {"Entitlements": granted | {"com.apple.application-identifier": f"{team}.*"}},
                {"ProvisionedDevices": ["mini"]},
                {"ExpirationDate": now},
                {"DeveloperCertificates": [b"different"]},
            ):
                with self.subTest(bundle=bundle, override=override), self.assertRaises(ValueError):
                    signing_entitlements(profile | override, {key: "development"}, bundle, identity, devices, now)
