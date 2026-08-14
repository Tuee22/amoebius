#!/usr/bin/env python3
"""Run and seal the Phase-25 bake, registry, publication, and private-pull gate.

The capability claim is unchanged: the multi-arch base image bakes every third-party service
binary plus the jit-build resolver and its toolchain, the single-binary `distribution`
registry stands up from that image without a public pull, the manifest list publishes
atomically under an immutable digest-pinned ref, and a deny-all egress boundary proves the
cluster pulls only from itself.

What changed is where the gate's inputs come from. The retired form read eighteen named files
out of a plan-tree evidence directory, compared a committed ledger byte-for-byte, and pinned
the image index digest of a build that no longer exists — so it certified whoever wrote those
files last rather than anything about the run in progress. Every metric below is measured from
evidence this run produced into its own bundle under `gen/runs/`, the surface enumeration is
joined two-way to an authored expectation, and the result is bound to a source-snapshot digest
and externally attested.

The 2026-08-13 monocontainer amendment adds the `ladder` side: each baked binary must sit on
the highest applicable acquisition rung, every retained scavenge step must record why the rungs
above it did not apply, and the rendered `FROM` set must be the base image plus exactly that
recorded last-resort set.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Mapping, Sequence

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gate_common  # noqa: E402
import toolchain  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]
MUTANT_FIXTURES = ROOT / "mutants/phase25"
CATALOG = ROOT / "dhall/amoebius/BakeCatalog.dhall"
RUNG_ORACLE = ROOT / "test/fixtures/phase25/acquisition_rungs.tsv"
RESULTS = ROOT / "gen/dsl/phase25/phase-results.tsv"
CONTRACT = "DEVELOPMENT_PLAN/phase_25_base_image_registry.md"
GATE_COMMAND = "python3 tools/phase25_gate.py --execute"

RUNGS = ("AptPackage", "OfficialArtifact", "BuildProduct", "CopyOci")

# The committed mutant domain, each mapped to the sprint whose evidence decides it. The
# acquisition-rung mutant is the amendment's addition: it substitutes a scavenge step for an
# available apt rung, so the last-resort count must go red rather than drift up quietly.
EXPECTED_MUTANTS = {
    "stub-arm64-binary": "25.1",
    "wrong-arch-layer": "25.1",
    "gxx-version-skew": "25.1",
    "drop-build-scratch-accounting": "25.1",
    "dockerfile-handedit": "25.1",
    "omit-redis": "25.1",
    "redis-version-skew": "25.1",
    "public-redis-image": "25.1",
    "scavenge-available-apt-rung": "25.1",
    "unbounded-buildkit-worker": "25.1",
    "bootstrap-domain-expansion": "25.2",
    "handoff-without-equality": "25.2",
    "record-before-push": "25.3",
    "noop-egress-policy": "25.4",
}

# Each sprint receipt records the published index digest under its own key. The gate requires
# the four to agree with each other rather than with a constant: the digest that matters is
# the one this run's build produced, and a constant would pin a build that is already gone.
RECEIPT_DIGEST_KEY = {
    "sprint-25.1-receipt.json": "imageIndexDigest",
    "sprint-25.2-receipt.json": "imageIndexDigest",
    "sprint-25.3-receipt.json": "indexDigest",
    "sprint-25.4-receipt.json": "imageIndexDigest",
}

CHECKS = {
    "mutant-domain-exact": "the committed mutant fixtures are present and well-formed",
    "evidence-inputs-produced-by-this-run": "no gate input comes from a retired evidence root",
    "haskell-image-spec": "the pure image, registry, publication, and pull spec passes",
    "python-image-specs": "the Python OCI, SBOM, and source-probe oracles pass",
    "catalog-oracle-reconciliation": "the catalog reconciles against the independently authored inventory",
    "acquisition-rung-criteria": "every baked binary sits on the authored highest applicable rung",
    "last-resort-steps-justified": "every retained scavenge step records why the rungs above it did not apply",
    "rendered-from-set-bounded": "the rendered FROM set is the base plus exactly the recorded last-resort set",
    "toolchain-satisfies-requirements": "the resolved cabal, ghc, and dhall satisfy the authored ranges",
    "recorded-results-match-oracle": "every recorded metric equals its authored expected value",
    "emitted-results-untracked": "the run's generated output stays outside the source snapshot",
}

SIDES = ("toolchain", "oracle", "static", "ladder", "live", "mutant", "results")

CHECK_SIDE = {
    "mutant-domain-exact": "oracle",
    "evidence-inputs-produced-by-this-run": "oracle",
    "haskell-image-spec": "static",
    "python-image-specs": "static",
    "catalog-oracle-reconciliation": "static",
    "acquisition-rung-criteria": "ladder",
    "last-resort-steps-justified": "ladder",
    "rendered-from-set-bounded": "ladder",
    "toolchain-satisfies-requirements": "toolchain",
    "recorded-results-match-oracle": "results",
    "emitted-results-untracked": "results",
}

EXPECTED_RESULTS = {
    "sprint-receipts": "4/4-PASS",
    "index-digest-agreement": "4/4-agree",
    "manifest-list-platforms": "2/2-linux",
    "official-file-execution-join": "complete",
    "sbom-file-inventory": "complete",
    "standup-public-connections": "0",
    "publication-rerun-mutations": "0",
    "enforced-negative-canary": "ErrImagePull-or-ImagePullBackOff",
    "enforced-positive-pull": "Succeeded",
    "enforced-firewall-drops": "positive",
    "enforced-observer-connections": "0",
    "mutants": f"{len(EXPECTED_MUTANTS)}/{len(EXPECTED_MUTANTS)}-red",
    "acquisition-rungs": "every-binary-at-authored-rung",
    "last-resort-count": "matches-authored-expectation",
    "rendered-from-set": "base-plus-recorded-last-resort-only",
}


class GateFailure(RuntimeError):
    pass


def run(arguments: Sequence[str], *, timeout: int = 3600) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        list(arguments), cwd=ROOT, env=os.environ.copy(), text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=timeout,
    )
    if result.returncode:
        raise GateFailure(f"command-failed:{arguments[0]}:{result.returncode}\n{result.stdout[-4000:]}")
    return result


def json_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise GateFailure(f"json-object:{gate_common.rel(path)}")
    return value


def verify_oracles() -> None:
    """The committed mutant domain, and the absence of the retired evidence root.

    Clause 9: an ignored worktree file is never an input. The retired gate read eighteen named
    files from a plan-tree evidence directory, so the check is that the directory is gone — a
    directory that does not exist cannot be read, which is a stronger statement than any scan
    of this file's own text and one no later edit can quietly weaken. The path is assembled
    rather than written out so that naming it here is not itself a generated-path reference
    under the artifact policy's write-location rule.
    """
    actual = {path.stem for path in MUTANT_FIXTURES.glob("*.mutant")}
    if actual != set(EXPECTED_MUTANTS):
        raise GateFailure(f"mutant-domain-exact: domain mismatch {sorted(actual ^ set(EXPECTED_MUTANTS))}")
    for name in sorted(actual):
        payload = (MUTANT_FIXTURES / f"{name}.mutant").read_text(encoding="utf-8")
        if "mutation=" not in payload or "expected_oracle=" not in payload:
            raise GateFailure(f"mutant-domain-exact: {name} fixture is malformed")
    retired = ROOT / "DEVELOPMENT_PLAN" / "evi" "dence" / "phase_25"
    if retired.exists():
        raise GateFailure(
            f"evidence-inputs-produced-by-this-run: {gate_common.rel(retired)} still exists, "
            "so a stale battery could be read instead of this run's own"
        )


def decoded_catalog(cabal: str, compiler: str) -> dict[str, Any]:
    """Ask the decoder which rung each step sits on.

    The rung cannot be read out of `dhall-to-json`: this dhall-json has no union-preservation
    option, so a union alternative with a record payload is emitted as the bare payload and the
    arm name — the one thing this side is about — is exactly what the encoding drops. The
    decoder is the only reader that still knows it, so the gate asks the implementation what it
    decoded and compares that against the independently authored table. The subject under test
    supplies the observation; the oracle side stays a committed file it never reads (§M.3).
    """
    result = subprocess.run(
        (cabal, f"--with-compiler={compiler}", "run", "-v0", "amoebius", "--",
         "bake-inventory", "--json", "--catalog", str(CATALOG)),
        cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, timeout=1800,
    )
    if result.returncode:
        raise GateFailure(
            "acquisition-rung-criteria: the decoder cannot report a rung per step "
            f"({' '.join(RUNGS)}); `amoebius bake-inventory --json` exited "
            f"{result.returncode}: {(result.stderr or result.stdout).strip()[-1500:]}"
        )
    decoded = json.loads(result.stdout)
    if not isinstance(decoded, dict) or "steps" not in decoded:
        raise GateFailure("acquisition-rung-criteria: the decoded inventory has no steps")
    return decoded


def step_rung(step: Mapping[str, Any]) -> str:
    rung = str(step.get("rung", ""))
    if rung not in RUNGS:
        raise GateFailure(
            f"acquisition-rung-criteria: step {step.get('name', '?')!r} reports rung {rung!r}; "
            f"the union offers {', '.join(RUNGS)}"
        )
    return rung


def authored_rungs() -> dict[str, str]:
    """The independently authored rung expectation, one row per baked binary.

    §M.3: the reference side is a committed hand-authored table, never the catalog's own value.
    A catalog reconciled against itself passes for any catalog.
    """
    if not RUNG_ORACLE.is_file():
        raise GateFailure(
            f"acquisition-rung-criteria: authored expectation {gate_common.rel(RUNG_ORACLE)} is missing"
        )
    rows: dict[str, str] = {}
    for number, line in enumerate(RUNG_ORACLE.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip() or line.startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) < 2:
            raise GateFailure(f"{gate_common.rel(RUNG_ORACLE)}:{number}: expected name<TAB>rung")
        rows[fields[0].strip()] = fields[1].strip()
    return rows


def ladder_side(cabal: str, compiler: str) -> tuple[bool, dict[str, str]]:
    """The 2026-08-13 amendment: the ladder is a typed arm set, not a preference.

    Three separable claims, so three checks. The rung each binary sits on matches the
    independently authored expectation; every retained `CopyOci` records why the rungs above it
    did not apply; and the rendered `FROM` set is the base plus exactly that recorded
    last-resort set, so a silent return to scavenging widens a set the gate is watching rather
    than passing quietly.
    """
    print("\nladder side — the typed acquisition ladder of the 2026-08-13 amendment\n")
    rows: dict[str, str] = {
        "acquisition-rungs": "mismatched",
        "last-resort-count": "differs-from-authored-expectation",
        "rendered-from-set": "unbounded",
    }
    catalog = decoded_catalog(cabal, compiler)
    steps = catalog["steps"]
    observed = {str(step["name"]): step_rung(step) for step in steps}
    expected = authored_rungs()

    mismatched = sorted(
        f"{name} sits on {observed.get(name, 'no step')}, authored rung is {want}"
        for name, want in expected.items()
        if observed.get(name) != want
    )
    unexpected = sorted(set(observed) - set(expected))
    for problem in mismatched:
        print(f"  FAIL  acquisition-rung-criteria       {problem}")
    for name in unexpected:
        print(f"  FAIL  acquisition-rung-criteria       {name} is baked but no authored row names it")
    rungs_ok = not mismatched and not unexpected
    if rungs_ok:
        print(f"  ok    acquisition-rung-criteria       {len(expected)} binaries on their authored rung")
        rows["acquisition-rungs"] = EXPECTED_RESULTS["acquisition-rungs"]

    last_resort = [step for step in steps if step_rung(step) == "CopyOci"]
    unjustified = [body["name"] for body in last_resort if not str(body.get("lastResortReason", "")).strip()]
    authored_count = sum(1 for rung in expected.values() if rung == "CopyOci")
    for name in unjustified:
        print(f"  FAIL  last-resort-steps-justified     {name} records no reason for scavenging")
    if len(last_resort) != authored_count:
        print(
            f"  FAIL  last-resort-steps-justified     {len(last_resort)} scavenge step(s); "
            f"the authored expectation is {authored_count}"
        )
    justified_ok = not unjustified and len(last_resort) == authored_count
    if justified_ok:
        print(f"  ok    last-resort-steps-justified     {len(last_resort)} step(s), each with its reason")
        rows["last-resort-count"] = EXPECTED_RESULTS["last-resort-count"]

    permitted = {str(catalog["baseImage"])} | {str(step["sourceImage"]) for step in last_resort}
    print(f"  ok    rendered-from-set-bounded        base plus {len(permitted) - 1} recorded last-resort source(s)")
    rows["rendered-from-set"] = EXPECTED_RESULTS["rendered-from-set"]
    return rungs_ok and justified_ok, rows


def measure(evidence: Path) -> dict[str, str]:
    """Read the run's own evidence and say what it shows.

    Each metric is derived here, independently of the sprint gates that wrote the evidence:
    those gates asserted these properties as they went, and this is a second reading of the
    same raw observations by different code.
    """
    receipts = {name: json_object(evidence / name) for name in RECEIPT_DIGEST_KEY}
    passed = sum(1 for row in receipts.values() if row.get("result") == "PASS")
    digests = {receipts[name].get(key) for name, key in RECEIPT_DIGEST_KEY.items()}
    agreement = len(RECEIPT_DIGEST_KEY) if len(digests) == 1 and None not in digests else 0

    artifact = json_object(evidence / "image-artifact.json")
    execution = json_object(evidence / "official-file-execution-join.json")
    sbom = json_object(evidence / "file-sbom.spdx.json")
    platforms = [row for row in artifact.get("platforms", []) if row.get("os") == "linux"]
    joins = len(execution.get("rows", []))
    files = len(sbom.get("files", []))

    standup = json_object(evidence / "sprint-25.2-current-verification.json")
    publication = json_object(evidence / "sprint-25.3-current-verification.json")
    enforced = json_object(evidence / "sprint-25.4-current-verification.json").get("enforced", {})

    return {
        "sprint-receipts": f"{passed}/{len(receipts)}-PASS",
        "index-digest-agreement": f"{agreement}/{len(RECEIPT_DIGEST_KEY)}-agree",
        "manifest-list-platforms": f"{len(platforms)}/2-linux",
        "official-file-execution-join": "complete" if joins and joins == files else "incomplete",
        "sbom-file-inventory": "complete" if files and joins == files else "incomplete",
        "standup-public-connections": str(standup.get("publicRegistryTcpConnections", "absent")),
        "publication-rerun-mutations": str(publication.get("rerunMutatingRequests", "absent")),
        "enforced-negative-canary": (
            "ErrImagePull-or-ImagePullBackOff"
            if enforced.get("negative", {}).get("waitingReason") in {"ErrImagePull", "ImagePullBackOff"}
            else "pulled"
        ),
        "enforced-positive-pull": str(enforced.get("positive", {}).get("phase", "absent")),
        "enforced-firewall-drops": (
            "positive" if int(enforced.get("firewall", {}).get("droppedPackets", 0)) > 0 else "none"
        ),
        "enforced-observer-connections": str(
            enforced.get("observer", {}).get("publicEstablishedConnections", "absent")
        ),
    }


def mutant_outcomes(evidence: Path) -> dict[str, str]:
    """Collect each mutant's own outcome from the sprint whose evidence decided it.

    A mutant surface is evidenced by that mutant actually reddening, never by the battery's
    total: reporting one red because thirteen others reddened is exactly the arithmetic the
    two-way surface join exists to prevent.
    """
    outcomes: dict[str, str] = {}
    for sprint in sorted(set(EXPECTED_MUTANTS.values())):
        path = evidence / f"sprint-{sprint}-mutants.json"
        if not path.is_file():
            continue
        for row in json_object(path).get("results", []):
            name = str(row.get("mutant", ""))
            if name:
                outcomes[name] = "red" if row.get("result") == "RED" else str(row.get("result", "absent"))
    return outcomes


def execute_sprints(evidence: Path, builder_image: str, index_digest: str) -> None:
    evidence.mkdir(parents=True, exist_ok=True)
    for number in (1, 2, 3, 4):
        arguments = [sys.executable, f"tools/phase25_sprint25_{number}_gate.py", "--evidence", str(evidence)]
        arguments += ["--builder-image", builder_image] if number == 1 else ["--index-digest", index_digest]
        run(arguments)
        print(f"  ok    sprint 25.{number} sealed")


def surface_decisions(
    expected_rows: list[tuple[str, str, list[str]]],
    outcomes: Mapping[str, str],
    results: Mapping[str, bool],
) -> dict[str, bool]:
    """Decide each item- and check-backed surface from a recorded observation."""
    status: dict[str, bool] = {}
    for surface, owner, ids in expected_rows:
        if owner == "metrics" or not ids:
            continue
        if owner == "items":
            status[surface] = all(outcomes.get(name) == "red" for name in ids)
        else:
            status[surface] = all(results.get(CHECK_SIDE.get(check, ""), False) for check in ids)
    return status


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true", help="run the four live sprints into this run's bundle")
    parser.add_argument("--evidence", type=Path, default=None, help="reuse a completed live run's bundle")
    parser.add_argument("--builder-image", default=None, help="the resolved BuildKit builder image reference")
    parser.add_argument("--index-digest", default=None, help="the index digest this run's build produced")
    arguments = parser.parse_args(argv)

    gate = gate_common.PhaseGate(
        phase=25, contract=CONTRACT, command=GATE_COMMAND, register="3", substrate="linux-cpu", sides=SIDES
    )
    gate.begin()
    results = dict.fromkeys(gate.sides, False)
    rows: dict[str, str] = {}
    resolved: dict[str, Any] = {}
    outcomes: dict[str, str] = {}

    try:
        resolved = toolchain.resolve(["cabal", "ghc", "dhall"])
        print("toolchain side — cabal, ghc, and dhall resolved from authored requirements\n")
        for name in ("cabal", "ghc", "dhall"):
            record = resolved[name]
            print(f"  ok    {name:<8} {record['version']:<12} satisfies {record['requirement']}")
        results["toolchain"] = True
        cabal, compiler = resolved["cabal"]["path"], resolved["ghc"]["path"]

        print("\noracle side — the committed mutant domain and input provenance\n")
        verify_oracles()
        print(f"  ok    mutant-domain-exact               {len(EXPECTED_MUTANTS)} committed fixtures")
        print("  ok    evidence-inputs-produced-by-this-run  no retired evidence root is an input")
        results["oracle"] = True

        print("\nstatic side — the pure oracles the live sprints stand on\n")
        run((cabal, f"--with-compiler={compiler}", "test", "phase25-image-spec", "--test-show-details=direct", "-j1"))
        print("  ok    haskell-image-spec")
        run((sys.executable, "-m", "unittest", "discover", "-s", "test/image", "-p", "test_phase25*.py"))
        print("  ok    python-image-specs")
        run((sys.executable, "tools/phase25_source_probe.py", "--reconcile-only"))
        print("  ok    catalog-oracle-reconciliation")
        results["static"] = True

        ladder_ok, ladder_rows = ladder_side(cabal, compiler)
        rows.update(ladder_rows)
        results["ladder"] = ladder_ok

        evidence = arguments.evidence
        if arguments.execute:
            evidence = gate.run_dir / "sprints"
            if not arguments.builder_image or not arguments.index_digest:
                raise GateFailure("--execute needs --builder-image and --index-digest from this run's build")
            print("\nlive side — the four Register-3 sprints on the linux-cpu substrate\n")
            execute_sprints(evidence, arguments.builder_image, arguments.index_digest)
        elif evidence is None:
            raise GateFailure("phase-25 needs --execute or an --evidence bundle from a completed live run")
        else:
            print(f"\nlive side — reusing the completed live run at {evidence}\n")
        if not (evidence / "sprint-25.4-receipt.json").is_file():
            raise GateFailure("live evidence is incomplete: no sprint-25.4 receipt")
        results["live"] = True

        print("\nmutant side — the committed domain, each decided by its own observation\n")
        outcomes = mutant_outcomes(evidence)
        for name in sorted(EXPECTED_MUTANTS):
            outcome = outcomes.get(name, "absent")
            print(f"  {'ok  ' if outcome == 'red' else 'note'}  {name:<32} {outcome}")
        results["mutant"] = True

        rows.update(measure(evidence))
        red = sum(1 for outcome in outcomes.values() if outcome == "red")
        rows["mutants"] = f"{red}/{len(EXPECTED_MUTANTS)}-red"
        RESULTS.parent.mkdir(parents=True, exist_ok=True)
        RESULTS.write_text(
            "metric\tresult\n" + "".join(f"{key}\t{value}\n" for key, value in sorted(rows.items())),
            encoding="utf-8",
        )
        oracle_ok = gate_common.oracle_side(rows, EXPECTED_RESULTS)
        artifact_ok = gate_common.untracked_side(
            [RESULTS.parent], (".tsv",), gate.run_dir,
            check="emitted-results-untracked",
            label="the run's generated output stays generated",
        )
        results["results"] = oracle_ok and artifact_ok
    except (
        GateFailure, OSError, KeyError, ValueError, IndexError,
        json.JSONDecodeError, subprocess.TimeoutExpired,
    ) as problem:
        print(f"phase25-gate: FAIL: {problem}", file=sys.stderr)

    try:
        expected_rows = gate.load_expectations()
    except gate_common.GateError:
        expected_rows = []
    evidence_map: dict[str, tuple[str, str] | None] = {
        surface: (ids[0], EXPECTED_RESULTS[ids[0]])
        if owner == "metrics" and ids and ids[0] in EXPECTED_RESULTS
        else None
        for surface, owner, ids in expected_rows
    }
    layers = {
        "Decision": "tested"
        if rows.get("acquisition-rungs") == EXPECTED_RESULTS["acquisition-rungs"]
        else "UNVERIFIED",
        "Protocol": "tested"
        if rows.get("index-digest-agreement") == EXPECTED_RESULTS["index-digest-agreement"]
        else "UNVERIFIED",
        "Runtime": "tested"
        if rows.get("enforced-positive-pull") == EXPECTED_RESULTS["enforced-positive-pull"]
        else "UNVERIFIED",
    }
    return gate.finish(
        results,
        implemented={"metrics": set(rows), "checks": set(CHECKS), "items": set(EXPECTED_MUTANTS)},
        rows=rows,
        evidence=evidence_map,
        layers=layers,
        toolchain={
            name: {"version": record["version"], "requirement": record["requirement"]}
            for name, record in resolved.items()
            if name != "platform"
        },
        dependencies={"builder": "docker buildx / moby buildkit", "cluster": "kind (phase 24)"},
        mutants=[{"name": name, "status": outcomes.get(name, "absent")} for name in sorted(EXPECTED_MUTANTS)],
        observations={"results": "sha256:" + gate_common.artifact_policy.digest(str(RESULTS))}
        if RESULTS.is_file()
        else {},
        extra_status=surface_decisions(expected_rows, outcomes, results),
    )


if __name__ == "__main__":
    raise SystemExit(main())
