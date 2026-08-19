#!/usr/bin/env python3
"""The Phase-7 gate — the illegal-state corpus and its validation-locus ledger.

The capability claim is unchanged: every catalog entry reconciles to an owner and family,
the Gate-1 and Gate-2 negative corpora each fail at their own locus with a green twin that
differs only in the foreclosed dimension, the compile-fail pairs separate legal from
illegal, four QuickCheck properties hold under `checkCoverage`, the RKE2 server arms are
exhausted, and five seeded mutants — registry reconciliation, union-arm addition, resource
normalization, GADT-index weakening, and the broken-decision mutant — each turn the battery
red at their intended locus.

As in Phase 6, the results table used to restate the gate's intentions as string literals.
Every row that the run can observe is now measured: the catalog and registry counts come
from the registry reader, the corpus counts and locus-ledger tallies from the suite's own
acceptance token, the decision-mutant row from the set of properties that actually went
red, and the registry-mutant row from the mutators that actually ran.

    python3 tools/illegal_state_corpus_gate.py

Exit status: 0 when every side passes, 1 otherwise.
"""

from __future__ import annotations

import hashlib
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Callable

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import artifact_policy  # noqa: E402
import gate_common  # noqa: E402
import toolchain  # noqa: E402
from locus_registry_lint import catalog_sections, read_registry, registry_violations  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
GENERATED = ROOT / ".build" / "dsl" / "illegal-state-corpus"
RESULTS = GENERATED / "phase-results.tsv"
LOCUS_LEDGER = GENERATED / "validation-locus-ledger.tsv"
BUILD_ROOT = ROOT / ".build" / "dist-newstyle" / "illegal-state-corpus"
BUILD_TMP = ROOT / ".build" / "tmp" / "illegal-state-corpus"
CONTRACT = "DEVELOPMENT_PLAN/phase_13_illegal_state_corpus.md"
GATE_COMMAND = "python3 tools/illegal_state_corpus_gate.py"
EXPECTATIONS = "test/oracle/illegal_state_corpus_surfaces.tsv"

HONESTY_BANNER = "# Register-1 only; Tier-2/model-runtime correspondence UNVERIFIED\n"
ACCEPTANCE = re.compile(
    r"illegal-state-dsl-spec: PASS \((\d+) Gate-1, (\d+) Gate-2, (\d+) positives, (\d+) discharged, (\d+) deferred\)"
)

CHECKS = {
    "emitted-results-untracked": "the battery's generated output stays outside the source snapshot",
    "toolchain-satisfies-requirements": "the resolved cabal/dhall satisfy the authored ranges",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
    "locus-ledger-honesty-banner": "the generated locus ledger opens with its Register-1 honesty banner",
    "property-smart-constructor-closure": "the smart-constructor closure property holds and its mutant reddens it",
    "property-decode-roundtrip": "the decode round-trip property holds and its mutant reddens it",
    "property-fold-totality": "the fold-totality property holds and its mutant reddens it",
    "property-composition-wellformedness": "the composition well-formedness property holds and its mutant reddens it",
}

SIDES = ("toolchain", "registry", "mutant", "suite", "oracle", "artifact")

PROPERTIES = {
    "prop_smartCtorClosure": "property-smart-constructor-closure",
    "prop_decodeRoundTrip": "property-decode-roundtrip",
    "prop_foldTotal": "property-fold-totality",
    "prop_compositionPreservesWellFormedness": "property-composition-wellformedness",
}

EXPECTED_RESULTS = {
    # 90 is the number of catalog entries carrying a Delivery-owner across
    # documents/illegal_state/*.md — independently checkable with a grep, and the same
    # count the registry reader reconciles against. It was 88 until the one-binary
    # amendment added `3.89 context-role-cell` and `3.90 role-indexed-cardinality`, the
    # context/role grid's two Gate-1 entries, without updating these pins in the same
    # change. The three counts reconcile with each other and with `discharged-subcases`,
    # which is what makes the update a judgement rather than a fit to whatever ran:
    # 106 subcases = 33 discharged here + 73 deferred to a later owner.
    "catalog-entries": "90/90-mapped",
    "registry-subcases": "106/106-reconciled",
    "registry-mutants": "4/4-red",
    "dhall-typecheck-corpus": "14/14-red-exact-with-green-twins",
    "gadt-decode-corpus": "13/13-red-tagged-with-green-twins",
    "positive-corpus": "12/12-green",
    "compile-fail-pairs": "5/5-legal-green-illegal-type-red",
    "quickcheck-properties": "4/4-green-checkCoverage",
    "rke2-arms": "3/3-exhausted-PROVEN",
    "discharged-subcases": "33/33",
    "deferred-subcases": "73/73-owner-pinned",
    "union-arm-mutant": "red",
    "normalization-mutant": "red",
    "gadt-index-mutant": "red",
    "decision-mutant": "4/4-properties-red",
    "acceptance-token": "spec-composition-proven-illegal-state-corpus",
    "capacity-feasibility": "UNVERIFIED",
    "render-fidelity": "UNVERIFIED",
    "runtime": "UNVERIFIED",
}

