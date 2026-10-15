#!/usr/bin/env python3
"""Product diagnostics must use the bounded AppLog API."""
from pathlib import Path
import re

violations = []
for path in Path("SafeQR/SafeQR").rglob("*.swift"):
    text = path.read_text()
    if re.search(r"\b(?:print|debugPrint|NSLog|dump|os_log)\s*\(", text):
        violations.append(str(path))
    if path.name != "AppLog.swift" and re.search(r"\bLogger\s*\(", text):
        violations.append(str(path))
if violations:
    print("ログ方針違反: " + ", ".join(sorted(set(violations))))
    raise SystemExit(1)
print("ログ方針: OK")
