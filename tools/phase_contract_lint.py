#!/usr/bin/env python3
"""Check what a phase contract *promises*, which `doc_lint` does not read.

`doc_lint` checks a phase document thoroughly as a document — its links, anchors, shape,
vocabulary, budgets, and cross-file reconciliation. What it does not check is the contract
half: whether the section skeleton is the one section D fixes, whether the six Phase
Summary fields are present, whether a mutant the gate names exists, and whether the
promises the contract makes match the gate script that will be held to them.

The cost of that gap was measured before this file existed: `**Phase scope:**` was missing
from sixty-four of seventy-five carried-forward contracts and `**Depends on**` from
fifty-seven, and nothing reported either. `**Register:**` had no check at all. A field that
is normative in the rulebook and unread by every tool is a field that does not exist, and
four re-baselines each left one behind.

Four checks, each closing one of those gaps:

    d1  the section skeleton is section D's set, in section D's order
    d2  the six Phase Summary fields are present, and Register names a real register
    d3  every mutant capability and id the gate names exists in the mutant registry
    d4  the contract's command, register, substrate and lane equal its gate script's,
        and every oracle path it names resolves

d4 reports a contract with no gate script rather than passing it silently: sixty-three of
ninety-six contracts have no executing code behind them, and that is a fact about the plan
worth printing rather than hiding.

This file is itself condemned by the generative re-baseline: `tools/**` is emitted from the
declarations it checks, and Phase 48 owns its closure. Until then it is authored, like the
tools beside it.
"""

from __future__ import annotations

import argparse
import csv
import shutil
import tempfile
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import mutant_registry  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
PLAN = ROOT / "DEVELOPMENT_PLAN"
SELF_REFERENTIAL_INVENTORY = ROOT / "test/oracle/self_referential_gates/gate_inventory.tsv"

# Scratch state stays inside the checkout. The host default temporary directory is
# outside it, and a run that writes there escapes the containment contract the
# Phase-0 gate decides (`state_escapes_checkout`).
TEMP_ROOT = ROOT / ".build" / "tmp" / "phase-contract-lint"

# The registry the Phase-0 surface join enumerates. A check that is not here is invisible
# to that join, which is the same failure this file exists to stop.
CHECKS = {
    "d1": "contract shape: the section-D skeleton, in section-D order",
    "d2": "contract fields: the six required Phase Summary fields, and a real register",
    "d3": "contract mutants: every capability and id names a registry row that exists",
    "d4": "contract promises: the command, register, substrate and lane its gate declares",
    "d5": "contract scope: Phase scope says something the Purpose blockquote does not",
    "d6": "contract clause 13: every contract discharges section M clause 13 or marks it not applicable",
    "d7": "contract status: no completion marker survives inside a phase the tracker has reopened",
    "d8": "plan arithmetic: the band, register and substrate claims the plan states about itself",
}

# Section D's skeleton. `Contents` is conditional on section P.1 and the two gate-detail
# sections are optional, so the required set is the rest; the ORDER below is complete and
# is what d1 compares a document's real heading sequence against.
REQUIRED = ("Phase Status", "Phase Summary", "Doctrine adopted", "Sprints",
            "Documentation Requirements", "Related Documents")
ORDER = ("Contents", "Phase Status", "Phase Summary", "Gate integrity",
         "Resource provision", "Doctrine adopted", "Sprints",
         "Documentation Requirements", "Related Documents")
FIELDS = ("Phase scope", "Substrate", "Lane", "Register", "Depends on", "Gate")
REGISTERS = {"1", "2", "3", "1/2", "—"}

FIELD_RE = re.compile(r"^\*\*(%s):\*\*" % "|".join(re.escape(f) for f in FIELDS), re.M)
HEAD_RE = re.compile(r"^## (.+?)\s*$", re.M)
SPRINT_RE = re.compile(r"^## Sprint \d+\.\d+:", re.M)
REGISTER_RE = re.compile(r"^\*\*Register:\*\*\s*(.+?)(?=\n\*\*|\n##|\n\n)", re.M | re.S)
SUBSTRATE_RE = re.compile(r"^\*\*Substrate:\*\*\s*(.+?)(?=\n\*\*|\n##|\n\n)", re.M | re.S)
LANE_RE = re.compile(r"^\*\*Lane:\*\*\s*(.+?)(?=\n\*\*|\n##|\n\n)", re.M | re.S)
GATE_RE = re.compile(r"^\*\*Gate:\*\*\s*(.+?)(?=\n\n|\n##)", re.M | re.S)
COMMAND_RE = re.compile(r"`\s*((?:cabal|python3?|pytest|make|kubectl|ghc|dhall|npm|spago|"
                        r"bash|sh|helm|terraform|docker|go|cargo)\b[^`\n]*)`")
