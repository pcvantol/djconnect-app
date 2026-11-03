import hashlib
import io
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "release"))
from private_apple_artifact import verified_asset


class PrivateAppleArtifactTests(unittest.TestCase):
    def fixture(self, device):
        archive = f"{device} fixture".encode()
        digest = hashlib.sha256(archive).hexdigest()
        binding = {
            "target": "apple_private_device",
            "target_device": device,
            "github_repository_id": 123,
            "github_release_asset_id": 456,
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
            ("asset", {"id": 999, "state": "uploaded"}),
            ("source_sha", "b" * 40),
            ("archive", io.BytesIO(b"tampered")),
        ):
            with self.subTest(field=field), self.assertRaises(ValueError):
                verified_asset(**(self.fixture("iphone") | {field: value}))

    def test_rejects_wrong_approval_route_and_reused_asset(self):
        for case in ("approval", "watch", "reused"):
            fixture = self.fixture("ipad")
            manifest = fixture["manifest"]
            binding = manifest["artifact_bindings"][0]
            if case == "approval":
                manifest["approval"]["state"] = "PENDING"
            elif case == "watch":
                binding["paired_watch_validation"] = "disabled"
            else:
                manifest["artifact_bindings"].append(binding | {"target_device": "iphone"})
            with self.subTest(case=case), self.assertRaises(ValueError):
                verified_asset(**fixture)
