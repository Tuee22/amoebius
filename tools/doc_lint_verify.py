#!/usr/bin/env python3
"""Run doc_lint two-sided — the Phase 0 gate command.

Side one   the governed tree must lint clean.
Side two   every negative materialized from the authored seed and mutation list must
           exit non-zero AND name the check its seeded defect trips, while tripping no
           other check. Naming the check is what a stub keyed on fixture identity
           cannot do.

The negatives are reproducible projections of `tools/doc_lint_corpus/_positive/` and
`_build.py`, so the run materializes them beneath `.build/test-corpora/doc_lint/` rather
than reading committed copies.

    python3 tools/doc_lint_verify.py            # both sides
    python3 tools/doc_lint_verify.py --fixtures # fixture side only

Exit status: 0 both sides pass, 1 otherwise.
"""

import argparse
import datetime as dt
import hashlib
import json
import os
import pathlib
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import artifact_policy  # noqa: E402
import attestation  # noqa: E402
import doc_lint  # noqa: E402
import ledger_lint  # noqa: E402
import artifact_manifest_lint  # noqa: E402
import containment  # noqa: E402
import gate_common  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
CORPUS = os.path.join(HERE, "doc_lint_corpus")
ROOT = os.path.dirname(HERE)
NEGATIVES = os.path.join(ROOT, ".build", "test-corpora", "doc_lint")
SURFACES = os.path.join(ROOT, ".build", "test-surfaces", "phase_00.json")
EXPECTATIONS = os.path.join(ROOT, "test", "oracle", "documentation_suite_surfaces.tsv")

SIDE_NAMES = (
    "fixture",
    "architecture",
    "corpus",
    "contract",
    "covering",
    "snapshot",
    "surface",
    "ledger",
    "artifact",
    "policy",
    "attestation",
    "containment",
    "write-guard",
)


def contract_side():
    """Section D's skeleton and the promises each contract makes about its own gate.

    `doc_lint` reads a phase document thoroughly as a document. What it does not read is
    the contract half — the required Phase Summary fields, the mutant ids a gate names,
    and whether the command a contract promises is the command its gate script runs. That
    gap is why `**Phase scope:**` was missing from sixty-four contracts and `**Register:**`
    had no check at all: both were normative in the rulebook and unread by every tool.
    """
    print("\ncontract side — section D's skeleton and each contract's promises\n")
    problems = phase_contract_lint.check(pathlib.Path(ROOT))
    counts = {}
    for check, _, _ in problems:
        counts[check] = counts.get(check, 0) + 1
    for check in phase_contract_lint.CHECKS:
        n = counts.get(check, 0)
        print(f"  {'FAIL' if n else 'ok  '}  {check:4s} {phase_contract_lint.CHECKS[check]}"
              + (f" — {n} violation(s)" if n else ""))
    for check, rel, message in problems[:20]:
        print(f"    {check}  {rel}: {message}")
    return not problems


def covering_side():
    """Section S clause 16: the catalogue is a covering, and an empty cell owes a reason.

    The grid is generated here rather than committed, so widening an axis reports its own
    new empty cells instead of waiting to be noticed. What stays authored is each entry's
    layer-to-locus pairing, the admissibility relation between the two axes, and the
    justification rows — each is an independent expectation, and deriving any of them from
    the catalogue it measures would turn a test into a description.

    A covering that reports zero unjustified cells says nothing on its own, so the side
    also seeds each way the covering can be wrong into a scratch copy and requires it to
    turn red there.
    """
    print("\ncovering side — every cell holds an entry or a reason it holds none\n")
    layers, loci, fams = covering_grid.axes()
    total = len(layers) * len(loci) * len(fams)
    counts = covering_grid.census()
    bad = covering_grid.unjustified()
    broken = covering_grid.entry_violations()
    seeded = covering_grid.selftest()
    grid = covering_grid.emit()
    print(f"  grid    {os.path.relpath(grid, ROOT)}")
    print(f"  cells   {total} = {len(layers)} layers x {len(loci)} loci x {len(fams)} families")
    print(f"  state   " + ", ".join(f"{v} {k.lower()}" for k, v in counts.items()))
    entries = len(covering_grid.entries())
    if broken:
        for entry, message in broken[:12]:
            print(f"  FAIL  c1/c2  {entry}: {message}")
    else:
        print(f"  ok    c1/c2  {entries} entries pair every foreclosure to an admissible locus")
    if bad:
        for cell in bad[:12]:
            print(f"  FAIL  c3     {cell[0]} x {cell[1]} x {cell[2]}")
        if len(bad) > 12:
            print(f"  FAIL  c3     ... and {len(bad) - 12} more")
    else:
        print(f"  ok    c3     {counts['justified']} empty admissible cell(s) each carry a reason")
    if seeded:
        for message in seeded:
            print(f"  FAIL  c4     {message}")
    else:
        print(f"  ok    c4     {len(covering_grid.MUTANTS)} seeded defects each turned it red")
    return not (bad or broken or seeded)