ORACLE_RE = re.compile(r"`(test/oracle/[A-Za-z0-9_./-]+)`")
MUTANT_DIR_RE = re.compile(r"`?test/mutant/([a-z0-9_]+)/([A-Za-z0-9_.-]*)`?")


def mutant_refs(text: str) -> set[tuple[str, str]]:
    """(capability, body) for every mutant path, with set notation left whole.

    `emitTLA-mut-0{1..4}` is one set of four ids and `phase_{16..23}_*` is a glob. The body
    group stops at the brace either way, so the match is filtered on the character that
    follows it rather than by the pattern — a checker that reported the truncation as a
    missing path would teach its readers to skip its output.
    """
    out: set[tuple[str, str]] = set()
    for m in MUTANT_DIR_RE.finditer(text):
        if text[m.end():m.end() + 1] in "{*":
            continue
        cap, body = m.group(1), m.group(2)
        if any(ch in cap + body for ch in "{}*") or ".." in body:
            continue
        out.add((cap, body))
    return out


def head(value: str) -> str:
    """The declaration head: the part before an em dash or a parenthetical aside.

    A value that *is* an em dash is its own head — Phase 0's register is `—`, meaning it
    reaches no register, and splitting that on the dash would leave nothing to compare.
    """
    first = re.split(r"[—(]", value, 1)[0].strip().strip("`").strip()
    return first if first else value.strip().split()[0].strip("`")


def contracts() -> list[Path]:
    return sorted(PLAN.glob("phase_*.md"))


def gate_scripts() -> dict[str, dict[str, str]]:
    """Each gate script's promises, keyed by the contract path it declares."""
    out: dict[str, dict[str, str]] = {}
    for path in sorted((ROOT / "tools").glob("*.py")):
        text = path.read_text(encoding="utf-8")
        # A gate names its contract as a module constant or as a joined path; Phase 0's
        # verifier does the latter, and a checker that only knew the first would have
        # reported the one phase that is Active as having no gate at all.
        m = re.search(r'CONTRACT\s*=\s*"(DEVELOPMENT_PLAN/phase_\d\d_[a-z0-9_]+\.md)"', text)
        if not m and (path.name.endswith(("_gate.py", "_verify.py")) or "PhaseGate(" in text):
            m = re.search(r'"DEVELOPMENT_PLAN",\s*"(phase_\d\d_[a-z0-9_]+\.md)"', text)
            if m:
                m = re.match(r"(.*)", "DEVELOPMENT_PLAN/" + m.group(1))
        if not m:
            continue
        got = {"script": path.name}
        for field, pattern in (("command", r'GATE_COMMAND\s*=\s*"([^"]+)"'),
                               ("register", r'register="([^"]*)"'),
                               ("substrate", r'substrate="([^"]*)"'),
                               ("lane", r'lane="([^"]*)"')):
            hit = re.search(pattern, text)
            if hit:
                got[field] = hit.group(1)
        out[m.group(1)] = got
    return out


def retained_gate_mechanisms() -> dict[str, str]:
    """Contract path -> independent mechanism retained by the Phase-50 consumer switch."""
    if not SELF_REFERENTIAL_INVENTORY.is_file():
        return {}
    with SELF_REFERENTIAL_INVENTORY.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    return {
        row["contract"]: row["authored_command"]
        for row in rows
        if row.get("authored_command") not in {None, "—"}
    }


