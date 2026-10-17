import os
from pathlib import Path
import tempfile
import unittest

from install_ordinary_macos import bundle_manifest, copy_bundle


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


if __name__ == "__main__":
    unittest.main()
