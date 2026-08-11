#!/usr/bin/env python3
"""Negative entrypoint: provider deploys require the in-cluster singleton."""

from __future__ import annotations

import sys


def main() -> int:
    print("NoSingletonContext", file=sys.stderr)
    return 44


if __name__ == "__main__":
    raise SystemExit(main())
