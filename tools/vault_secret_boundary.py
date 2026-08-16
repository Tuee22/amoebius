#!/usr/bin/env python3
"""Validate the prompt-only test-secret seam without reading a production secret."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import artifact_policy  # noqa: E402
import containment  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]
SCHEMA = ROOT / "test-secrets-types.dhall"
MUTANTS = ROOT / "test/mutant/vault_pki"


class BoundaryFailure(RuntimeError):
    pass


def require(condition: bool, label: str) -> None:
    if not condition:
        raise BoundaryFailure(label)


def rejected(action, label: str) -> None:
    try:
        action()
    except containment.ContainmentError:
        return
    raise BoundaryFailure(label)


def validate(dhall: str) -> None:
    schema = SCHEMA.read_text(encoding="utf-8")
    require("aws_admin_for_test_simulation" in schema, "narrow-test-secret-shape-absent")
    require("access_key_id" in schema and "secret_access_key" in schema, "provider-fields-absent")
    require(all(name not in schema for name in ("route53", "ses_", "acme_eab", "pulumi_state_backend")), "unused-secret-field-present")
    checked = subprocess.run(
        [dhall, "--file", str(SCHEMA)], cwd=ROOT, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=120,
    )
    require(checked.returncode == 0, "test-secret-schema-does-not-typecheck")

    ignored = subprocess.run(
        ["git", "check-ignore", "test-secrets.dhall"], cwd=ROOT,
        text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    )
    require(ignored.returncode == 0, "test-secret-file-not-ignored")
    dockerignore = (ROOT / ".dockerignore").read_text(encoding="utf-8")
    require("test-secrets.dhall" in dockerignore, "test-secret-file-in-container-context")

    for relative in artifact_policy.snapshot_paths():
        if not relative.startswith(("app/", "src/", "pb/", "pulumi/")):
            continue
        path = ROOT / relative
        if path.is_file() and path.suffix in {".hs", ".py", ".sh"}:
            require(
                not containment.production_secret_references(relative, path.read_text(encoding="utf-8", errors="replace")),
                f"production-secret-reference:{relative}",
            )

    rejected(lambda: containment.require_secret_access("production"), "production-secret-read-was-admitted")
    rejected(lambda: containment.require_secret_access("ordinary-tool"), "ordinary-secret-read-was-admitted")
    containment.require_secret_sink("operator-prompt-stdin")
    for sink in ("environment", "argv", "build-state-copy", "test-state-copy", "container-context", "log", "attestation"):
        rejected(lambda sink=sink: containment.require_secret_sink(sink), f"secret-sink-admitted:{sink}")

    for root in containment.STATE_ROOTS.values():
        if root.is_dir():
            require(not any(root.rglob("test-secrets.dhall")), f"copied-test-secret:{root.name}")

    expected_mutants = {"production-secret-read.mutant", "copy-secret.mutant"}
    require({path.name for path in MUTANTS.glob("*.mutant")} >= expected_mutants, "secret-boundary-mutant-absent")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dhall", required=True, help="dynamically resolved Dhall executable")
    arguments = parser.parse_args()
    try:
        validate(arguments.dhall)
        print("vault-secret-boundary: PASS (production rejection, prompt-only sink, narrow schema, no copies)")
        return 0
    except (BoundaryFailure, OSError, subprocess.TimeoutExpired) as problem:
        print(f"vault-secret-boundary: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
