"""Integration tests for validation selection and the final gate."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1]


class ChangesTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.addCleanup(self.temp.cleanup)
        self.git("init", "-q")
        self.git("config", "user.email", "ci-test@example.invalid")
        self.git("config", "user.name", "CI fixture")
        self.write("SafeQR/App.swift", "// app")
        self.write("docs/guide.md", "guide")
        self.git("add", ".")
        self.git("commit", "-qm", "base")
        self.base = self.git("rev-parse", "HEAD").strip()

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.root, text=True)

    def write(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def commit(self):
        self.git("add", "-A")
        self.git("commit", "-qm", "change")

    def select(self, base=None, force="false", check=True):
        env = {**os.environ, "SAFEQR_BASE_SHA": base or self.base, "SAFEQR_FORCE_IOS": force}
        env.pop("GITHUB_OUTPUT", None)
        result = subprocess.run([sys.executable, str(SCRIPTS / "ci-changes.py")], cwd=self.root,
                                env=env, text=True, capture_output=True)
        if check:
            self.assertEqual(result.returncode, 0, result.stderr)
            return json.loads(result.stdout)["ios_required"]
        return result

    def test_docs_and_capture_changes_skip_ios(self):
        self.write("README.md", "readme")
        self.write("docs/pr-captures/new\ncapture.png", "fixture")
        self.commit()
        self.assertEqual(self.select(), "false")

    def test_code_and_unknown_inputs_require_ios(self):
        for name in ("SafeQR/App.swift", ".github/workflows/ci.yml", "scripts/check.sh", "new.config"):
            with self.subTest(name=name):
                self.write(name, "// updated")
                self.commit()
                self.assertEqual(self.select(), "true")
                self.base = self.git("rev-parse", "HEAD").strip()

    def test_code_deletion_requires_ios(self):
        (self.root / "SafeQR/App.swift").unlink()
        self.commit()
        self.assertEqual(self.select(), "true")

    def test_rename_code_into_docs_still_requires_ios(self):
        self.git("mv", "SafeQR/App.swift", "docs/old.swift")
        self.commit()
        self.assertEqual(self.select(), "true")

    def test_docs_deletion_skips_ios(self):
        (self.root / "docs/guide.md").unlink()
        self.commit()
        self.assertEqual(self.select(), "false")

    def test_manual_dispatch_forces_ios_without_base(self):
        self.assertEqual(self.select(base="missing", force="true"), "true")

    def test_invalid_or_unavailable_base_is_failure(self):
        for base in ("--all", "missing", "0" * 40):
            with self.subTest(base=base):
                self.assertNotEqual(self.select(base=base, check=False).returncode, 0)

    def test_invalid_force_is_failure(self):
        self.assertNotEqual(self.select(force="yes", check=False).returncode, 0)


class GateTests(unittest.TestCase):
    def result(self, portable, required, ios):
        env = {**os.environ, "SAFEQR_PORTABLE_RESULT": portable,
               "SAFEQR_IOS_REQUIRED": required, "SAFEQR_IOS_RESULT": ios}
        return subprocess.run([sys.executable, str(SCRIPTS / "ci-gate.py")], env=env,
                              text=True, capture_output=True)

    def test_successful_full_validation(self):
        self.assertEqual(self.result("success", "true", "success").returncode, 0)

    def test_explicit_docs_only_skip(self):
        self.assertEqual(self.result("success", "false", "skipped").returncode, 0)

    def test_failure_cancellation_and_unexpected_skip_are_rejected(self):
        for portable, required, ios in (
            ("failure", "false", "skipped"), ("cancelled", "true", "success"),
            ("skipped", "false", "skipped"), ("success", "true", "failure"),
            ("success", "true", "cancelled"), ("success", "true", "skipped"),
            ("success", "", "skipped"), ("success", "false", "failure"),
            ("success", "false", "success"),
        ):
            with self.subTest(portable=portable, required=required, ios=ios):
                self.assertNotEqual(self.result(portable, required, ios).returncode, 0)


if __name__ == "__main__":
    unittest.main()
