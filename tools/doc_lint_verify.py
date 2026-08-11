#!/usr/bin/env python3
"""Run doc_lint two-sided — the Phase 0 gate command.

Side one   the governed tree must lint clean.
Side two   every fixture in tools/doc_lint_corpus/ must exit non-zero AND name the
           check its seeded defect trips, while tripping no other check. Naming the
           check is what a stub keyed on fixture identity cannot do.

    python3 tools/doc_lint_verify.py            # both sides
    python3 tools/doc_lint_verify.py --fixtures # fixture side only

Exit status: 0 both sides pass, 1 otherwise.
"""

import argparse
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import doc_lint  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
CORPUS = os.path.join(HERE, "doc_lint_corpus")
ROOT = os.path.dirname(HERE)


sys.path.insert(0, CORPUS)
import _build  # noqa: E402


def expected(fixture_name):
    """(check the fixture must trip, checks the same defect legitimately co-implies)."""
    return _build.EXPECTED[fixture_name]


def fixture_side():
    ok = True
    names = sorted(
        d for d in os.listdir(CORPUS)
        if os.path.isdir(os.path.join(CORPUS, d)) and not d.startswith("_")
    )
    if not names:
        print("no fixtures found", file=sys.stderr)
        return False

    print(f"fixture side — {len(names)} seeded negatives\n")
    for name in names:
        want, co_implied = expected(name)
        # An advisory check does not fail the gate, so its fixture is proven by the
        # check's own run. The seeded defect must still be the ONLY one it trips.
        only = {want} if want in doc_lint.ADVISORY else None
        code, violations = doc_lint.run(os.path.join(CORPUS, name), only=only)
        hit = sorted({v.check for v in violations})
        allowed = {want} | co_implied
        if only:
            _, all_v = doc_lint.run(os.path.join(CORPUS, name))
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


def ledger_side():
    """Prove the independent ledger checker accepts and rejects its own corpus."""
    command = [sys.executable, os.path.join(HERE, "ledger_lint.py"), "--verify-corpus"]
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False)
    phase_zero = subprocess.run(
        [
            sys.executable,
            os.path.join(HERE, "ledger_lint.py"),
            os.path.join(ROOT, "test", "golden", "phase_00_ledger.json"),
            "--enumeration",
            os.path.join(ROOT, "test", "enumeration", "phase_00_surfaces.txt"),
        ],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    print("\nledger side — schema and seeded negatives\n")
    if result.stdout:
        print(result.stdout.rstrip())
    if phase_zero.returncode == 0:
        print("  ok   phase_00_ledger.json         schema, tracker, surfaces, hash")
    if result.returncode == 0 and phase_zero.returncode == 0:
        return True
    if result.stderr:
        print(result.stderr.rstrip())
    if phase_zero.stderr:
        print(phase_zero.stderr.rstrip())
    return False


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

    tree_ok = tree_side()
    ledger_ok = ledger_side()
    artifact_ok = artifact_side()
    print()
    print(f"fixture side: {'PASS' if fixtures_ok else 'FAIL'}")
    print(f"corpus  side: {'PASS' if tree_ok else 'FAIL'}")
    print(f"ledger  side: {'PASS' if ledger_ok else 'FAIL'}")
    print(f"artifact side: {'PASS' if artifact_ok else 'FAIL'}")
    return 0 if (fixtures_ok and tree_ok and ledger_ok and artifact_ok) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
