"""Every narrowing arm, including the ones that refuse."""

from __future__ import annotations

from pathlib import Path

import pytest
from pb import narrow


def test_load_parses(tmp_path: Path) -> None:
    document = tmp_path / "d.json"
    document.write_text('{"a": 1}', encoding="utf-8")
    assert narrow.as_mapping(narrow.load(document), "d") == {"a": 1}


def test_load_refuses_invalid_json(tmp_path: Path) -> None:
    document = tmp_path / "d.json"
    document.write_text("{", encoding="utf-8")
    with pytest.raises(narrow.NarrowError, match="not valid JSON"):
        narrow.load(document)


def test_as_mapping_refuses_non_object() -> None:
    with pytest.raises(narrow.NarrowError, match="expected an object"):
        narrow.as_mapping([1], "where")


def test_as_sequence_round_trips_and_refuses() -> None:
    assert narrow.as_sequence([1, 2], "w") == [1, 2]
    with pytest.raises(narrow.NarrowError, match="expected an array"):
        narrow.as_sequence({}, "w")


def test_as_text_round_trips_and_refuses() -> None:
    assert narrow.as_text("x", "w") == "x"
    with pytest.raises(narrow.NarrowError, match="expected a string"):
        narrow.as_text(1, "w")


def test_as_int_round_trips_and_refuses_bool() -> None:
    assert narrow.as_int(3, "w") == 3
    with pytest.raises(narrow.NarrowError, match="expected an integer"):
        narrow.as_int(True, "w")
    with pytest.raises(narrow.NarrowError, match="expected an integer"):
        narrow.as_int("3", "w")


def test_field_reports_the_missing_name() -> None:
    with pytest.raises(narrow.NarrowError, match="no 'b' field"):
        narrow.field({"a": 1}, "b", "w")
    assert narrow.field({"a": 1}, "a", "w") == 1


def test_typed_field_helpers() -> None:
    node: dict[str, object] = {"t": "s", "m": {"k": 1}, "q": [1], "n": 2}
    assert narrow.text_field(node, "t", "w") == "s"
    assert narrow.mapping_field(node, "m", "w") == {"k": 1}
    assert narrow.sequence_field(node, "q", "w") == [1]
    assert narrow.int_field(node, "n", "w") == 2


def test_optional_text_admits_absence_but_not_a_wrong_type() -> None:
    assert narrow.optional_text({}, "t") is None
    assert narrow.optional_text({"t": "v"}, "t") == "v"
    with pytest.raises(narrow.NarrowError):
        narrow.optional_text({"t": 1}, "t")
