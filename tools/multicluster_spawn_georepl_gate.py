#!/usr/bin/env python3
"""Run and seal the Phase-43 recursive-spawn and sibling-replication gate."""

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
EVIDENCE = ROOT / "DEVELOPMENT_PLAN/evidence/phase_42"
LIVE = EVIDENCE / "multicluster-live.json"
ENUMERATION = ROOT / "test/enumeration/phase_43_surfaces.txt"
LEDGER = ROOT / "test/golden/phase_43_ledger.json"
MANIFEST = ROOT / "test/oracle/preimplementation_artifacts.tsv"
CABAL = "/home/matthewnowak/.ghcup/bin/cabal"
GHC = "/home/matthewnowak/.ghcup/ghc/9.12.4/bin/ghc"
KIND = "/home/matthewnowak/.local/bin/kind"
DHALL_TO_JSON = "/home/matthewnowak/.local/bin/dhall-to-json"
MUTANTS = (
    ("M-classifier-default-confluent", "multicluster-spawn-georepl-classifier-default-confluent-mutant", "multicluster-spawn-georepl-classifier-default-confluent:"),
    ("M-project-identity", "multicluster-spawn-georepl-project-identity-mutant", "multicluster-spawn-georepl-project-identity:"),
    ("M-drop-parallel-executor", "multicluster-spawn-georepl-drop-parallel-executor-mutant", "multicluster-spawn-georepl-drop-parallel-executor:"),
)
UNVERIFIED = {
    "physically-independent-pulsar-broker-per-child",
    "child-local-vault-process-per-mode",
    "provider-managed-children",
    "rke2-children",
}


class GateFailure(RuntimeError):
    pass


def require(condition: bool, tag: str) -> None:
    if not condition:
        raise GateFailure(tag)


def fingerprint(value: Any, *, newline: bool = False) -> str:
    payload = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    if newline:
        payload += b"\n"
    return "sha256:" + hashlib.sha256(payload).hexdigest()


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


def flags(enabled: str | None = None) -> tuple[str, ...]:
    return tuple(f"-f{'-' if flag != enabled else ''}{flag}" for _, flag, _ in MUTANTS)


def test_args(enabled: str | None = None) -> tuple[str, ...]:
    return (CABAL, "test", "multicluster-spawn-live", "-w", GHC, *flags(enabled), "--test-show-details=direct", "-j1", "-v0")


def reject_mutant(name: str, flag: str, marker: str) -> dict[str, str]:
    environment = os.environ.copy()
    environment.update({"MULTICLUSTER_SPAWN_GEOREPL_PURE_ONLY": "1"})
    arguments = test_args(flag)
    result = subprocess.run(
        arguments, cwd=ROOT, env=environment, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=1800,
    )
    require(result.returncode != 0, f"{name}:green-mutant")
    require(marker in result.stdout, f"{name}:wrong-red-reason:{result.stdout}")
    return {"name": name, "command": shlex.join(arguments), "output": marker, "result": "RED"}


def phase0_domain() -> dict[str, str]:
    rows = [line for line in MANIFEST.read_text(encoding="utf-8").splitlines() if line.startswith("42\t")]
    require(len(rows) == 15, "phase0-custody-cardinality")
    require(sum("\toracle\t" in row for row in rows) == 12, "phase0-oracle-cardinality")
    require(sum("\tmutant\t" in row for row in rows) == 3, "phase0-mutant-cardinality")
    for row in rows:
        path = ROOT / row.split("\t")[2]
        require(path.is_file() and path.stat().st_size > 0, f"phase0-custody-missing:{path}")
    return {"name": "phase0-custody", "command": "read test/oracle/preimplementation_artifacts.tsv", "output": "12 oracles; 3 mutants", "result": "PASS"}


def compile_corpus() -> dict[str, str]:
    base = (CABAL, "exec", "--", GHC, "-fno-code", "-XGHC2024", "-isrc", "-package", "text")
    positive = subprocess.run(
        (*base, "test/negative/compile_fail/ChildInForceSpec/Positive.hs"), cwd=ROOT, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=300,
    )
    require(positive.returncode == 0, f"positive-compile:{positive.stdout}")
    for stem in ("NegativeSibling", "NegativeAncestor"):
        result = subprocess.run(
            (*base, f"test/negative/compile_fail/ChildInForceSpec/{stem}.hs"), cwd=ROOT, text=True,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=300,
        )
        expected = (ROOT / f"test/negative/compile_fail/ChildInForceSpec/{stem}.stderr").read_text(encoding="utf-8").strip()
        require(result.returncode != 0, f"{stem}:compiled")
        require(re.sub(r"\s+", " ", expected) in re.sub(r"\s+", " ", result.stdout), f"{stem}:wrong-error:{result.stdout}")
    return {"name": "child-in-force-compile-corpus", "command": "cabal exec -- ghc -fno-code compile corpus", "output": "positive compiled; sibling and ancestor projections rejected", "result": "PASS"}


