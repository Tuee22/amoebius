#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
pattern='removePathForcibly|removeDirectoryRecursive|destroyRetainedBacking|deleteRetainedBacking|unlinkRetainedBacking'

if rg -n --glob '*.hs' "$pattern" "$root/src"; then
  echo 'no-retained-delete: FAIL: normal-operation source contains a retained-backing destruction primitive' >&2
  exit 1
fi

echo 'no-retained-delete: PASS (no normal-operation backing destruction primitive)'
