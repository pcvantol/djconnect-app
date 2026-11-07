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
import signal
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


def extension_image_pattern(destination: Path) -> str:
    return re.escape(str(destination / "Contents/PlugIns")) + r"/[^/]+\.appex/Contents/MacOS/[^/]+"


def extension_pattern(destination: Path) -> str:
    return "^" + extension_image_pattern(destination) + r"($| )"


def process_start(pid: int) -> str | None:
    result = subprocess.run(["ps", "-p", str(pid), "-o", "lstart="], capture_output=True, text=True)
    if result.returncode == 1:
        return None
    if result.returncode != 0 or not result.stdout.strip():
        raise ValueError("Extension process identity is uncertain")
    return result.stdout.strip()


def extension_processes(destination: Path) -> dict[int, str]:
    result = subprocess.run(["pgrep", "-f", extension_pattern(destination)], capture_output=True, text=True)
    if result.returncode == 1:
        return {}
    if result.returncode != 0 or not result.stdout.split() or not all(p.isdecimal() for p in result.stdout.split()):
        raise ValueError("Extension process inventory is uncertain")
    captured = {}
    for value in result.stdout.split():
        pid = int(value)
        if (started := process_start(pid)) is not None:
            captured[pid] = started
    return captured


def retire_replaced_extensions(destination: Path, backup: Path | None, captured: dict[int, str]) -> None:
    """Retire only the original processes demonstrably executing this backup.

    WidgetKit may keep the old executable mapped after an atomic app replacement.
    Never terminate the widget host, a reused PID, or an unproven extension.
    """
    if not captured:
        return
    if backup is None:
        raise ValueError("Running extensions have no original recovery bundle")
    old_image = re.compile("^n" + extension_image_pattern(backup) + "$")
    new_image = re.compile("^n" + extension_image_pattern(destination) + "$")
    for pid, started in captured.items():
        if process_start(pid) != started:
            continue
        live = subprocess.run(["pgrep", "-f", extension_pattern(destination)], capture_output=True, text=True)
        if live.returncode == 1:
            continue
        if live.returncode != 0 or not live.stdout.split() or not all(p.isdecimal() for p in live.stdout.split()):
            raise ValueError("Extension process inventory changed ambiguously")
        if str(pid) not in live.stdout.split():
            continue
        files = subprocess.run(["lsof", "-p", str(pid), "-Fn"], capture_output=True, text=True)
        if files.returncode != 0:
            if process_start(pid) is None:
                continue
            raise ValueError("Cannot verify the extension's original loaded image")
        lines = files.stdout.splitlines()
        if not any(old_image.fullmatch(line) for line in lines):
            if any(new_image.fullmatch(line) for line in lines):
                continue
            raise ValueError("Extension loaded image does not match either qualified bundle")
        # Recheck birth immediately before signalling; a newly launched process
        # must not inherit the captured process's retirement decision.
        if process_start(pid) == started:
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass


def install(source: Path, destination: Path, expected_build: str) -> Path | None:
    validate_bundle(source, expected_build)
    pattern = "^" + re.escape(str(destination / "Contents/MacOS/DJConnect")) + r"($| )"
    process = subprocess.run(["pgrep", "-f", pattern], capture_output=True, text=True)
    if process.returncode != 1:
        raise ValueError("Destination app is running or process state is uncertain")
    extensions = extension_processes(destination)
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
        extensions.update(extension_processes(destination))
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
        # This occurs after successful replacement, so WidgetKit's next launch
        # resolves the new bundle. A failure preserves both signed installations.
        retire_replaced_extensions(destination, backup, extensions)
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
