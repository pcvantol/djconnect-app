"""Isolated workflow/public-API fixtures, never real TDE/provider qualification."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest
from unittest.mock import patch
from types import SimpleNamespace

SCRIPT = Path(__file__).with_name("tde_observe_diagnostics.py")
REPO = SCRIPT.parents[2]
spec = importlib.util.spec_from_file_location("observe_diagnostics", SCRIPT)
diagnostic = importlib.util.module_from_spec(spec)
spec.loader.exec_module(diagnostic)


class ObserveDiagnosticTests(unittest.TestCase):
    def test_actual_workflow_shell_preserves_original_bytes_exit_and_decisions(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            tools = root / "Tools/qualification"
            tools.mkdir(parents=True)
            shutil.copyfile(SCRIPT, tools / SCRIPT.name)
            binary = root / "bin"
            binary.mkdir()
            # The real workflow uses this only for the stdlib detector.
            (binary / "python3.14").symlink_to(sys.executable)
            fake = binary / "tde"
            assessment = b'{"status":"BLOCKED","reason":"original failure"}\n\n'
            qualification = b'{"status":"BLOCKED","reason":"different failure"}\n'
            fake.write_text("#!" + sys.executable + "\n" + textwrap.dedent(f"""
                import sys
                if '--version' in sys.argv:
                    print('synthetic fixture runtime'); raise SystemExit(0)
                assessment = 'assess' in sys.argv
                sys.stdout.buffer.write({assessment!r} if assessment else {qualification!r})
                sys.stderr.buffer.write(b'original stderr\\n' if assessment else b'qualification stderr\\n')
                raise SystemExit(3 if assessment else 7)
            """))
            fake.chmod(0o755)
            workflow = (REPO / ".github/workflows/tde-observe.yml").read_text()
            block = workflow.split("      - name: Run TDE standard assessment in observe mode\n", 1)[1]
            shell = textwrap.dedent(block.split("        run: |\n", 1)[1].split("\n      - name:", 1)[0])
            env = {**os.environ, "PATH": str(binary) + os.pathsep + os.environ["PATH"],
                   "GITHUB_OUTPUT": str(root / "github-output"), "GITHUB_STEP_SUMMARY": str(root / "summary")}
            result = subprocess.run(["bash", "-c", shell], cwd=root, env=env, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            output = root / "tde-observe"
            self.assertEqual((output / "assessment.json").read_bytes(), assessment)
            self.assertEqual((output / "qualification.json").read_bytes(), qualification)
            self.assertEqual((output / "assessment.stderr.txt").read_bytes(), b"original stderr\n")
            self.assertEqual((output / "qualification.stderr.txt").read_bytes(), b"qualification stderr\n")
            self.assertEqual((output / "assessment.exit").read_bytes(), b"3\n")
            self.assertEqual((output / "qualification.exit").read_bytes(), b"7\n")
            self.assertIn(b"original stderr\nqualification stderr\n", result.stderr)
            self.assertEqual((root / "github-output").read_text(), "blocked=true\n")
            self.assertIn("Assessment decision: unavailable", (output / "summary.md").read_text())

            # The canonical assessment decision alone must trigger diagnostics,
            # even when qualification is unavailable and validation is not BLOCKED.
            canonical = b'{"evidence":{"assessmentDecision":{"decision":"BLOCKED"},"assessment":{"executedCapabilities":[]}}}\n'
            unavailable = b'{"status":"unavailable"}\n'
            fake.write_text(fake.read_text().replace(repr(assessment), repr(canonical)).replace(repr(qualification), repr(unavailable)))
            (root / "github-output").unlink()
            result = subprocess.run(["bash", "-c", shell], cwd=root, env=env, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((output / "assessment.json").read_bytes(), canonical)
            self.assertEqual((output / "qualification.json").read_bytes(), unavailable)
            self.assertEqual((output / "assessment.exit").read_bytes(), b"3\n")
            self.assertEqual((output / "qualification.exit").read_bytes(), b"7\n")
            self.assertEqual((root / "github-output").read_text(), "blocked=true\n")
            self.assertIn("Assessment decision: BLOCKED", (output / "summary.md").read_text())

    def test_nonblocked_or_unreadable_result_never_creates_diagnostic(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            observe = root / "observe"
            observe.mkdir()
            for content in (b'{"status":"PASS"}', b'not JSON', b'[]', b'{"reason":"exit3 only"}'):
                (observe / "assessment.json").write_bytes(content)
                self.assertFalse(diagnostic.capture(root, observe, root / "never-created"))
                self.assertFalse((root / "never-created").exists())
            (observe / "qualification.json").write_text('{"repositoryQualification":{"qualificationStatus":"BLOCKED"}}')
            self.assertTrue(diagnostic.blocked(observe))

    def test_worker_retains_whole_public_result_without_store_or_environment_export(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            candidate, observe = root / "candidate", root / "observe"
            candidate.mkdir(); observe.mkdir()
            subprocess.run(["git", "init", "-q", str(candidate)], check=True)
            (candidate / "source").write_text("synthetic tracked input")
            subprocess.run(["git", "-C", str(candidate), "add", "source"], check=True)
            subprocess.run(["git", "-C", str(candidate), "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                            "commit", "-qm", "fixture"], check=True)
            (observe / "assessment.json").write_text('{"status":"BLOCKED"}\n')
            package = root / "modules/tde_runtime"
            package.mkdir(parents=True)
            (package / "__init__.py").write_text(textwrap.dedent("""
                from types import SimpleNamespace
                class RuntimeConfiguration:
                    @staticmethod
                    def discover(root, config): return {'unchanged': True}
                class AssessmentOrchestrator:
                    def configure(self, configuration, profile):
                        assert profile == 'standard'; return configuration
                class Runtime:
                    def execute(self, root, configuration):
                        return SimpleNamespace(evidence={'findings':[{'id':'retain-this-finding'}]},
                            validation={'status':'BLOCKED'}, report={'decision':'BLOCKED'})
            """))
            output = root / "external-diagnostic"
            env = {**os.environ, "PYTHONPATH": str(package.parent), "DIAGNOSTIC_TEST_SECRET": "do-not-export-this-value"}
            result = subprocess.run([sys.executable, str(SCRIPT), "capture", str(candidate), str(observe), str(output)], env=env, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            data = json.loads((output / "runtime-diagnostic.json").read_text())
            self.assertEqual(data, {"evidence":{"findings":[{"id":"retain-this-finding"}]},
                                    "validation":{"status":"BLOCKED"}, "report":{"decision":"BLOCKED"}})
            manifest = json.loads((output / "manifest-NOT_QUALIFIED.json").read_text())
            self.assertEqual(manifest["classification"], "NOT_QUALIFIED")
            self.assertTrue(manifest["inputs_unchanged"])
            self.assertTrue(manifest["head_unchanged"])
            self.assertFalse((candidate / ".tde").exists())
            self.assertEqual((observe / "assessment.json").read_text(), '{"status":"BLOCKED"}\n')
            self.assertNotIn("do-not-export-this-value", "".join(p.read_text() for p in output.iterdir()))

            # A failed diagnostic must neither replace the CLI decision nor leak
            # exception text, even when that text contains a credential sentinel.
            with (package / "__init__.py").open("a") as stream:
                stream.write("\nclass Runtime:\n    def execute(self, root, configuration):\n        raise RuntimeError('do-not-export-this-value')\n")
            failed = root / "failed-diagnostic"
            result = subprocess.run([sys.executable, str(SCRIPT), "capture", str(candidate), str(observe), str(failed)], env=env, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads((failed / "worker-result.json").read_text()),
                             {"outcome":"ERROR", "exception_type":"RuntimeError"})
            self.assertEqual(json.loads((failed / "manifest-NOT_QUALIFIED.json").read_text())["worker_exit"], 1)
            self.assertNotIn("do-not-export-this-value", "".join(p.read_text() for p in failed.iterdir()))
            self.assertFalse((failed / "runtime-diagnostic.json").exists())

            with (package / "__init__.py").open("a") as stream:
                stream.write("\nclass Runtime:\n    def execute(self, root, configuration):\n        import time; time.sleep(30)\n")
            timed_out = root / "timed-out-diagnostic"
            with patch.dict(os.environ, {"PYTHONPATH":str(package.parent)}), patch.object(diagnostic, "TIMEOUT_SECONDS", 0.1):
                self.assertTrue(diagnostic.capture(candidate, observe, timed_out))
            timeout_manifest = json.loads((timed_out / "manifest-NOT_QUALIFIED.json").read_text())
            self.assertEqual(timeout_manifest["worker_outcome"], "TIMEOUT")
            self.assertTrue(timeout_manifest["inputs_unchanged"])
            self.assertFalse((timed_out / "runtime-diagnostic.json").exists())

    def test_oversize_result_is_not_truncated_filtered_or_persisted(self):
        class Configuration:
            @staticmethod
            def discover(root, config): return {}
        class Orchestrator:
            def configure(self, configuration, profile): return configuration
        class Runtime:
            def execute(self, root, configuration):
                return SimpleNamespace(evidence={"findings":[{"original":"x" * 1024}]},
                                       validation={"status":"BLOCKED"}, report={})
        fixture = SimpleNamespace(RuntimeConfiguration=Configuration,
                                  AssessmentOrchestrator=Orchestrator, Runtime=Runtime)
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            with patch.dict(sys.modules, {"tde_runtime":fixture}), patch.object(diagnostic, "MAX_BYTES", 128):
                diagnostic.worker(output, output)
            self.assertFalse((output / "runtime-diagnostic.json").exists())
            receipt = json.loads((output / "worker-result.json").read_text())
            self.assertEqual(receipt["outcome"], "OUTPUT_TOO_LARGE_NOT_CAPTURED")
            self.assertGreater(receipt["bytes"], 128)
            self.assertFalse((output / ".tde").exists())


if __name__ == "__main__":
    unittest.main()
