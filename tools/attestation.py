#!/usr/bin/env python3
"""The external-attestation adapter for amoebius phase gates.

`documents/engineering/repository_layout_doctrine.md` section 5 requires each gate to
emit its evidence under `gen/runs/**` and upload an **immutable** attestation to an
evidence store outside Git, binding the source snapshot, phase contract, command,
resolved dependency graph, toolchain, substrate, checks, mutants, coverage, cleanup,
and raw-observation digests.

The binding is the snapshot digest, never a commit. Commit timing is the operator's and
is not a gate input (`development_plan_standards.md` section S), so a bundle records the
revision it happened to sit on only as context and is refused for a missing digest, not
for uncommitted work.

This module owns two things and nothing else:

    schema_check(bundle)   the run-bundle shape, checked before anything is stored
    Store                  a content-addressed, write-once evidence backend

The bundles a conforming store must refuse live in `tools/attestation_negative_corpus.py`,
because a corpus has to contain the defect it seeds and this adapter must stay fully
scanned by the repository audit.

The default backend is a local content-addressed directory outside the repository.
A deployment swaps it for object storage by supplying a `Store`-compatible object; the
gate only needs `put` and `verify`.

    python3 tools/attestation.py --self-test
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from pathlib import Path

SCHEMA = 1

REQUIRED_KEYS = {
    "schema",
    "phase",
    "contract",
    "contract_digest",
    "commit",
    "source_digest",
    "command",
    "register",
    "substrate",
    "toolchain",
    "dependencies",
    "checks",
    "mutants",
    "coverage",
    "cleanup",
    "observations",
    "ledger_hash",
}


class AttestationError(Exception):
    """The store refused a bundle."""


def canonical_bytes(bundle: dict) -> bytes:
    payload = {key: value for key, value in bundle.items() if key != "attestation_digest"}
    return json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode(
        "utf-8"
    )


def bundle_digest(bundle: dict) -> str:
    return "sha256:" + hashlib.sha256(canonical_bytes(bundle)).hexdigest()


def schema_check(bundle: object) -> list[str]:
    problems: list[str] = []
    if not isinstance(bundle, dict):
        return ["bundle root must be an object"]

    missing = REQUIRED_KEYS - set(bundle)
    extra = set(bundle) - REQUIRED_KEYS
    if missing:
        problems.append(f"missing keys: {', '.join(sorted(missing))}")
    if extra:
        problems.append(f"unexpected keys: {', '.join(sorted(extra))}")
    if missing:
        return problems

    if bundle["schema"] != SCHEMA:
        problems.append(f"schema must be {SCHEMA}")
    if not isinstance(bundle["phase"], int) or bundle["phase"] < 0:
        problems.append("phase must be a non-negative integer")
    if not isinstance(bundle["commit"], str) or not bundle["commit"].strip():
        problems.append("commit must name the revision the snapshot sat on, or 'uncommitted'")
    digest = bundle["source_digest"]
    if not isinstance(digest, str) or not digest.startswith("sha256:") or len(digest) != 71:
        problems.append("source_digest must be the sha256 digest of the source snapshot")
    for key in ("contract", "contract_digest", "command", "register", "substrate", "ledger_hash"):
        if not isinstance(bundle[key], str) or not bundle[key].strip():
            problems.append(f"{key} must be a non-empty string")
    for key in ("toolchain", "dependencies", "observations"):
        if not isinstance(bundle[key], dict):
            problems.append(f"{key} must be an object")
    for key in ("checks", "mutants", "coverage"):
        value = bundle[key]
        if not isinstance(value, list) or not value:
            problems.append(f"{key} must be a non-empty array")
    if not isinstance(bundle["cleanup"], dict) or "left_resources" not in bundle["cleanup"]:
        problems.append("cleanup must record whether the run left resources behind")
    return problems


class Store:
    """A write-once, content-addressed evidence store on a local filesystem."""

    def __init__(self, root: Path):
        self.root = Path(root)
        self.root.mkdir(parents=True, exist_ok=True)

    def _path(self, reference: str) -> Path:
        return self.root / (reference.replace("sha256:", "") + ".json")

    def put(self, bundle: dict) -> str:
        problems = schema_check(bundle)
        if problems:
            raise AttestationError("; ".join(problems))
        reference = bundle_digest(bundle)
        target = self._path(reference)
        payload = canonical_bytes(bundle)
        if target.exists():
            if target.read_bytes() != payload:
                raise AttestationError(f"{reference} already stored with different content")
            return reference
        temporary = target.with_suffix(".partial")
        temporary.write_bytes(payload)
        os.chmod(temporary, 0o444)
        temporary.rename(target)
        return reference

    def verify(self, reference: str) -> bool:
        target = self._path(reference)
        if not target.is_file():
            return False
        try:
            stored = json.loads(target.read_bytes())
        except (OSError, json.JSONDecodeError):
            return False
        return bundle_digest(stored) == reference

    def tamper(self, reference: str, key: str, value: object) -> None:
        """Mutate a stored bundle. Only the self-test calls this."""
        target = self._path(reference)
        stored = json.loads(target.read_bytes())
        stored[key] = value
        os.chmod(target, 0o644)
        target.write_bytes(json.dumps(stored, sort_keys=True, separators=(",", ":")).encode())
        os.chmod(target, 0o444)


def default_store() -> Store:
    configured = os.environ.get("AMOEBIUS_EVIDENCE_STORE")
    root = Path(configured) if configured else Path.home() / ".local" / "share" / "amoebius" / "evidence"
    return Store(root)


def sample_bundle() -> dict:
    """A minimal conforming bundle, used to prove the path before a real run uses it."""
    return {
        "schema": SCHEMA,
        "phase": 0,
        "contract": "DEVELOPMENT_PLAN/phase_00_documentation_suite.md",
        "contract_digest": "sha256:" + "0" * 64,
        "commit": "0" * 40,
        "source_digest": "sha256:" + "2" * 64,
        "command": "python3 tools/doc_lint_verify.py",
        "register": "—",
        "substrate": "none",
        "toolchain": {"python": "synthetic"},
        "dependencies": {},
        "checks": [{"name": "synthetic", "status": "pass"}],
        "mutants": [{"name": "synthetic", "status": "red"}],
        "coverage": [{"surface": "synthetic", "status": "tested"}],
        "cleanup": {"left_resources": False},
        "observations": {},
        "ledger_hash": "sha256:" + "1" * 64,
    }


def run_self_test() -> bool:
    import tempfile

    from attestation_negative_corpus import negative_corpus

    ok = True
    with tempfile.TemporaryDirectory(prefix="amoebius-attest-selftest-") as directory:
        store = Store(Path(directory))
        positive = sample_bundle()
        problems = schema_check(positive)
        if problems:
            print(f"  FAIL positive bundle rejected: {problems}")
            return False
        reference = store.put(positive)
        print(f"  ok   positive                     stored {reference[:19]}…")
        if not store.verify(reference):
            print("  FAIL positive bundle did not verify")
            ok = False
        else:
            print("  ok   verify                       digest matches the stored bytes")

        store.tamper(reference, "substrate", "linux-cpu")
        if store.verify(reference):
            print("  FAIL tampered bundle still verified")
            ok = False
        else:
            print("  ok   tamper                       mutation breaks verification")

        for name, broken, expect in negative_corpus(positive):
            if schema_check(broken):
                print(f"  ok   {name:<27} refused at schema")
                continue
            try:
                store.put(broken)
            except AttestationError:
                print(f"  ok   {name:<27} refused at store")
                continue
            print(f"  FAIL {name:<27} accepted; expected refusal at {expect}")
            ok = False
    return ok


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="The amoebius external-attestation adapter.")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args(argv)
    if args.self_test:
        return 0 if run_self_test() else 1
    ap.error("nothing to do; pass --self-test")
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
