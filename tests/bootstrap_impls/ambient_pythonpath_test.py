"""Ambient PYTHONPATH must not hide a binary's declared runfiles."""

import os
import pathlib
import subprocess
import tempfile
import unittest

from python.runfiles import runfiles


class AmbientPythonPathTest(unittest.TestCase):
    def _check_ambient(self, pythonpath, change_cwd=False):
        with tempfile.TemporaryDirectory() as temp:
            ambient = pathlib.Path(temp)
            package = ambient / "python"
            package.mkdir()
            (package / "__init__.py").write_text("# Unrelated regular package.\n")
            (ambient / "ambient_only.py").write_text('IDENTITY = "ambient-only"\n')
            env = os.environ.copy()
            env["PYTHONPATH"] = pythonpath(temp)
            env["VERIFY_AMBIENT_FALLBACK"] = "1"
            # An inner binary has its own runfiles tree, not the test's.
            env.pop("RUNFILES_DIR", None)
            env.pop("RUNFILES_MANIFEST_FILE", None)
            locator = runfiles.Create()
            assert locator is not None
            binary = locator.Rlocation(os.environ["TEST_BINARY_RLOCATION"])
            assert binary is not None
            result = subprocess.run(
                [binary],
                cwd=temp if change_cwd else None,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                check=False,
                timeout=20,
            )
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("/python/runfiles/runfiles.py", result.stdout.replace("\\", "/"))
            self.assertIn("AMBIENT_FALLBACK_OK", result.stdout)

    def test_absolute_ambient_package_does_not_shadow_declared_namespace(self):
        self._check_ambient(lambda temp: temp)

    @unittest.skipUnless(os.name == "posix", "POSIX empty PYTHONPATH entries")
    def test_empty_pythonpath_entry_does_not_shadow_declared_namespace(self):
        self._check_ambient(lambda _temp: os.pathsep, change_cwd=True)


if __name__ == "__main__":
    unittest.main()
