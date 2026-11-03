"""Fixture-qualified proposal for private GitHub Apple release asset bindings."""

import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile


APPROVED_STATES = {
    "APPROVED_DEPLOYMENT_DISPATCH_PENDING",
    "APPROVED_PARTIAL_DEPLOYMENT_OPERATIONAL",
}
WATCH_REQUIREMENTS = {"macbook": "disabled", "iphone": "required", "ipad": None}


def verify_binding(manifest, *, manifest_id, source_sha, device, repository_id, asset_id, checksum):
    if (not manifest_id or manifest.get("manifest_id") != manifest_id
            or manifest.get("status") not in APPROVED_STATES
            or manifest.get("approval", {}).get("state") != "APPROVED"
            or manifest.get("release_profile") != "INTERNAL_RELEASE"):
        raise ValueError("Manifest is not approved for this deployment")
    if (not re.fullmatch(r"[0-9a-f]{40}", source_sha)
            or not any(entry.get("repository") == "pcvantol/djconnect-app"
                       and entry.get("source_sha") == source_sha
                       for entry in manifest.get("repositories", []))):
        raise ValueError("Apple source SHA does not match")
    if type(repository_id) is not int or repository_id <= 0:
        raise ValueError("Expected a configured private repository ID")

    bindings = [entry for entry in manifest.get("artifact_bindings", [])
                if entry.get("target") == "apple_private_device"]
    matches = [entry for entry in bindings if entry.get("target_device") == device]
    if device not in WATCH_REQUIREMENTS or len(matches) != 1:
        raise ValueError("Expected one binding for the requested device")
    binding = matches[0]
    watch_requirement = WATCH_REQUIREMENTS[device]
    if (binding.get("signing") != "local_developer_provisioning_required"
            or (binding.get("paired_watch_validation") != watch_requirement)
            or (watch_requirement is None and "paired_watch_validation" in binding)):
        raise ValueError("Signing or Watch validation scope does not match the device")

    if (binding.get("github_repository_id") != repository_id
            or type(asset_id) is not int or asset_id <= 0
            or binding.get("artifact_id") != str(asset_id)
            or binding.get("github_release_asset_id") != asset_id
            or binding.get("artifact_sha256") != checksum
            or sum(entry.get("github_release_asset_id") == asset_id for entry in bindings) != 1
            or not isinstance(checksum, str) or not re.fullmatch(r"[0-9a-f]{64}", checksum)):
        raise ValueError("Expected a unique asset ID and SHA-256 in the configured repository")

def verify_asset_metadata(asset, asset_id, checksum):
    if (asset.get("id") != asset_id or asset.get("state") != "uploaded"
            or asset.get("digest") != f"sha256:{checksum}"):
        raise ValueError("GitHub asset metadata does not match the manifest")

def verify_archive(archive, checksum):
    digest = hashlib.sha256()
    for chunk in iter(lambda: archive.read(1024 * 1024), b""):
        digest.update(chunk)
    if digest.hexdigest() != checksum:
        raise ValueError("Downloaded bytes do not match the manifest")


def verified_asset(manifest, *, repository, asset, archive, **binding):
    """Verify a proposed binding and bytes with trusted repository and asset metadata."""
    verify_binding(manifest, **binding)
    if repository.get("id") != binding["repository_id"] or repository.get("private") is not True:
        raise ValueError("Artifact repository is not the configured private repository")
    verify_asset_metadata(asset, binding["asset_id"], binding["checksum"])
    verify_archive(archive, binding["checksum"])
    return binding["asset_id"]


def download(manifest_path, device):
    """Download a manifest-bound asset using a dedicated relay credential."""
    token = os.environ.get("DJCONNECT_ARTIFACT_READ_TOKEN")
    if not token:
        raise ValueError("Private Apple artifact read credential is required")
    repository_id = int(os.environ["ARTIFACT_REPOSITORY_ID"])
    asset_id = int(os.environ["ARTIFACT_ID"])
    manifest = json.loads(Path(manifest_path).read_text())
    checksum = os.environ["ARTIFACT_SHA256"]
    verify_binding(manifest, manifest_id=os.environ["MANIFEST_ID"],
                   source_sha=os.environ["CANDIDATE_SHA"], device=device,
                   repository_id=repository_id, asset_id=asset_id, checksum=checksum)
    env = dict(os.environ, GH_TOKEN=token, GH_PROMPT_DISABLED="1")
    repo = "repos/pcvantol/djconnect-apple-internal-artifacts"
    endpoint = f"{repo}/releases/assets/{asset_id}"
    command = ["gh", "api", "--hostname", "github.com"]
    repository = json.loads(subprocess.check_output([*command, repo], env=env, timeout=30))
    if repository.get("id") != repository_id or repository.get("private") is not True:
        raise ValueError("Artifact repository is not the configured private repository")
    asset = json.loads(subprocess.check_output([*command, endpoint], env=env, timeout=30))
    verify_asset_metadata(asset, asset_id, checksum)

    output = Path("artifact.zip")
    with tempfile.TemporaryDirectory(dir=output.parent) as staging:
        path = Path(staging) / output.name
        with path.open("wb") as archive:
            subprocess.run([*command, endpoint, "-H", "Accept: application/octet-stream"],
                           env=env, stdout=archive, check=True, timeout=300)
        with path.open("rb") as archive:
            verify_archive(archive, checksum)
        path.replace(output)


if __name__ == "__main__":
    import sys

    download(*sys.argv[1:])
