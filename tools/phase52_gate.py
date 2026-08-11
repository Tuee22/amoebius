#!/usr/bin/env python3
"""Run and seal the scoped Phase-52 jitML UI lift gate."""

from __future__ import annotations

import argparse
import csv
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
EVIDENCE_DIR = ROOT / "DEVELOPMENT_PLAN/evidence/phase_52"
LIVE = EVIDENCE_DIR / "jitml-ui-live.json"
MANIFEST = ROOT / "test/phase0_oracle_manifest.tsv"
ENUMERATION = ROOT / "test/enumeration/phase_52_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_52_ledger.json"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
GHC = "/home/matthewnowak/.ghcup/ghc/9.12.4/bin/ghc"
DHALL = "/home/matthewnowak/.local/bin/dhall"
DHALL_TO_JSON = "/home/matthewnowak/.local/bin/dhall-to-json"
KIND = "/home/matthewnowak/.local/bin/kind"
KUBECTL = "/usr/bin/kubectl"
FLAGS = (
    "phase52-mint-ready-from-checkpoint-path-mutant", "phase52-ignore-artifact-scope-mutant",
    "phase52-ignore-artifact-owner-mutant", "phase52-local-only-websocket-route-mutant",
    "phase52-redis-as-receipt-mutant",
)
MUTANTS = {
    "phase52-mint-ready-from-checkpoint-path-mutant": "mut-52-mint-ready-from-checkpoint-path",
    "phase52-ignore-artifact-scope-mutant": "mut-52-ignore-artifact-scope",
    "phase52-ignore-artifact-owner-mutant": "mut-52-ignore-artifact-owner",
    "phase52-local-only-websocket-route-mutant": "mut-52-local-only-websocket-route",
    "phase52-redis-as-receipt-mutant": "mut-52-redis-as-receipt",
}
UNVERIFIED = {
    "fresh-keycloak-sessions", "browser-through-envoy", "kubernetes-ui-server-replicas",
    "retained-minio-ready-and-receipt", "native-cbor-pulsar-command-event-chain",
    "retained-redis-tls-route-loss", "full-sibling-jitml-serving-engine",
    "phase51-training-commit-in-same-ui-flow", "direct-jitml-worker-networkpolicy-denial",
    "general-tenant-noninterference", "multi-zone-high-availability",
}


class GateFailure(RuntimeError):
    pass


def require(condition: bool, tag: str) -> None:
    if not condition:
        raise GateFailure(tag)


def fingerprint(value: Any, *, newline: bool = False) -> str:
    payload = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    return "sha256:" + hashlib.sha256(payload + (b"\n" if newline else b"")).hexdigest()


def canonical_hash(value: dict[str, Any]) -> str:
    stable = dict(value)
    stable.pop("ledger_hash", None)
    return fingerprint(stable)


