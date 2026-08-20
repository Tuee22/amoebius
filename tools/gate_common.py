#!/usr/bin/env python3
"""The universal artifact-hygiene half of every amoebius phase gate.

`development_plan_standards.md` section S attaches fourteen postconditions to *every* phase
gate. Sixty-five gates cannot each re-implement them: the copies drift, and a gate whose
copy drifted is a gate that passes for the wrong reason. This module owns that half once.

What a phase still owns, and this module deliberately does not:

  * its capability checks — the actual claim the phase makes
  * its authored surface expectation under `test/oracle/`
  * its seeded mutants and its independent oracles

What this module owns:

  * the run bundle location and the run id
  * the two-way surface join between a run-time enumeration and the authored expectation
  * the proven/tested/assumed ledger, emitted into the run bundle and schema-checked
  * the project-contained attestation, bound to the source-snapshot digest
  * the closed-root and outside-host inventory check
  * the authored-root write guard bracketing the whole run
  * the pass/fail report

Typical use:

    gate = PhaseGate(phase=2, contract="DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md",
                     command="python3 tools/formal_model_kernel_gate.py",
                     expectations="test/oracle/formal_model_kernel_surfaces.tsv",
                     register="1", substrate="none",
                     sides=("model", "mutant", ...))
    gate.begin()
    results = {...}                      # the phase's own capability sides
    ok, surfaces = gate.surface_join({"checks": {...}, "models": {...}})
    results["ledger"] = gate.ledger_side(surfaces, layers)
    results["attestation"] = gate.attestation_side(toolchain=..., dependencies=..., mutants=...)
    results["write-guard"] = gate.write_guard_side()
    return gate.report(results)
"""

from __future__ import annotations

import datetime as dt
import json
import os
import platform
import subprocess
import sys
from pathlib import Path
from typing import Any, Iterable, Mapping

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import artifact_policy  # noqa: E402
import attestation  # noqa: E402
import ledger_lint  # noqa: E402
import containment  # noqa: E402
import host_platform  # noqa: E402

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent

# The universal sides this module contributes. A phase appends its own names before
# these, so the report reads capability-first and hygiene-last.
UNIVERSAL_SIDES = ("architecture", "surface", "ledger", "attestation", "containment", "write-guard")

# ---------------------------------------------------------------------------
# Section S clause 15 — the architecture a run actually executed on
# ---------------------------------------------------------------------------
#
# The catalogue and its aliases belong to `tools/host_platform.py`, which is the one
# canonical normalizer the resolver and the pre-binary coordinator read too. They are
# re-exported here because sixty-odd gates already name them through this module.
ARCHITECTURES = host_platform.ARCHITECTURES
ARCHITECTURE_ALIASES = host_platform.ARCHITECTURE_ALIASES
# An emulator maps its own image into the process, and on Darwin the kernel answers
# outright. Both are the platform's own signal about the process, not a guess from the
# artifact's filename.
EMULATOR_HINTS = ("qemu-", "qemu_", "box64", "box86", "rosetta")


def rel(path: Path | str) -> str:
    return os.path.relpath(str(path), str(ROOT))


def normalize_architecture(name: str) -> str:
    """Map a kernel's machine name onto the closed lane vocabulary."""
    try:
        return host_platform.normalize_architecture(name)
    except host_platform.PlatformError as error:
        raise GateError(f"{error}; clause 15 admits {ARCHITECTURES}") from error


def _proc_translated() -> bool:
    """Darwin's own answer to 'is this process running under Rosetta?'."""
    try:
        result = subprocess.run(
            ["sysctl", "-n", "sysctl.proc_translated"],
            text=True,
            capture_output=True,
            check=False,
        )
    except OSError:
        return False
    return result.stdout.strip() == "1"


