import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace
import signal

from install_ordinary_macos import bundle_manifest, copy_bundle
import install_ordinary_macos as installer


class OrdinaryBundleCopyTests(unittest.TestCase):
    def test_preserves_executable_bits_and_versioned_framework_symlinks(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source, target = root / "source.app", root / "target.app"
            executable = source / "Contents/MacOS/DJConnect"
            executable.parent.mkdir(parents=True)
            executable.write_bytes(b"synthetic executable fixture")
            executable.chmod(0o755)
            framework = source / "Contents/Frameworks/Core.framework"
            (framework / "Versions/A").mkdir(parents=True)
            binary = framework / "Versions/A/Core"
            binary.write_bytes(b"synthetic framework fixture")
            binary.chmod(0o755)
            (framework / "Versions/Current").symlink_to("A")
            (framework / "Core").symlink_to("Versions/Current/Core")
            copy_bundle(source, target)
            self.assertEqual(bundle_manifest(source), bundle_manifest(target))
            self.assertTrue(os.access(target / "Contents/MacOS/DJConnect", os.X_OK))
            self.assertTrue((target / "Contents/Frameworks/Core.framework/Core").is_symlink())
            self.assertEqual(binary.read_bytes(), (target / "Contents/Frameworks/Core.framework/Core").read_bytes())

    def test_existing_target_is_preserved_and_external_symlinks_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source, target = root / "source.app", root / "target.app"
            source.mkdir(); target.mkdir()
            (target / "retained").write_text("existing installation")
            with self.assertRaises(ValueError):
                copy_bundle(source, target)
            self.assertEqual((target / "retained").read_text(), "existing installation")
            (source / "outside").symlink_to(root / "unrelated")
            with self.assertRaises(ValueError):
                bundle_manifest(source)


class WidgetProcessRetirementTests(unittest.TestCase):
    destination = Path("/Applications/DJ Connect (test).app")
    backup = Path("/Applications/DJConnect-recovery-fixture.app")
    suffix = "/Contents/PlugIns/DJConnectWidget.appex/Contents/MacOS/DJConnectWidget"

    def result(self, text, code=0):
        return SimpleNamespace(stdout=text, returncode=code)

    def test_only_original_process_mapped_from_this_recovery_is_retired(self):
        responses = [self.result("original birth"), self.result("42\n"),
                     self.result("n" + str(self.backup) + self.suffix + "\n"), self.result("original birth")]
        with patch.object(installer.subprocess, "run", side_effect=responses), patch.object(installer.os, "kill") as kill:
            installer.retire_replaced_extensions(self.destination, self.backup, {42: "original birth"})
        kill.assert_called_once_with(42, signal.SIGTERM)

    def test_reused_pid_and_already_reloaded_widget_are_not_signalled(self):
        with patch.object(installer.subprocess, "run", return_value=self.result("new birth")), patch.object(installer.os, "kill") as kill:
            installer.retire_replaced_extensions(self.destination, self.backup, {42: "original birth"})
            kill.assert_not_called()
        responses = [self.result("original birth"), self.result("42\n"),
                     self.result("n" + str(self.destination) + self.suffix + "\n")]
        with patch.object(installer.subprocess, "run", side_effect=responses), patch.object(installer.os, "kill") as kill:
            installer.retire_replaced_extensions(self.destination, self.backup, {42: "original birth"})
            kill.assert_not_called()

    def test_unrelated_loaded_image_is_rejected_without_a_signal(self):
        responses = [self.result("original birth"), self.result("42\n"),
                     self.result("n/Applications/Unrelated.app" + self.suffix + "\n")]
        with patch.object(installer.subprocess, "run", side_effect=responses), patch.object(installer.os, "kill") as kill:
            with self.assertRaisesRegex(ValueError, "loaded image"):
                installer.retire_replaced_extensions(self.destination, self.backup, {42: "original birth"})
            kill.assert_not_called()

    def test_pid_changed_after_image_check_is_not_signalled(self):
        responses = [self.result("original birth"), self.result("42\n"),
                     self.result("n" + str(self.backup) + self.suffix + "\n"), self.result("new birth")]
        with patch.object(installer.subprocess, "run", side_effect=responses), patch.object(installer.os, "kill") as kill:
            installer.retire_replaced_extensions(self.destination, self.backup, {42: "original birth"})
            kill.assert_not_called()

    def test_widget_inventory_is_confined_to_the_destination_and_birth(self):
        responses = [self.result("42\n"), self.result("original birth")]
        with patch.object(installer.subprocess, "run", side_effect=responses) as run:
            self.assertEqual(installer.extension_processes(self.destination), {42: "original birth"})
        pattern = run.call_args_list[0].args[0][-1]
        self.assertRegex(str(self.destination) + self.suffix + " -service", pattern)
        self.assertNotRegex("/Applications/Unrelated.app" + self.suffix, pattern)


if __name__ == "__main__":
    unittest.main()
