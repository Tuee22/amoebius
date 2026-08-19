"""The quality floor's own behaviour, including the escape-hatch scan."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest
from pb import check_code, process


def test_tool_resolves_inside_this_environment() -> None:
    assert check_code._tool("ruff") == Path(sys.executable).parent / "ruff"


def test_tool_refuses_an_absent_checker() -> None:
    with pytest.raises(process.ProcessError, match="quality-tool-absent"):
        check_code._tool("no-such-checker")


def test_run_reports_the_child_code(
    monkeypatch: pytest.MonkeyPatch, executable
) -> None:
    monkeypatch.setattr(
        check_code, "_tool", lambda _name: executable("t", "#!/bin/sh\nexit 5\n")
    )
    assert check_code._run("t", ()) == 5


def test_scan_finds_each_escape_hatch(tmp_path: Path) -> None:
    package = tmp_path / "pb"
    package.mkdir()
    (package / "m.py").write_text(
        "from typing import Any, cast\n"
        "x: Any = 1\n"
        "y = cast(int, x)\n"
        "z = 1  # type: ignore[assignment]\n",
        encoding="utf-8",
    )
    (tmp_path / "stubs").mkdir()
    findings = check_code.scan_escape_hatches(tmp_path)
    labels = {finding.split(": ", 1)[1].split(" --")[0] for finding in findings}
    assert labels == {"explicit-Any", "cast", "type-ignore"}


def test_scan_is_silent_on_conforming_source(tmp_path: Path) -> None:
    (tmp_path / "pb").mkdir()
    (tmp_path / "stubs").mkdir()
    (tmp_path / "pb" / "m.py").write_text("x: object = 1\n", encoding="utf-8")
    assert check_code.scan_escape_hatches(tmp_path) == []


def test_scan_does_not_report_the_scanner_itself() -> None:
    """The module names each hatch in order to ban it, so its text is not evidence."""
    assert not any(
        "check_code.py" in finding for finding in check_code.scan_escape_hatches()
    )


def test_the_distribution_reaches_for_no_escape_hatch() -> None:
    assert check_code.scan_escape_hatches() == []


def test_main_stops_at_the_first_failing_step(monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[str] = []

    def fake(name: str, _arguments: object) -> int:
        calls.append(name)
        return 1 if name == "black" else 0

    monkeypatch.setattr(check_code, "_run", fake)
    assert check_code.main() == 1
    assert calls == ["ruff", "black"]


def test_main_reports_scan_findings_after_the_tools_pass(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    monkeypatch.setattr(check_code, "_run", lambda _name, _arguments: 0)
    monkeypatch.setattr(
        check_code, "scan_escape_hatches", lambda: ["pb/m.py:1: cast -- no"]
    )
    assert check_code.main() == 1
    assert "cast" in capsys.readouterr().out


def test_main_passes_when_everything_is_clean(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(check_code, "_run", lambda _name, _arguments: 0)
    monkeypatch.setattr(check_code, "scan_escape_hatches", lambda: [])
    assert check_code.main() == 0
