#!/usr/bin/env python3
"""Validate and install an ordinary, already signed DJConnect Mac app.

Preserve relative framework symlinks and executable bits, without copying Finder
resource forks. Never replace a running app or discard its previous installation.
"""
from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import plistlib
import re
import shutil
import stat
import subprocess
import tempfile
from datetime import datetime, timezone


def bundle_manifest(root: Path) -> dict[str, tuple]:
    result = {}
    for base, dirs, files in os.walk(root, followlinks=False):
        for name in sorted(dirs + files):
            path = Path(base) / name
            relative = str(path.relative_to(root))
            info = path.lstat()
            mode = stat.S_IMODE(info.st_mode)
            if path.is_symlink():
                if not path.resolve().is_relative_to(root.resolve()):
                    raise ValueError("Bundle symlink escapes its own root")
                value = ("link", os.readlink(path), mode)
            elif path.is_dir():
                value = ("directory", mode)
            elif path.is_file():
                with path.open("rb") as stream:
                    checksum = hashlib.sha256()
                    for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                        checksum.update(chunk)
                    digest = checksum.hexdigest()
                value = ("file", info.st_size, digest, mode)
            else:
                raise ValueError("Unsupported bundle entry")
            result[relative] = value
    return result


def copy_bundle(source: Path, destination: Path) -> None:
    if destination.exists() or destination.is_symlink():
        raise ValueError("Copy destination already exists")
    before = bundle_manifest(source)

    def copy_file(origin: str, target: str) -> str:
        shutil.copyfile(origin, target)
        shutil.copymode(origin, target)
        return target

    shutil.copytree(source, destination, symlinks=True, copy_function=copy_file)
    if bundle_manifest(source) != before or bundle_manifest(destination) != before:
        raise ValueError("Bundle bytes, symlinks or modes changed during copying")


def validate_bundle(path: Path, expected_build: str) -> None:
    if path.is_symlink() or path.suffix != ".app":
        raise ValueError("Expected an ordinary app directory")
    with (path / "Contents/Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    if info.get("CFBundleIdentifier") != "dev.djconnect.mac" or str(info.get("CFBundleVersion")) != expected_build:
        raise ValueError("Unexpected app identity or build")
    if not os.access(path / "Contents/MacOS/DJConnect", os.X_OK):
        raise ValueError("Main executable has lost its executable mode")
    if any(path.rglob("*.xctest")) or any(p.name.startswith("._") for p in path.rglob("*")):
        raise ValueError("Diagnostic bundle or Finder resource-fork file present")
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(path)], check=True)


def install(source: Path, destination: Path, expected_build: str) -> Path | None:
    validate_bundle(source, expected_build)
    pattern = "^" + re.escape(str(destination / "Contents/MacOS/DJConnect")) + r"($| )"
    process = subprocess.run(["pgrep", "-f", pattern], capture_output=True, text=True)
    if process.returncode != 1:
        raise ValueError("Destination app is running or process state is uncertain")
    destination.parent.mkdir(parents=True, exist_ok=True)
    stage_root = Path(tempfile.mkdtemp(prefix=".djconnect-install-", dir=destination.parent))
    staged = stage_root / "DJConnect.app"
    backup = None
    try:
        copy_bundle(source, staged)
        validate_bundle(staged, expected_build)
        # Recheck immediately before changing the destination.
        if subprocess.run(["pgrep", "-f", pattern], capture_output=True).returncode != 1:
            raise ValueError("Destination app started during qualification")
        if destination.exists():
            stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
            backup = destination.with_name("DJConnect-recovery-" + stamp + ".app")
            if backup.exists():
                raise ValueError("Recovery path already exists")
            destination.rename(backup)
        try:
            staged.rename(destination)
            validate_bundle(destination, expected_build)
        except BaseException:
            # Preserve both products when final validation is uncertain.
            if backup is not None:
                if destination.exists():
                    rejected = destination.with_name("DJConnect-unconfirmed-" + stamp + ".app")
                    destination.rename(rejected)
                backup.rename(destination)
            raise
        return backup
    finally:
        if stage_root.exists():
            shutil.rmtree(stage_root)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--destination", type=Path, default=Path("/Applications/DJConnect.app"))
    parser.add_argument("--expected-build", required=True)
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    validate_bundle(args.source, args.expected_build)
    if args.execute:
        backup = install(args.source, args.destination, args.expected_build)
        print("Ordinary app validated and installed; previous app retained:", backup)
    else:
        print("Ordinary source app validated; destination unchanged")


if __name__ == "__main__":
    main()