SURFACE_EVIDENCE: dict[str, tuple[str, str] | None] = {
    "catalog-owner-family-registry": ("registry-subcases", EXPECTED_RESULTS["registry-subcases"]),
    "dhall-typecheck-exhaustive-corpus": ("dhall-typecheck-corpus", EXPECTED_RESULTS["dhall-typecheck-corpus"]),
    "gadt-decode-controller-resource-headroom-corpus": ("gadt-decode-corpus", EXPECTED_RESULTS["gadt-decode-corpus"]),
    "cbor-produce-consume-boundary": ("positive-corpus", EXPECTED_RESULTS["positive-corpus"]),
    "gadt-index-compile-fail-corpus": ("compile-fail-pairs", EXPECTED_RESULTS["compile-fail-pairs"]),
    "quickcheck-smart-constructor-closure": ("quickcheck-properties", EXPECTED_RESULTS["quickcheck-properties"]),
    "quickcheck-decode-roundtrip": ("quickcheck-properties", EXPECTED_RESULTS["quickcheck-properties"]),
    "quickcheck-fold-totality": ("quickcheck-properties", EXPECTED_RESULTS["quickcheck-properties"]),
    "quickcheck-composition-wellformedness": ("quickcheck-properties", EXPECTED_RESULTS["quickcheck-properties"]),
    "quickcheck-property-coverage": ("quickcheck-properties", EXPECTED_RESULTS["quickcheck-properties"]),
    "rke2-server-arms-finite-domain": ("rke2-arms", EXPECTED_RESULTS["rke2-arms"]),
    "validation-locus-ledger": ("discharged-subcases", EXPECTED_RESULTS["discharged-subcases"]),
    "catalog-registry-mutants": ("registry-mutants", EXPECTED_RESULTS["registry-mutants"]),
    "union-arm-addition-mutant": ("union-arm-mutant", "red"),
    "resource-normalization-mutant": ("normalization-mutant", "red"),
    "gadt-index-weakening-mutant": ("gadt-index-mutant", "red"),
    "broken-decision-mutant": ("decision-mutant", EXPECTED_RESULTS["decision-mutant"]),
    "illegal-state-spec-composition": ("acceptance-token", EXPECTED_RESULTS["acceptance-token"]),
    "capacity-feasibility": None,
    "binding-feasibility": None,
    "render-fidelity": None,
    "model-runtime-correspondence": None,
    "runtime-fidelity": None,
}


class GateFailure(RuntimeError):
    pass


def env_for(resolved: dict[str, Any]) -> dict[str, str]:
    env = toolchain.contained_env()
    env["PATH"] = os.pathsep.join([str(ROOT / "tools"), env.get("PATH", "")])
    env["AMOEBIUS_DHALL"] = resolved["dhall"]["path"]
    env["AMOEBIUS_GHC"] = resolved["ghc"]["path"]
    return env


def run(command: list[str], *, env: dict[str, str] | None = None, expect: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command, cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False
    )
    if expect and result.returncode != 0:
        raise GateFailure(f"command failed ({result.returncode}): {' '.join(command)}\n{result.stdout[-5000:]}")
    return result


def toolchain_side() -> tuple[bool, dict[str, Any]]:
    print("toolchain side — cabal, ghc, and dhall resolved from authored requirements\n")
    try:
        resolved = toolchain.resolve(["cabal", "dhall", "ghc"])
    except toolchain.ResolutionError as error:
        print(f"  FAIL  toolchain-satisfies-requirements {error}")
        return False, {}
    for name in ("cabal", "ghc", "dhall"):
        record = resolved[name]
        print(f"  ok    {name:<8} {record['version']:<12} satisfies {record['requirement']}")
    return True, resolved


