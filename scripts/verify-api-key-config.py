#!/usr/bin/env python3
"""Generated Info.plist configuration status only; never print the key."""
import argparse
import plistlib
import re

parser = argparse.ArgumentParser()
parser.add_argument("plist")
parser.add_argument("--expect", choices=("configured", "missing"))
args = parser.parse_args()
with open(args.plist, "rb") as stream:
    value = plistlib.load(stream).get("SafeBrowsingAPIKey", "")
value = value.strip() if isinstance(value, str) else ""
valid = bool(value and not value.upper().startswith("YOUR_") and re.fullmatch(r"[A-Za-z0-9_-]+", value))
state = "configured" if valid else "missing"
print(state)
if args.expect and state != args.expect:
    raise SystemExit(1)
