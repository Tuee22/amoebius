#!/usr/bin/env python3
"""Run and seal the Phase-41 raw-kernel WireGuard fabric gate."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Sequence


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_41"
LIVE = EVIDENCE / "wireguard-live.json"
ENUMERATION = ROOT / "test/enumeration/phase_41_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_41_ledger.json"
ORACLE_MANIFEST = ROOT / "test/oracle/preimplementation_artifacts.tsv"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
GHC = "/home/matthewnowak/.ghcup/ghc/9.12.4/bin/ghc"
MODEL_PROVEN = {
    "keyless-peer-type-foreclosure",
    "overlapping-vpn-ip-foreclosure",
    "allowed-ips-outside-cidr-foreclosure",
}
UNVERIFIED = {"broker-geo-replication", "gateway-hub-repoint", "stretched-control-plane-peer"}
MUTANTS = (
    ("M-missing-peer-key", "phase41-missing-peer-key-mutant", "phase41-missing-peer-key:"),
    ("M-hub-no-endpoint", "phase41-hub-no-endpoint-mutant", "phase41-hub-no-endpoint:"),
    ("M-drop-resource-envelope", "phase41-drop-resource-envelope-mutant", "phase41-drop-resource-envelope:"),
    ("M-early-listener-replacement", "phase41-early-listener-replacement-mutant", "phase41-early-listener-replacement:"),
)


class GateFailure(RuntimeError):
    pass


def require(condition: bool, tag: str) -> None:
    if not condition:
        raise GateFailure(tag)


def fingerprint(value: Any, *, newline: bool = False) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    if newline:
        encoded += b"\n"
    return "sha256:" + hashlib.sha256(encoded).hexdigest()


def canonical_hash(value: dict[str, Any]) -> str:
    payload = dict(value)
    payload.pop("ledger_hash", None)
    return fingerprint(payload)


def invoke(name: str, arguments: Sequence[str], *, extra_env: dict[str, str] | None = None, timeout: int = 3600) -> dict[str, str]:
    environment = os.environ.copy()
    environment.update(extra_env or {})
    result = subprocess.run(
        list(arguments), cwd=ROOT, env=environment, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if result.returncode:
        raise GateFailure(f"{name}:exit-{result.returncode}:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": result.stdout.strip(), "result": "PASS"}


def all_flags(enabled: str | None = None) -> tuple[str, ...]:
    return tuple(f"-f{'-' if flag != enabled else ''}{flag}" for _, flag, _ in MUTANTS)


def cabal_test_args(enabled: str | None = None) -> tuple[str, ...]:
    return (
        CABAL, "test", "phase41-wireguard-live-gate", "-w", GHC, *all_flags(enabled),
        "--test-show-details=direct", "-j1", "-v0",
    )


def reject_mutant(name: str, flag: str, marker: str) -> dict[str, str]:
    environment = os.environ.copy()
    environment["PHASE41_PURE_ONLY"] = "1"
    arguments = cabal_test_args(flag)
    result = subprocess.run(
        arguments, cwd=ROOT, env=environment, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=1800,
    )
    require(result.returncode != 0, f"{name}:green-mutant")
    require(marker in result.stdout, f"{name}:wrong-red-reason:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": marker, "result": "RED"}


def phase0_domain() -> dict[str, str]:
    rows = [line for line in ORACLE_MANIFEST.read_text(encoding="utf-8").splitlines() if line.startswith("41\t")]
    require(len(rows) == 9, "phase0-custody-cardinality")
    require(sum("\toracle\t" in row for row in rows) == 5, "phase0-oracle-cardinality")
    require(sum("\tmutant\t" in row for row in rows) == 4, "phase0-mutant-cardinality")
    for row in rows:
        path = ROOT / row.split("\t")[2]
        require(path.is_file() and path.stat().st_size > 0, f"phase0-custody-missing:{path}")
    return {"name": "phase0-custody", "command": "read test/oracle/preimplementation_artifacts.tsv", "output": "5 oracles; 4 mutants", "result": "PASS"}


def derive_ledger() -> dict[str, Any]:
    surfaces = [line.strip() for line in ENUMERATION.read_text(encoding="utf-8").splitlines() if line.strip() and not line.startswith("#")]
    coverage = []
    for surface in surfaces:
        status = "UNVERIFIED" if surface in UNVERIFIED else "proven-for-the-model" if surface in MODEL_PROVEN else "tested"
        coverage.append({"surface": surface, "status": status})
    ledger: dict[str, Any] = {
        "phase": 41,
        "gate_command": "python3 tools/phase41_gate.py --reuse-fresh-live",
        "register": "3", "substrate": "linux-cpu", "date": "2026-08-11",
        "layers": [
            {"name": "Decision", "status": "proven-for-the-model"},
            {"name": "Protocol", "status": "tested"},
            {"name": "Runtime", "status": "tested"},
        ],
        "coverage": coverage,
    }
    ledger["ledger_hash"] = canonical_hash(ledger)
    return ledger


def evidence_domain(*, fresh: bool) -> None:
    require(LIVE.is_file(), "live-evidence-absent")
    if fresh:
        require(time.time() - LIVE.stat().st_mtime < 7200, "live-evidence-stale")
    live = json.loads(LIVE.read_text(encoding="utf-8"))
    require(live.get("schema") == "amoebius.phase41.wireguard-live.v1", "live-schema")
    require(live.get("register") == 3 and live.get("substrate") == "linux-cpu", "register-substrate")
    stable = dict(live)
    actual_digest = stable.pop("evidenceDigest", None)
    require(actual_digest == fingerprint(stable, newline=True), "live-evidence-digest")
    admission = live.get("admission", {})
    require(admission.get("tokenConsumedOnce") is True and admission.get("zeroEffectsBeforeAdmission") is True, "admission-token")
    require(set(admission.get("preEffectNegatives", {})) == {
        "cpuReservationOneShort", "cpuCeilingOneShort", "memoryReservationOneShort", "memoryCeilingOneShort",
        "nodeFsOneShort", "queueOneShort", "hostProcessSlotOneShort", "changedFingerprint", "missingPeerExpansion",
    }, "pre-effect-negative-domain")
    vault = live.get("vault", {})
    require(vault.get("secretRefsOnly") is True and vault.get("freshKeysResolved") is True, "vault-secretref-resolution")
    require(vault.get("missingRefSpecificReason") == "secret-missing" and vault.get("rawKeyBytesRetained") is False, "vault-missing-or-custody")
    require(re.fullmatch(r"sha256:[0-9a-f]{64}", str(vault.get("currentTreeClientBinaryDigest"))), "vault-client-binary-digest")
    kernel = live.get("kernel", {})
    require(kernel.get("interface") == "wg0" and kernel.get("hubVpnIp") == "10.77.0.1" and kernel.get("spokeVpnIp") == "10.77.1.2", "kernel-identity")
    require(all(kernel.get(key) is True for key in ("icmpReachable", "tcpReachable", "wgShowMatched")), "kernel-reachability")
    require(all(re.fullmatch(r"sha256:[0-9a-f]{64}", str(kernel.get(key))) for key in ("hubStateDigest", "spokeStateDigest")), "kernel-state-digests")
    underlay = live.get("underlay", {})
    require(underlay.get("protocol") == "udp/51820" and underlay.get("wireguardUdpObserved") is True and underlay.get("cleartextCanaryAbsent") is True, "underlay-observation")
    require(re.fullmatch(r"sha256:[0-9a-f]{64}", str(underlay.get("captureDigest"))), "capture-digest")
    require(live.get("reconcile") == {"firstPassMutations": 2, "secondPassMutations": 0}, "reconcile-idempotence")
    resources = live.get("resourceReadback", {})
    require(resources.get("withinProvision") is True and resources.get("nodeFsHighWaterBytes", 1245185) <= 1245184, "resource-high-water")
    require(resources.get("logPolicy") == {"maxBytesPerFile": 65536, "maxBackups": 2, "retentionSeconds": 86400}, "log-policy")
    nodes = resources.get("nodes", [])
    require(len(nodes) == 2, "resource-node-domain")
    for node in nodes:
        require(node.get("cpuWeight") == 25 and node.get("cpuMax") == "10000 100000", "cpu-readback")
        require(node.get("memoryLow") == 8388608 and node.get("memoryMax") == 33554432, "memory-readback")
        require(node.get("qdiscKind") == "tbf" and node.get("qdiscRateBytesPerSecond") == 2560000 and node.get("qdiscLimitBytes") == 65536, "queue-readback")
    require(live.get("cleanup") == {"cgroups": [], "exact": True, "namespaces": [], "temporaryPaths": []}, "cleanup")
    require(live.get("deferred") == {
        "brokerGeoReplication": "UNVERIFIED", "gatewayHubRepoint": "UNVERIFIED", "stretchedControlPlanePeer": "UNVERIFIED",
    }, "deferred-domain")
    require(live.get("universalLinuxCpu") == {
        "availableOnEveryHardwareSubstrate": True,
        "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"},
    }, "universal-linux-cpu-and-pristine-routing")
    serialized = LIVE.read_text(encoding="utf-8")
    require(not re.search(r"[A-Za-z0-9+/]{43}=", serialized), "wireguard-key-in-evidence")
    require("root_token" not in serialized and "kubernetes.jwt" not in serialized and "privateKey" not in serialized, "secret-custody")


def no_live_residue() -> dict[str, str]:
    namespaces = subprocess.run(("/usr/sbin/ip", "netns", "list"), text=True, stdout=subprocess.PIPE, check=False).stdout
    require(not re.search(r"a41[hs]-", namespaces), "live-namespace-residue")
    cgroups = list(Path("/sys/fs/cgroup").glob("amoebius-phase41-*"))
    require(not cgroups, "live-cgroup-residue")
    temporary = list(Path("/var/tmp").glob("amoebius-phase41-*"))
    require(not temporary, "live-temporary-residue")
    return {"name": "external-cleanup-readback", "command": "read ip-netns/cgroup/tmp inventories", "output": "empty", "result": "PASS"}


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--derive-ledger", action="store_true")
    parser.add_argument("--reuse-fresh-live", action="store_true")
    args = parser.parse_args(argv)
    try:
        if args.derive_ledger:
            print(json.dumps(derive_ledger(), separators=(",", ":")))
            return 0
        disabled = all_flags()
        rows = [invoke("source-build", (
            CABAL, "build", "amoebius:dsl-core", "phase41-wireguard-live-gate", "-w", GHC, *disabled, "-j1", "-v0",
        ))]
        rows.append(phase0_domain())
        rows.append(invoke("representative-dhall-typecheck", ("/home/matthewnowak/.local/bin/dhall", "--file", "dhall/examples/wireguard_fabric.dhall")))
        if args.reuse_fresh_live:
            rows.append({"name": "wireguard-live", "command": "sealed just-produced Phase-41 live receipt", "output": "fresh final live evidence", "result": "PASS"})
        else:
            rows.append(invoke("wireguard-live", (sys.executable, "tools/phase41_wireguard_live.py"), timeout=3600))
        evidence_domain(fresh=args.reuse_fresh_live)
        rows.append(no_live_residue())
        rows.append(invoke("sealed-live-reader", cabal_test_args(), extra_env={"PHASE41_REUSE_FRESH_LIVE": "1"}))
        rows.extend(reject_mutant(*mutant) for mutant in MUTANTS)
        rows.append(invoke("baseline-restored", cabal_test_args(), extra_env={"PHASE41_REUSE_FRESH_LIVE": "1"}))
        rows.append(invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")))
        derived = derive_ledger()
        require(LEDGER.is_file() and json.loads(LEDGER.read_text(encoding="utf-8")) == derived, "committed-ledger-differs")
        rows.append(invoke("ledger-lint", (sys.executable, "tools/ledger_lint.py", str(LEDGER), "--enumeration", str(ENUMERATION))))
        stable = {
            "schema": "amoebius.phase41.receipt.v1", "register": 3, "substrate": "linux-cpu",
            "peers": ["gateway-root", "spoke-alpha"], "wireguardUdpObserved": True,
            "cleartextCanaryAbsent": True, "secondPassMutations": 0,
            "mutantsRed": [name for name, _, _ in MUTANTS], "result": "PASS",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        (EVIDENCE / "phase-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE / "phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        (EVIDENCE / "phase-gate.log").write_text(
            "\n".join(f"CHECK {row['name']}\nCOMMAND {row['command']}\n{row['output']}\nRESULT {row['result']}" for row in rows)
            + f"\nPHASE-41-GATE PASS {derived['ledger_hash']}\n", encoding="utf-8",
        )
        print(f"phase41-gate: PASS ({len(rows)} checks; {derived['ledger_hash']}; {receipt['receiptFingerprint']})")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
        print(f"phase41-gate: FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
