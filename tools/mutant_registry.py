#!/usr/bin/env python3
"""Read the one mutant registry.

`test/mutant/registry.tsv` replaced eighteen per-capability `mutants.tsv` files and a
hundred and six mutations that no file named at all. Every consumer reads it through here
so the parse — the comment convention, the field order, the capability filter — exists
once.

**One record format is not one schema.** The files this registry replaced carried eight
different shapes: the second column was `operator`, `variant`, `target`, `locus`, or
`surface` depending on the capability, and the third was `expected_locus`,
`expected_red_locus`, `expected`, `fixture`, or `token`. Flattening those into two columns
would have made the registry lie about five of them — a `locus` read as an `operator` is
not the same claim. What every mutation genuinely shares is four facts: which capability
owns it, what it is called, where its body lives, and which build flag switches it on.
Everything else is that phase's own vocabulary and travels as named `detail`, which this
module merges back into the row so a gate reads the field names it authored.

    import mutant_registry
    for row in mutant_registry.capability("chain_boundary"):
        print(row["mutant"], row["operator"], row["expected_locus"])
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "test" / "mutant" / "registry.tsv"

FIELDS = ("capability", "mutant", "body", "flag", "detail")
ABSENT = "—"
GATE_CARRIED = "gate:"


class RegistryError(RuntimeError):
    """The registry cannot be read — an authored-input failure, not a failed check."""


def rows(path: Path = REGISTRY) -> list[dict[str, str]]:
    """Every mutation, with its capability's own detail fields merged in.

    The id is exposed as both `mutant` and `id`: one capability's authored table called
    that column `id`, and a reader should not have to know which.
    """
    if not path.is_file():
        raise RegistryError(f"the mutant registry {path} is missing")
    out: list[dict[str, str]] = []
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) != len(FIELDS):
            raise RegistryError(f"{path}:{number}: expected {len(FIELDS)} tab-separated fields")
        row = dict(zip(FIELDS, (field.strip() for field in fields)))
        row["id"] = row["mutant"]
        if row["detail"] != ABSENT:
            for pair in row["detail"].split(";"):
                key, separator, value = pair.partition("=")
                if not separator:
                    raise RegistryError(f"{path}:{number}: detail {pair!r} is not key=value")
                row.setdefault(key.strip(), value.strip())
        out.append(row)
    return out


def capability(name: str, path: Path = REGISTRY) -> list[dict[str, str]]:
    """Every mutation the named capability owns, in registry order."""
    return [row for row in rows(path) if row["capability"] == name]


def bodies(path: Path = REGISTRY) -> dict[str, tuple[str, str]]:
    """Committed body path -> (capability, mutant), for the one-row-per-body check.

    A `gate:` carrier is deliberately absent from this map: the mutation is materialized
    by the named gate rather than stored as a file, so there is no body for a body check
    to join against. It is still a row, which is the point — the registry is where every
    mutation is reachable from, whichever of the three carriers holds it.
    """
    out: dict[str, tuple[str, str]] = {}
    for row in rows(path):
        if row["body"] == ABSENT or row["body"].startswith(GATE_CARRIED):
            continue
        for body in row["body"].split(","):
            out[body.strip()] = (row["capability"], row["mutant"])
    return out


def flags(path: Path = REGISTRY) -> dict[str, tuple[str, str]]:
    """Build flag -> (capability, mutant), for the no-flag-alone check."""
    return {
        row["flag"]: (row["capability"], row["mutant"])
        for row in rows(path)
        if row["flag"] != ABSENT
    }
