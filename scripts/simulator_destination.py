#!/usr/bin/env python3
"""iOS 18.5以上の使用可能なiPhone Simulatorを選ぶ。"""
import json
import re
import subprocess
import sys

catalog = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "--json"]))
candidates = []
for runtime, devices in catalog["devices"].items():
    match = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not match:
        continue
    version = tuple(map(int, match.groups()))
    if version < (18, 5):
        continue
    for device in devices:
        if device.get("isAvailable") and device["name"].startswith("iPhone"):
            candidates.append((version, device["udid"]))
if not candidates:
    sys.exit("iOS 18.5以上のiPhone Simulatorが必要です。xcodebuild -downloadPlatform iOSで追加してください。")
print(max(candidates)[1])