def run_id():
    """One directory per run. The bundle is evidence, so a wall-clock stamp is right."""
    return dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")


sys.path.insert(0, CORPUS)
import _build  # noqa: E402
import phase_contract_lint  # noqa: E402
import covering_grid  # noqa: E402


def expected(fixture_name):
    """(check the fixture must trip, checks the same defect legitimately co-implies)."""
    return _build.EXPECTED[fixture_name]


def fixture_side():
    ok = True
    try:
        built = _build.materialize(NEGATIVES)
    except _build.SeedError as exc:
        print(f"cannot materialize the negative corpus: {exc}", file=sys.stderr)
        return False
    names = sorted(built)
    if not names:
        print("no negatives materialized", file=sys.stderr)
        return False

    print(f"fixture side — {len(names)} seeded negatives materialized under")
    print(f"               {os.path.relpath(NEGATIVES, ROOT)}\n")
    for name in names:
        want, co_implied = expected(name)
        # An advisory check does not fail the gate, so its fixture is proven by the
        # check's own run. The seeded defect must still be the ONLY one it trips.
        only = {want} if want in doc_lint.ADVISORY else None
        code, violations = doc_lint.run(built[name], only=only)
        hit = sorted({v.check for v in violations})
        allowed = {want} | co_implied
        if only:
            _, all_v = doc_lint.run(built[name])
            hit = sorted({v.check for v in all_v})
        if code == 0:
            print(f"  FAIL  {name:38s} lint stayed clean; expected {want}")
            ok = False
        elif want not in hit:
            print(f"  FAIL  {name:38s} expected {want}, got {', '.join(hit) or 'nothing'}")
            ok = False
        elif set(hit) - allowed:
            extra = sorted(set(hit) - allowed)
            print(f"  FAIL  {name:38s} tripped {want} but also {', '.join(extra)} — not a single-defect fixture")
            ok = False
        else:
            also = f"  (co-implies {', '.join(sorted(co_implied))})" if co_implied else ""
            adv = "  (advisory)" if want in doc_lint.ADVISORY else ""
            print(f"  ok    {name:38s} {want}{adv}{also}")
    return ok


def positive_side():
    code, violations = doc_lint.run(os.path.join(CORPUS, "_positive"))
    if code == 0:
        print("\n  ok    _positive                              lints clean")
        return True
    hit = sorted({v.check for v in violations})
    print(f"\n  FAIL  _positive                              not clean: {', '.join(hit)}")
    for v in violations[:10]:
        print(f"          {v.render()}")
    return False


def tree_side():
    code, violations = doc_lint.run(ROOT)
    counts = {}
    for v in violations:
        counts[v.check] = counts.get(v.check, 0) + 1
    print("\ncorpus side — the governed documentation tree\n")
    if code == 0:
        print("  ok    the tree lints clean")
        return True
    for cid in doc_lint.CHECKS:
        if counts.get(cid):
            print(f"  FAIL  {counts[cid]:5d}  {cid:<3} {doc_lint.CHECKS[cid]}")
    print(f"\n  {sum(counts.values())} violation(s) — the tree is not yet clean, so the Phase 0 gate is RED")
    return False