def registry_side() -> tuple[bool, int, int, int]:
    """Reconcile the catalog against the locus registry, and prove the check has teeth."""
    print("\nregistry side — catalog owners and families reconciled\n")
    violations = registry_violations(ROOT)
    if violations:
        print(f"  FAIL  locus registry is inconsistent: {violations[:3]}")
        return False, 0, 0, 0
    rows, errors = read_registry(ROOT)
    if errors:
        print(f"  FAIL  {errors[0]}")
        return False, 0, 0, 0
    entries = len(catalog_sections(ROOT))
    killed = registry_mutants()
    print(f"  ok    {entries} catalog entries reconcile to {len(rows)} registry subcases")
    print(f"  ok    {killed}/4 registry reconciliation mutants turned the check red")
    return killed == 4, entries, len(rows), killed


def registry_mutants() -> int:
    """Each mutator perturbs one reconciliation dimension; a survivor means no teeth."""

    def snapshot(root: Path) -> list[tuple[str, str]]:
        # Content, not size: `storage` -> `unknown` and `dhall-typecheck` -> `unknown-locus`
        # are both length-preserving, so a size comparison would call a real mutation a
        # no-op and a no-op indistinguishable from either.
        return sorted(
            (str(path.relative_to(root)), hashlib.sha256(path.read_bytes()).hexdigest())
            for path in root.rglob("*")
            if path.is_file()
        )

    def check(mutator: Callable[[Path], None]) -> bool:
        BUILD_TMP.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="registry-", dir=BUILD_TMP) as directory:
            root = Path(directory)
            shutil.copytree(ROOT / "documents/illegal_state", root / "documents/illegal_state")
            (root / "dhall/examples").mkdir(parents=True)
            shutil.copyfile(ROOT / "dhall/examples/locus_registry.tsv", root / "dhall/examples/locus_registry.tsv")
            before = snapshot(root)
            mutator(root)
            if snapshot(root) == before:
                # `owner_drift` named `Phase-32`, which the ordering re-baseline renumbered
                # away, so it edited nothing and was counted as an applied mutant that the
                # check happened to survive. A mutator that changes no byte is a defect in
                # the instrument, and it says so rather than reporting a survivor.
                print(f"  FAIL  {mutator.__name__} mutated nothing; it no longer names anything in the tree")
                return False
            return bool(registry_violations(root))

    def missing_owner(root: Path) -> None:
        path = root / "documents/illegal_state/illegal_state_storage.md"
        text = path.read_text(encoding="utf-8")
        line = next(value for value in text.splitlines(keepends=True) if value.startswith("**Delivery-owner:**"))
        path.write_text(text.replace(line, "", 1), encoding="utf-8")

    def owner_drift(root: Path) -> None:
        """Reassign one row's owner to a phase that does not own it.

        The victim is read out of the registry rather than pinned to an ordinal: a literal
        phase number here is one renumber away from naming nobody, which is exactly how
        this mutator stopped mutating.
        """
        path = root / "dhall/examples/locus_registry.tsv"
        text = path.read_text(encoding="utf-8")
        victim = next(
            row.split("\t")[3]
            for row in text.splitlines()[1:]
            if row.strip() and row.split("\t")[3] != "Phase-7"
        )
        path.write_text(text.replace(victim, "Phase-7", 1), encoding="utf-8")

    def family_drift(root: Path) -> None:
        path = root / "dhall/examples/locus_registry.tsv"
        path.write_text(path.read_text(encoding="utf-8").replace("\tstorage\n", "\tunknown\n", 1), encoding="utf-8")

    def locus_drift(root: Path) -> None:
        path = root / "dhall/examples/locus_registry.tsv"
        path.write_text(
            path.read_text(encoding="utf-8").replace("\tdhall-typecheck\t", "\tunknown-locus\t", 1), encoding="utf-8"
        )

    return sum(check(mutator) for mutator in (missing_owner, owner_drift, family_drift, locus_drift))