def invoke(name: str, arguments: Sequence[str], *, timeout: int = 1800) -> dict[str, str]:
    result = subprocess.run(
        list(arguments), cwd=ROOT, env=os.environ,
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    require(result.returncode == 0, f"{name}:exit-{result.returncode}:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": result.stdout.strip(), "result": "PASS"}


def flags(enabled: str | None = None) -> tuple[str, ...]:
    return tuple(("-f" if flag == enabled else "-f-") + flag for flag in FLAGS)


def contract_args(enabled: str | None = None) -> tuple[str, ...]:
    return (CABAL, "test", "jitml-ui-lift-contract", "-w", GHC, *flags(enabled),
            "--test-show-details=direct", "-j1", "-v0")


def reject_mutant(flag: str, marker: str) -> dict[str, str]:
    arguments = contract_args(flag)
    result = subprocess.run(
        arguments, cwd=ROOT, env=os.environ,
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=1800,
    )
    require(result.returncode != 0 and marker in result.stdout, f"{marker}:green-or-wrong-locus:{result.stdout}")
    return {"name": marker, "command": shlex.join(arguments), "output": marker, "result": "RED"}


def phase0_domain() -> dict[str, str]:
    rows = [line for line in MANIFEST.read_text(encoding="utf-8").splitlines() if line.startswith("52\t")]
    require(len(rows) == 11, "phase0-cardinality")
    require(sum("\toracle\t" in row for row in rows) == 6 and sum("\tmutant\t" in row for row in rows) == 5,
            "phase0-kind-cardinality")
    for row in rows:
        path = ROOT / row.split("\t")[2]
        require(path.is_file() and path.stat().st_size > 0, f"phase0-missing:{path}")
    patches = "\n".join((ROOT / row.split("\t")[2]).read_text(encoding="utf-8")
                         for row in rows if "\tmutant\t" in row)
    require("src/Amoebius/JitML/UiAdapter.hs" in patches and all(locus in patches for locus in
            ("CheckpointInFlight", "contextTenant", "contextSubject", "routePendingReceipt", "authoritativeReceipt")),
            "phase0-mutant-loci")
    return {"name": "phase0-custody", "command": "read Phase-52 manifest rows",
            "output": "6 oracles; 5 mutants", "result": "PASS"}


def oracle_domain() -> dict[str, str]:
    decoded = subprocess.run(
        (DHALL_TO_JSON, "--file", "test/dhall/phase_52/jitml_ui.dhall"), cwd=ROOT,
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=120,
    )
    require(decoded.returncode == 0, f"phase52-dhall-oracle:{decoded.stdout}")
    value = json.loads(decoded.stdout)
    require(value == {"program": "jitml-ui", "ports": ["WorkflowProgress", "ArtifactProvenance", "ModelInteractor"],
                      "mode": "MultiTenant"}, "dhall-oracle")
    matrix = list(csv.DictReader((ROOT / "test/fixtures/phase_52/readiness_owner_scope_matrix.tsv").open(encoding="utf-8"), delimiter="\t"))
    require([row["result"] for row in matrix] == ["allow", "NotReady", "NotReady", "Unavailable", "Unavailable"]
            and [int(row["gpu_effects"]) for row in matrix] == [1, 0, 0, 0, 0], "readiness-owner-scope-matrix")
    timeline = list(csv.DictReader((ROOT / "test/fixtures/phase_52/cross_pod_receipt_timeline.tsv").open(encoding="utf-8"), delimiter="\t"))
    require([row["source"] for row in timeline] == ["ui-A", "jitml-worker", "ui-B", "harness", "ui-current"]
            and all(row["pulsar_starts"] == "1" for row in timeline)
            and all(row["gpu_launches"] == ("0" if index == 0 else "1") for index, row in enumerate(timeline)),
            "receipt-timeline")
    contract = (ROOT / "test/fixtures/phase_52/public_contract.golden").read_text(encoding="utf-8")
    require("OpaqueHandle" in contract and "Checkpoint paths" in contract
            and not any(token in contract for token in ("http://", "https://", "s3://", "pulsar://")), "public-contract")
    return {"name": "independent-oracles", "command": "Dhall/TSV/public-contract validation",
            "output": "UI, readiness/owner/scope, timeline, public contract oracles valid", "result": "PASS"}


def evidence_domain(*, fresh: bool) -> None:
    require(LIVE.is_file(), "live-evidence-absent")
    if fresh:
        require(time.time() - LIVE.stat().st_mtime < 7200, "live-evidence-stale")
    raw = LIVE.read_text(encoding="utf-8")
    live = json.loads(raw)
    stable = dict(live)
    actual = stable.pop("evidenceDigest", None)
    require(actual == fingerprint(stable, newline=True), "live-evidence-digest")
    require(live["schema"] == "amoebius.phase52.jitml-ui-live.v1" and live["register"] == 3
            and live["substrate"] == "linux-cuda" and live["result"] == "PASS-SCOPED", "live-schema")
    authority = live["authority"]
    require(not authority["freshKeycloakSessions"] and not authority["rawTokensStored"]
            and set(authority["scopedIdentityFixtures"]) == {"alice", "bob", "carol"}
            and all(row["active"] for row in authority["scopedIdentityFixtures"].values())
            and all(str(value).startswith("sha256:") for value in authority["tokenDigests"].values()), "live-authority")
    browser = live["browser"]
    require(browser["engine"] == "google-chrome/playwright-core" and browser["positiveStatuses"] == [200] * 4
            and browser["visibleResult"] == "stable-reference-vector" and browser["hostileScriptCount"] == 0
            and "&lt;SCRIPT&gt;" in browser["hostileHtml"] and len(set(browser["origins"])) == 2, "live-browser")
    workflow = live["workflow"]
    require(workflow["commandId"] == workflow["workId"] and workflow["terminalOutcome"] == "TerminalSucceeded"
            and workflow["effects"] == {"trainingStarts": 1, "cudaInvocations": 1, "checkpointReads": 1,
                                         "resultWrites": 1, "pointerAdvances": 0}
            and workflow["denials"] == {"sameTenantNonOwner": 404, "foreignTenant": 404, "inflight": 409, "failed": 409}
            and workflow["forbiddenEffectDelta"] == 0 and workflow["receiptOriginReplica"] == "ui-B", "live-workflow")
    cuda = live["cuda"]
    require(cuda["physicalDevice"] and not cuda["cpuFallback"] and cuda["driverApi"] == "libcuda.so.1"
            and cuda["parameters"] == 10000000 and cuda["optimizerSteps"] == cuda["kernelLaunches"] == 200
            and cuda["checkpointBytes"] == 40000000 and cuda["allocationReleased"], "live-cuda")
    require(all(value == "UNVERIFIED" for key, value in live["providers"].items() if key != "retainedProviderReason"),
            "provider-honesty")
    require(all(live["cleanup"].values()), "live-cleanup")
    require(live["universalLinuxCpu"] == {"availableOnEveryHardwareSubstrate": True,
            "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"}},
            "universal-linux-cpu")
    require(not re.search(r'(?i)(access_token|client_secret|password"\s*:|authorization"\s*:)', raw), "secret-in-evidence")