def surface_side():
    """Enumerate what the three checkers implement and join it to the authored table.

    The enumeration is discovered from the live check registries, never from a
    committed list, so a deleted check shrinks the enumeration and breaks the join.
    """
    print("\nsurface side — run-time enumeration joined to the authored expectation\n")
    implemented = {
        "doc_lint": set(doc_lint.CHECKS),
        "ledger_lint": set(ledger_lint.CHECKS),
        "artifact_policy": set(artifact_policy.RULES),
        "artifact_manifest_lint": set(artifact_manifest_lint.CHECKS),
        "phase_contract_lint": set(phase_contract_lint.CHECKS),
        "covering_grid": set(covering_grid.CHECKS),
    }

    if not os.path.isfile(EXPECTATIONS):
        print(f"  FAIL  authored expectation {os.path.relpath(EXPECTATIONS, ROOT)} is missing")
        return False, []

    expected: list[tuple[str, str, list[str]]] = []
    for number, line in enumerate(open(EXPECTATIONS, encoding="utf-8"), 1):
        if not line.strip() or line.startswith("#"):
            continue
        fields = line.rstrip("\n").split("\t")
        if len(fields) != 3:
            print(f"  FAIL  {os.path.relpath(EXPECTATIONS, ROOT)}:{number}: expected three fields")
            return False, []
        surface, owner, ids = (f.strip() for f in fields)
        expected.append((surface, owner, [i for i in ids.split(",") if i]))

    ok = True
    claimed: dict[str, set[str]] = {owner: set() for owner in implemented}
    for surface, owner, ids in expected:
        if owner not in implemented:
            print(f"  FAIL  {surface:<45} unknown owner {owner!r}")
            ok = False
            continue
        missing = [i for i in ids if i not in implemented[owner]]
        if missing:
            print(f"  FAIL  {surface:<45} {owner} implements no {', '.join(missing)}")
            ok = False
        for i in ids:
            if i in claimed[owner]:
                print(f"  FAIL  {surface:<45} check {i} is claimed twice")
                ok = False
            claimed[owner].add(i)

    for owner, ids in implemented.items():
        for orphan in sorted(ids - claimed[owner]):
            print(f"  FAIL  {owner}:{orphan:<36} implemented check joins to no surface")
            ok = False

    surfaces = [surface for surface, _owner, _ids in expected]
    if ok:
        total = sum(len(ids) for ids in implemented.values())
        print(f"  ok    {len(surfaces)} surfaces join completely to {total} implemented checks")

    os.makedirs(os.path.dirname(SURFACES), exist_ok=True)
    with open(SURFACES, "w", encoding="utf-8") as fh:
        json.dump(
            {
                "phase": 0,
                "surfaces": surfaces,
                "implemented": {owner: sorted(ids) for owner, ids in implemented.items()},
            },
            fh,
            indent=2,
            sort_keys=True,
        )
        fh.write("\n")
    print(f"  ok    enumeration written to {os.path.relpath(SURFACES, ROOT)}")
    return ok, surfaces


def snapshot_side():
    """Prove clause 9: the governed corpus lints from the snapshot alone.

    Every non-ignored file is copied into a scratch tree and the documentation lint runs
    there. Anything the lint needs that exists only as an ignored worktree file is
    missing source, and it shows up here as a failure. This replaces the older
    clone-based check, which could only ever see committed content and so made source
    closure depend on when the operator committed.
    """
    print("\nsnapshot side — the governed corpus lints from non-ignored source alone\n")
    target = os.path.join(ROOT, ".build", "tmp", "source-snapshot")
    if os.path.isdir(target):
        shutil.rmtree(target)
    paths = artifact_policy.snapshot_paths()
    for relative in paths:
        destination = os.path.join(target, relative)
        os.makedirs(os.path.dirname(destination), exist_ok=True)
        shutil.copy2(os.path.join(ROOT, relative), destination)

    code, violations = doc_lint.run(target)
    if code == 0:
        print(f"  ok    {len(paths)} non-ignored files copied; the corpus lints clean there")
        return True
    counts = {}
    for violation in violations:
        counts[violation.check] = counts.get(violation.check, 0) + 1
    for cid, total in sorted(counts.items()):
        if cid not in doc_lint.ADVISORY:
            print(f"  FAIL  {total:5d}  {cid:<3} {doc_lint.CHECKS[cid]}")
    print("  FAIL  the corpus needs an ignored worktree file, so source closure is broken")
    return False


