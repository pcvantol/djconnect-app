import importlib.util
import json
import signal
from pathlib import Path
import sys
import tempfile
import unittest

MODULE = Path(__file__).with_name("run_parallel_validation.py")
spec = importlib.util.spec_from_file_location("parallel_validation", MODULE)
parallel = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = parallel
spec.loader.exec_module(parallel)


class ParallelValidationTests(unittest.TestCase):
    def test_real_children_overlap_and_keep_separate_logs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            jobs = []
            for name, peer in [("first", "second"), ("second", "first")]:
                # Both children must enter before either can finish. A serial
                # runner fails rather than producing a timing-based speed claim.
                code = ("from pathlib import Path; import time; "
                        "p=Path(" + repr(str(root)) + "); "
                        "(p/" + repr(name) + ").write_text('started'); "
                        "end=time.monotonic()+5\n"
                        "while not (p/" + repr(peer) + ").exists():\n"
                        " assert time.monotonic()<end, 'peer never started'\n"
                        " time.sleep(.01)\n"
                        "print(" + repr(name) + ")")
                jobs.append(parallel.Job(name, (sys.executable, "-c", code)))
            results = parallel.run_jobs(jobs, root / "logs", 2)
            self.assertEqual([r["exit_code"] for r in results], [0, 0])
            for name in ["first", "second"]:
                self.assertEqual((root / "logs" / (name + ".log")).read_text().strip(), name)

    def test_failure_cannot_hide_behind_success_or_skip_other_commands(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            jobs = [parallel.Job("failure", (sys.executable, "-c", "print('failure'); raise SystemExit(7)")),
                    parallel.Job("success", (sys.executable, "-c", "print('success')")),
                    parallel.Job("missing-executable", (str(root / "absent"),))]
            results = parallel.run_jobs(jobs, root / "logs", 2)
            self.assertEqual([r["exit_code"] for r in results], [7, 0, 127])
            receipt = json.loads((root / "logs" / "results.json").read_text())
            self.assertFalse(receipt["passed"])
            self.assertEqual(len(receipt["jobs"]), 3)
            self.assertIn("failure", (root / "logs" / "failure.log").read_text())
            self.assertIn("success", (root / "logs" / "success.log").read_text())

    def test_cancelled_phase_does_not_start_remaining_commands_or_pass(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            processes = parallel.Processes(); processes.cancel()
            marker = root / "must-not-run"
            job = parallel.Job("cancelled", (sys.executable, "-c", "from pathlib import Path; Path(" + repr(str(marker)) + ").touch()"))
            results = parallel.run_jobs([job], root / "logs", 2, processes=processes)
            self.assertIsNone(results[0]["exit_code"])
            self.assertFalse(marker.exists())
            self.assertFalse(json.loads((root / "logs" / "results.json").read_text())["passed"])

    def test_late_cancellation_cannot_publish_pass_even_if_child_exits_zero(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            processes = parallel.Processes()
            previous = signal.signal(signal.SIGUSR1, lambda *_: processes.cancelled.set())
            try:
                # Mark this phase cancelled while its real child still reports
                # exit0. Individual command success is not phase acceptance.
                code = "import os, signal; os.kill(os.getppid(), signal.SIGUSR1)"
                results = parallel.run_jobs([parallel.Job("late-cancel", (sys.executable, "-c", code))],
                                            root / "logs", 1, processes=processes)
            finally:
                signal.signal(signal.SIGUSR1, previous)
            self.assertEqual(results[0]["exit_code"], 0)
            self.assertFalse(json.loads((root / "logs" / "results.json").read_text())["passed"])
