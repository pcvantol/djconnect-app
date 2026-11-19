"""Real Git provenance regression; no signing, device, SDK or network effects."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class NativeRunSourceBindingTests(unittest.TestCase):
    def test_foreign_git_dir_cannot_authorize_unmerged_native_source(self):
        clean_env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
        clean_env["PYTHONDONTWRITEBYTECODE"] = "1"
        with tempfile.TemporaryDirectory(prefix="djc-native-source-gate-") as name:
            work = Path(name)
            actual = work / "actual"
            actual.mkdir()

            def git(*args):
                return subprocess.check_output(["git", "-C", str(actual), *args], env=clean_env, text=True, stderr=subprocess.PIPE).strip()

            git("init", "-q", "-b", "main")
            (actual / "marker").write_text("base\n")
            git("add", ".")
            git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-qm", "base")
            base = git("rev-parse", "HEAD")
            tools = actual / "Tools/qualification/vibecast-fixed-qa"
            tools.mkdir(parents=True)
            for filename in ("prepare_fixed_qa.py", "prepare_native_test_run.py"):
                shutil.copy2(ROOT / "Tools/qualification/vibecast-fixed-qa" / filename, tools / filename)
            git("add", ".")
            git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-qm", "unmerged candidate")
            candidate = git("rev-parse", "HEAD")
            git("update-ref", "refs/remotes/origin/main", base)

            foreign = work / "foreign.git"
            subprocess.run(["git", "init", "-q", "--bare", str(foreign)], env=clean_env, check=True, capture_output=True)
            (foreign / "objects/info/alternates").write_text(str(actual / ".git/objects") + "\n")
            subprocess.run(["git", "--git-dir", str(foreign), "update-ref", "refs/remotes/origin/main", candidate], env=clean_env, check=True, capture_output=True)
            hostile = {**clean_env, "GIT_DIR": str(foreign)}
            unsafe = subprocess.run(["git", "-C", str(actual), "merge-base", "--is-ancestor", candidate, "origin/main"], env=hostile, capture_output=True)
            self.assertEqual(unsafe.returncode, 0, "Control must reproduce the old inherited-env bypass")

            policy = {"schema": "djc-apple-native-test-run/1", "source_sha": candidate, "policy": {
                "identifier": "00000000-0000-4000-8000-000000000001", "bundleID": "dev.djconnect.ios.vibecastqa", "build": "40407",
                "teamID": "ZEML4LPXH4", "applicationIdentifier": "ZEML4LPXH4.dev.djconnect.ios.vibecastqa", "environment": "development",
                "provisioningProfileSHA256": "a" * 64, "serviceOrigin": "https://api-vibecast-qa.djconnect.dev", "browserOrigin": "https://qa.vibecast.tv",
                "validFromMS": 1000, "validUntilMS": 601000}}
            manifest = work / "policy.json"
            manifest.write_text(json.dumps(policy))
            destination = work / "must-not-be-created"
            result = subprocess.run([sys.executable, str(tools / "prepare_native_test_run.py"), str(destination),
                "--jose-checkout", str(work / "unused-jose"), "--manifest", str(manifest), "--expected-source", candidate,
                "--signing-inputs", str(work / "must-not-be-read.json")], cwd=actual, env=hostile, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("merge-base", result.stderr)
            self.assertIn("origin/main", result.stderr)
            self.assertNotIn("FileNotFoundError", result.stderr)
            self.assertFalse(destination.exists())


if __name__ == "__main__":
    unittest.main()
