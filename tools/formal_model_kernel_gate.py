#!/usr/bin/env python3
"""The Phase-2 gate — the formal-model kernel and its explorer/TLC differential.

The capability claim is unchanged from the pre-amendment gate: one reifiable `Model` value
renders both ways, the in-process explorer and TLC agree on the safety verdict and on the
canonical distinct-state fingerprints, every mechanical model mutant and every renderer
mutant is caught, and the emitted `.tla`/`.cfg` are never committed.

What changed is everything around that claim. The gate used to acquire its JVM and
`tla2tools` from URLs and archive checksums pinned in a tracked manifest, assert two
hard-coded version strings, write its evidence into the plan tree, and compare a committed
ledger against machine-derived results. It now resolves the toolchain from authored
compatibility requirements, writes every observation into the run bundle, enumerates its
surfaces at run time, and publishes an attestation bound to the source snapshot.

The oracle side is untouched and is where the teeth are: `EXPECTED_RESULTS` below is the
authored expectation the recorded suite results must equal, and the ledger is *derived*
from those same recorded results — so a print-statement ledger still cannot pass.

    python3 tools/formal_model_kernel_gate.py

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
RESULTS = ROOT / ".build" / "tla" / "formal-model-spec" / "phase-results.tsv"
EMITTED = ROOT / ".build" / "tla" / "formal-model-spec"
CONTRACT = "DEVELOPMENT_PLAN/phase_02_formal_model_kernel.md"
GATE_COMMAND = "python3 tools/formal_model_kernel_gate.py"
EXPECTATIONS = "test/oracle/formal_model_kernel_surfaces.tsv"

CHECKS = {
    "emitted-spec-untracked": "the emitted .tla/.cfg live under .build/ and are not in the snapshot",
    "toolchain-satisfies-requirements": "the resolved JVM and tla2tools satisfy the authored ranges",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
    "ledger-derived-from-results": "each ledger row is derived from a recorded metric, not asserted",
}

SIDES = ("toolchain", "suite", "oracle", "artifact")

# The authored oracle. Every value here is read off the Phase-2 contract's Gate paragraph,
# which fixes the hand-derived distinct-state count, the mutation quotas, the differential
# sample floor, and the per-constructor coverage floor.
EXPECTED_RESULTS = {
    "toy-distinct-state-count": "8",
    "toy-safety-explorer": "green",
    "toy-safety-tlc": "green",
    "toy-state-fingerprints-equal": "yes",
    "toy-liveness-under-fairness": "green",
    "fairness-drop-liveness": "red",
    "model-safety-mutants-caught": "5/5",
    "spec-weakening-mutants-caught": "1/1",
    "renderer-golden-mutants-caught": "2/2",
    "renderer-differential-mutants-caught": "2/2",
    "case-count": "200",
    "safety-violating-count": "95",
    "constraint-boundary-count": "200",
}
EXPECTED_RESULTS.update(
    {
        f"coverage-{name}": "100%"
        for name in (
            "BoolLiteral", "ArithmeticComparison", "Implication", "Subtraction",
            "FiniteSetMembership", "SetUnion", "SetDifference", "Cardinality",
            "FiniteQuantifier", "FunctionLiteral", "FunctionUpdate", "FunctionApplication",
            "Conditional", "WeakFair", "StrongFair", "Always", "Eventually", "LeadsTo",
        )
    }
)

# Which recorded metric decides each surface's ledger status. A surface with no deciding
# metric is one this register cannot reach.
SURFACE_EVIDENCE = {
    "interpret-hand-oracle": ("toy-distinct-state-count", "8"),
    "toy-safety": ("toy-state-fingerprints-equal", "yes"),
    "toy-liveness-under-fairness": ("toy-liveness-under-fairness", "green"),
    "fairness-sensitivity": ("fairness-drop-liveness", "red"),
    "tla-renderer-golden": ("renderer-golden-mutants-caught", "2/2"),
    "mechanical-model-mutants": ("model-safety-mutants-caught", "5/5"),
    "renderer-mutants": ("renderer-differential-mutants-caught", "2/2"),
    "renderer-mutant-corpus": ("renderer-differential-mutants-caught", "2/2"),
    "differential-fragment-200": ("case-count", "200"),
    "constraint-boundary-semantics": ("constraint-boundary-count", "200"),
    "formal-model-edsl": ("coverage-BoolLiteral", "100%"),
    "phase-3-code-correspondence": None,
    "runtime-fidelity": None,
}


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
        resolved = toolchain.resolve(["ghc", "cabal", "java", "tla2tools"])
    except toolchain.ResolutionError as error:
        print(f"  FAIL  toolchain-satisfies-requirements {error}")
        return False, {}
    for name in ("ghc", "cabal", "java", "tla2tools"):
        record = resolved[name]
        print(f"  ok    {name:<12} {record['version']:<12} satisfies {record['requirement']}")
    # TLC identifies itself only when asked, and a jar that resolves but cannot run is a
    # silent skip waiting to happen.
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
    print("\nsuite side — the in-process explorer, the renderer, and TLC\n")
    env = toolchain.contained_env()
    env["PATH"] = os.pathsep.join([str(ROOT / "tools"), env.get("PATH", "")])
    env["AMOEBIUS_JAVA"] = resolved["java"]["path"]
    env["AMOEBIUS_TLA2TOOLS"] = resolved["tla2tools"]["path"]
    build_root = ROOT / ".build" / "dist-newstyle" / "formal-model-kernel"
    if build_root.exists():
        shutil.rmtree(build_root)
    try:
        result = run(
            [resolved["cabal"]["path"],
             f"--with-compiler={resolved.get('ghc', {}).get('path', 'ghc')}",
             f"--builddir={build_root}",
             f"--store-dir={ROOT / '.build' / 'cabal-store'}",
             "test", "formal-model-spec", "--test-show-details=direct"],
            env=env,
        )
    except GateFailure as error:
        (run_dir / "suite.log").write_text(str(error), encoding="utf-8")
        print(f"  FAIL  formal-model-spec did not pass; transcript at {gate_common.rel(run_dir / 'suite.log')}")
        return False, {}
    (run_dir / "suite.log").write_text(result.stdout, encoding="utf-8")
    if not RESULTS.is_file():
        print(f"  FAIL  the suite emitted no {gate_common.rel(RESULTS)}")
        return False, {}
    rows: dict[str, str] = {}
    for line in RESULTS.read_text(encoding="utf-8").splitlines()[1:]:
        key, _, value = line.partition("\t")
        rows[key] = value
    print(f"  ok    formal-model-spec green; {len(rows)} metric(s) recorded")
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
    return ok


def artifact_side(run_dir: Path) -> bool:
    """The emitted spec is a build artifact: generated fresh, never a repository input."""
    print("\nartifact side — the emitted spec stays generated\n")
    snapshot = set(artifact_policy.snapshot_paths())
    emitted = sorted(EMITTED.rglob("*.tla")) + sorted(EMITTED.rglob("*.cfg"))
    if not emitted:
        print(f"  FAIL  emitted-spec-untracked the run emitted no .tla/.cfg under {gate_common.rel(EMITTED)}")
        return False
    leaked = [p for p in emitted if gate_common.rel(p) in snapshot]
    if leaked:
        for path in leaked:
            print(f"  FAIL  emitted-spec-untracked {gate_common.rel(path)} is in the source snapshot")
        return False
    strays = sorted(p for p in snapshot if p.endswith((".tla", ".cfg")))
    if strays:
        for stray in strays:
            print(f"  FAIL  emitted-spec-untracked {stray} is a specification file in authored source")
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
        phase=2, contract=CONTRACT, command=GATE_COMMAND, expectations=EXPECTATIONS,
        register="1", substrate="none", sides=SIDES
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)

    results["toolchain"], resolved = toolchain_side()
    rows: dict[str, str] = {}
    if results["toolchain"]:
        results["suite"], rows = suite_side(resolved, gate.run_dir)
    if rows:
        results["oracle"] = oracle_side(rows)
        results["artifact"] = artifact_side(gate.run_dir)

    implemented = {
        "metrics": set(rows),
        "mutants": {p.name for p in (ROOT / "test" / "formal" / "mutants").iterdir() if p.is_file()},
        "checks": set(CHECKS),
    }
    results["surface"], surfaces = gate.surface_join(implemented)

    # Every ledger row is decided by a recorded metric. A surface whose deciding metric did
    # not come back with its expected value is UNVERIFIED, not silently tested.
    status: dict[str, bool] = {}
    for surface in surfaces:
        evidence = SURFACE_EVIDENCE.get(surface)
        status[surface] = bool(evidence) and rows.get(evidence[0]) == evidence[1]
    status["generated-artifact-discipline"] = results["artifact"]

    layers = {
        "Decision": "tested" if rows.get("toy-state-fingerprints-equal") == "yes" else "UNVERIFIED",
        "Protocol": "proven-for-the-model"
        if rows.get("toy-safety-tlc") == "green" and rows.get("toy-liveness-under-fairness") == "green"
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
        dependencies={"formal-model-spec": "cabal test"},
        checks=results,
        mutants=[
            {"name": "model safety mutants", "status": rows.get("model-safety-mutants-caught", "unrun")},
            {"name": "spec weakening mutants", "status": rows.get("spec-weakening-mutants-caught", "unrun")},
            {"name": "renderer golden mutants", "status": rows.get("renderer-golden-mutants-caught", "unrun")},
            {"name": "renderer differential mutants", "status": rows.get("renderer-differential-mutants-caught", "unrun")},
        ],
        observations={"results": "sha256:" + artifact_policy.digest(str(RESULTS))} if RESULTS.is_file() else {},
    )
    results["containment"] = gate.containment_side()
    results["write-guard"] = gate.write_guard_side()
    return gate.report(results)


if __name__ == "__main__":
    raise SystemExit(main())