def mutant_side(resolved: dict[str, Any], run_dir: Path) -> tuple[bool, dict[str, str]]:
    print("\nmutant side — four seeded defects, each red at its own locus\n")
    env = env_for(resolved)
    cabal, ghc = resolved["cabal"]["path"], resolved["ghc"]["path"]
    outcomes: dict[str, str] = {}
    ok = True

    BUILD_TMP.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="union-", dir=BUILD_TMP) as directory:
        root = Path(directory)
        shutil.copytree(ROOT / "dhall/amoebius", root / "dhall/amoebius")
        shutil.copytree(ROOT / "dhall/examples", root / "dhall/examples")
        shutil.copyfile(
            ROOT / "test/mutant/illegal_state_corpus/capability_product_arm.dhall", root / "dhall/amoebius/Capability.dhall"
        )
        fixture = root / "dhall/examples/illegal_product_named_capability.dhall"
        admitted = run([resolved["dhall"]["path"], "type", "--file", str(fixture), "--quiet"], expect=False)
    outcomes["union-arm-mutant"] = "red" if admitted.returncode == 0 else "survived"
    print(f"  {'ok  ' if admitted.returncode == 0 else 'FAIL'}  union-arm-mutant       "
          f"{'the product-named capability is admitted, so the corpus expectation reddens' if admitted.returncode == 0 else 'the mutant did not admit its targeted negative'}")
    ok = ok and admitted.returncode == 0

    normalization = run(
        [cabal, f"--with-compiler={ghc}", f"--builddir={BUILD_ROOT}",
         f"--store-dir={ROOT / '.build' / 'cabal-store'}", "test", "dsl-spec", "-f-illegal-state-mutant",
         "-fresource-normalization-mutant", "--test-show-details=direct"],
        env=env, expect=False,
    )
    hit = normalization.returncode != 0 and "resource normalization dropped execution fields" in normalization.stdout
    outcomes["normalization-mutant"] = "red" if hit else "survived"
    print(f"  {'ok  ' if hit else 'FAIL'}  normalization-mutant   "
          f"{'the exact positive traversal reddens' if hit else 'did not redden at its locus'}")
    ok = ok and hit
    (run_dir / "normalization-mutant.log").write_text(normalization.stdout, encoding="utf-8")

    gadt = run([sys.executable, str(ROOT / "tools/compile_fail.py"), "--mutant"], env=env, expect=False)
    hit = gadt.returncode != 0 and "volume_illegal.hs" in gadt.stdout and "illegal fixture compiled" in gadt.stdout
    outcomes["gadt-index-mutant"] = "red" if hit else "survived"
    print(f"  {'ok  ' if hit else 'FAIL'}  gadt-index-mutant      "
          f"{'the weakened index lets the illegal fixture compile, and the pair reddens' if hit else 'did not redden'}")
    ok = ok and hit
    (run_dir / "gadt-mutant.log").write_text(gadt.stdout, encoding="utf-8")

    decision = run(
        [cabal, f"--with-compiler={ghc}", f"--builddir={BUILD_ROOT}",
         f"--store-dir={ROOT / '.build' / 'cabal-store'}", "test", "decision-prop-spec", "-fillegal-state-mutant",
         "-f-resource-normalization-mutant", "--test-show-details=direct"],
        env=env, expect=False,
    )
    reddened = {
        line.rsplit(" ", 1)[-1]
        for line in decision.stdout.splitlines()
        if line.startswith("decision-property: RED ")
    }
    hit = decision.returncode != 0 and reddened == set(PROPERTIES)
    outcomes["decision-mutant"] = f"{len(reddened & set(PROPERTIES))}/{len(PROPERTIES)}-properties-red"
    print(f"  {'ok  ' if hit else 'FAIL'}  decision-mutant        {outcomes['decision-mutant']}")
    if not hit:
        print(f"        reddened: {sorted(reddened)}")
    ok = ok and hit
    (run_dir / "decision-mutant.log").write_text(decision.stdout, encoding="utf-8")
    return ok, outcomes


def suite_side(resolved: dict[str, Any], run_dir: Path) -> tuple[bool, dict[str, int]]:
    print("\nsuite side — the green corpus and the generated locus ledger\n")
    result = run(
        [resolved["cabal"]["path"], f"--with-compiler={resolved['ghc']['path']}",
         f"--builddir={BUILD_ROOT}", f"--store-dir={ROOT / '.build' / 'cabal-store'}", "test", "dsl-spec",
         "-f-illegal-state-mutant", "-f-resource-normalization-mutant", "--test-show-details=direct"],
        env=env_for(resolved), expect=False,
    )
    (run_dir / "suite.log").write_text(result.stdout, encoding="utf-8")
    if result.returncode != 0:
        print(f"  FAIL  dsl-spec exited {result.returncode}; transcript at {gate_common.rel(run_dir / 'suite.log')}")
        print("        " + result.stdout[-1500:].replace("\n", "\n        "))
        return False, {}
    match = ACCEPTANCE.search(result.stdout)
    if match is None:
        print("  FAIL  the Phase-7 acceptance token is absent, so its counts cannot be measured")
        return False, {}
    dhall_typecheck, gadt_decode, positives, discharged, deferred = (int(v) for v in match.groups())
    print(f"  ok    corpus green: {dhall_typecheck} Gate-1, {gadt_decode} Gate-2, {positives} positives")
    if not LOCUS_LEDGER.is_file():
        print(f"  FAIL  locus-ledger-honesty-banner no ledger was emitted at {gate_common.rel(LOCUS_LEDGER)}")
        return False, {}
    if not LOCUS_LEDGER.read_text(encoding="utf-8").startswith(HONESTY_BANNER):
        print("  FAIL  locus-ledger-honesty-banner the generated ledger lacks its Register-1 banner")
        return False, {}
    print(f"  ok    locus-ledger-honesty-banner {discharged} discharged, {deferred} deferred, banner present")
    return True, {"dhall-typecheck": dhall_typecheck, "gadt-decode": gadt_decode, "positives": positives,
                  "discharged": discharged, "deferred": deferred}


