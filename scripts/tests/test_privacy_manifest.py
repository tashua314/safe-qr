import importlib.util
import plistlib
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "privacy_manifest", Path(__file__).parents[1] / "verify_privacy_manifest.py"
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PrivacyManifestTests(unittest.TestCase):
    def check_manifest(self, manifest):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "PrivacyInfo.xcprivacy"
            path.write_bytes(plistlib.dumps(manifest))
            module.verify(path)

    def test_real_manifest_is_valid(self):
        module.verify(Path(__file__).parents[2] / "SafeQR/SafeQR/PrivacyInfo.xcprivacy")

    def test_missing_declaration_is_rejected(self):
        with self.assertRaises(ValueError):
            self.check_manifest({"NSPrivacyAccessedAPITypes": []})

    def test_wrong_reason_is_rejected(self):
        with self.assertRaises(ValueError):
            self.check_manifest({"NSPrivacyAccessedAPITypes": [{
                "NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults",
                "NSPrivacyAccessedAPITypeReasons": ["1C8F.1"],
            }]})

    def test_string_instead_of_reason_array_is_rejected(self):
        with self.assertRaises(ValueError):
            self.check_manifest({"NSPrivacyAccessedAPITypes": [{
                "NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults",
                "NSPrivacyAccessedAPITypeReasons": "CA92.1",
            }]})

    def test_missing_file_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(FileNotFoundError):
                module.verify(Path(directory) / "missing.xcprivacy")