def check(root: Path) -> list[tuple[str, str, str]]:
    """(check id, contract, message) for every violation."""
    problems: list[tuple[str, str, str]] = []
    unbacked: list[str] = []
    try:
        registry = mutant_registry.rows()
    except mutant_registry.RegistryError as error:
        return [("d3", "test/mutant/registry.tsv", str(error))]
    known_caps = {r["capability"] for r in registry}
    known_ids = {(r["capability"], r["mutant"]) for r in registry}
    scripts = gate_scripts()
    retained = retained_gate_mechanisms()
    status = tracker_status(root)

    for path in contracts():
        rel = f"DEVELOPMENT_PLAN/{path.name}"
        text = path.read_text(encoding="utf-8")
        heads = [h for h in HEAD_RE.findall(text) if not h.startswith("Sprint ")]

        # d1 — the skeleton is section D's set, in section D's order.
        for name in REQUIRED:
            if name not in heads:
                problems.append(("d1", rel, f"no '## {name}' section"))
        seen = [h.split(" —")[0].strip() for h in heads]
        rank = {name: i for i, name in enumerate(ORDER)}
        ordered = [rank[s] for s in seen if s in rank]
        if ordered != sorted(ordered):
            problems.append(("d1", rel, f"sections out of section-D order: {seen}"))
        if not SPRINT_RE.search(text):
            problems.append(("d1", rel, "no '## Sprint N.M:' heading"))

        # d2 — the six Phase Summary fields, and a real register.
        present = set(FIELD_RE.findall(text))
        for field in FIELDS:
            if field not in present:
                problems.append(("d2", rel, f"no '**{field}:**' field"))
        rm = REGISTER_RE.search(text)
        if rm and head(rm.group(1)) not in REGISTERS:
            problems.append(("d2", rel, f"register {head(rm.group(1))!r} is not one of {sorted(REGISTERS)}"))

        # d3 — a named mutant capability, body, and id must all be real.
        refs = mutant_refs(text)
        seen_caps = {c for c, _ in refs}
        for cap in sorted(seen_caps - known_caps):
            problems.append(("d3", rel, f"names mutant capability {cap!r}, which the registry does not carry"))
        for cap, body in sorted(refs):
            if not body:
                continue
            claimed = f"test/mutant/{cap}/{body}"
            stem = body.rsplit(".", 1)[0]
            # A contract may name the mutant by id rather than by filename — `…/omit-redis`
            # for `omit-redis.mutant`. That is a reference to the registry, not a broken
            # path, so it resolves when the registry carries the id.
            if (cap, stem) in known_ids:
                continue
            if (root / claimed).exists():
                continue
            if cap in known_caps:
                problems.append(("d3", rel, f"names mutant {cap}/{stem}, which the registry does not carry"))
            else:
                problems.append(("d3", rel, f"names {claimed}, whose capability the registry does not carry"))

        # d4 — the contract's promises equal its gate script's.
        script = scripts.get(rel)
        if script is None:
            # An unbuilt phase has no gate script, and that is where most of the plan is.
            # Counting it as a violation would leave this check permanently red, which is
            # how a checker teaches its readers to stop reading it. It is counted instead.
            unbacked.append(rel)
        else:
            gate = GATE_RE.search(text)
            commands = COMMAND_RE.findall(gate.group(1) if gate else "")
            want = script.get("command")
            named = [c.strip() for c in commands]
            wrapper = f"python3 tools/run_phase_gate.py {int(path.name[6:8]):02d}"
            if any(command.startswith("python3 tools/run_phase_gate.py ") for command in named):
                if wrapper not in named:
                    problems.append(("d4", rel, f"self-referential runner does not name phase {path.name[6:8]}"))
                mechanism = retained.get(rel)
                if mechanism is not None:
                    named.append(mechanism)
            if want and want not in named:
                problems.append(("d4", rel, f"gate names {commands or 'no command'}; {script['script']} runs {want!r}"))
            for field, pattern in (("register", REGISTER_RE), ("substrate", SUBSTRATE_RE), ("lane", LANE_RE)):
                mm = pattern.search(text)
                promised, declared = head(mm.group(1)) if mm else None, script.get(field)
                if declared is not None and promised is not None and promised != declared:
                    problems.append(("d4", rel, f"{field} {promised!r} but {script['script']} declares {declared!r}"))
        # An oracle path is only a claim about the tree once something runs against it.
        # Before that it is a commitment the phase makes about what it will author, so it
        # is checked for the contracts that have a gate and counted for the rest.
        if script is not None:
            for oracle in sorted(set(ORACLE_RE.findall(text))):
                if not (root / oracle).exists():
                    problems.append(("d4", rel, f"names oracle {oracle}, which does not exist"))
        ordinal = int(re.search(r"phase_(\d+)_", rel).group(1))
        reopened = "✅" not in status.get(ordinal, "")
        problems.extend(check_authored(root, rel, text, reopened))
    problems.extend(check_plan_arithmetic(root))
    if unbacked:
        print(f"phase_contract_lint: {len(unbacked)} of {len(contracts())} contracts have no gate script yet")
    return problems


