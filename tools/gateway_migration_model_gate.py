#!/usr/bin/env python3
"""The Phase-4 gate — the gateway-migration model, both branches.

The capability claim is unchanged: the concrete `GatewayMigration` model renders through
`emitTLA`, the in-process explorer and TLC agree on its 53 distinct reachable states and
their canonical fingerprints, five safety invariants hold, three liveness properties hold
under the declared fairness and redden without it, and every per-invariant, mechanical,
cutoff-clause, and shared-resource mutant turns the gate red.

What changed is the apparatus. The gate no longer acquires its JVM and `tla2tools` from
pinned URLs and archive checksums, no longer compares a committed ledger against derived
outcomes, and no longer writes evidence into an authored root. It resolves the toolchain
from authored requirements, derives the ledger into the run bundle, enumerates its surfaces
at run time, and publishes an attestation bound to the source snapshot.

    python3 tools/gateway_migration_model_gate.py

Exit status: 0 when every side passes, 1 otherwise.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import artifact_policy  # noqa: E402
import gate_common  # noqa: E402
import toolchain  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
EMITTED = ROOT / ".build" / "tla" / "gateway-migration-model-spec"
RESULTS = EMITTED / "phase-results.tsv"
CONTRACT = "DEVELOPMENT_PLAN/phase_17_gateway_migration_model.md"
GATE_COMMAND = "python3 tools/gateway_migration_model_gate.py"
EXPECTATIONS = "test/oracle/gateway_migration_model_surfaces.tsv"

CHECKS = {
    "emitted-spec-untracked": "the emitted .tla/.cfg live under .build/ and are not in the snapshot",
    "toolchain-satisfies-requirements": "the resolved JVM and tla2tools satisfy the authored ranges",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
    "invariant-mutants-exact": "each per-invariant mutant reddens its own invariant and no other",
    "cutoff-mutants-red": "deleting any structural-fit cutoff clause turns the gate red",
}

SIDES = ("toolchain", "suite", "oracle", "artifact")

# The authored oracle, read off the Phase-4 contract's Gate paragraph.
EXPECTED_RESULTS = {
    "gateway-distinct-state-count": "53",
    "explorer-tlc-fingerprints": "equal",
    "safety-invariants": "5/5-green",
    "liveness-properties": "3/3-green-under-fairness",
    "fairness-drop-mutants": "3/3-red",
    "per-invariant-mutants": "5/5-red-exactly",
    "mechanical-safety-mutants": "5/5-red",
    "iosimpor-schedule-bound": "20",
    "iosimpor-agreement": "green",
    "cutoff-clause-delete-mutants": "8/8-red",
    "scope3-shared-resource-mutant": "red",
    # The decomposition lemma is deliberately open: the contract records it as an
    # unproven obligation, and a gate that quietly reported it closed would be the
    # dishonest reading.
    "decomposition-lemma": "OPEN",
}

# Which recorded metric decides each surface, and the value it must carry.
SURFACE_EVIDENCE = {
    "gateway-model-structure": ("gateway-distinct-state-count", "53"),
    "gateway-safety": ("safety-invariants", "5/5-green"),
    "gateway-liveness": ("liveness-properties", "3/3-green-under-fairness"),
    "explorer-tlc-agreement": ("explorer-tlc-fingerprints", "equal"),
    "vacuity-action-antecedent": ("per-invariant-mutants", "5/5-red-exactly"),
    "fairness-sensitivity": ("fairness-drop-mutants", "3/3-red"),
    "per-invariant-mutants": ("per-invariant-mutants", "5/5-red-exactly"),
    "mechanical-mutation-family": ("mechanical-safety-mutants", "5/5-red"),
    "iosimpor-bounded-schedules": ("iosimpor-agreement", "green"),
    "structural-fit-cutoff": ("cutoff-clause-delete-mutants", "8/8-red"),
    "cutoff-clause-mutants": ("cutoff-clause-delete-mutants", "8/8-red"),
    "scope3-shared-resource-stress": ("scope3-shared-resource-mutant", "red"),
    # OPEN is the honest value, not a passing one. The surface stays UNVERIFIED.
    "decomposition-lemma": None,
    "runtime-fidelity": None,
}

PROVEN_SURFACES = {"gateway-safety", "gateway-liveness"}


class GateFailure(RuntimeError):
    pass


def run(command: list[str], *, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command, cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False
    )
    if result.returncode != 0:
        raise GateFailure(f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout[-6000:]}")
    return result


def toolchain_side() -> tuple[bool, dict[str, Any]]:
    print("toolchain side — the JVM and TLC resolved from authored requirements\n")
    try:
        resolved = toolchain.resolve(["cabal", "ghc", "java", "tla2tools"])
    except toolchain.ResolutionError as error:
        print(f"  FAIL  toolchain-satisfies-requirements {error}")
        return False, {}
    for name in ("ghc", "cabal", "java", "tla2tools"):
        record = resolved[name]
        print(f"  ok    {name:<12} {record['version']:<12} satisfies {record['requirement']}")
    probe = subprocess.run(
        [resolved["java"]["path"], "-jar", resolved["tla2tools"]["path"], "-help"],
        cwd=ROOT, env=toolchain.contained_env(), text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False,
    )
    banner = next((line for line in probe.stdout.splitlines() if "Version" in line), "")
    if not banner:
        print(f"  FAIL  toolchain-satisfies-requirements TLC printed no version banner:\n{probe.stdout[-800:]}")
        return False, resolved
    print(f"  ok    tlc          {banner.strip()}")
    return True, resolved


def suite_side(resolved: dict[str, Any], run_dir: Path) -> tuple[bool, dict[str, str]]:
    print("\nsuite side — the model, the renderer, TLC, and the IOSimPOR schedules\n")
    env = toolchain.contained_env()
    env["PATH"] = os.pathsep.join([str(ROOT / "tools"), env.get("PATH", "")])
    env["AMOEBIUS_JAVA"] = resolved["java"]["path"]
    env["AMOEBIUS_TLA2TOOLS"] = resolved["tla2tools"]["path"]
    build_root = ROOT / ".build" / "dist-newstyle" / "gateway-migration-model"
    if build_root.exists():
        shutil.rmtree(build_root)
    try:
        result = run(
            [resolved["cabal"]["path"], f"--with-compiler={resolved['ghc']['path']}",
             f"--builddir={build_root}", f"--store-dir={ROOT / '.build' / 'cabal-store'}",
             "test", "gateway-migration-model-spec", "--test-show-details=direct"],
            env=env,
        )
    except GateFailure as error:
        (run_dir / "suite.log").write_text(str(error), encoding="utf-8")
        print(f"  FAIL  gateway-migration-model-spec did not pass; transcript at {gate_common.rel(run_dir / 'suite.log')}")
        return False, {}
    (run_dir / "suite.log").write_text(result.stdout, encoding="utf-8")
    if not RESULTS.is_file():
        print(f"  FAIL  the suite emitted no {gate_common.rel(RESULTS)}")
        return False, {}
    rows: dict[str, str] = {}
    for line in RESULTS.read_text(encoding="utf-8").splitlines()[1:]:
        key, _, value = line.partition("\t")
        rows[key] = value
    print(f"  ok    gateway-migration-model-spec green; {len(rows)} metric(s) recorded")
    return True, rows


def oracle_side(rows: dict[str, str]) -> bool:
    print("\noracle side — recorded results against the authored expectation\n")
    ok = True
    for key, expected in sorted(EXPECTED_RESULTS.items()):
        actual = rows.get(key)
        if actual != expected:
            print(f"  FAIL  recorded-results-match-oracle {key}: {actual!r} != {expected!r}")
            ok = False
    extra = sorted(set(rows) - set(EXPECTED_RESULTS))
    if extra:
        print(f"  FAIL  recorded-results-match-oracle unexpected metric(s): {', '.join(extra)}")
        ok = False
    if ok:
        print(f"  ok    recorded-results-match-oracle all {len(EXPECTED_RESULTS)} metrics equal their authored values")
        print("  ok    invariant-mutants-exact   5/5 reddened exactly, so no invariant is vacuously true")
        print("  ok    cutoff-mutants-red        8/8 cutoff-clause deletions reddened")
    return ok


def artifact_side(run_dir: Path) -> bool:
    print("\nartifact side — the emitted spec stays generated\n")
    snapshot = set(artifact_policy.snapshot_paths())
    emitted = sorted(EMITTED.rglob("*.tla")) + sorted(EMITTED.rglob("*.cfg"))
    if not emitted:
        print(f"  FAIL  emitted-spec-untracked the run emitted no .tla/.cfg under {gate_common.rel(EMITTED)}")
        return False
    leaked = [p for p in emitted if gate_common.rel(p) in snapshot]
    for path in leaked:
        print(f"  FAIL  emitted-spec-untracked {gate_common.rel(path)} is in the source snapshot")
    if leaked:
        return False
    (run_dir / "emitted-spec.json").write_text(
        json.dumps(
            {gate_common.rel(p): artifact_policy.digest(str(p)) for p in emitted}, indent=2, sort_keys=True
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"  ok    emitted-spec-untracked {len(emitted)} emitted file(s), none in the source snapshot")
    return True


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=17, contract=CONTRACT, command=GATE_COMMAND, expectations=EXPECTATIONS,
        register="1", substrate="none", lane="none", sides=SIDES
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)

    # Clause 15 first: a run that cannot name the architecture it executed on, or that is
    # executing under translation, has nothing worth model-checking.
    results["architecture"] = gate.architecture_side()
    if not results["architecture"]:
        return gate.report(results)

    results["toolchain"], resolved = toolchain_side()
    rows: dict[str, str] = {}
    if results["toolchain"]:
        results["suite"], rows = suite_side(resolved, gate.run_dir)
    if rows:
        results["oracle"] = oracle_side(rows)
        results["artifact"] = artifact_side(gate.run_dir)

    implemented = {"metrics": set(rows), "checks": set(CHECKS)}
    results["surface"], surfaces = gate.surface_join(implemented)

    status: dict[str, bool] = {}
    for surface in surfaces:
        evidence = SURFACE_EVIDENCE.get(surface)
        status[surface] = bool(evidence) and rows.get(evidence[0]) == evidence[1]
    status["generated-artifact-discipline"] = results["artifact"]

    layers = {
        "Decision": "tested" if rows.get("explorer-tlc-fingerprints") == "equal" else "UNVERIFIED",
        "Protocol": "proven-for-the-model"
        if rows.get("safety-invariants") == "5/5-green"
        and rows.get("liveness-properties") == "3/3-green-under-fairness"
        else "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    results["ledger"] = gate.ledger_side(surfaces, layers, status)
    results["attestation"] = gate.attestation_side(
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items()
            if name != "platform"
        },
        dependencies={"gateway-migration-model-spec": "cabal test"},
        checks=results,
        mutants=[
            {"name": "per-invariant mutants", "status": rows.get("per-invariant-mutants", "unrun")},
            {"name": "mechanical safety mutants", "status": rows.get("mechanical-safety-mutants", "unrun")},
            {"name": "fairness-drop mutants", "status": rows.get("fairness-drop-mutants", "unrun")},
            {"name": "cutoff-clause delete mutants", "status": rows.get("cutoff-clause-delete-mutants", "unrun")},
            {"name": "scope-3 shared-resource mutant", "status": rows.get("scope3-shared-resource-mutant", "unrun")},
        ],
        observations={"results": "sha256:" + artifact_policy.digest(str(RESULTS))} if RESULTS.is_file() else {},
    )
    results["containment"] = gate.containment_side()
    results["write-guard"] = gate.write_guard_side()
    return gate.report(results)


if __name__ == "__main__":
    raise SystemExit(main())