def oracle_domain() -> dict[str, str]:
    classification = subprocess.run(
        (DHALL_TO_JSON, "--file", "test/fixture/inject/confluence/expected_classes.dhall"), cwd=ROOT,
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=120,
    )
    require(classification.returncode == 0, f"classification-dhall:{classification.stdout}")
    rows = json.loads(classification.stdout)
    require({row.get("invariant") for row in rows} == {
        "content-addressed-blob", "work-id-event-fold", "relational-work-row",
        "gateway-authority", "latest-pointer", "cluster-vpn-ip-allocation",
    }, "classification-domain")
    require(all(
        row.get("activeActiveAllowed") is (row.get("class") == "Confluent")
        for row in rows
    ), "classification-active-active-domain")
    for name in ("idempotent-write.golden.json", "expected-forest-demand.json", "live-observer-contract.json"):
        require(isinstance(json.loads((ROOT / "test/fixture/phase42" / name).read_text(encoding="utf-8")), dict), f"json-oracle:{name}")
    for name in ("kind-parent.yaml", "amoebius-p42-a.yaml", "amoebius-p42-b.yaml"):
        value = (ROOT / "test/fixture/phase42" / name).read_text(encoding="utf-8")
        require("kind: Cluster" in value and "apiVersion: kind.x-k8s.io/v1alpha4" in value, f"kind-oracle:{name}")
    return {"name": "independent-oracles", "command": "dhall-to-json and parse pinned fixtures", "output": "Dhall, JSON, and kind fixtures valid", "result": "PASS"}


def evidence_domain(*, fresh: bool) -> None:
    require(LIVE.is_file(), "live-evidence-absent")
    if fresh:
        require(time.time() - LIVE.stat().st_mtime < 7200, "live-evidence-stale")
    live = json.loads(LIVE.read_text(encoding="utf-8"))
    require(live.get("schema") == "amoebius.phase42.multicluster-live.v1", "live-schema")
    require(live.get("register") == 3 and live.get("substrate") == "linux-cpu", "register-substrate")
    stable = dict(live)
    actual_digest = stable.pop("evidenceDigest", None)
    require(actual_digest == fingerprint(stable, newline=True), "live-evidence-digest")
    spawn = live.get("spawn", {})
    require(spawn.get("parentCluster") == "amoebius-p42-parent", "parent-identity")
    require(spawn.get("children") == ["amoebius-p42-a", "amoebius-p42-b"], "child-identity")
    require(spawn.get("pulumiRanInsideParent") is True and spawn.get("boundedParallel") == 2, "in-parent-bounded-pulumi")
    require(spawn.get("childrenReady") is True and spawn.get("secondPassNoOp") is True, "child-ready-idempotence")
    require(spawn.get("firstPassMutations") == 2 and spawn.get("secondPassMutations") == 0, "pulumi-mutation-counts")
    readback = spawn.get("executorJobReadback", [])
    require(len(readback) == 2, "executor-readback-domain")
    for job in readback:
        require(job.get("requests") == {"cpu": "250m", "ephemeral-storage": "64Mi", "memory": "256Mi"}, "executor-requests")
        require(job.get("limits") == {"cpu": "500m", "ephemeral-storage": "128Mi", "memory": "512Mi"}, "executor-limits")
        require(job.get("workspaceSizeLimit") == "64Mi" and job.get("pluginCacheSizeLimit") == "32Mi", "executor-volume-limits")
    require(live.get("projection", {}).get("noSiblingOrAncestorBranch") is True, "projection-isolation")
    vault = live.get("vault", {})
    require(all(vault.get(key) is True for key in ("bothUnsealModes", "parentHeldModeBricksWhenParentSealed", "crossChildDecryptDenied", "namedSecretResolved")), "vault-contract")
    require(vault.get("rawSecretBytesRetained") is False, "raw-secret-retention")
    replication = live.get("replication", {})
    require(all(replication.get(key) is True for key in ("nativePulsarRoundtrip", "minioWriteOnceHead", "postgresWorkIdReadback", "duplicateReorderIdentical")), "replication-contract")
    require(replication.get("boundary") == "two real child clusters; retained HA native-protocol data plane", "replication-boundary-honesty")
    cleanup = live.get("cleanup", {})
    require(cleanup.get("exact") is True, "cleanup-exact")
    require(cleanup.get("survivingChildClusters") == 0 and cleanup.get("survivingPulumiStacks") == 0 and cleanup.get("survivingParentClusters") == 0, "cleanup-inventory")
    require(live.get("deferred") == {
        "physicallyIndependentPulsarBrokerPerChild": "UNVERIFIED",
        "childLocalVaultProcessPerMode": "UNVERIFIED",
        "providerManagedChildren": "UNVERIFIED until Phase 45",
        "rke2Children": "UNVERIFIED",
    }, "deferred-honesty")
    require(live.get("universalLinuxCpu") == {
        "availableOnEveryHardwareSubstrate": True,
        "pristineLinuxHost": {"linux": "Incus", "linux-cuda": "Incus", "apple": "Lima", "windows": "WSL2"},
    }, "universal-linux-cpu-and-pristine-routing")
    serialized = LIVE.read_text(encoding="utf-8")
    require(not re.search(r"(?i)(root_token|privateKey|kubernetes\.jwt|parent-injected-bytes)", serialized), "secret-in-evidence")