PURPOSE_RE = re.compile(r"^> \*\*Purpose\*\*:(.*?)(?=^> \*\*|^\s*$)", re.M | re.S)
SCOPE_RE = re.compile(r"^\*\*Phase scope:\*\*(.*?)(?=^\*\*[A-Z]|^\s*$)", re.M | re.S)
CLAUSE13_RE = re.compile(r"^- \*\*Extension conformance \(§M\.13\)\.\*\*", re.M)
DONE_RE = re.compile(r"✅|\*\*Status\*\*:\s*Done\b")
TRACKER_ROW_RE = re.compile(r"^\| (\d{1,2}) \|(?:[^|]*\|){4}([^|]*)\|", re.M)


def tracker_status(root: Path) -> dict[int, str]:
    """Phase ordinal -> the status cell of its Phase Overview row.

    Read from the tracker rather than from the phase document, because the phase document
    is the thing being judged. It also cannot be read from the document's own first
    `**Status**:` line, which is the link-graph metadata block's `Authoritative source` --
    that mistake made every phase look reopened, so no contract could ever carry a sealed
    sprint and the check silently asserted the opposite of what it says.
    """
    path = root / "DEVELOPMENT_PLAN" / "README.md"
    if not path.exists():
        return {}
    return {int(m.group(1)): m.group(2).strip()
            for m in TRACKER_ROW_RE.finditer(path.read_text(encoding="utf-8"))}


def words(text: str) -> list[str]:
    return re.findall(r"[a-z0-9`]+", text.lower())


def check_authored(root: Path, rel: str, text: str, reopened: bool) -> list[tuple[str, str, str]]:
    """d5-d7: the three things a contract can say that no other check reads."""
    out = []

    # d5 -- a Phase scope that repeats the Purpose blockquote carries no information the
    # reader did not already have one screen earlier. It is measured rather than judged:
    # a scope whose words are a subset of the purpose's has added nothing.
    pm, sm = PURPOSE_RE.search(text), SCOPE_RE.search(text)
    if pm and sm:
        purpose, scope = set(words(pm.group(1))), words(sm.group(1))
        if scope:
            fresh = [w for w in scope if w not in purpose]
            if len(fresh) / len(scope) < 0.15:
                out.append(("d5", rel, "Phase scope restates the Purpose blockquote"))

    # d6 -- clause 13 is owed by every contract, as a discharge or as "Not applicable".
    # Silence is the one answer the clause does not admit, and 67 contracts were silent.
    if not CLAUSE13_RE.search(text):
        out.append(("d6", rel, "no §M.13 bullet: a contract discharges the clause or marks it not applicable"))

    # d7 -- a sprint may not claim completion inside a phase the tracker has reopened.
    # doc_lint's `e` compares only the phase-level marker, so a stale sprint heading
    # passes lint while contradicting section N.
    if reopened:
        for m in DONE_RE.finditer(text):
            line = text[:m.start()].count("\n") + 1
            snippet = text.split("\n")[line - 1].strip()[:60]
            if snippet.startswith(">") or "✅ Done row" in snippet:
                continue                      # a rule about the marker, not a use of it
            out.append(("d7", rel, f"line {line}: completion marker in a reopened phase: {snippet!r}"))
    return out


