#!/usr/bin/env python3
"""Run and seal the complete Phase-29 Vault/PKI acceptance gate."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shlex
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_29"
ENUMERATION = ROOT / "test/enumeration/phase_29_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_29_ledger.json"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
UNVERIFIED = {"parent-child-unseal", "cross-cluster-intermediate-ca", "parent-secret-injection"}
MUTANTS = (
    ("M-reinit-existing", "phase29-vault-spec", "phase29-reinit-existing-mutant", "initialized sealed unseals"),
    ("M-raw-sha256-seal", "phase29-vault-spec", "phase29-raw-sha256-seal-mutant", "envelope has pinned magic"),
    ("M-delete-storage-term", "phase29-vault-spec", "phase29-delete-storage-term-mutant", "resident bytes"),
    ("M-unbounded-audit", "phase29-vault-spec", "phase29-unbounded-audit-mutant", "audit raw minimum"),
    ("M-sealed-issuance", "phase29-vault-spec", "phase29-sealed-issuance-mutant", "sealed issuance fails"),
    ("M-unrelated-leaf-key", "phase29-vault-spec", "phase29-unrelated-leaf-mutant", "leaf chains to root"),
    ("M-preminted-token", "phase29-vault-spec", "phase29-preminted-token-mutant", "client performs auth/kubernetes/login"),
    ("M-error-collapse", "phase29-vault-spec", "phase29-error-collapse-mutant", "six exact typed redacted errors"),
    ("M-stale-read", "phase29-vault-spec", "phase29-stale-read-mutant", "sealed cannot start"),
)


class GateFailure(RuntimeError):
    pass


def invoke(name: str, arguments: Sequence[str], timeout: int = 2400) -> dict[str, str]:
    environment = os.environ.copy()
    environment.pop("PHASE29_RESUME_CLEAN_RUN1", None)
    result = subprocess.run(list(arguments), cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout)
    if result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": result.stdout.strip(), "result": "PASS"}


def reject_mutant(name: str, suite: str, flag: str, marker: str) -> dict[str, str]:
    arguments = (CABAL, "test", suite, f"-f{flag}", "--test-show-details=direct", "-j1")
    result = subprocess.run(arguments, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=1200)
    if result.returncode == 0:
        raise GateFailure(f"{name}:green-mutant")
    if marker not in result.stdout:
        raise GateFailure(f"{name}:wrong-red-reason:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": marker, "result": "RED"}


def canonical_hash(value: dict[str, Any]) -> str:
    payload = dict(value)
    payload.pop("ledger_hash", None)
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    return "sha256:" + hashlib.sha256(encoded).hexdigest()


def derive_ledger() -> dict[str, Any]:
    surfaces = [line.strip() for line in ENUMERATION.read_text(encoding="utf-8").splitlines() if line.strip() and not line.lstrip().startswith("#")]
    ledger: dict[str, Any] = {
        "phase": 29,
        "gate_command": "python3 tools/phase29_gate.py",
        "register": "3",
        "substrate": "linux-cpu",
        "date": "2026-08-10",
        "layers": [
            {"name": "Decision", "status": "tested"},
            {"name": "Protocol", "status": "tested"},
            {"name": "Runtime", "status": "tested"},
        ],
        "coverage": [{"surface": surface, "status": "UNVERIFIED" if surface in UNVERIFIED else "tested"} for surface in surfaces],
    }
    ledger["ledger_hash"] = canonical_hash(ledger)
    return ledger


def evidence_domain(*, require_fresh: bool) -> dict[str, Any]:
    path = EVIDENCE / "vault-live.json"
    if not path.is_file():
        raise GateFailure("vault-live-evidence-absent")
    live = json.loads(path.read_text(encoding="utf-8"))
    if live.get("artifactSource", {}).get("run1", {}).get("resumedCleanRun1"):
        raise GateFailure("vault-live-used-resume-shortcut")
    if live.get("unlockEnvelope", {}).get("developmentPasswordUsed"):
        raise GateFailure("vault-live-used-development-password")
    if not live.get("unlockEnvelope", {}).get("operatorPasswordSupplied"):
        raise GateFailure("vault-live-operator-password-absent")
    if require_fresh and (time.time() - path.stat().st_mtime) > 3600:
        raise GateFailure("vault-live-evidence-stale")
    initialized = live.get("initOnce", {})
    if initialized.get("run1InitializedBefore") or initialized.get("initCount") != 1 or not initialized.get("vaultClusterIdStable"):
        raise GateFailure("init-once-domain")
    if not all(live.get("clusterRebuild", {}).get(key) for key in ("serverCaChanged", "clusterUidChanged", "kindClusterAbsent", "nodeContainerAbsent", "backingPresentWhileAbsent")):
        raise GateFailure("cluster-rebuild-domain")
    if not all(live.get("client", {}).get(key) for key in ("secretRefByteIdentical", "transitByteIdentical", "roleDeletionDenied", "auditKubernetesLoginObserved")):
        raise GateFailure("client-domain")
    if live.get("client", {}).get("agentSidecars") != 0 or live.get("client", {}).get("plainSecretMounts") != 0:
        raise GateFailure("plaintext-or-sidecar-domain")
    if not live.get("pki", {}).get("sameRootAfterRecreate") or live.get("pki", {}).get("sealedIssuanceStatus") == 200:
        raise GateFailure("pki-domain")
    return live


def fingerprint(value: dict[str, Any]) -> str:
    return "sha256:" + hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--derive-ledger", action="store_true")
    parser.add_argument("--seal-existing-live", action="store_true", help="Seal a just-produced non-resumed live receipt instead of rerunning the long cycle")
    arguments = parser.parse_args(argv)
    try:
        if arguments.derive_ledger:
            print(json.dumps(derive_ledger(), indent=2))
            return 0
        python = sys.executable
        rows = [
            invoke("pure-vault-contract", (CABAL, "test", "phase29-vault-spec", "--test-show-details=direct", "-j1")),
            invoke("fault-simulation", (CABAL, "test", "phase29-vault-sim", "--test-show-details=direct", "-j1")),
        ]
        if not arguments.seal_existing_live:
            rows.append(invoke("vault-delete-recreate-live", (python, "tools/phase29_vault_live.py"), timeout=3600))
        else:
            rows.append({"name": "vault-delete-recreate-live", "command": "sealed just-produced tools/phase29_vault_live.py receipt", "output": "fresh non-resumed evidence", "result": "PASS"})
        evidence_domain(require_fresh=arguments.seal_existing_live)
        rows.append(invoke("external-live-reader", (CABAL, "test", "vault-pki-live", "--test-show-details=direct", "-j1")))
        rows.extend(reject_mutant(*mutant) for mutant in MUTANTS)
        disabled = tuple(f"-f-{flag}" for _, _, flag, _ in MUTANTS)
        rows.append(invoke("baseline-restored", (CABAL, "test", "phase29-vault-spec", "phase29-vault-sim", *disabled, "--test-show-details=direct", "-j1")))
        rows.append(invoke("documentation-lint", (python, "tools/doc_lint.py")))
        derived = derive_ledger()
        committed = json.loads(LEDGER.read_text(encoding="utf-8"))
        if committed != derived:
            raise GateFailure("committed-ledger-differs:\n" + json.dumps(derived, indent=2))
        rows.append(invoke("ledger-lint", (python, "tools/ledger_lint.py", str(LEDGER), "--enumeration", str(ENUMERATION))))
        stable = {
            "schema": "amoebius.phase29.receipt.v1",
            "register": 3,
            "substrate": "linux-cpu",
            "initOnce": True,
            "retainedRebuild": True,
            "selfSignedRootAndLeaf": True,
            "directKubernetesAuthClient": True,
            "mutantsRed": [name for name, _, _, _ in MUTANTS],
            "result": "PASS",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        (EVIDENCE / "phase-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE / "phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        log = [f"CHECK {row['name']}\nCOMMAND {row['command']}\n{row['output']}\nRESULT {row['result']}" for row in rows]
        log.append(f"PHASE-29-GATE PASS {derived['ledger_hash']}")
        (EVIDENCE / "phase-gate.log").write_text("\n".join(log) + "\n", encoding="utf-8")
        print(f"phase29-gate: PASS ({len(rows)} checks; {derived['ledger_hash']}; {receipt['receiptFingerprint']})")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as problem:
        print(f"phase29-gate: FAIL: {problem}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
