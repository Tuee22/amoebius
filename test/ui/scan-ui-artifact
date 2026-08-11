#!/usr/bin/env python3
"""Reject browser escape surfaces in the built generic UI bundle."""

from __future__ import annotations

import argparse
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle", type=Path)
    args = parser.parse_args()
    source = args.bundle.read_text(encoding="utf-8")
    forbidden = {
        "eval(": "eval",
        "new Function": "dynamic-function",
        "localStorage": "localStorage",
        "sessionStorage": "sessionStorage",
        "indexedDB": "indexedDB",
        "innerHTML": "raw-html-sink",
        "provider.invalid": "provider-host",
        "pulsar://": "provider-protocol",
        "redis://": "provider-protocol",
        "http://": "remote-import-or-provider",
        "private:server-handle": "server-handle-codec",
    }
    found = [label for token, label in forbidden.items() if token in source]
    required = [token for token in ("textContent", "WebSocket", "/ui/action/submit") if token in source]
    if found:
        print("ui-artifact-scan: FAIL " + ",".join(found))
        return 1
    if len(required) != 3:
        print("ui-artifact-scan: FAIL required runtime surface absent")
        return 1
    print("ui-artifact-scan: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