def no_live_residue() -> dict[str, str]:
    clusters = subprocess.run((KIND, "get", "clusters"), text=True, stdout=subprocess.PIPE, check=False, timeout=60).stdout.splitlines()
    require(not any(name in clusters for name in ("amoebius-p42-parent", "amoebius-p42-a", "amoebius-p42-b")), "kind-cluster-residue")
    require(not Path("/var/tmp/amoebius-multicluster-spawn-georepl-live").exists(), "temporary-root-residue")
    return {"name": "external-cleanup-readback", "command": "kind and exact temporary-root inventories", "output": "no Phase-43 clusters, stacks, or temporary root", "result": "PASS"}


def derive_ledger() -> dict[str, Any]:
    surfaces = [line.strip() for line in ENUMERATION.read_text(encoding="utf-8").splitlines() if line.strip() and not line.startswith("#")]
    ledger: dict[str, Any] = {
        "phase": 42,
        "gate_command": "python3 tools/multicluster_spawn_georepl_gate.py --reuse-fresh-live",
        "register": "3", "substrate": "linux-cpu", "date": "2026-08-11",
        "layers": [
            {"name": "Decision", "status": "tested"},
            {"name": "Protocol", "status": "tested"},
            {"name": "Runtime", "status": "tested"},
        ],
        "coverage": [{"surface": surface, "status": "UNVERIFIED" if surface in UNVERIFIED else "tested"} for surface in surfaces],
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
        rows = [invoke("source-build", (CABAL, "build", "amoebius:dsl-core", "amoebius-pulumi", "-w", GHC, *flags(), "-j1", "-v0"))]
        rows.append(phase0_domain())
        rows.append(compile_corpus())
        rows.append(oracle_domain())
        if args.reuse_fresh_live:
            rows.append({"name": "multicluster-live", "command": "sealed just-produced Phase-43 live receipt", "output": "fresh final live evidence", "result": "PASS"})
        else:
            rows.append(invoke("multicluster-live", (sys.executable, "tools/multicluster_spawn_georepl_live.py"), timeout=5400))
        evidence_domain(fresh=args.reuse_fresh_live)
        rows.append(no_live_residue())
        rows.append(invoke("sealed-live-reader", test_args(), extra_env={"MULTICLUSTER_SPAWN_GEOREPL_REUSE_FRESH_LIVE": "1"}))
        rows.extend(reject_mutant(*mutant) for mutant in MUTANTS)
        rows.append(invoke("baseline-restored", test_args(), extra_env={"MULTICLUSTER_SPAWN_GEOREPL_REUSE_FRESH_LIVE": "1"}))
        rows.append(invoke("documentation-lint", (sys.executable, "tools/doc_lint.py")))
        derived = derive_ledger()
        require(LEDGER.is_file() and json.loads(LEDGER.read_text(encoding="utf-8")) == derived, "committed-ledger-differs")
        rows.append(invoke("ledger-lint", (sys.executable, "tools/ledger_lint.py", str(LEDGER), "--enumeration", str(ENUMERATION))))
        stable = {
            "schema": "amoebius.phase42.receipt.v1", "register": 3, "substrate": "linux-cpu",
            "children": ["amoebius-p42-a", "amoebius-p42-b"], "secondPassMutations": 0,
            "retainedDataPlane": True, "mutantsRed": [name for name, _, _ in MUTANTS], "result": "PASS",
        }
        receipt = {**stable, "receiptFingerprint": fingerprint(stable)}
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        (EVIDENCE / "phase-receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (EVIDENCE / "phase-results.tsv").write_text("check\tresult\n" + "".join(f"{row['name']}\t{row['result']}\n" for row in rows), encoding="utf-8")
        (EVIDENCE / "phase-gate.log").write_text(
            "\n".join(f"CHECK {row['name']}\nCOMMAND {row['command']}\n{row['output']}\nRESULT {row['result']}" for row in rows)
            + f"\nPHASE-42-GATE PASS {derived['ledger_hash']}\n", encoding="utf-8",
        )
        print(f"multicluster-spawn-georepl-gate: PASS ({len(rows)} checks; {derived['ledger_hash']}; {receipt['receiptFingerprint']})")
        return 0
    except (GateFailure, OSError, ValueError, KeyError, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
        print(f"multicluster-spawn-georepl-gate: FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
