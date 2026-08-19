#!/usr/bin/env python3
"""Validate the Phase-7 catalog ownership oracle against its authored tags."""

from __future__ import annotations

import argparse
import csv
import re
import sys
from collections import defaultdict
from pathlib import Path


ENTRY_RE = re.compile(r"^### (3\.\d+) .+$", re.MULTILINE)
OWNER_RE = re.compile(r"^\*\*Delivery-owner:\*\*\s*`([^`]+)`\s*$", re.MULTILINE)
FAMILY_RE = re.compile(r"^\*\*Case-family:\*\*\s*`([^`]+)`\s*$", re.MULTILINE)
LOCUS_RE = re.compile(r"`(dhall-typecheck|gadt-decode|extension-astcheck|provision-seal|rendered-output-golden|live-effect)`")

ALLOWED_LOCI = {
    "dhall-typecheck",
    "gadt-decode",
    "extension-astcheck",
    "provision-seal",
    "rendered-output-golden",
    "live-effect",
}
ALLOWED_FAMILIES = {
    "accelerator",
    "backup",
    "cache",
    "capacity",
    "capability-provision",
    "image",
    "lifecycle",
    "messaging",
    "ml-asset",
    "multicluster",
    "security",
    "storage",
    "topology",
    "ui",
}


def catalog_paths(root: Path) -> list[Path]:
    directory = root / "documents" / "illegal_state"
    return sorted(
        path
        for path in directory.glob("illegal_state_*.md")
        if path.name not in {"illegal_state_catalog.md", "illegal_state_techniques.md"}
    )


def catalog_sections(root: Path) -> dict[str, tuple[Path, int, str]]:
    sections: dict[str, tuple[Path, int, str]] = {}
    for path in catalog_paths(root):
        text = path.read_text(encoding="utf-8")
        matches = list(ENTRY_RE.finditer(text))
        for index, match in enumerate(matches):
            entry = match.group(1)
            end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
            line = text.count("\n", 0, match.start()) + 1
            if entry in sections:
                raise ValueError(f"duplicate catalog entry {entry}")
            sections[entry] = (path, line, text[match.start():end])
    return sections


def read_registry(root: Path) -> tuple[list[dict[str, str]], list[str]]:
    path = root / "dhall" / "examples" / "locus_registry.tsv"
    if not path.exists():
        return [], [f"{path}: missing registry"]
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        expected = ["entry", "subcase", "validation_locus", "owner_phase", "case_family"]
        if reader.fieldnames != expected:
            return [], [f"{path}: columns must be exactly {expected}"]
        return list(reader), []


def registry_violations(root: Path) -> list[tuple[str, int | None, str]]:
    errors: list[tuple[str, int | None, str]] = []
    try:
        sections = catalog_sections(root)
    except ValueError as problem:
        return [("documents/illegal_state", None, str(problem))]
    rows, registry_errors = read_registry(root)
    errors.extend(("dhall/examples/locus_registry.tsv", None, message) for message in registry_errors)
    if registry_errors:
        return errors

    by_entry: dict[str, list[dict[str, str]]] = defaultdict(list)
    keys: set[tuple[str, str]] = set()
    for line, row in enumerate(rows, 2):
        key = (row["entry"], row["subcase"])
        if key in keys:
            errors.append(("dhall/examples/locus_registry.tsv", line, f"duplicate row {key[0]}/{key[1]}"))
        keys.add(key)
        by_entry[row["entry"]].append(row)
        if not row["subcase"] or not re.fullmatch(r"[a-z0-9][a-z0-9-]*", row["subcase"]):
            errors.append(("dhall/examples/locus_registry.tsv", line, "subcase must be non-empty kebab-case"))
        if row["validation_locus"] not in ALLOWED_LOCI:
            errors.append(("dhall/examples/locus_registry.tsv", line, f"unknown locus {row['validation_locus']}"))
        if not re.fullmatch(r"Phase-(?:[1-9]|[1-6][0-9]|7[0-4])", row["owner_phase"]):
            errors.append(("dhall/examples/locus_registry.tsv", line, f"unknown owner {row['owner_phase']}"))
        if row["case_family"] not in ALLOWED_FAMILIES:
            errors.append(("dhall/examples/locus_registry.tsv", line, f"unknown family {row['case_family']}"))

    missing = sorted(set(sections) - set(by_entry), key=lambda value: int(value.split(".")[1]))
    extra = sorted(set(by_entry) - set(sections), key=lambda value: int(value.split(".")[1]))
    if missing:
        errors.append(("dhall/examples/locus_registry.tsv", None, f"catalog entries missing rows: {', '.join(missing)}"))
    if extra:
        errors.append(("dhall/examples/locus_registry.tsv", None, f"unknown registry entries: {', '.join(extra)}"))

    for entry, (path, line, section) in sections.items():
        owner_tags = OWNER_RE.findall(section)
        family_tags = FAMILY_RE.findall(section)
        rel = str(path.relative_to(root))
        if len(owner_tags) != 1:
            errors.append((rel, line, f"entry {entry} has {len(owner_tags)} Delivery-owner tags"))
        if len(family_tags) != 1:
            errors.append((rel, line, f"entry {entry} has {len(family_tags)} Case-family tags"))
        entry_rows = by_entry.get(entry, [])
        if owner_tags and any(row["owner_phase"] != owner_tags[0] for row in entry_rows):
            errors.append((rel, line, f"entry {entry} owner diverges from registry"))
        if family_tags and any(row["case_family"] != family_tags[0] for row in entry_rows):
            errors.append((rel, line, f"entry {entry} family diverges from registry"))
        section_loci = set(LOCUS_RE.findall(section))
        for row in entry_rows:
            if row["validation_locus"] not in section_loci:
                errors.append(
                    (rel, line, f"entry {entry}/{row['subcase']} locus {row['validation_locus']} is absent from catalog text")
                )
    return errors


def apply_catalog_tags(root: Path) -> None:
    rows, errors = read_registry(root)
    if errors:
        raise SystemExit(errors[0])
    values: dict[str, tuple[str, str]] = {}
    for row in rows:
        pair = (row["owner_phase"], row["case_family"])
        if row["entry"] in values and values[row["entry"]] != pair:
            raise SystemExit(f"entry {row['entry']} has more than one owner/family pair")
        values[row["entry"]] = pair
    for path in catalog_paths(root):
        text = path.read_text(encoding="utf-8")

        def insert(match: re.Match[str]) -> str:
            entry = match.group(1)
            owner, family = values[entry]
            return f"{match.group(0)}\n\n**Delivery-owner:** `{owner}`  \n**Case-family:** `{family}`"

        rewritten = ENTRY_RE.sub(insert, text)
        path.write_text(rewritten, encoding="utf-8")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--apply-catalog-tags", action="store_true")
    args = parser.parse_args(argv)
    root = args.root.resolve()
    if args.apply_catalog_tags:
        apply_catalog_tags(root)
    violations = registry_violations(root)
    for path, line, message in violations:
        location = f"{path}:{line}" if line is not None else path
        print(f"locus_registry: {location}: {message}", file=sys.stderr)
    if violations:
        print(f"locus_registry: FAIL ({len(violations)} violation(s))", file=sys.stderr)
        return 1
    rows, _ = read_registry(root)
    print(f"locus_registry: PASS ({len(catalog_sections(root))} entries, {len(rows)} subcases)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
