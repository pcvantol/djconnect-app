"""Fixture-qualified proposal for private GitHub Apple release asset bindings."""

import hashlib
import re


APPROVED_STATES = {
    "APPROVED_DEPLOYMENT_DISPATCH_PENDING",
    "APPROVED_PARTIAL_DEPLOYMENT_OPERATIONAL",
}
WATCH_REQUIREMENTS = {"macbook": "disabled", "iphone": "required", "ipad": None}


def verified_asset(manifest, *, manifest_id, source_sha, device, repository_id,
                   repository, asset_id, checksum, asset, archive):
    """Return the verified asset ID using metadata from a trusted API reader.

    The repository ID must come from relay configuration, independently of
    the manifest. This function performs no network access or installation.
    """
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
    if (type(repository_id) is not int or repository_id <= 0
            or repository.get("id") != repository_id or repository.get("private") is not True):
        raise ValueError("Artifact repository is not the configured private repository")

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
            or binding.get("github_release_asset_id") != asset_id
            or binding.get("artifact_sha256") != checksum
            or sum(entry.get("github_release_asset_id") == asset_id for entry in bindings) != 1
            or not isinstance(checksum, str) or not re.fullmatch(r"[0-9a-f]{64}", checksum)):
        raise ValueError("Expected a unique asset ID and SHA-256 in the configured repository")
    if (asset.get("id") != asset_id or asset.get("state") != "uploaded"
            or asset.get("digest") != f"sha256:{checksum}"):
        raise ValueError("GitHub asset metadata does not match the manifest")
    digest = hashlib.sha256()
    for chunk in iter(lambda: archive.read(1024 * 1024), b""):
        digest.update(chunk)
    if digest.hexdigest() != checksum:
        raise ValueError("Downloaded bytes do not match the manifest")
    return asset_id