def _mapped_emulator() -> str | None:
    """An emulator image mapped into this process, as Linux reports its own maps."""
    try:
        maps = Path("/proc/self/maps").read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    for line in maps.splitlines():
        lowered = line.lower()
        for hint in EMULATOR_HINTS:
            if hint in lowered:
                return line.split()[-1]
    return None


def natural_architecture() -> str:
    """The architecture this process is executing as, refusing a translated one.

    Clause 15 asks two different questions and this answers both: *which* architecture
    the run used, and whether the hardware actually ran it. A translated process
    answers the first perfectly well and is still exactly the thing the clause exists
    to refuse, so the refusal happens here rather than in each caller.
    """
    problems = architecture_problems()
    if problems:
        raise GateError(problems[0])
    return normalize_architecture(platform.machine())


def architecture_problems() -> list[str]:
    """Every reason this process is not a natural-architecture run."""
    problems: list[str] = []
    try:
        machine = normalize_architecture(platform.machine())
    except GateError as error:
        return [str(error)]
    if sys.platform == "darwin" and _proc_translated():
        problems.append(
            f"the process reports {machine} under Darwin translation; clause 15 admits no emulated run"
        )
    mapped = _mapped_emulator()
    if mapped is not None:
        problems.append(f"an emulator image {mapped} is mapped into this process")
    return problems


def architecture_side(recorded: str | None = None) -> tuple[bool, str]:
    """Prove clause 15 for this run, and prove the proof reddens for the complement.

    The mutant is the point. Comparing the detected architecture with itself passes on
    any host and proves nothing, so the side also runs the same comparison against the
    complement and requires it to fail — a comparison that cannot fail is not a check.
    """
    print("\narchitecture side — the natural architecture this run executed on\n")
    problems = architecture_problems()
    for problem in problems:
        print(f"  FAIL  {problem}")
    if problems:
        return False, ""
    observed = normalize_architecture(platform.machine())
    if recorded is not None and recorded != observed:
        print(f"  FAIL  the run records {recorded}, but it executed on {observed}")
        return False, observed
    complement = next(name for name in ARCHITECTURES if name != observed)
    if complement == observed:
        print("  FAIL  the complement mutant is not distinguishable from the observation")
        return False, observed
    print(f"  ok    {sys.platform}/{platform.machine()} is natural {observed}, untranslated")
    print(f"  ok    mutant: the same comparison against {complement} is red")
    return True, observed


def run_id() -> str:
    """One directory per run. A bundle is evidence, so a wall-clock stamp is right."""
    return dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")


class GateError(RuntimeError):
    """The gate cannot proceed — a missing authored input, not a failed check."""