def check_plan_arithmetic(root: Path) -> list[tuple[str, str, str]]:
    """d8: every quantified claim the plan makes about its own sequence.

    Each is re-derived from the contracts, which are the only source of truth for a
    phase's band, register and substrate. Before this check nothing read these claims,
    and the register cut, the band count and three whole tables had drifted apart.
    """
    out = []
    facts = {}
    for path in contracts():
        m = re.match(r"phase_(\d\d)_", path.name)
        if not m:
            continue
        text = path.read_text(encoding="utf-8")
        def field(name: str) -> str:
            mm = re.search(r"^\*\*%s:\*\*(.*)$" % name, text, re.M)
            return head(mm.group(1)) if mm else ""
        title = re.search(r"^# Phase \d+: (.*)$", text, re.M)
        facts[int(m.group(1))] = dict(
            title=title.group(1).strip() if title else "",
            substrate=field("Substrate"),
            lane=field("Lane"),
            register=re.split(r"\s+\(", field("Register"))[0].strip() or "—",
        )

    pure = sorted(n for n, f in facts.items() if f["substrate"] == "none")
    live = sorted(n for n, f in facts.items() if f["register"] == "3")
    cut = (max(pure), min(live)) if pure and live else (0, 0)
    if max(pure) + 1 != min(live):
        out.append(("d8", "DEVELOPMENT_PLAN/", "substrate `none` and Register 3 do not meet at one boundary"))

    model = root / "DEVELOPMENT_PLAN" / "development_plan_phase_model.md"
    if model.exists():
        text = model.read_text(encoding="utf-8")
        want = "%d/%d" % cut
        for m in re.finditer(r"register cut[^.]*?exact at (\d+/\d+)", text):
            if m.group(1) != want:
                out.append(("d8", "DEVELOPMENT_PLAN/development_plan_phase_model.md",
                            f"states the register cut at {m.group(1)}; the contracts put it at {want}"))
        for m in re.finditer(r"at or below (\d+)", text):
            if int(m.group(1)) != max(pure):
                out.append(("d8", "DEVELOPMENT_PLAN/development_plan_phase_model.md",
                            f"bounds the pure band at {m.group(1)}; the contracts put it at {max(pure)}"))
        # The band count is a word, and the enumeration beside it is a list of bold names.
        bm = re.search(r"names \*\*(\w+) bands\*\*(.*?)(?=\n\n)", text, re.S)
        if bm:
            named = {"eight": 8, "nine": 9, "ten": 10, "seven": 7}
            listed = len(re.findall(r"\*\*[A-Z][^*]+\*\* \(phases", bm.group(2)))
            if named.get(bm.group(1)) not in (None, listed):
                out.append(("d8", "DEVELOPMENT_PLAN/development_plan_phase_model.md",
                            f"says {bm.group(1)} bands and enumerates {listed}"))

    # Every table row that keys a phase must carry that phase's own title, substrate and lane.
    for rel in ("DEVELOPMENT_PLAN/README.md", "DEVELOPMENT_PLAN/substrates.md"):
        path = root / rel
        if not path.exists():
            continue
        for line in path.read_text(encoding="utf-8").split("\n"):
            m = re.match(r"^\| (\d{1,2}) \|", line)
            if not m:
                continue
            n = int(m.group(1))
            if n not in facts:
                continue
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) not in (5, 7):
                continue
            f = facts[n]
            got = (cells[1], cells[2].strip("`"), cells[3].strip("`"))
            want = (f["title"], f["substrate"], f["lane"])
            if got != want:
                out.append(("d8", rel, f"row {n} carries {got}; the contract declares {want}"))
    return out


