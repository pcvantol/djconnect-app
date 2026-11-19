import contextlib
import io
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import validate_native_mac_widget as validator


class NativeWidgetPushEvidenceTests(unittest.TestCase):
    def test_mobile_evidence_is_absent_when_signed_environment_is_missing_or_differs(self):
        with tempfile.TemporaryDirectory() as directory:
            app = Path(directory) / "DJConnect.app"
            widget = app / "PlugIns/DJConnectWidget.appex"
            widget.mkdir(parents=True)
            identifier = "dev.djconnect.ios"
            info = {
                "CFBundleIdentifier": identifier,
                "CFBundleVersion": "40506",
                "CFBundleURLTypes": [{"CFBundleURLSchemes": ["djconnect"]}],
            }
            (app / "Info.plist").write_bytes(plistlib.dumps(info))
            (widget / "Info.plist").write_bytes(plistlib.dumps({
                "CFBundleIdentifier": identifier + ".track-insight-widget",
                "CFBundleVersion": "40506",
                "CFBundleSupportedPlatforms": ["iPhoneOS"],
                "NSExtension": {"NSExtensionPointIdentifier": "com.apple.widgetkit-extension"},
            }))
            rights = {
                "com.apple.developer.team-identifier": "ABCDE12345",
                "com.apple.security.application-groups": ["group.dev.djconnect"],
            }
            parent = rights | {"aps-environment": "development"}
            for child in (rights, rights | {"aps-environment": "production"}):
                with (
                    self.subTest(child=child),
                    patch.object(validator, "entitlements", side_effect=[child, parent]),
                    patch.object(validator.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)),
                    contextlib.redirect_stdout(io.StringIO()) as evidence,
                    contextlib.redirect_stderr(io.StringIO()) as checks,
                ):
                    self.assertFalse(validator.validate(app, mobile=True, emit_evidence=True))
                    self.assertEqual(evidence.getvalue(), "")
                    self.assertIn("FAIL: widget has APNs entitlement matching parent", checks.getvalue())