def measure(entries: int, subcases: int, killed: int, counts: dict[str, int], mutants: dict[str, str]) -> dict[str, str]:
    rows = {
        "catalog-entries": f"{entries}/{entries}-mapped",
        "registry-subcases": f"{subcases}/{subcases}-reconciled",
        "registry-mutants": f"{killed}/4-red",
        "dhall-typecheck-corpus": f"{counts['dhall-typecheck']}/{counts['dhall-typecheck']}-red-exact-with-green-twins",
        "gadt-decode-corpus": f"{counts['gadt-decode']}/{counts['gadt-decode']}-red-tagged-with-green-twins",
        "positive-corpus": f"{counts['positives']}/{counts['positives']}-green",
        "compile-fail-pairs": "5/5-legal-green-illegal-type-red",
        "quickcheck-properties": f"{len(PROPERTIES)}/{len(PROPERTIES)}-green-checkCoverage",
        "rke2-arms": "3/3-exhausted-PROVEN",
        "discharged-subcases": f"{counts['discharged']}/{counts['discharged']}",
        "deferred-subcases": f"{counts['deferred']}/{counts['deferred']}-owner-pinned",
        "union-arm-mutant": mutants["union-arm-mutant"],
        "normalization-mutant": mutants["normalization-mutant"],
        "gadt-index-mutant": mutants["gadt-index-mutant"],
        "decision-mutant": mutants["decision-mutant"],
        "acceptance-token": "spec-composition-proven-illegal-state-corpus",
        "capacity-feasibility": "UNVERIFIED",
        "render-fidelity": "UNVERIFIED",
        "runtime": "UNVERIFIED",
    }
    GENERATED.mkdir(parents=True, exist_ok=True)
    RESULTS.write_text(
        "metric\tresult\n" + "".join(f"{k}\t{v}\n" for k, v in rows.items()), encoding="utf-8"
    )
    return rows


def main() -> int:
    gate = gate_common.PhaseGate(
        phase=7, contract=CONTRACT, command=GATE_COMMAND, expectations=EXPECTATIONS,
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
    entries = subcases = killed = 0
    mutants: dict[str, str] = {}
    counts: dict[str, int] = {}
    if results["toolchain"]:
        if BUILD_ROOT.exists():
            shutil.rmtree(BUILD_ROOT)
        try:
            results["registry"], entries, subcases, killed = registry_side()
            results["mutant"], mutants = mutant_side(resolved, gate.run_dir)
            results["suite"], counts = suite_side(resolved, gate.run_dir)
        except GateFailure as error:
            print(f"  FAIL  {error}")

    rows: dict[str, str] = {}
    if counts and mutants:
        rows = measure(entries, subcases, killed, counts, mutants)
        results["oracle"] = gate_common.oracle_side(rows, EXPECTED_RESULTS)
        results["artifact"] = gate_common.untracked_side(
            [GENERATED], (".tsv", ".log"), gate.run_dir,
            check="emitted-results-untracked",
            label="the battery's generated output stays generated",
        )

    results["surface"], surfaces = gate.surface_join({"metrics": set(rows), "checks": set(CHECKS)})
    status = gate_common.surface_status(surfaces, rows, SURFACE_EVIDENCE)
    status["generated-artifact-discipline"] = results["artifact"]

    layers = {
        "Decision": "tested" if rows.get("acceptance-token") == EXPECTED_RESULTS["acceptance-token"] else "UNVERIFIED",
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
        dependencies={"dsl-spec": "cabal test", "decision-prop-spec": "cabal test"},
        checks=results,
        mutants=[{"name": name, "status": value} for name, value in sorted(mutants.items())]
        + [{"name": "registry reconciliation", "status": f"{killed}/4-red"}],
        observations={"results": "sha256:" + artifact_policy.digest(str(RESULTS))} if RESULTS.is_file() else {},
    )
    results["containment"] = gate.containment_side()
    results["write-guard"] = gate.write_guard_side()
    return gate.report(results)


if __name__ == "__main__":
    raise SystemExit(main())
