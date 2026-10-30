"""Supplemental BLOCKED-only diagnostics; never an assessment/qualification store."""
from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import inspect
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys

MAX_BYTES = 16 * 1024 * 1024
TIMEOUT_SECONDS = 120


def blocked(directory: Path) -> bool:
    for name in ("assessment.json", "qualification.json"):
        path = directory / name
        try:
            if path.stat().st_size > MAX_BYTES:
                continue
            value = json.loads(path.read_bytes())
        except (OSError, ValueError):
            continue
        if not isinstance(value, dict):
            continue
        # Observe public decisions only. Exit3 alone is not a BLOCKED decision.
        for keys in (("status",), ("validation", "status"),
                     ("evidence", "validation", "status"),
                     ("evidence", "assessmentDecision", "decision"),
                     ("repositoryQualification", "qualificationStatus")):
            current = value
            for key in keys:
                current = current.get(key) if isinstance(current, dict) else None
            if current == "BLOCKED":
                return True
    return False


def identity(path: Path) -> dict:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for part in iter(lambda: stream.read(65536), b""):
            digest.update(part)
    return {"bytes": path.stat().st_size, "sha256": digest.hexdigest()}


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()


def worker(root: Path, output: Path) -> None:
    # Only public API; no EvidenceStore, private analyzer, persistence or patches.
    from tde_runtime import AssessmentOrchestrator, Runtime, RuntimeConfiguration

    (output / "runtime-public-api-provenance.json").write_text(json.dumps({
        str(Path(inspect.getfile(value)).resolve()): identity(Path(inspect.getfile(value)))
        for value in (Runtime, RuntimeConfiguration, AssessmentOrchestrator)}, indent=2) + "\n")
    configuration = AssessmentOrchestrator().configure(
        RuntimeConfiguration.discover(str(root), None), profile="standard")
    result = Runtime().execute(root, configuration)
    raw = json.dumps({"evidence": result.evidence, "validation": result.validation,
                      "report": result.report}, ensure_ascii=False).encode("utf-8")
    receipt = {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}
    if len(raw) <= MAX_BYTES:
        (output / "runtime-diagnostic.json").write_bytes(raw)
        receipt["outcome"] = "CAPTURED"
    else:
        # No truncation/filtering of findings or substitute positive evidence.
        receipt["outcome"] = "OUTPUT_TOO_LARGE_NOT_CAPTURED"
    (output / "worker-result.json").write_text(json.dumps(receipt) + "\n")


def capture(root: Path, observe: Path, output: Path) -> bool:
    if not blocked(observe):
        return False
    root, output = root.resolve(), output.resolve()
    if output.is_relative_to(root):
        raise ValueError("diagnostic output must be outside the repository")
    output.mkdir(parents=True, exist_ok=False)
    inputs = {}
    for path in [Path(__file__).resolve(), root / "coverage.json", root / ".github/tde/repository-definition.json",
                 root / ".github/workflows/tde-observe.yml", root / ".tde.yml",
                 *[observe / name for name in ("assessment.json", "qualification.json",
                    "assessment.stderr.txt", "qualification.stderr.txt",
                    "assessment.exit", "qualification.exit", "runtime-version.txt")]]:
        inputs[str(path)] = identity(path) if path.is_file() else None
    tools = {}
    for name in ("cloc", "lizard", "radon", "tde"):
        location = shutil.which(name)
        if location:
            tools[name] = {"path": location, **identity(Path(location))}
    packages = {}
    for name in ("technical-debt-engine-runtime", "lizard", "radon"):
        try:
            distribution = importlib.metadata.distribution(name)
            record = distribution.read_text("RECORD")
            packages[name] = {"version": distribution.version,
                "installed_record_sha256": hashlib.sha256(record.encode()).hexdigest() if record else None}
        except importlib.metadata.PackageNotFoundError:
            packages[name] = "UNAVAILABLE"
    before = git(root, "rev-parse", "HEAD")
    manifest = {"classification": "NOT_QUALIFIED", "purpose": "supplemental BLOCKED diagnostic only",
                "head": before, "tree": git(root, "rev-parse", "HEAD^{tree}"),
                "tracked_changes_before": bool(git(root, "diff", "--name-only", "HEAD")),
                "python": sys.version, "python_executable": sys.executable,
                "packages": packages, "tools": tools, "inputs": inputs,
                "maximum_output_bytes": MAX_BYTES, "timeout_seconds": TIMEOUT_SECONDS,
                "persistence": "NONE; original CLI decisions and files remain authoritative"}
    with subprocess.Popen([sys.executable, str(Path(__file__).resolve()),
            "worker", str(root), str(output)], stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL, start_new_session=True) as process:
        try:
            manifest["worker_exit"] = process.wait(timeout=TIMEOUT_SECONDS)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass  # The owned worker exited between timeout and termination.
            process.wait()
            manifest["worker_outcome"] = "TIMEOUT"
    manifest["head_unchanged"] = git(root, "rev-parse", "HEAD") == before
    manifest["tracked_changes_after"] = bool(git(root, "diff", "--name-only", "HEAD"))
    manifest["inputs_unchanged"] = all(
        (identity(Path(path)) if Path(path).is_file() else None) == value
        for path, value in inputs.items())
    manifest["outputs"] = {path.name: identity(path) for path in output.iterdir() if path.is_file()}
    (output / "manifest-NOT_QUALIFIED.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return True


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    detect = commands.add_parser("detect")
    detect.add_argument("observe", type=Path)
    for name in ("capture", "worker"):
        command = commands.add_parser(name)
        command.add_argument("root", type=Path)
        if name == "capture":
            command.add_argument("observe", type=Path)
        command.add_argument("output", type=Path)
    args = parser.parse_args()
    if args.command == "detect":
        print("true" if blocked(args.observe) else "false")
    elif args.command == "capture":
        capture(args.root, args.observe, args.output)
    else:
        try:
            worker(args.root, args.output)
        except Exception as error:
            # Do not export exception strings, tracebacks, environment or secrets.
            (args.output / "worker-result.json").write_text(json.dumps({
                "outcome": "ERROR", "exception_type": type(error).__name__}) + "\n")
            raise SystemExit(1)


if __name__ == "__main__":
    main()
