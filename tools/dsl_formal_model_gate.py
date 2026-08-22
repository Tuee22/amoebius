#!/usr/bin/env python3
"""Phase 18: bounded DSL formal models and actual implementation projections."""

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
EMITTED = ROOT / ".build" / "tla" / "dsl-formal-model-spec"
RESULTS = EMITTED / "phase-results.tsv"
CONTRACT = "DEVELOPMENT_PLAN/phase_18_dsl_formal_model.md"
GATE_COMMAND = "python3 tools/dsl_formal_model_gate.py"
EXPECTATIONS = "test/oracle/dsl_formal_model_surfaces.tsv"

CHECKS = {
    "emitted-spec-untracked": "fresh TLA+/CFG and TLC output stay generated beneath .build/**",
    "toolchain-satisfies-requirements": "the resolved compiler, JVM, and TLC satisfy authored ranges",
    "recorded-results-match-oracle": "every suite metric equals the phase contract's expectation",
    "mutation-catalog-exact": "all eight named safety mutants redden exactly their authored invariant",
}

SIDES = ("toolchain", "suite", "oracle", "artifact")

EXPECTED_RESULTS = {
    "formal-model-count": "6",
    "explorer-state-total": "18",
    "explorer-tlc-fingerprints": "5/5-equal",
    "dsl-safety-invariants": "8/8-green-explorer-tlc",
    "liveness-properties": "4/4-green-under-fairness",
    "fairness-drop-mutants": "4/4-red",
    "exact-safety-mutants": "8/8-red-exactly",
    "decoder-projection": "5-positive/4-negative",
    "capacity-differential": "6561/6561",
    "render-chain-projection": "2/2-green",
    "protocol-code-projection": "3/3-green",
    "calculus-composition-projection": "green",
    "renderer-semantics": "6/6-green",
    "runtime-fidelity": "UNVERIFIED",
}

SURFACE_EVIDENCE = {
    "formal-model-structure": ("formal-model-count", "6"),
    "explorer-tlc-agreement": ("explorer-tlc-fingerprints", "5/5-equal"),
    "dsl-safety": ("dsl-safety-invariants", "8/8-green-explorer-tlc"),
    "dsl-liveness": ("liveness-properties", "4/4-green-under-fairness"),
    "fairness-sensitivity": ("fairness-drop-mutants", "4/4-red"),
    "exact-safety-mutants": ("exact-safety-mutants", "8/8-red-exactly"),
    "mutation-catalogue": ("exact-safety-mutants", "8/8-red-exactly"),
    "decoder-bounded-projection": ("decoder-projection", "5-positive/4-negative"),
    "capacity-bounded-differential": ("capacity-differential", "6561/6561"),
    "render-chain-semantic-projection": ("render-chain-projection", "2/2-green"),
    "protocol-code-projection": ("protocol-code-projection", "3/3-green"),
    "calculus-composition": ("calculus-composition-projection", "green"),
    "semantic-renderer": ("renderer-semantics", "6/6-green"),
    "runtime-fidelity": None,
}

PROVEN_SURFACES = {"dsl-safety", "dsl-liveness"}


class GateFailure(RuntimeError):
    pass


def run(command: list[str], *, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command, cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, check=False,
    )
    if result.returncode != 0:
        raise GateFailure(f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout[-8000:]}")
    return result


def toolchain_side() -> tuple[bool, dict[str, Any]]:
    print("toolchain side — compiler, JVM, and TLC from authored requirements\n")
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
        print("  FAIL  toolchain-satisfies-requirements TLC printed no version banner")
        return False, resolved
    print(f"  ok    tlc          {banner.strip()}")
    return True, resolved