def self_test() -> int:
    """Each authored check names its own seeded defect, and nothing else.

    A check nobody has ever seen redden is a check nobody knows the shape of. These
    mutations are the minimal single-defect kind the gate-integrity discipline asks
    for: a passing contract with exactly one thing removed or added, and the check
    that must react is named beside it. d1-d4 and d8 read the tree rather than one
    document, so they are exercised by the gate itself and are not seeded here --
    which is stated rather than left to be inferred from their absence.
    """
    # The base must be a contract that carries no completion marker of its own, or the
    # d7 seed cannot discriminate: the marker it adds would already be there.
    base = next(text for text in (path.read_text(encoding="utf-8") for path in contracts())
                if not DONE_RE.search(text))
    cases = [
        # d5 -- a scope that is the purpose blockquote again.
        ("d5", re.sub(r"^\*\*Phase scope:\*\*.*?(?=\n\*\*[A-Z])",
                      "**Phase scope:** one cohesive claim — " +
                      (PURPOSE_RE.search(base).group(1).replace("\n> ", " ").strip()
                       if PURPOSE_RE.search(base) else "restated"),
                      base, count=1, flags=re.M | re.S)),
        # d6 -- clause 13 left silent rather than discharged or excused.
        ("d6", CLAUSE13_RE.sub("- **Something else.**", base, count=1)),
        # d7 -- a sprint claiming completion inside a reopened phase.
        ("d7", base.replace("## Sprints", "## Sprints\n\nThe whole sprint (✅ Done).", 1)),
    ]
    failures = []
    for want, mutated in cases:
        got = {cid for cid, _, _ in check_authored(ROOT, "seeded", mutated, True)}
        clean = {cid for cid, _, _ in check_authored(ROOT, "seeded", base, True)}
        if want not in got - clean:
            failures.append(f"{want}: seeded defect did not redden it (saw {sorted(got) or 'nothing'})")

    # The control for d7. The same completion marker inside a phase the tracker has
    # *sealed* is not a defect, and a check that fires either way reads nothing.
    sealed = base.replace("## Sprints", "## Sprints\n\nThe whole sprint (✅ Done).", 1)
    if "d7" in {cid for cid, _, _ in check_authored(ROOT, "seeded", sealed, False)}:
        failures.append("d7: a completion marker reddened a phase the tracker has sealed")

    # d8 reads a tree rather than one document, so it is seeded against a scratch copy of
    # the plan. Both mutations are the exact defects the 2026-08-20 review found: a cut
    # stated one phase early, and a table row disagreeing with the contract it keys.
    TEMP_ROOT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="plan-", dir=TEMP_ROOT) as td:
        scratch = Path(td) / "repo" / "DEVELOPMENT_PLAN"
        scratch.mkdir(parents=True)
        for path in (ROOT / "DEVELOPMENT_PLAN").glob("*.md"):
            shutil.copy(path, scratch / path.name)
        tree = scratch.parent
        if check_plan_arithmetic(tree):
            failures.append("d8: the unmutated copy is not clean, so nothing below discriminates")
        model = scratch / "development_plan_phase_model.md"
        text = model.read_text(encoding="utf-8")
        cut = re.search(r"exact at (\d+)/(\d+)", text)
        if cut:
            wrong = f"exact at {int(cut.group(1)) - 2}/{int(cut.group(2)) - 2}"
            model.write_text(text.replace(cut.group(0), wrong, 1), encoding="utf-8")
            if not check_plan_arithmetic(tree):
                failures.append("d8: a register cut two phases early did not redden it")
            model.write_text(text, encoding="utf-8")
        readme = scratch / "README.md"
        rtext = readme.read_text(encoding="utf-8")
        # The phase-overview row, which is the seven-celled one d8 joins to a contract --
        # not the implementation-audit row, which keys a phase but carries no substrate.
        row = next((line for line in rtext.split("\n")
                    if re.match(r"^\| \d{1,2} \|", line)
                    and len([c for c in line.strip().strip("|").split("|")]) == 7), None)
        if row:
            cells = [c.strip() for c in row.strip().strip("|").split("|")]
            cells[2] = "wrong-substrate"
            readme.write_text(rtext.replace(row, "| " + " | ".join(cells) + " |", 1), encoding="utf-8")
            if not check_plan_arithmetic(tree):
                failures.append("d8: a table row disagreeing with its contract did not redden it")
            readme.write_text(rtext, encoding="utf-8")
    for line in failures:
        print("self-test  " + line, file=sys.stderr)
    if failures:
        print(f"phase_contract_lint: SELF-TEST FAIL ({len(failures)})", file=sys.stderr)
        return 1
    print(f"phase_contract_lint: self-test PASS ({len(cases) + 2} seeded negatives; "
          "d1-d4 read the tree and are exercised by the gate)")
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--only", help="comma-separated check ids")
    parser.add_argument("--summary", action="store_true")
    parser.add_argument("--self-test", action="store_true",
                        help="assert each authored check reddens on a seeded defect")
    args = parser.parse_args(argv)
    if args.self_test:
        return self_test()
    problems = check(args.root.resolve())
    if args.only:
        wanted = {x.strip() for x in args.only.split(",")}
        problems = [p for p in problems if p[0] in wanted]
    if args.summary:
        counts: dict[str, int] = {}
        for cid, _, _ in problems:
            counts[cid] = counts.get(cid, 0) + 1
        for cid in sorted(counts):
            print(f"  {counts[cid]:4d}  {cid}")
    else:
        for cid, rel, message in problems:
            print(f"{cid}  {rel}: {message}", file=sys.stderr)
    if problems:
        print(f"phase_contract_lint: FAIL ({len(problems)} violation(s))", file=sys.stderr)
        return 1
    print(f"phase_contract_lint: PASS ({len(contracts())} contracts)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
