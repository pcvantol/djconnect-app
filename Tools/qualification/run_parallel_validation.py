#!/usr/bin/env python3
"""Run independent CI checks with bounded concurrency and retain every result.

Tool/package updates precede these phases. No signing, installation, key access,
provider action or release is performed. Child commands never share build roots.
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import threading
import time

REPOSITORY = Path(__file__).resolve().parents[2]


@dataclass(frozen=True)
class Job:
    name: str
    command: tuple[str, ...]


class Processes:
    def __init__(self):
        self.lock = threading.Lock()
        self.children = {}
        self.cancelled = threading.Event()

    def cancel(self, signum=signal.SIGTERM):
        self.cancelled.set()
        with self.lock:
            for child in self.children.values():
                if child.poll() is None:
                    try:
                        os.killpg(child.pid, signum)
                    except ProcessLookupError:
                        pass


def run_jobs(jobs, output_dir, workers, *, cwd=REPOSITORY, processes=None):
    """Wait for ALL checks; one failed command can never hide behind another."""
    if workers < 1 or len({job.name for job in jobs}) != len(jobs):
        raise ValueError("Invalid parallel job configuration")
    if any(not re.fullmatch(r"[a-z0-9-]+", job.name) for job in jobs):
        raise ValueError("Invalid job name")
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=False)
    processes = processes or Processes()

    def run(job):
        started = time.monotonic()
        result = {"name": job.name, "command": list(job.command), "log": job.name + ".log",
                  "started_monotonic": started, "spawned_monotonic": None, "pid": None}
        with (output_dir / result["log"]).open("w") as log:
            if processes.cancelled.is_set():
                code = None
            else:
                try:
                    child = subprocess.Popen(job.command, cwd=cwd, stdout=log,
                                             stderr=subprocess.STDOUT, start_new_session=True)
                    result.update(pid=child.pid, spawned_monotonic=time.monotonic())
                    with processes.lock:
                        processes.children[child.pid] = child
                        if processes.cancelled.is_set():
                            try:
                                os.killpg(child.pid, signal.SIGTERM)
                            except ProcessLookupError:
                                pass
                    try:
                        code = child.wait()
                    finally:
                        with processes.lock:
                            processes.children.pop(child.pid, None)
                except OSError as error:
                    # No environment, credential or unbounded exception export.
                    log.write(type(error).__name__ + "\n")
                    code = 127
        ended = time.monotonic()
        result.update(exit_code=code, seconds=ended - started, ended_monotonic=ended,
                      status="passed" if code == 0 else "failed")
        return result

    with ThreadPoolExecutor(max_workers=workers) as pool:
        results = list(pool.map(run, jobs))
    (output_dir / "results.json").write_text(json.dumps({
        "workers": workers, "cancelled": processes.cancelled.is_set(),
        "jobs": results, "passed": not processes.cancelled.is_set() and all(r["exit_code"] == 0 for r in results)
    }, indent=2) + "\n")
    return results


def phase_jobs(phase, root):
    py = sys.executable
    if phase == "checks":
        return 4, [
            Job("websocket-contract", ("node", "Tools/websocket_e2e_contract.js")),
            Job("http-contract", ("node", "Tools/http_e2e_contract.js")),
            Job("fixture-security", ("node", "Tools/validate_ha_contract_fixture_security.js")),
            Job("localizations", (py, "scripts/validate_localizations.py")),
            Job("brand-tagline", (py, "Tools/validate_brand_tagline.py")),
            Job("brand-assets", (py, "Tools/validate_brand_assets.py")),
            Job("installation-hygiene", (py, "-m", "unittest", "discover", "-s", "Tools/qualification", "-p", "test_*.py")),
            Job("work-registers", (py, "Tools/qualification/validate_apple_work_registers.py")),
            Job("golden-orchestration", (py, "-m", "unittest", "discover", "-s", "Tools/qualification/askdj-golden", "-p", "test_*.py")),
        ]
    if phase == "swift":
        return 2, [Job("swift-main", ("swift", "test", "--parallel", "--jobs", "8",
                    "--scratch-path", str(root / "swift-main"),
                    "--cache-path", str(root / "package-cache-main"),
                    "--config-path", str(root / "package-config-main"),
                    "--security-path", str(root / "package-security-main"))),
                   Job("swift-vibecast", ("swift", "test", "--parallel", "--num-workers", "2", "--package-path",
                    "Tools/qualification/vibecast-native", "--scratch-path", str(root / "swift-vibecast"), "--jobs", "2"))]
    jobs = []
    for platform, scheme, destination in [("macos", "DJConnectMac", "platform=macOS"),
                                          ("ios", "DJConnectIOS", "generic/platform=iOS")]:
        jobs.append(Job("build-" + platform, ("xcodebuild", "-project", "DJConnectApp.xcodeproj",
            "-scheme", scheme, "-configuration", "Debug", "-destination", destination,
            "-parallelizeTargets", "-jobs", "4", "-derivedDataPath", str(root / ("derived-" + platform)),
            "CODE_SIGNING_ALLOWED=NO", "build")))
    return 2, jobs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase", choices=("checks", "swift", "builds"), required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    args = parser.parse_args()
    root = args.output_root.resolve()
    if root == REPOSITORY or REPOSITORY in root.parents:
        parser.error("Use an external, per-run output root")
    workers, jobs = phase_jobs(args.phase, root)
    processes = Processes()
    def cancel(signum, frame):
        processes.cancel()
        # A command that ignores termination cannot retain the worker forever.
        timer = threading.Timer(10, lambda: processes.cancel(signal.SIGKILL))
        timer.daemon = True
        timer.start()
    for signum in (signal.SIGTERM, signal.SIGINT):
        signal.signal(signum, cancel)
    results = run_jobs(jobs, root / ("logs-" + args.phase), workers, processes=processes)
    for result in results:
        print(result["status"].upper(), result["name"], "exit=" + str(result["exit_code"]),
              "log=" + str(root / ("logs-" + args.phase) / result["log"]))
    return 0 if not processes.cancelled.is_set() and all(r["exit_code"] == 0 for r in results) else 1


if __name__ == "__main__":
    sys.exit(main())
