#!/usr/bin/env python3
"""The Phase-25 gate — the Dhall Gate-1 schema and its smart-constructor prelude.

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

    python3 tools/dhall_typecheck_schema_gate.py

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
DHALL_TYPECHECK = ROOT / ".build" / "dhall" / "dhall-typecheck"
RESULTS = DHALL_TYPECHECK / "phase-results.tsv"
CONFORMANCE_PROJECTION = DHALL_TYPECHECK / "conformance-projection.tsv"
EXPECTED_CONFORMANCE_PROJECTION = ROOT / "test/oracle/dhall_typecheck_schema/conformance_projection.tsv"
BUILD_ROOT = ROOT / ".build/dist-newstyle/dhall-schema-conformance"
CONTRACT = "DEVELOPMENT_PLAN/phase_25_dhall_schema_generation.md"
GATE_COMMAND = "python3 tools/dhall_typecheck_schema_gate.py"
EXPECTATIONS = "test/oracle/dhall_typecheck_schema_surfaces.tsv"

CHECKS = {
    "emitted-results-untracked": "the battery's generated output stays outside the source snapshot",
    "phase24-plan-consumed": "the Dhall schema derives all Phase-24 obligations and mints no unsupported verdict",
    "toolchain-satisfies-requirements": "the resolved dhall satisfies the authored range",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
}

SIDES = ("toolchain", "battery", "conformance", "oracle", "artifact")

# The authored oracle, read off the Phase-25 contract.
EXPECTED_RESULTS = {
    # Amended 2026-08-12 from intent, not from a failing run. The count moved 14 -> 17
    # because Phase 19 added SanctionedApi, Phase 24 added UiOffline, and Phase 30 added
    # BakeCatalog. A count is not the oracle; the reviewed inventory beside it is, and a
    # module added without review breaks the inventory rather than sliding past a number.
    # Amended again 2026-08-13 by the secrets amendment: 17 -> 18 for the shared
    # SecretRef union, which is Gate-1 surface and so belongs to this phase.
    "schema-modules": "18",
    "schema-module-inventory": "dhall/amoebius/App.dhall,dhall/amoebius/Backup.dhall,dhall/amoebius/BakeCatalog.dhall,dhall/amoebius/Capability.dhall,dhall/amoebius/Capacity.dhall,dhall/amoebius/Cluster.dhall,dhall/amoebius/Consistency.dhall,dhall/amoebius/Deployment.dhall,dhall/amoebius/Extension.dhall,dhall/amoebius/Image.dhall,dhall/amoebius/Resources.dhall,dhall/amoebius/Retention.dhall,dhall/amoebius/SanctionedApi.dhall,dhall/amoebius/SecretRef.dhall,dhall/amoebius/Storage.dhall,dhall/amoebius/Topology.dhall,dhall/amoebius/UiOffline.dhall,dhall/amoebius/prelude/package.dhall",
    "positive-fixtures": "4/4-green",
    "dhall-typecheck-negatives": "8/8-red-specific",
    "image-process-negatives": "3/3-red-specific",
    "secret-policy-negatives": "1/1-red-specific",
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
    "extension-conformance-plan": "19/19-derived",
    "extension-conformance-verdict": "UNVERIFIED",
    # Both of these are honestly UNVERIFIED at this register and say so in the results.
    "gadt-decode-residue": "UNVERIFIED",
    "runtime": "UNVERIFIED",
}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    "dhall-schema-wellformed": ("schema-modules", "18"),
    "dhall-typecheck-positive-corpus": ("positive-fixtures", "4/4-green"),
    "dhall-typecheck-catalog-negatives": ("dhall-typecheck-negatives", "8/8-red-specific"),
    "image-process-negatives": ("image-process-negatives", "3/3-red-specific"),
    "secret-reference-policy": ("secret-policy-negatives", "1/1-red-specific"),
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
    "extension-conformance-plan": ("extension-conformance-plan", "19/19-derived"),
    "extension-conformance-verdict": None,
    "gadt-decode-residue": None,
    "runtime-fidelity": None,
}


def toolchain_side() -> tuple[bool, dict[str, Any]]:
    print("toolchain side — Dhall and the Phase-24 projection toolchain from authored requirements\n")
    try:
        resolved = toolchain.resolve(["dhall", "cabal", "ghc"])
    except toolchain.ResolutionError as error:
        print(f"  FAIL  toolchain-satisfies-requirements {error}")
        return False, {}
    for name in ("dhall", "ghc", "cabal"):
        record = resolved[name]
        print(f"  ok    {name:<8} {record['version']:<12} satisfies {record['requirement']}")
    return True, resolved


def battery_side(resolved: dict[str, Any], run_dir: Path) -> tuple[bool, dict[str, str]]:
    print("\nbattery side — the Gate-1 corpus, negatives, inventories, and mutants\n")
    env = toolchain.contained_env()
    env["AMOEBIUS_DHALL"] = resolved["dhall"]["path"]
    result = subprocess.run(
        [sys.executable, str(ROOT / "tools" / "dhall_typecheck.py")],
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


def cabal_command(resolved: dict[str, Any], *arguments: str) -> list[str]:
    return [
        resolved["cabal"]["path"],
        f"--with-compiler={resolved['ghc']['path']}",
        f"--builddir={BUILD_ROOT}",
        f"--store-dir={ROOT / '.build/cabal-store'}",
        "--jobs=1",
        *arguments,
    ]


def conformance_side(resolved: dict[str, Any], run_dir: Path) -> tuple[bool, dict[str, str]]:
    print("\nconformance side — Phase-24 plan is derived and its unsupported verdict stays absent\n")
    env = toolchain.contained_env()
    env["AMOEBIUS_SOURCE_ROOT"] = str(ROOT)
    result = subprocess.run(
        cabal_command(
            resolved,
            "test",
            "dhall-schema-conformance-spec",
            "--test-show-details=direct",
            f"--test-options={ROOT}",
        ),
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    (run_dir / "conformance.log").write_text(result.stdout, encoding="utf-8")
    token = "dhall-schema-conformance-spec: PASS (19 generated obligations, verdict UNVERIFIED)"
    if result.returncode != 0 or token not in result.stdout or not CONFORMANCE_PROJECTION.is_file():
        print(f"  FAIL  phase24-plan-consumed; transcript at {gate_common.rel(run_dir / 'conformance.log')}")
        return False, {}
    expected = sorted(EXPECTED_CONFORMANCE_PROJECTION.read_text(encoding="utf-8").splitlines()[1:])
    actual = sorted(CONFORMANCE_PROJECTION.read_text(encoding="utf-8").splitlines()[1:])
    green = len(actual) == 19 and actual == expected
    print(f"  {'ok  ' if green else 'FAIL'}  phase24-plan-consumed 19 obligations derived; verdict remains UNVERIFIED")
    if not green:
        return False, {}
    return True, {
        "extension-conformance-plan": "19/19-derived",
        "extension-conformance-verdict": "UNVERIFIED",
    }


def write_results(rows: dict[str, str]) -> None:
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text(
        "metric\tresult\n" + "".join(f"{key}\t{rows[key]}\n" for key in EXPECTED_RESULTS if key in rows),
        encoding="utf-8",
    )


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=25, contract=CONTRACT, command=GATE_COMMAND, expectations=EXPECTATIONS,
        register="1", substrate="none", lane="none", sides=SIDES
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)

    # Clause 15 first: a run that cannot name the architecture it executed on, or
    # that is executing under translation, has nothing worth proving.
    results["architecture"] = gate.architecture_side()
    if not results["architecture"]:
        return gate.report(results)

    results["toolchain"], resolved = toolchain_side()
    rows: dict[str, str] = {}
    if results["toolchain"]:
        results["battery"], rows = battery_side(resolved, gate.run_dir)
    if results["battery"]:
        results["conformance"], conformance_rows = conformance_side(resolved, gate.run_dir)
        rows.update(conformance_rows)
        write_results(rows)
    if results["conformance"]:
        results["oracle"] = gate_common.oracle_side(rows, EXPECTED_RESULTS)
        results["artifact"] = gate_common.untracked_side(
            [DHALL_TYPECHECK],
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
        dependencies={
            "dhall-typecheck": "tools/dhall_typecheck.py",
            "dhall-schema-conformance-spec": "Phase-24 obligation projection",
        },
        checks=results,
        mutants=[
            {"name": "resource-field deletion", "status": rows.get("resource-field-deletion-mutants", "unrun")},
            {"name": "resource-type substitution", "status": rows.get("resource-type-substitution-mutants", "unrun")},
            {"name": "special-resource", "status": rows.get("special-resource-mutants", "unrun")},
            {"name": "custom-arm", "status": rows.get("custom-arm-mutant", "unrun")},
        ],
        observations={
            "results": "sha256:" + artifact_policy.digest(str(RESULTS)),
            "conformance_projection": "sha256:" + artifact_policy.digest(str(CONFORMANCE_PROJECTION)),
        }
        if RESULTS.is_file() and CONFORMANCE_PROJECTION.is_file()
        else {},
    )
    results["containment"] = gate.containment_side()
    results["write-guard"] = gate.write_guard_side()
    return gate.report(results)


if __name__ == "__main__":
    raise SystemExit(main())
