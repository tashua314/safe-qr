#!/usr/bin/env python3
"""Keep the required check explicit even when macOS is intentionally unnecessary."""
import os
import sys


def gate(portable, required, ios):
    if portable != "success":
        return False
    if required == "true":
        return ios == "success"
    if required == "false":
        return ios == "skipped"
    return False


if __name__ == "__main__":
    portable = os.environ.get("SAFEQR_PORTABLE_RESULT", "")
    required = os.environ.get("SAFEQR_IOS_REQUIRED", "")
    ios = os.environ.get("SAFEQR_IOS_RESULT", "")
    if not gate(portable, required, ios):
        sys.exit(f"品質ゲート失敗: portable={portable}, ios_required={required}, ios={ios}")
    print("品質ゲート成功: iOS全検証成功" if required == "true" else "品質ゲート成功: 文書のみのためiOS検証を省略")