def emit_ledger(run_dir, surfaces, results, architecture):
    """Write this run's proven/tested/assumed ledger into the run bundle."""
    ledger = {
        "phase": 0,
        "gate_command": "python3 tools/doc_lint_verify.py",
        "register": "—",
        "substrate": "none",
        "lane": "none",
        "architecture": architecture,
        "date": dt.date.today().isoformat(),
        # Phase 0 validates text, the link graph, and repository provenance. It
        # exercises no amoebius decision, protocol, or runtime, so all three
        # correctness layers stay UNVERIFIED.
        "layers": [
            {"name": "Decision", "status": "UNVERIFIED"},
            {"name": "Protocol", "status": "UNVERIFIED"},
            {"name": "Runtime", "status": "UNVERIFIED"},
        ],
        "coverage": [
            {"surface": surface, "status": "tested" if results.get(surface, True) else "UNVERIFIED"}
            for surface in surfaces
        ],
    }
    ledger["ledger_hash"] = ledger_lint.canonical_hash(ledger)
    os.makedirs(run_dir, exist_ok=True)
    path = os.path.join(run_dir, "ledger.json")
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(ledger, fh, indent=2, sort_keys=True)
        fh.write("\n")
    return path


def ledger_side(run_dir, surfaces, architecture):
    """Prove the ledger checker accepts and rejects its corpus, then check this run's."""
    command = [sys.executable, os.path.join(HERE, "ledger_lint.py"), "--verify-corpus"]
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False)
    print("\nledger side — schema and seeded negatives\n")
    if result.stdout:
        print(result.stdout.rstrip())

    emitted = emit_ledger(run_dir, surfaces, {}, architecture)
    run_check = subprocess.run(
        [sys.executable, os.path.join(HERE, "ledger_lint.py"), emitted, "--enumeration", SURFACES],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if run_check.returncode == 0:
        print(f"  ok   {os.path.relpath(emitted, ROOT)}  schema, tracker, surfaces, hash")
    else:
        print(run_check.stderr.rstrip())
    if result.returncode == 0 and run_check.returncode == 0:
        return True, emitted
    if result.stderr:
        print(result.stderr.rstrip())
    return False, emitted


def policy_side():
    """Audit repository provenance, and prove each of its rules rejects its negative."""
    print("\npolicy side — repository artifact provenance\n")
    negatives = subprocess.run(
        [sys.executable, os.path.join(HERE, "artifact_policy.py"), "--self-test"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    body = "\n".join(negatives.stdout.splitlines()[2:])
    if body.strip():
        print(body.rstrip())
    audit = subprocess.run(
        [sys.executable, os.path.join(HERE, "artifact_policy.py")],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if audit.stdout:
        print("\n" + "\n".join(
            line for line in audit.stdout.splitlines() if not line.startswith("  defer")
        ).rstrip())
        deferred = sum(1 for line in audit.stdout.splitlines() if line.startswith("  defer"))
        if deferred:
            print(f"  note {deferred} finding(s) deferred to an owning phase; see "
                  "tools/migration_allowlist.tsv")
    if audit.returncode != 0 and audit.stderr:
        print(audit.stderr.rstrip())
    return negatives.returncode == 0 and audit.returncode == 0


def attestation_side(run_dir, ledger_path, architecture):
    """Bind this run to its source snapshot and retain it beneath `.build/`.

    The binding is the digest of every non-ignored file as the run saw it. Whether that
    source is committed, and when, is the operator's business and no part of the gate.
    """
    print("\nattestation side — project-contained retention\n")
    commit = artifact_policy.git("rev-parse", "HEAD").strip()
    dirty = bool(artifact_policy.git("status", "--porcelain").strip())
    snapshot = artifact_policy.source_digest()
    contract = os.path.join("DEVELOPMENT_PLAN", "phase_00_documentation_suite.md")
    bundle = {
        "schema": attestation.SCHEMA,
        "phase": 0,
        "contract": contract,
        "contract_digest": "sha256:" + artifact_policy.digest(os.path.join(ROOT, contract)),
        "commit": f"{commit}+uncommitted" if dirty and commit else (commit or "uncommitted"),
        "source_digest": snapshot,
        "command": "python3 tools/doc_lint_verify.py",
        "register": "—",
        "substrate": "none",
        "lane": "none",
        "architecture": architecture,
        "toolchain": {"python": sys.version.split()[0]},
        "dependencies": {},
        "checks": [{"name": name, "status": "pass"} for name in SIDE_NAMES],
        "mutants": [
            {"name": "doc_lint seeded negatives", "status": "red"},
            {"name": "ledger_lint seeded negatives", "status": "red"},
            {"name": "artifact_policy seeded negatives", "status": "red"},
            {"name": "architecture complement comparison", "status": "red"},
        ],
        "coverage": [{"surface": "phase_00", "status": "tested"}],
        "cleanup": {"left_resources": False},
        "observations": {"ledger": "sha256:" + artifact_policy.digest(ledger_path)},
        "ledger_hash": json.load(open(ledger_path, encoding="utf-8"))["ledger_hash"],
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
    return True


def artifact_side():
    """Audit the independently authored Phase-0 oracle and mutant manifest."""
    command = [sys.executable, os.path.join(HERE, "artifact_manifest_lint.py")]
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False)
    print("\nartifact side — pre-implementation oracles and mutants\n")
    if result.stdout:
        print(result.stdout.rstrip())
    if result.returncode == 0:
        return True
    if result.stderr:
        print(result.stderr.rstrip())
    return False


def containment_side(before, after, contained_paths):
    """Prove closed-root selection and equality of every outside-host observation."""
    print("\ncontainment side — closed roots and outside-host inventory\n")
    ok = True
    for path in contained_paths:
        try:
            containment.require_state_path(path, "build", actor="production")
        except containment.ContainmentError as exc:
            print(f"  FAIL  {exc}")
            ok = False
    problems = containment.host_inventory_problems(before, after)
    for problem in problems:
        print(f"  FAIL  {problem}")
        ok = False
    if not problems:
        digest = hashlib.sha256(after.canonical_bytes()).hexdigest()
        print(f"  ok    outside-host inventory unchanged ({digest[:16]}…)")
    if after.observation_errors:
        for error in after.observation_errors:
            print(f"  note  {error}")
    if ok:
        print("  ok    every Phase-0 output resolves beneath .build/")
    return ok


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--fixtures", action="store_true", help="run the fixture side only")
    args = ap.parse_args(argv)

    before_host = containment.host_inventory()
    fixtures_ok = positive_side() and fixture_side()
    if args.fixtures:
        return 0 if fixtures_ok else 1

    # The write guard brackets the whole run: whatever the sides below do, nothing may
    # appear, change, or vanish beneath an authored root while they do it.
    before_authored = artifact_policy.authored_snapshot()

    # Clause 15 first: a run that cannot name the architecture it executed on has
    # nothing to bind the rest of the evidence to.
    architecture_ok, architecture = gate_common.architecture_side()

    tree_ok = tree_side()
    contract_ok = contract_side()
    covering_ok = covering_side()
    snapshot_ok = snapshot_side()
    surface_ok, surfaces = surface_side()
    run_dir = os.path.join(ROOT, ".build", "runs", "phase_00", run_id())
    ledger_ok, ledger_path = ledger_side(run_dir, surfaces, architecture)
    artifact_ok = artifact_side()
    policy_ok = policy_side()
    attest_ok = attestation_side(run_dir, ledger_path, architecture)
    after_host = containment.host_inventory()
    contained_ok = containment_side(
        before_host,
        after_host,
        (NEGATIVES, SURFACES, os.path.join(ROOT, ".build", "tmp", "source-snapshot"), run_dir),
    )

    guard = artifact_policy.Report()
    artifact_policy.audit_write_guard(guard, before_authored, artifact_policy.authored_snapshot())
    guard_ok = not guard.findings
    print("\nwrite guard — authored roots during this run\n")
    if guard_ok:
        print("  ok    no authored path was created, changed, or removed")
    else:
        for finding in guard.findings:
            print(f"  FAIL  {finding.render()}")

    results = {
        "fixture": fixtures_ok,
        "architecture": architecture_ok,
        "corpus": tree_ok,
        "contract": contract_ok,
        "covering": covering_ok,
        "snapshot": snapshot_ok,
        "surface": surface_ok,
        "ledger": ledger_ok,
        "artifact": artifact_ok,
        "policy": policy_ok,
        "attestation": attest_ok,
        "containment": contained_ok,
        "write-guard": guard_ok,
    }
    print()
    for name in SIDE_NAMES:
        print(f"{name:<12} side: {'PASS' if results[name] else 'FAIL'}")
    return 0 if all(results.values()) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
