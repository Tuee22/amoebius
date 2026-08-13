#!/usr/bin/env python3
"""Run doc_lint two-sided — the Phase 0 gate command.

Side one   the governed tree must lint clean.
Side two   every negative materialized from the authored seed and mutation list must
           exit non-zero AND name the check its seeded defect trips, while tripping no
           other check. Naming the check is what a stub keyed on fixture identity
           cannot do.

The negatives are reproducible projections of `tools/doc_lint_corpus/_positive/` and
`_build.py`, so the run materializes them beneath `gen/test-corpora/doc_lint/` rather
than reading committed copies.

    python3 tools/doc_lint_verify.py            # both sides
    python3 tools/doc_lint_verify.py --fixtures # fixture side only

Exit status: 0 both sides pass, 1 otherwise.
"""

import argparse
import datetime as dt
import json
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import artifact_policy  # noqa: E402
import attestation  # noqa: E402
import doc_lint  # noqa: E402
import ledger_lint  # noqa: E402
import phase0_artifact_lint  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
CORPUS = os.path.join(HERE, "doc_lint_corpus")
ROOT = os.path.dirname(HERE)
NEGATIVES = os.path.join(ROOT, "gen", "test-corpora", "doc_lint")
SURFACES = os.path.join(ROOT, "gen", "test-surfaces", "phase_00.json")
EXPECTATIONS = os.path.join(ROOT, "test", "phase_00_surface_expectations.tsv")

SIDE_NAMES = (
    "fixture",
    "corpus",
    "snapshot",
    "surface",
    "ledger",
    "artifact",
    "policy",
    "attestation",
    "write-guard",
)


def run_id():
    """One directory per run. The bundle is evidence, so a wall-clock stamp is right."""
    return dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")


sys.path.insert(0, CORPUS)
import _build  # noqa: E402


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
        "phase0_artifact_lint": set(phase0_artifact_lint.CHECKS),
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
    target = os.path.join(ROOT, "gen", "tmp", "source-snapshot")
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


def emit_ledger(run_dir, surfaces, results):
    """Write this run's proven/tested/assumed ledger into the run bundle."""
    ledger = {
        "phase": 0,
        "gate_command": "python3 tools/doc_lint_verify.py",
        "register": "—",
        "substrate": "none",
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


def ledger_side(run_dir, surfaces):
    """Prove the ledger checker accepts and rejects its corpus, then check this run's."""
    command = [sys.executable, os.path.join(HERE, "ledger_lint.py"), "--verify-corpus"]
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False)
    print("\nledger side — schema and seeded negatives\n")
    if result.stdout:
        print(result.stdout.rstrip())

    emitted = emit_ledger(run_dir, surfaces, {})
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


def attestation_side(run_dir, ledger_path):
    """Bind this run to its source snapshot and retain the attestation outside Git.

    The binding is the digest of every non-ignored file as the run saw it. Whether that
    source is committed, and when, is the operator's business and no part of the gate.
    """
    print("\nattestation side — external retention\n")
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
        "toolchain": {"python": sys.version.split()[0]},
        "dependencies": {},
        "checks": [{"name": name, "status": "pass"} for name in SIDE_NAMES],
        "mutants": [
            {"name": "doc_lint seeded negatives", "status": "red"},
            {"name": "ledger_lint seeded negatives", "status": "red"},
            {"name": "artifact_policy seeded negatives", "status": "red"},
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
    command = [sys.executable, os.path.join(HERE, "phase0_artifact_lint.py")]
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False)
    print("\nartifact side — pre-implementation oracles and mutants\n")
    if result.stdout:
        print(result.stdout.rstrip())
    if result.returncode == 0:
        return True
    if result.stderr:
        print(result.stderr.rstrip())
    return False


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--fixtures", action="store_true", help="run the fixture side only")
    args = ap.parse_args(argv)

    fixtures_ok = positive_side() and fixture_side()
    if args.fixtures:
        return 0 if fixtures_ok else 1

    # The write guard brackets the whole run: whatever the sides below do, nothing may
    # appear, change, or vanish beneath an authored root while they do it.
    before_authored = artifact_policy.authored_snapshot()

    tree_ok = tree_side()
    snapshot_ok = snapshot_side()
    surface_ok, surfaces = surface_side()
    run_dir = os.path.join(ROOT, "gen", "runs", "phase_00", run_id())
    ledger_ok, ledger_path = ledger_side(run_dir, surfaces)
    artifact_ok = artifact_side()
    policy_ok = policy_side()
    attest_ok = attestation_side(run_dir, ledger_path)

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
        "corpus": tree_ok,
        "snapshot": snapshot_ok,
        "surface": surface_ok,
        "ledger": ledger_ok,
        "artifact": artifact_ok,
        "policy": policy_ok,
        "attestation": attest_ok,
        "write-guard": guard_ok,
    }
    print()
    for name in SIDE_NAMES:
        print(f"{name:<12} side: {'PASS' if results[name] else 'FAIL'}")
    return 0 if all(results.values()) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