def suite_side(resolved: dict[str, Any], run_dir: Path) -> tuple[bool, dict[str, str]]:
    print("\nsuite side — actual DSL projections and six bounded formal models\n")
    env = toolchain.contained_env()
    env["PATH"] = os.pathsep.join([str(ROOT / "tools"), env.get("PATH", "")])
    env["AMOEBIUS_JAVA"] = resolved["java"]["path"]
    env["AMOEBIUS_TLA2TOOLS"] = resolved["tla2tools"]["path"]
    build_root = ROOT / ".build" / "dist-newstyle" / "dsl-formal-model"
    if build_root.exists():
        shutil.rmtree(build_root)
    try:
        result = run(
            [resolved["cabal"]["path"], f"--with-compiler={resolved['ghc']['path']}",
             f"--builddir={build_root}", f"--store-dir={ROOT / '.build' / 'cabal-store'}",
             "test", "dsl-formal-model-spec", "--test-show-details=direct"],
            env=env,
        )
    except GateFailure as error:
        (run_dir / "suite.log").write_text(str(error), encoding="utf-8")
        print(f"  FAIL  dsl-formal-model-spec; transcript at {gate_common.rel(run_dir / 'suite.log')}")
        return False, {}
    (run_dir / "suite.log").write_text(result.stdout, encoding="utf-8")
    if not RESULTS.is_file():
        print(f"  FAIL  suite emitted no {gate_common.rel(RESULTS)}")
        return False, {}
    rows: dict[str, str] = {}
    for line in RESULTS.read_text(encoding="utf-8").splitlines()[1:]:
        key, _, value = line.partition("\t")
        rows[key] = value
    print(f"  ok    dsl-formal-model-spec green; {len(rows)} metric(s) recorded")
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
        print(f"  ok    recorded-results-match-oracle all {len(EXPECTED_RESULTS)} metrics match")
        print("  ok    mutation-catalog-exact   8/8 reddened exactly their authored invariant")
    return ok


def artifact_side(run_dir: Path) -> bool:
    print("\nartifact side — emitted formal artifacts remain generated\n")
    snapshot = set(artifact_policy.snapshot_paths())
    emitted = sorted(EMITTED.rglob("*.tla")) + sorted(EMITTED.rglob("*.cfg"))
    if not emitted:
        print("  FAIL  emitted-spec-untracked no TLA+/CFG artifacts were emitted")
        return False
    leaked = [path for path in emitted if gate_common.rel(path) in snapshot]
    for path in leaked:
        print(f"  FAIL  emitted-spec-untracked {gate_common.rel(path)} is in the source snapshot")
    if leaked:
        return False
    (run_dir / "emitted-spec.json").write_text(
        json.dumps({gate_common.rel(path): artifact_policy.digest(str(path)) for path in emitted},
                   indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"  ok    emitted-spec-untracked {len(emitted)} emitted file(s), none tracked")
    return True


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=18, contract=CONTRACT, command=GATE_COMMAND, expectations=EXPECTATIONS,
        register="1", substrate="none", lane="none", sides=SIDES,
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)

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

    decision_green = all(rows.get(key) == value for key, value in {
        "decoder-projection": "5-positive/4-negative",
        "capacity-differential": "6561/6561",
        "render-chain-projection": "2/2-green",
        "protocol-code-projection": "3/3-green",
        "calculus-composition-projection": "green",
    }.items())
    layers = {
        "Decision": "tested" if decision_green else "UNVERIFIED",
        "Protocol": "proven-for-the-model"
        if rows.get("dsl-safety-invariants") == "8/8-green-explorer-tlc"
        and rows.get("liveness-properties") == "4/4-green-under-fairness"
        else "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    results["ledger"] = gate.ledger_side(surfaces, layers, status)
    results["attestation"] = gate.attestation_side(
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items() if name != "platform"
        },
        dependencies={"dsl-formal-model-spec": "cabal test"},
        checks=results,
        mutants=[
            {"name": "exact safety mutants", "status": rows.get("exact-safety-mutants", "unrun")},
            {"name": "fairness-drop mutants", "status": rows.get("fairness-drop-mutants", "unrun")},
        ],
        observations={"results": "sha256:" + artifact_policy.digest(str(RESULTS))}
        if RESULTS.is_file() else {},
    )
    results["containment"] = gate.containment_side()
    results["write-guard"] = gate.write_guard_side()
    return gate.report(results)


if __name__ == "__main__":
    raise SystemExit(main())
