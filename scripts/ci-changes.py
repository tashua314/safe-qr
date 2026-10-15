#!/usr/bin/env python3
"""Decide whether a PR changes iOS validation inputs; errors never mean docs-only."""
import json
import os
from pathlib import Path
import re
import subprocess


def ios_required(paths):
    # docs/ is documentation only. App build inputs must remain under SafeQR/.
    return any(path not in {"README.md", "CLAUDE.md"} and not path.startswith("docs/") for path in paths)


def changed_paths(base):
    if not re.fullmatch(r"[0-9a-fA-F]{40}|[0-9a-fA-F]{64}", base):
        raise ValueError("変更判定には有効なbaseコミットSHAが必要です。")
    # Without --no-renames, moving a Swift file into docs/ could hide its deletion.
    data = subprocess.check_output(["git", "diff", "--no-renames", "--name-only", "-z", base, "HEAD", "--"])
    return [path.decode("utf-8", errors="surrogateescape") for path in data.split(b"\0") if path]


def main():
    force = os.environ.get("SAFEQR_FORCE_IOS", "false")
    if force not in {"true", "false"}:
        raise ValueError("SAFEQR_FORCE_IOSはtrue/falseで指定してください。")
    paths = [] if force == "true" else changed_paths(os.environ.get("SAFEQR_BASE_SHA", ""))
    required = force == "true" or ios_required(paths)
    value = "true" if required else "false"
    print(json.dumps({"ios_required": value, "changed_paths": paths, "manual": force == "true"}, ensure_ascii=True))
    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with Path(output).open("a") as stream:
            stream.write(f"ios_required={value}\n")


if __name__ == "__main__":
    main()
