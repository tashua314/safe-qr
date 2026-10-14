#!/usr/bin/env python3
"""iOS 18.5以上の検証専用iPhone Simulatorを再利用、または作成する。"""
import json
import re
import subprocess
import sys

catalog = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "--json"]))
candidates = []
for runtime, devices in catalog["devices"].items():
    match = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if match and tuple(map(int, match.groups())) >= (18, 5):
        candidates.append((tuple(map(int, match.groups())), runtime, devices))
if not candidates:
    sys.exit("iOS 18.5以上のSimulatorが必要です。xcodebuild -downloadPlatform iOSで追加してください。")
_, runtime, devices = max(candidates, key=lambda item: item[0])
for device in devices:
    if device.get("isAvailable") and device["name"] == "SafeQR QA iPhone":
        print(device["udid"])
        break
else:
    identifier = subprocess.check_output([
        "xcrun", "simctl", "create", "SafeQR QA iPhone",
        "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro", runtime
    ], text=True).strip()
    print(identifier)