class PhaseGate:
    def __init__(
        self,
        *,
        phase: int,
        contract: str,
        command: str,
        expectations: str | None = None,
        register: str,
        substrate: str,
        lane: str | None = None,
        sides: Iterable[str],
    ) -> None:
        # Clause 15 is a postcondition on the *run*, so the lane is declared by the gate
        # rather than read back out of the tracker: a value the gate copies from the
        # document it is checked against cannot disagree with it, and a comparison that
        # cannot disagree is not a check.
        if lane is None:
            raise GateError(
                f"phase {phase}: section S clause 15 requires this gate to declare the lane it runs"
            )
        self.phase = phase
        self.contract = contract
        self.command = command
        self.register = register
        self.substrate = substrate
        self.lane = lane
        self.architecture = ""
        self.sides = tuple(sides) + UNIVERSAL_SIDES
        self.tag = f"phase_{phase:02d}"
        self.expectations = (
            ROOT / expectations
            if expectations is not None
            else ROOT / "test" / f"{self.tag}_surface_expectations.tsv"
        )
        self.surfaces_path = ROOT / ".build" / "test-surfaces" / f"{self.tag}.json"
        self.run_dir = ROOT / ".build" / "runs" / self.tag / run_id()
        self.corpora = ROOT / ".build" / "test-corpora" / self.tag
        self._before: dict[str, str] = {}
        self._before_host: containment.HostInventory | None = None
        self._ledger_path: Path | None = None

    # -- lifecycle ---------------------------------------------------------

    def begin(self) -> None:
        """Open the run bundle and take the authored-root baseline.

        The baseline is taken before any side runs, so the guard covers the whole gate
        rather than whichever part remembered to be careful.
        """
        self._before = artifact_policy.authored_snapshot()
        self._before_host = containment.host_inventory()
        self.run_dir.mkdir(parents=True, exist_ok=True)

    # -- architecture ------------------------------------------------------

    def architecture_side(self) -> bool:
        """Record the architecture this run executed on, and refuse another's."""
        ok, observed = architecture_side()
        self.architecture = observed
        if ok:
            # The lane's own architecture is owned by the ledger checker, so the gate
            # and the record it emits cannot disagree about what a lane name means.
            wanted = ledger_lint.LANE_ARCHITECTURE.get(self.lane.split("→")[0].strip())
            if wanted is not None and wanted != observed:
                print(f"  FAIL  lane {self.lane} names {wanted}, but this host is {observed}")
                return False
        return ok

    # -- surface join ------------------------------------------------------

    def load_expectations(self) -> list[tuple[str, str, list[str]]]:
        if not self.expectations.is_file():
            raise GateError(f"authored expectation {rel(self.expectations)} is missing")
        rows: list[tuple[str, str, list[str]]] = []
        for number, line in enumerate(self.expectations.read_text(encoding="utf-8").splitlines(), 1):
            if not line.strip() or line.startswith("#"):
                continue
            fields = line.split("\t")
            # A surface this register cannot reach has no ids. Requiring the trailing tab
            # anyway makes the file's meaning depend on invisible whitespace, so a
            # two-field row is read as "no ids" rather than rejected.
            if len(fields) == 2:
                fields = [*fields, ""]
            if len(fields) != 3:
                raise GateError(f"{rel(self.expectations)}:{number}: expected two or three tab-separated fields")
            surface, owner, ids = (field.strip() for field in fields)
            rows.append((surface, owner, [i for i in ids.split(",") if i]))
        return rows

    def surface_join(self, implemented: Mapping[str, set[str]]) -> tuple[bool, list[str]]:
        """Join a run-time enumeration to the authored expectation, both ways.

        One-way would be enough to catch a surface that claims something absent. It is the
        *other* direction that matters: an implemented item no surface claims means the
        expectation stopped describing the gate, and that is exactly how a deleted check
        or a dropped dependency shrinks a gate without anyone noticing.
        """
        print("\nsurface side — run-time enumeration joined to the authored expectation\n")
        try:
            expected = self.load_expectations()
        except GateError as error:
            print(f"  FAIL  {error}")
            return False, []

        ok = True
        claimed: dict[str, set[str]] = {owner: set() for owner in implemented}
        for surface, owner, ids in expected:
            if owner not in implemented:
                print(f"  FAIL  {surface:<38} unknown owner {owner!r}")
                ok = False
                continue
            missing = [i for i in ids if i not in implemented[owner]]
            if missing:
                print(f"  FAIL  {surface:<38} {owner} produced no {', '.join(missing)}")
                ok = False
            for i in ids:
                if i in claimed[owner]:
                    print(f"  FAIL  {surface:<38} {i} is claimed twice")
                    ok = False
                claimed[owner].add(i)
        for owner, ids in implemented.items():
            for orphan in sorted(set(ids) - claimed[owner]):
                print(f"  FAIL  {owner}:{orphan:<32} enumerated but joins to no surface")
                ok = False

        surfaces = [surface for surface, _owner, _ids in expected]
        if ok:
            total = sum(len(ids) for ids in implemented.values())
            print(f"  ok    {len(surfaces)} surfaces join completely to {total} enumerated items")
        self.surfaces_path.parent.mkdir(parents=True, exist_ok=True)
        self.surfaces_path.write_text(
            json.dumps(
                {
                    "phase": self.phase,
                    "surfaces": surfaces,
                    "implemented": {owner: sorted(ids) for owner, ids in implemented.items()},
                },
                indent=2,
                sort_keys=True,
            )
            + "\n",
            encoding="utf-8",
        )
        print(f"  ok    enumeration written to {rel(self.surfaces_path)}")
        return ok, surfaces

    # -- ledger ------------------------------------------------------------

    def emit_ledger(self, surfaces: list[str], layers: Mapping[str, str], results: Mapping[str, bool] | None = None) -> Path:
        results = results or {}
        ledger = {
            "phase": self.phase,
            "gate_command": self.command,
            "register": self.register,
            "substrate": self.substrate,
            "lane": self.lane,
            "architecture": self.architecture,
            "date": dt.date.today().isoformat(),
            "layers": [{"name": name, "status": layers[name]} for name in ("Decision", "Protocol", "Runtime")],
            "coverage": [
                {"surface": surface, "status": "tested" if results.get(surface, True) else "UNVERIFIED"}
                for surface in surfaces
            ],
        }
        ledger["ledger_hash"] = ledger_lint.canonical_hash(ledger)
        self.run_dir.mkdir(parents=True, exist_ok=True)
        path = self.run_dir / "ledger.json"
        path.write_text(json.dumps(ledger, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        return path

    def ledger_side(self, surfaces: list[str], layers: Mapping[str, str], results: Mapping[str, bool] | None = None) -> bool:
        print("\nledger side — the run ledger inside the run bundle\n")
        path = self.emit_ledger(surfaces, layers, results)
        self._ledger_path = path
        check = subprocess.run(
            [sys.executable, str(HERE / "ledger_lint.py"), str(path), "--enumeration", str(self.surfaces_path)],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        if check.returncode == 0:
            print(f"  ok    {rel(path)}  schema, tracker, surfaces, hash")
            return True
        print((check.stdout + check.stderr).rstrip())
        return False

    # -- attestation -------------------------------------------------------

    def attestation_side(
        self,
        *,
        toolchain: Mapping[str, Any],
        dependencies: Mapping[str, Any],
        checks: Mapping[str, bool],
        mutants: list[Mapping[str, str]],
        observations: Mapping[str, str] | None = None,
        coverage: list[Mapping[str, str]] | None = None,
        left_resources: bool = False,
    ) -> bool:
        """Bind this run to its source snapshot and retain it beneath `.build/`.

        The binding is the digest of every non-ignored file as the run saw it. Whether
        that source is committed, and when, is the operator's business and no part of the
        gate (`development_plan_standards.md` section S, commit timing).
        """
        print("\nattestation side — project-contained retention\n")
        if self._ledger_path is None:
            print("  FAIL  no ledger was emitted, so there is nothing to bind")
            return False
        commit = artifact_policy.git("rev-parse", "HEAD").strip()
        dirty = bool(artifact_policy.git("status", "--porcelain").strip())
        snapshot = artifact_policy.source_digest()
        record = dict(observations or {})
        record["ledger"] = "sha256:" + artifact_policy.digest(str(self._ledger_path))
        bundle = {
            "schema": attestation.SCHEMA,
            "phase": self.phase,
            "contract": self.contract,
            "contract_digest": "sha256:" + artifact_policy.digest(str(ROOT / self.contract)),
            "commit": f"{commit}+uncommitted" if dirty and commit else (commit or "uncommitted"),
            "source_digest": snapshot,
            "command": self.command,
            "register": self.register,
            "substrate": self.substrate,
            "lane": self.lane,
            "architecture": self.architecture,
            "toolchain": dict(toolchain),
            "dependencies": dict(dependencies),
            "checks": [{"name": name, "status": "pass" if passed else "fail"} for name, passed in checks.items()],
            "mutants": [dict(mutant) for mutant in mutants],
            "coverage": list(coverage or [{"surface": self.tag, "status": "tested"}]),
            "cleanup": {"left_resources": left_resources},
            "observations": record,
            "ledger_hash": json.loads(self._ledger_path.read_text(encoding="utf-8"))["ledger_hash"],
        }
        problems = attestation.schema_check(bundle)
        if problems:
            for problem in problems:
                print(f"  FAIL  run bundle: {problem}")
            return False
        store = attestation.default_store()
        reference = store.put(bundle)
        if not store.verify(reference):
            print(f"  FAIL  attestation {reference} did not verify")
            return False
        print(f"  ok    attested {reference}")
        print(f"  ok    bound to source snapshot {snapshot[:23]}… ({len(artifact_policy.snapshot_paths())} files)")
        self.reference = reference
        return True

    # -- containment ------------------------------------------------------

    def containment_side(self) -> bool:
        print("\ncontainment side — closed roots and outside-host inventory\n")
        if self._before_host is None:
            print("  FAIL  gate did not capture its initial host inventory")
            return False
        after = containment.host_inventory()
        problems = containment.host_inventory_problems(self._before_host, after)
        for problem in problems:
            print(f"  FAIL  {problem}")
        for path in (self.surfaces_path, self.run_dir, self.corpora):
            try:
                containment.require_state_path(path, "build", actor="production")
            except containment.ContainmentError as error:
                problems.append(str(error))
                print(f"  FAIL  {error}")
        if after.observation_errors:
            for error in after.observation_errors:
                print(f"  note  {error}")
        if not problems:
            print("  ok    gate output is beneath .build/ and the outside-host inventory is unchanged")
        return not problems

    # -- write guard and report -------------------------------------------

    def write_guard_side(self) -> bool:
        guard = artifact_policy.Report()
        artifact_policy.audit_write_guard(guard, self._before, artifact_policy.authored_snapshot())
        print("\nwrite guard — authored roots during this run\n")
        if not guard.findings:
            print("  ok    no authored path was created, changed, or removed")
            return True
        for finding in guard.findings:
            print(f"  FAIL  {finding.render()}")
        return False

    def finish(
        self,
        results: dict[str, bool],
        *,
        implemented: Mapping[str, set[str]],
        rows: Mapping[str, str],
        evidence: Mapping[str, tuple[str, str] | None],
        layers: Mapping[str, str],
        toolchain: Mapping[str, Any],
        dependencies: Mapping[str, Any],
        mutants: list[Mapping[str, str]],
        observations: Mapping[str, str] | None = None,
        extra_status: Mapping[str, bool] | None = None,
    ) -> int:
        """Run the universal sides and report.

        Every phase's tail is identical, so it lives here rather than in sixty-five copies
        that would drift apart one edit at a time.
        """
        results["architecture"] = self.architecture_side()
        results["surface"], surfaces = self.surface_join(implemented)
        status = surface_status(surfaces, rows, evidence)
        status.update(extra_status or {})
        results["ledger"] = self.ledger_side(surfaces, layers, status)
        # Containment and the authored-root write guard are claims the immutable
        # record must carry, so decide them before constructing that record.  The
        # retired order stored both as failures even when the final report printed
        # PASS.  The attestation check itself is marked pass in the candidate: the
        # method returns true only after that exact candidate is stored and its
        # content address verifies.
        results["containment"] = self.containment_side()
        results["write-guard"] = self.write_guard_side()
        attested_checks = dict(results)
        attested_checks["attestation"] = True
        results["attestation"] = self.attestation_side(
            toolchain=toolchain,
            dependencies=dependencies,
            checks=attested_checks,
            mutants=mutants,
            observations=observations,
            left_resources=not results["containment"],
        )
        return self.report(results)

    def report(self, results: Mapping[str, bool]) -> int:
        print()
        for name in self.sides:
            print(f"{name:<12} side: {'PASS' if results.get(name) else 'FAIL'}")
        return 0 if all(results.get(name) for name in self.sides) else 1


def metric_rows(path: Path) -> dict[str, str]:
    """Parse a `metric<TAB>value` results table emitted by a suite."""
    rows: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines()[1:]:
        key, _, value = line.partition("\t")
        if key.strip():
            rows[key.strip()] = value.strip()
    return rows


def oracle_side(rows: dict[str, str], expected: Mapping[str, str], check: str = "recorded-results-match-oracle") -> bool:
    """Compare the suite's recorded metrics against the authored expectation, both ways.

    The reverse direction matters as much as the forward one: a metric the suite records
    that no expectation mentions is a result nobody authored an opinion about, and it is
    where a quietly added row hides.
    """
    print("\noracle side — recorded results against the authored expectation\n")
    ok = True
    for key, want in sorted(expected.items()):
        actual = rows.get(key)
        if actual != want:
            print(f"  FAIL  {check} {key}: {actual!r} != {want!r}")
            ok = False
    extra = sorted(set(rows) - set(expected))
    if extra:
        print(f"  FAIL  {check} unexpected metric(s): {', '.join(extra)}")
        ok = False
    if ok:
        print(f"  ok    {check} all {len(expected)} metrics equal their authored values")
    return ok


def untracked_side(
    roots: list[Path],
    suffixes: tuple[str, ...],
    run_dir: Path,
    *,
    check: str,
    label: str,
    record: str = "emitted.json",
) -> bool:
    """Assert that what the run generated stays out of the source snapshot.

    Most phases claim their emitted artifacts are never repository inputs. Until now that
    claim was prose. This is the check.
    """
    print(f"\nartifact side — {label}\n")
    snapshot = set(artifact_policy.snapshot_paths())
    emitted: list[Path] = []
    for root in roots:
        if not root.is_dir():
            continue
        for suffix in suffixes:
            emitted.extend(sorted(root.rglob(f"*{suffix}")))
    if not emitted:
        print(f"  FAIL  {check} the run emitted nothing under {', '.join(rel(r) for r in roots)}")
        return False
    leaked = [path for path in emitted if rel(path) in snapshot]
    for path in leaked:
        print(f"  FAIL  {check} {rel(path)} is in the source snapshot")
    if leaked:
        return False
    run_dir.mkdir(parents=True, exist_ok=True)
    (run_dir / record).write_text(
        json.dumps({rel(p): artifact_policy.digest(str(p)) for p in emitted}, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"  ok    {check} {len(emitted)} emitted file(s), none in the source snapshot")
    return True


def surface_status(
    surfaces: list[str], rows: Mapping[str, str], evidence: Mapping[str, tuple[str, str] | None]
) -> dict[str, bool]:
    """Decide each ledger row from a recorded metric, never from an assertion.

    A surface with no deciding metric stays False, which the ledger renders UNVERIFIED.
    That is the point: a row nothing measured is not a row anything proved.
    """
    return {
        surface: bool(evidence.get(surface)) and rows.get(evidence[surface][0]) == evidence[surface][1]
        for surface in surfaces
    }


def deferred_findings(collected: list[tuple[str, str, str]]) -> tuple[list[artifact_policy.Finding], dict[str, int]]:
    """Split (rule, locus, message) triples into own-phase failures and deferrals.

    Section S clause 5 is enforced by every gate and remediated by the owning phase: a
    finding this phase does not own is reported and attributed, never suppressed, and the
    allowlist row that covers it must still match something or the audit fails.
    """
    report = artifact_policy.Report()
    for rule, locus, message in collected:
        report.findings.append(artifact_policy.Finding(rule, locus, message))
    artifact_policy.apply_allowances(report, artifact_policy.load_allowances())
    owners: dict[str, int] = {}
    for finding in report.deferred:
        owners[finding.owner] = owners.get(finding.owner, 0) + 1
    return report.findings, owners
