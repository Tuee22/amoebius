#!/usr/bin/env bash
set -euo pipefail
exec python3 tools/dhall_typecheck.py --positive-only
