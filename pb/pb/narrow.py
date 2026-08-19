"""Explicit narrowing at the JSON boundary.

`mypy` runs here with `disallow_any_explicit`, so `dict[str, Any]` -- the usual
shape of a parsed JSON document -- cannot be written at all. That is deliberate
rather than inconvenient: `Any` at a boundary silently disables every downstream
check, so a document that stopped carrying a field is discovered by an
`AttributeError` three functions later instead of by the type checker.

The replacement is `object` plus these helpers. A parsed document is `object`,
and every step into it is a narrowing that either succeeds or raises naming the
path it failed at. The cost is one call per step; the gain is that a malformed
authored input is reported *as* a malformed authored input, at the field.
"""

from __future__ import annotations

import json
from collections.abc import Mapping, Sequence
from pathlib import Path


class NarrowError(RuntimeError):
    """A JSON node was not the shape the reader required, named by its path."""


def load(path: Path) -> object:
    """Parse a document without asserting anything about its shape yet."""
    try:
        parsed: object = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as problem:
        raise NarrowError(f"{path}: not valid JSON: {problem}") from problem
    return parsed


def as_mapping(value: object, where: str) -> Mapping[str, object]:
    if not isinstance(value, dict):
        raise NarrowError(f"{where}: expected an object")
    return {str(key): item for key, item in value.items()}


def as_sequence(value: object, where: str) -> Sequence[object]:
    if not isinstance(value, list):
        raise NarrowError(f"{where}: expected an array")
    return list(value)


def as_text(value: object, where: str) -> str:
    if not isinstance(value, str):
        raise NarrowError(f"{where}: expected a string")
    return value


def as_int(value: object, where: str) -> int:
    # `bool` is an `int` in Python and is never the integer a size field meant.
    if isinstance(value, bool) or not isinstance(value, int):
        raise NarrowError(f"{where}: expected an integer")
    return value


def field(node: Mapping[str, object], name: str, where: str) -> object:
    if name not in node:
        raise NarrowError(f"{where}: no {name!r} field")
    return node[name]


def text_field(node: Mapping[str, object], name: str, where: str) -> str:
    return as_text(field(node, name, where), f"{where}.{name}")


def mapping_field(node: Mapping[str, object], name: str, where: str) -> Mapping[str, object]:
    return as_mapping(field(node, name, where), f"{where}.{name}")


def sequence_field(node: Mapping[str, object], name: str, where: str) -> Sequence[object]:
    return as_sequence(field(node, name, where), f"{where}.{name}")


def int_field(node: Mapping[str, object], name: str, where: str) -> int:
    return as_int(field(node, name, where), f"{where}.{name}")


def optional_text(node: Mapping[str, object], name: str) -> str | None:
    """A field that may be absent, narrowed only when it is present."""
    value = node.get(name)
    return None if value is None else as_text(value, name)
