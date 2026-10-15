"""生成アプリに、自アプリ設定用UserDefaultsの必須理由が残ることを検査する。"""

import plistlib
import sys
from pathlib import Path


def verify(path):
    with Path(path).open("rb") as source:
        manifest = plistlib.load(source)
    declarations = manifest.get("NSPrivacyAccessedAPITypes", [])
    if not isinstance(declarations, list) or not any(
        isinstance(item, dict)
        and item.get("NSPrivacyAccessedAPIType") == "NSPrivacyAccessedAPICategoryUserDefaults"
        and isinstance(item.get("NSPrivacyAccessedAPITypeReasons"), list)
        and "CA92.1" in item["NSPrivacyAccessedAPITypeReasons"]
        for item in declarations
    ):
        raise ValueError(f"{path}: UserDefaults / CA92.1 の必須理由宣言がありません")


if __name__ == "__main__":
    for manifest_path in sys.argv[1:]:
        verify(manifest_path)
        print(f"{manifest_path}: UserDefaults / CA92.1 OK")
