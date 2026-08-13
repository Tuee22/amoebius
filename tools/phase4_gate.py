#!/usr/bin/env python3
"""The Phase-4 gate — the Dhall Gate-1 schema and its smart-constructor prelude.

The capability claim is unchanged: every positive cluster/app/deployment fixture typechecks,
every catalog, image/process, and import-policy negative fails at its own specific `dhall`
type error, the arm/surface/resource inventories match their authored expectations exactly,
and the 525 field-deletion, 176 type-substitution, four special-resource, and one custom-arm
mutants all turn the battery red.

What changed is the apparatus: `dhall` resolves from authored compatibility requirements
rather than a tracked pin, evidence lands in the run bundle instead of the plan tree, the
ledger is derived into that bundle rather than compared against a committed copy, surfaces
are enumerated at run time, and the run publishes an attestation bound to the source
snapshot.

    python3 tools/phase4_gate.py

Exit status: 0 when every side passes, 1 otherwise.
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import artifact_policy  # noqa: E402
import gate_common  # noqa: E402
import toolchain  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
GATE1 = ROOT / "gen" / "dhall" / "gate1"
RESULTS = GATE1 / "phase-results.tsv"
CONTRACT = "DEVELOPMENT_PLAN/phase_04_dhall_gate1_schema.md"
GATE_COMMAND = "python3 tools/phase4_gate.py"

CHECKS = {
    "emitted-results-untracked": "the battery's generated output stays outside the source snapshot",
    "toolchain-satisfies-requirements": "the resolved dhall satisfies the authored range",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
}

SIDES = ("toolchain", "battery", "oracle", "artifact")

# The authored oracle, read off the Phase-4 contract.
EXPECTED_RESULTS = {
    # Amended 2026-08-12 from intent, not from a failing run. The count moved 14 -> 17
    # because Phase 16 added SanctionedApi, Phase 60 added UiOffline, and Phase 25 added
    # BakeCatalog. A count is not the oracle; the reviewed inventory beside it is, and a
    # module added without review breaks the inventory rather than sliding past a number.
    "schema-modules": "17",
    "schema-module-inventory": "dhall/amoebius/App.dhall,dhall/amoebius/Backup.dhall,dhall/amoebius/BakeCatalog.dhall,dhall/amoebius/Capability.dhall,dhall/amoebius/Capacity.dhall,dhall/amoebius/Cluster.dhall,dhall/amoebius/Consistency.dhall,dhall/amoebius/Deployment.dhall,dhall/amoebius/Extension.dhall,dhall/amoebius/Image.dhall,dhall/amoebius/Resources.dhall,dhall/amoebius/Retention.dhall,dhall/amoebius/SanctionedApi.dhall,dhall/amoebius/Storage.dhall,dhall/amoebius/Topology.dhall,dhall/amoebius/UiOffline.dhall,dhall/amoebius/prelude/package.dhall",
    "positive-fixtures": "4/4-green",
    "gate1-negatives": "8/8-red-specific",
    "image-process-negatives": "3/3-red-specific",
    "import-policy-negatives": "2/2-red-ForbiddenImport",
    "constructor-rejections": "12/12-red",
    "arm-inventory": "equal",
    "surface-field-inventory": "equal",
    "resource-field-inventory": "equal",
    "resource-field-deletion-mutants": "525/525-red",
    "resource-type-substitution-mutants": "176/176-red",
    "special-resource-mutants": "4/4-red",
    "custom-arm-mutant": "red",
    "acceptance-token": "spec-composition-proven",
    # Both of these are honestly UNVERIFIED at this register and say so in the results.
    "gate2-residue": "UNVERIFIED",
    "runtime": "UNVERIFIED",
}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    "dhall-schema-wellformed": ("schema-modules", "17"),
    "gate1-positive-corpus": ("positive-fixtures", "4/4-green"),
    "gate1-catalog-negatives": ("gate1-negatives", "8/8-red-specific"),
    "image-process-negatives": ("image-process-negatives", "3/3-red-specific"),
    "import-policy": ("import-policy-negatives", "2/2-red-ForbiddenImport"),
    "smart-constructor-rejections": ("constructor-rejections", "12/12-red"),
    "arm-inventory": ("arm-inventory", "equal"),
    "surface-field-inventory": ("surface-field-inventory", "equal"),
    "resource-field-inventory": ("resource-field-inventory", "equal"),
    "resource-field-deletion-mutants": ("resource-field-deletion-mutants", "525/525-red"),
    "resource-type-substitution-mutants": ("resource-type-substitution-mutants", "176/176-red"),
    "special-resource-mutants": ("special-resource-mutants", "4/4-red"),
    "custom-arm-mutant": ("custom-arm-mutant", "red"),
    "spec-composition": ("acceptance-token", "spec-composition-proven"),
    "gate2-residue": None,
    "runtime-fidelity": None,
}


def toolchain_side() -> tuple[bool, dict[str, Any]]:
    print("toolchain side — dhall resolved from authored requirements\n")
    try:
        resolved = toolchain.resolve(["dhall"])
    except toolchain.ResolutionError as error:
        print(f"  FAIL  toolchain-satisfies-requirements {error}")
        return False, {}
    record = resolved["dhall"]
    print(f"  ok    dhall        {record['version']:<12} satisfies {record['requirement']}")
    return True, resolved


def battery_side(resolved: dict[str, Any], run_dir: Path) -> tuple[bool, dict[str, str]]:
    print("\nbattery side — the Gate-1 corpus, negatives, inventories, and mutants\n")
    env = dict(os.environ)
    env["AMOEBIUS_DHALL"] = resolved["dhall"]["path"]
    result = subprocess.run(
        [sys.executable, str(ROOT / "tools" / "dhall_gate1.py")],
        cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False,
    )
    run_dir.mkdir(parents=True, exist_ok=True)
    (run_dir / "battery.log").write_text(result.stdout, encoding="utf-8")
    if result.returncode != 0:
        print(f"  FAIL  the battery exited {result.returncode}; transcript at {gate_common.rel(run_dir / 'battery.log')}")
        print("        " + result.stdout[-1500:].replace("\n", "\n        "))
        return False, {}
    if not RESULTS.is_file():
        print(f"  FAIL  the battery emitted no {gate_common.rel(RESULTS)}")
        return False, {}
    rows = gate_common.metric_rows(RESULTS)
    print(f"  ok    the Gate-1 battery is green; {len(rows)} metric(s) recorded")
    return True, rows


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=4, contract=CONTRACT, command=GATE_COMMAND, register="1", substrate="none", sides=SIDES
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)

    results["toolchain"], resolved = toolchain_side()
    rows: dict[str, str] = {}
    if results["toolchain"]:
        results["battery"], rows = battery_side(resolved, gate.run_dir)
    if rows:
        results["oracle"] = gate_common.oracle_side(rows, EXPECTED_RESULTS)
        results["artifact"] = gate_common.untracked_side(
            [GATE1],
            (".tsv", ".dhall", ".txt", ".log"),
            gate.run_dir,
            check="emitted-results-untracked",
            label="the battery's generated output stays generated",
        )

    results["surface"], surfaces = gate.surface_join({"metrics": set(rows), "checks": set(CHECKS)})
    status = gate_common.surface_status(surfaces, rows, SURFACE_EVIDENCE)
    status["generated-artifact-discipline"] = results["artifact"]

    layers = {
        # Gate 1 forecloses illegal states in the schema. It exercises no protocol and
        # stands up no runtime, so those two layers stay outside its reach.
        "Decision": "tested" if rows.get("acceptance-token") == "spec-composition-proven" else "UNVERIFIED",
        "Protocol": "UNVERIFIED",
        "Runtime": "UNVERIFIED",
    }
    results["ledger"] = gate.ledger_side(surfaces, layers, status)
    results["attestation"] = gate.attestation_side(
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items()
            if name != "platform"
        },
        dependencies={"dhall-gate1": "tools/dhall_gate1.py"},
        checks=results,
        mutants=[
            {"name": "resource-field deletion", "status": rows.get("resource-field-deletion-mutants", "unrun")},
            {"name": "resource-type substitution", "status": rows.get("resource-type-substitution-mutants", "unrun")},
            {"name": "special-resource", "status": rows.get("special-resource-mutants", "unrun")},
            {"name": "custom-arm", "status": rows.get("custom-arm-mutant", "unrun")},
        ],
        observations={"results": "sha256:" + artifact_policy.digest(str(RESULTS))} if RESULTS.is_file() else {},
    )
    results["write-guard"] = gate.write_guard_side()
    return gate.report(results)


if __name__ == "__main__":
    raise SystemExit(main())
