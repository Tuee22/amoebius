#!/usr/bin/env python3
"""Run and seal the scoped Phase-53 Apple host-daemon gate."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_53"
LIVE = EVIDENCE / "apple-host-live.json"
ENUMERATION = ROOT / "test/enumeration/phase_53_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_53_ledger.json"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
GHC = "/home/matthewnowak/.ghcup/ghc/9.12.4/bin/ghc"
DHALL = "/home/matthewnowak/.local/bin/dhall"
FLAGS = (
    "phase53-const-output-mutant", "phase53-echo-golden-mutant", "phase53-lb-nodeport-mutant",
    "phase53-omit-metal-work-item-mutant", "phase53-favorable-metal-epoch-mutant",
    "phase53-drop-metal-overlap-debit-mutant",
)
MUTANTS = {
    "phase53-const-output-mutant": "job B",
    "phase53-echo-golden-mutant": "run-time challenge",
    "phase53-lb-nodeport-mutant": "NodePortRequired",
    "phase53-omit-metal-work-item-mutant": "MetalKeyDomainMismatch",
    "phase53-favorable-metal-epoch-mutant": "Metal coexistence peak",
    "phase53-drop-metal-overlap-debit-mutant": "host memory debit",
}
UNVERIFIED = {
    "physical-apple-silicon", "lima-vm-materialization", "brew-lima-live-ensure",
    "metal-framework-probe", "metal-device-library-pipeline", "metal-gpu-dispatch",
    "native-pulsar-work-consume", "content-mutation-gateway-write", "minio-content-addressed-artifact",
    "vault-live-resolution", "second-physical-lan-host-denial", "os-boundary-exec-trace",
    "live-sparse-image-high-water", "live-guest-mount-and-fs-type",
    "supervisor-metal-allocation-observer", "supervisor-cas-crash-repair", "full-cluster-teardown-recreate",
}


class Failure(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Failure(message)


def fingerprint(value: Any) -> str:
    payload = json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    return "sha256:" + hashlib.sha256(payload).hexdigest()


def canonical_hash(value: dict[str, Any]) -> str:
    stable = dict(value)
    stable.pop("ledger_hash", None)
    return fingerprint(stable)


def flags(enabled: str | None = None) -> tuple[str, ...]:
    return tuple(("-f" if flag == enabled else "-f-") + flag for flag in FLAGS)


def contract(enabled: str | None = None) -> tuple[str, ...]:
    return (CABAL, "test", "apple-host-lift:apple-metal-host-contract", "-w", GHC,
            *flags(enabled), "--test-show-details=direct", "-j1", "-v0")


def invoke(name: str, argv: Sequence[str], timeout: int = 1800) -> dict[str, str]:
    completed = subprocess.run(argv, cwd=ROOT, env=os.environ,
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout)
    require(completed.returncode == 0, f"{name}:exit-{completed.returncode}:{completed.stdout}")
    return {"name": name, "command": shlex.join(argv), "output": completed.stdout.strip(), "result": "PASS"}


def reject_mutant(flag: str, marker: str) -> dict[str, str]:
    argv = contract(flag)
    completed = subprocess.run(argv, cwd=ROOT, env=os.environ,
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=1800)
    require(completed.returncode != 0 and marker in completed.stdout, f"{flag}:green-or-wrong-locus:{completed.stdout}")
    return {"name": flag, "command": shlex.join(argv), "output": marker, "result": "RED"}


def phase0() -> dict[str, str]:
    rows = [line for line in (ROOT / "test/oracle/preimplementation_artifacts.tsv").read_text().splitlines() if line.startswith("53\t")]
    require(len(rows) == 20 and sum("\toracle\t" in row for row in rows) == 13
            and sum("\tmutant\t" in row for row in rows) == 7, "phase0-cardinality")
    for row in rows:
        require((ROOT / row.split("\t")[2]).is_file(), f"phase0-missing:{row}")
    return {"name": "phase0-custody", "command": "read Phase-53 manifest", "output": "13 oracles; 7 mutants", "result": "PASS"}


def dhall_domain() -> list[dict[str, str]]:
    rows = [invoke("green-host-comms-dhall", (DHALL, "type", "--file", "test/dhall/phase_53_illegal/green_host_comms.dhall", "--quiet"))]
    expected = (ROOT / "test/golden/phase_53/illegal_expected_errors.tsv").read_text().splitlines()[1:]
    for source in expected:
        fixture, locus, tag, message = source.split("\t")
        argv = (DHALL, "type", "--file", f"test/dhall/phase_53_illegal/{fixture}", "--quiet")
        completed = subprocess.run(argv, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
        require(completed.returncode != 0 and message in completed.stdout, f"{fixture}:{locus}:{tag}:{completed.stdout}")
        rows.append({"name": f"illegal-{tag}", "command": shlex.join(argv), "output": message, "result": "RED"})
    return rows


def evidence_domain() -> None:
    value = json.loads(LIVE.read_text())
    stable = dict(value)
    observed = stable.pop("evidenceDigest")
    payload = json.dumps(stable, sort_keys=True, separators=(",", ":")).encode() + b"\n"
    require(observed == "sha256:" + hashlib.sha256(payload).hexdigest(), "evidence-digest")
    require(value["result"] == "PASS-SCOPED" and value["executingHost"] == {"system": "Linux", "machine": "x86_64"}, "host-honesty")
    require(all(item == "UNVERIFIED" for key, item in value["honesty"].items() if key != "reason"), "honesty-matrix")
    require(value["universalLinuxCpu"] == {"availableOnEveryHardwareSubstrate": True,
        "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}}, "universal-cpu")


def derive_ledger() -> dict[str, Any]:
    surfaces = [line for line in ENUMERATION.read_text().splitlines() if line and not line.startswith("#")]
    require(len(surfaces) == len(set(surfaces)) and UNVERIFIED <= set(surfaces), "enumeration")
    ledger: dict[str, Any] = {
        "phase": 53, "gate_command": "python3 tools/phase53_gate.py",
        "register": "3", "substrate": "apple", "date": "2026-08-11",
        "layers": [{"name": "Decision", "status": "tested"}, {"name": "Protocol", "status": "tested"},
                   {"name": "Runtime", "status": "tested"}],
        "coverage": [{"surface": surface, "status": "UNVERIFIED" if surface in UNVERIFIED else "tested"}
                     for surface in surfaces],
    }
    ledger["ledger_hash"] = canonical_hash(ledger)
    return ledger


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--derive-ledger", action="store_true")
    args = parser.parse_args(argv)
    try:
        if args.derive_ledger:
            print(json.dumps(derive_ledger(), separators=(",", ":")))
            return 0
        rows = [invoke("apple-host-source-build", (CABAL, "build", "apple-host-lift:lib:apple-host-lift",
            "apple-host-lift:apple-metal-host-contract", "apple-host-lift:apple-metal-host-live-gate", "-w", GHC,
            *flags(), "-j1", "-v0"))]
        rows.append(phase0())
        rows.extend(dhall_domain())
        rows.append(invoke("apple-host-contract", contract()))
        rows.append(invoke("portable-live", (sys.executable, "tools/phase53_apple_host_live.py")))
        evidence_domain()
        reader = (CABAL, "test", "apple-host-lift:apple-metal-host-live-gate", "-w", GHC,
                  "--test-show-details=direct", "-j1", "-v0")
        rows.append(invoke("sealed-live-reader", reader))
        for flag, marker in MUTANTS.items():
            rows.append(reject_mutant(flag, marker))
        rows.append(invoke("baseline-restored", contract()))
        rows.append(invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")))
        derived = derive_ledger()
        require(LEDGER.is_file() and json.loads(LEDGER.read_text()) == derived, "committed-ledger-differs")
        rows.append(invoke("ledger-lint", (sys.executable, "tools/ledger_lint.py", str(LEDGER),
                                           "--enumeration", str(ENUMERATION))))
        stable = {"schema": "amoebius.phase53.receipt.v1", "register": 3, "substrate": "apple",
                  "portableContracts": "TESTED", "physicalAppleLimaMetal": "UNVERIFIED",
                  "mutantsRed": list(MUTANTS), "result": "PASS-SCOPED"}
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        (EVIDENCE / "phase-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n")
        (EVIDENCE / "phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows))
        (EVIDENCE / "phase-gate.log").write_text("\n".join(
            f"CHECK {row['name']}\nCOMMAND {row['command']}\n{row['output']}\nRESULT {row['result']}" for row in rows)
            + f"\nPHASE-53-GATE PASS-SCOPED {derived['ledger_hash']}\n")
        print(f"phase53-gate: PASS-SCOPED ({len(rows)} checks; {derived['ledger_hash']}; {receipt['receiptFingerprint']}; physical Apple/Lima/Metal/Pulsar/gateway/MinIO UNVERIFIED)")
        return 0
    except (Failure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
        print(f"phase53-gate: FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
