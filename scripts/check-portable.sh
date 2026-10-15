#!/usr/bin/env bash
set -euo pipefail
SAFEQR_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SAFEQR_ROOT"
for script in scripts/*.sh; do
    bash -n "$script"
done
python3 -B -m unittest discover -s scripts/tests -p 'test_*.py'
python3 scripts/check-log-policy.py
python3 - <<'PY'
import json
from pathlib import Path
paths = sorted(path for root in ("SafeQR", "docs") for path in Path(root).rglob("*.json"))
for path in paths:
    json.loads(path.read_text())
print(f"JSON構文: {len(paths)}件成功")
PY
