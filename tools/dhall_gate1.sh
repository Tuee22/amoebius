#!/usr/bin/env bash
set -euo pipefail
exec python3 tools/dhall_gate1.py --positive-only