def external_cleanup() -> dict[str, str]:
    clusters = subprocess.run((KIND, "get", "clusters"), text=True, stdout=subprocess.PIPE,
                              check=False, timeout=60).stdout.splitlines()
    require(clusters == ["amoebius-phase24"], f"kind-clusters:{clusters}")
    namespaces = subprocess.run(
        (KUBECTL, "--kubeconfig", str(Path.home() / ".amoebius/phase24/kubeconfig"),
         "get", "namespace", "-o", "name"), text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, check=False, timeout=60,
    )
    require(namespaces.returncode == 0 and not any("phase52" in row for row in namespaces.stdout.splitlines()),
            "phase52-namespace-residue")
    live = json.loads(LIVE.read_text(encoding="utf-8"))
    process = subprocess.run(("/bin/ps", "-p", str(live["cuda"]["nvidiaSmiObservedPid"])),
                             text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=30)
    require(process.returncode != 0, "phase52-live-process-still-running")
    return {"name": "external-cleanup-readback", "command": "kind/Kubernetes/process inventories",
            "output": "no Phase-52 namespace/process; retained kind only", "result": "PASS"}


def derive_ledger() -> dict[str, Any]:
    surfaces = [line.strip() for line in ENUMERATION.read_text(encoding="utf-8").splitlines()
                if line.strip() and not line.startswith("#")]
    require(len(surfaces) == len(set(surfaces)), "duplicate-enumeration-surface")
    require(UNVERIFIED <= set(surfaces), "unverified-surface-not-enumerated")
    ledger: dict[str, Any] = {
        "phase": 52,
        "gate_command": "python3 tools/phase52_gate.py --reuse-fresh-live",
        "register": "3", "substrate": "linux-cuda", "date": "2026-08-11",
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
    parser.add_argument("--reuse-fresh-live", action="store_true")
    args = parser.parse_args(argv)
    try:
        if args.derive_ledger:
            print(json.dumps(derive_ledger(), separators=(",", ":")))
            return 0
        disabled = flags()
        rows = [invoke("phase52-source-build", (CABAL, "build", "jitml-ui-lift:lib:jitml-ui-lift",
            "jitml-ui-lift-contract", "jitml-ui-lift-live-gate", "-w", GHC, *disabled, "-j1", "-v0"))]
        rows.append(phase0_domain())
        rows.append(oracle_domain())
        rows.append(invoke("production-dhall-ui", (DHALL, "type", "--file", "dhall/ui/jitml.dhall", "--quiet")))
        rows.append(invoke("jitml-ui-lift-contract", contract_args()))
        if args.reuse_fresh_live:
            rows.append({"name": "jitml-ui-live", "command": "sealed just-produced Phase-52 live receipt",
                         "output": "fresh Chrome/identity/durable-file/host-CUDA evidence", "result": "PASS"})
        else:
            rows.append(invoke("jitml-ui-live", (sys.executable, "tools/phase52_jitml_ui_live.py"), timeout=1200))
        evidence_domain(fresh=args.reuse_fresh_live)
        rows.append(external_cleanup())
        reader = (CABAL, "test", "jitml-ui-lift-live-gate", "-w", GHC,
                  "--test-show-details=direct", "-j1", "-v0")
        rows.append(invoke("sealed-live-reader", reader))
        for flag, marker in MUTANTS.items():
            rows.append(reject_mutant(flag, marker))
        rows.append(invoke("baseline-restored-contract", contract_args()))
        rows.append(invoke("baseline-restored-live-reader", reader))
        rows.append(invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")))
        derived = derive_ledger()
        require(LEDGER.is_file() and json.loads(LEDGER.read_text(encoding="utf-8")) == derived,
                "committed-ledger-differs")
        rows.append(invoke("ledger-lint", (sys.executable, "tools/ledger_lint.py", str(LEDGER),
                                           "--enumeration", str(ENUMERATION))))
        stable = {
            "schema": "amoebius.phase52.receipt.v1", "register": 3, "substrate": "linux-cuda",
            "realBrowser": "TESTED", "physicalHostCuda": "TESTED", "identityFixtures": 3,
            "forbiddenEffects": 0, "retainedProviders": "UNVERIFIED", "kubernetesUiReplicas": "UNVERIFIED",
            "mutantsRed": list(MUTANTS.values()), "result": "PASS-SCOPED",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
        (EVIDENCE_DIR / "phase-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE_DIR / "phase-results.tsv").write_text(
            "check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8",
        )
        (EVIDENCE_DIR / "phase-gate.log").write_text(
            "\n".join(f"CHECK {row['name']}\nCOMMAND {row['command']}\n{row['output']}\nRESULT {row['result']}" for row in rows)
            + f"\nPHASE-52-GATE PASS-SCOPED {derived['ledger_hash']}\n", encoding="utf-8",
        )
        print(f"phase52-gate: PASS-SCOPED ({len(rows)} checks; {derived['ledger_hash']}; {receipt['receiptFingerprint']}; retained providers/Kubernetes UI replicas/Envoy/native-CBOR/full sibling serving UNVERIFIED)")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
        print(f"phase52-gate: FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
