import hashlib
import io
import json
import os
import tempfile
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "release"))
from private_apple_artifact import download, verified_asset


class PrivateAppleArtifactTests(unittest.TestCase):
    def fixture(self, device):
        archive = f"{device} fixture".encode()
        digest = hashlib.sha256(archive).hexdigest()
        binding = {
            "target": "apple_private_device",
            "target_device": device,
            "github_repository_id": 123,
            "github_release_asset_id": 456,
            "artifact_id": "456",
            "artifact_sha256": digest,
            "signing": "local_developer_provisioning_required",
        }
        if device != "ipad":
            binding["paired_watch_validation"] = "required" if device == "iphone" else "disabled"
        return {
            "manifest": {
                "manifest_id": "fixture",
                "status": "APPROVED_DEPLOYMENT_DISPATCH_PENDING",
                "approval": {"state": "APPROVED"},
                "release_profile": "INTERNAL_RELEASE",
                "repositories": [{"repository": "pcvantol/djconnect-app", "source_sha": "a" * 40}],
                "artifact_bindings": [binding],
            },
            "manifest_id": "fixture",
            "source_sha": "a" * 40,
            "device": device,
            "repository_id": 123,
            "asset_id": 456,
            "checksum": digest,
            "repository": {"id": 123, "private": True},
            "asset": {"id": 456, "state": "uploaded", "digest": f"sha256:{digest}"},
            "archive": io.BytesIO(archive),
        }

    def test_routes_accept_only_verified_bytes(self):
        for device in ("macbook", "iphone", "ipad"):
            with self.subTest(device=device):
                self.assertEqual(verified_asset(**self.fixture(device)), 456)

    def test_rejects_wrong_repository_asset_and_bytes(self):
        for field, value in (
            ("repository", {"id": 123, "private": False}),
            ("repository_id", 124),
            ("asset_id", 457),
            ("checksum", "0" * 64),
            ("asset", {"id": 999, "state": "uploaded"}),
            ("source_sha", "b" * 40),
            ("archive", io.BytesIO(b"tampered")),
        ):
            with self.subTest(field=field), self.assertRaises(ValueError):
                verified_asset(**(self.fixture("iphone") | {field: value}))

    def test_rejects_wrong_approval_route_and_reused_asset(self):
        for case in ("approval", "watch", "reused", "duplicate_route"):
            fixture = self.fixture("ipad")
            manifest = fixture["manifest"]
            binding = manifest["artifact_bindings"][0]
            if case == "approval":
                manifest["approval"]["state"] = "PENDING"
            elif case == "watch":
                binding["paired_watch_validation"] = "disabled"
            elif case == "reused":
                manifest["artifact_bindings"].append(binding | {"target_device": "iphone"})
            else:
                manifest["artifact_bindings"].append(binding | {"github_release_asset_id": 457})
            with self.subTest(case=case), self.assertRaises(ValueError):
                verified_asset(**fixture)


    def test_missing_credential_stops_before_api_access(self):
        with patch.dict(os.environ, {}, clear=True), patch("subprocess.check_output") as api:
            with self.assertRaisesRegex(ValueError, "read credential"):
                download("unused.json", "ipad")
            api.assert_not_called()

    def test_download_uses_fixed_locator_and_rejects_tampering(self):
        fixture = self.fixture("ipad")
        env = {
            "DJCONNECT_ARTIFACT_READ_TOKEN": "fixture-token",
            "ARTIFACT_REPOSITORY_ID": "123",
            "ARTIFACT_ID": "456",
            "ARTIFACT_SHA256": fixture["checksum"],
            "MANIFEST_ID": fixture["manifest_id"],
            "CANDIDATE_SHA": fixture["source_sha"],
        }
        with tempfile.TemporaryDirectory() as root:
            manifest = Path(root) / "manifest.json"
            manifest.write_text(json.dumps(fixture["manifest"]))
            original = Path.cwd()
            try:
                os.chdir(root)
                for payload in (b"tampered", fixture["archive"].getvalue()):
                    with patch.dict(os.environ, env, clear=True), patch(
                        "subprocess.check_output",
                        side_effect=[json.dumps(fixture["repository"]), json.dumps(fixture["asset"])],
                    ), patch("subprocess.run") as api:
                        api.side_effect = lambda *args, **kwargs: kwargs["stdout"].write(payload)
                        if payload == b"tampered":
                            with self.assertRaisesRegex(ValueError, "Downloaded bytes"):
                                download(manifest, "ipad")
                            self.assertFalse(Path("artifact.zip").exists())
                        else:
                            download(manifest, "ipad")
                            self.assertEqual(Path("artifact.zip").read_bytes(), payload)
                        self.assertEqual(api.call_args.args[0][-3:], [
                            "repos/pcvantol/djconnect-apple-internal-artifacts/releases/assets/456",
                            "-H", "Accept: application/octet-stream",
                        ])
            finally:
                os.chdir(original)
